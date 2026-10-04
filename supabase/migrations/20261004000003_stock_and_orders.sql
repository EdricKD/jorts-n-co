-- =============================================================================
-- Stock and order functions
--
-- Every stock change goes through private.apply_stock_change(), which updates
-- variants.stock_qty and writes a stock_movements row in the same transaction.
--
-- "security definer" functions run with the database owner's rights, so they
-- can write tables the caller can't touch directly. That's why each one
-- checks its own inputs and who is calling.
--
-- Postgres lets everyone (PUBLIC) execute new functions by default, so each
-- public function below revokes that and grants only the roles that need it.
-- =============================================================================

-- The "private" schema isn't exposed through the Supabase API.
create schema if not exists private;
revoke all on schema private from public;

-- -----------------------------------------------------------------------------
-- Core: change one variant's stock and log it
-- -----------------------------------------------------------------------------
create function private.apply_stock_change(
  p_variant_id uuid,
  p_delta integer,
  p_reason public.stock_reason,
  p_note text default null,
  p_order_id uuid default null
) returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_current integer;
  v_new integer;
begin
  if p_delta is null or p_delta = 0 then
    raise exception 'Stock change must be a non-zero number';
  end if;

  -- Lock the row so two changes to the same size can't interleave.
  select stock_qty into v_current
  from public.variants
  where id = p_variant_id
  for update;

  if not found then
    raise exception 'Variant % not found', p_variant_id;
  end if;

  if v_current + p_delta < 0 then
    raise exception 'Not enough stock: % left, tried to remove %', v_current, -p_delta;
  end if;

  update public.variants
  set stock_qty = stock_qty + p_delta
  where id = p_variant_id
  returning stock_qty into v_new;

  insert into public.stock_movements (variant_id, delta, stock_after, reason, note, order_id, created_by)
  values (p_variant_id, p_delta, v_new, p_reason, nullif(trim(p_note), ''), p_order_id, (select auth.uid()));

  return v_new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Core: create an order from a cart, all or nothing
--
-- p_items is a JSON array: [{"variant_id": "…", "qty": 2}, …]
-- Returns {"ok": true, "order_number": …, "token": …}
--      or {"ok": false, "problems": [{variant_id, title, size_label, requested, available, reason}]}
-- On "ok": false nothing is written.
-- -----------------------------------------------------------------------------
create function private.create_order(
  p_items jsonb,
  p_channel public.sales_channel,
  p_customer_name text,
  p_phone text,
  p_fulfilment public.fulfilment,
  p_payment_method public.payment_method,
  p_popup_id uuid,
  p_delivery_zone_id uuid,
  p_delivery_address text,
  p_notes text,
  p_discount integer,
  p_payment_reference text
) returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_max_qty constant integer := case when p_channel = 'online' then 10 else 100 end;
  v_lines jsonb;
  v_problems jsonb := '[]'::jsonb;
  v_subtotal integer := 0;
  v_delivery_fee integer := 0;
  v_zone_name text;
  v_order public.orders;
  r record;
begin
  -- 1. Check the cart's shape and merge duplicate lines
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'The cart is empty';
  end if;
  if jsonb_array_length(p_items) > 30 then
    raise exception 'Too many lines in one order';
  end if;

  select jsonb_agg(jsonb_build_object('variant_id', variant_id, 'qty', qty) order by variant_id)
  into v_lines
  from (
    select (item ->> 'variant_id')::uuid as variant_id, sum((item ->> 'qty')::integer)::integer as qty
    from jsonb_array_elements(p_items) as item
    group by 1
  ) merged;

  if exists (
    select 1 from jsonb_to_recordset(v_lines) as l(variant_id uuid, qty integer)
    where l.variant_id is null or l.qty is null or l.qty < 1 or l.qty > v_max_qty
  ) then
    raise exception 'Each item needs a quantity between 1 and %', v_max_qty;
  end if;

  -- 2. Check the customer details
  if p_channel = 'online' then
    if p_customer_name is null or length(trim(p_customer_name)) not between 1 and 80 then
      raise exception 'Please enter your name';
    end if;
    if p_phone is null or p_phone !~ '^\+233[25][0-9]{8}$' then
      raise exception 'Please enter a valid Ghana phone number';
    end if;
    -- Stops one number from holding all the stock with orders it never collects
    if (
      select count(*) from public.orders
      where phone = p_phone and channel = 'online' and status = 'pending'
    ) >= 3 then
      raise exception 'You already have 3 orders waiting. Message us on WhatsApp to add to one.';
    end if;
  end if;

  if p_fulfilment = 'delivery' then
    select z.name, z.fee into v_zone_name, v_delivery_fee
    from public.delivery_zones z
    where z.id = p_delivery_zone_id and z.is_active;
    if not found then
      raise exception 'Please choose a delivery area';
    end if;
    if p_delivery_address is null or length(trim(p_delivery_address)) < 3 then
      raise exception 'Please add a delivery address';
    end if;
  elsif p_popup_id is not null and not exists (
    select 1 from public.popups
    where id = p_popup_id and (p_channel = 'popup' or (is_published and ends_at > now()))
  ) then
    raise exception 'That pop-up is not available for pickup';
  end if;

  -- 3. Lock every variant in the cart. Locking in id order means two
  --    checkouts with overlapping carts queue up instead of deadlocking.
  perform 1
  from public.variants
  where id in (select (l ->> 'variant_id')::uuid from jsonb_array_elements(v_lines) as l)
  order by id
  for update;

  -- 4. Check stock for every line. Prices come from the database, never the cart.
  for r in
    select l.variant_id, l.qty, v.stock_qty, v.size_label, p.title, p.price, p.status
    from jsonb_to_recordset(v_lines) as l(variant_id uuid, qty integer)
    left join public.variants v on v.id = l.variant_id
    left join public.products p on p.id = v.product_id
  loop
    if r.title is null or (p_channel = 'online' and r.status <> 'active') then
      v_problems := v_problems || jsonb_build_object(
        'variant_id', r.variant_id, 'title', r.title, 'size_label', r.size_label,
        'requested', r.qty, 'available', 0, 'reason', 'unavailable');
    elsif r.stock_qty < r.qty then
      v_problems := v_problems || jsonb_build_object(
        'variant_id', r.variant_id, 'title', r.title, 'size_label', r.size_label,
        'requested', r.qty, 'available', r.stock_qty,
        'reason', case when r.stock_qty = 0 then 'sold_out' else 'not_enough' end);
    else
      v_subtotal := v_subtotal + r.price * r.qty;
    end if;
  end loop;

  if jsonb_array_length(v_problems) > 0 then
    return jsonb_build_object('ok', false, 'problems', v_problems);
  end if;

  if coalesce(p_discount, 0) < 0 or coalesce(p_discount, 0) > v_subtotal then
    raise exception 'Discount must be between 0 and the subtotal';
  end if;

  -- 5. Write the order, its lines and the stock changes
  insert into public.orders (
    channel, status, customer_name, phone, fulfilment, popup_id,
    delivery_zone_id, delivery_zone_name, delivery_address,
    payment_method, payment_status, payment_reference,
    subtotal, delivery_fee, discount, notes
  ) values (
    p_channel,
    case when p_channel = 'popup' then 'completed' else 'pending' end::public.order_status,
    nullif(trim(p_customer_name), ''),
    nullif(trim(p_phone), ''),
    p_fulfilment,
    case when p_fulfilment = 'pickup' then p_popup_id end,
    case when p_fulfilment = 'delivery' then p_delivery_zone_id end,
    v_zone_name,
    case when p_fulfilment = 'delivery' then trim(p_delivery_address) end,
    p_payment_method,
    case when p_channel = 'popup' then 'paid' else 'unpaid' end::public.payment_status,
    nullif(trim(p_payment_reference), ''),
    v_subtotal,
    case when p_fulfilment = 'pickup' then 0 else v_delivery_fee end,
    coalesce(p_discount, 0),
    nullif(trim(p_notes), '')
  )
  returning * into v_order;

  insert into public.order_items (order_id, variant_id, product_id, title, size_label, colour, sku, unit_price, qty)
  select v_order.id, v.id, p.id, p.title, v.size_label, v.colour, v.sku, p.price, l.qty
  from jsonb_to_recordset(v_lines) as l(variant_id uuid, qty integer)
  join public.variants v on v.id = l.variant_id
  join public.products p on p.id = v.product_id;

  for r in
    select l.variant_id, l.qty from jsonb_to_recordset(v_lines) as l(variant_id uuid, qty integer)
  loop
    perform private.apply_stock_change(
      r.variant_id,
      -r.qty,
      case when p_channel = 'popup' then 'popup_sale' else 'online_sale' end::public.stock_reason,
      null,
      v_order.id
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'token', v_order.public_token,
    'total', v_order.total
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Public: shopper checkout
-- -----------------------------------------------------------------------------
create function public.place_order(
  p_items jsonb,
  p_customer_name text,
  p_phone text,
  p_fulfilment public.fulfilment,
  p_payment_method public.payment_method,
  p_popup_id uuid default null,
  p_delivery_zone_id uuid default null,
  p_delivery_address text default null,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.create_order(
    p_items, 'online', p_customer_name, p_phone, p_fulfilment, p_payment_method,
    p_popup_id, p_delivery_zone_id, p_delivery_address, p_notes, 0, null
  );
end;
$$;

revoke execute on function public.place_order(jsonb, text, text, public.fulfilment, public.payment_method, uuid, uuid, text, text) from public;
grant execute on function public.place_order(jsonb, text, text, public.fulfilment, public.payment_method, uuid, uuid, text, text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Public: confirmation page lookup by the order's random token
-- -----------------------------------------------------------------------------
create function public.get_order(p_token uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'order_number', o.order_number,
    'status', o.status,
    'customer_name', o.customer_name,
    'phone', o.phone,
    'fulfilment', o.fulfilment,
    'delivery_zone_name', o.delivery_zone_name,
    'delivery_address', o.delivery_address,
    'payment_method', o.payment_method,
    'payment_status', o.payment_status,
    'subtotal', o.subtotal,
    'delivery_fee', o.delivery_fee,
    'discount', o.discount,
    'total', o.total,
    'created_at', o.created_at,
    'popup', case when pu.id is null then null else jsonb_build_object(
      'title', pu.title, 'location', pu.location, 'starts_at', pu.starts_at, 'ends_at', pu.ends_at
    ) end,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'title', i.title, 'size_label', i.size_label, 'colour', i.colour,
        'unit_price', i.unit_price, 'qty', i.qty, 'line_total', i.line_total
      ) order by i.title, i.size_label)
      from public.order_items i
      where i.order_id = o.id
    ), '[]'::jsonb)
  )
  from public.orders o
  left join public.popups pu on pu.id = o.popup_id
  where o.public_token = p_token;
$$;

revoke execute on function public.get_order(uuid) from public;
grant execute on function public.get_order(uuid) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Owner: record a sale at a pop-up (completed and paid immediately)
-- -----------------------------------------------------------------------------
create function public.record_popup_sale(
  p_items jsonb,
  p_payment_method public.payment_method,
  p_popup_id uuid default null,
  p_payment_reference text default null,
  p_discount integer default 0,
  p_customer_name text default null,
  p_phone text default null,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return private.create_order(
    p_items, 'popup', p_customer_name, p_phone, 'pickup', p_payment_method,
    p_popup_id, null, null, p_notes, p_discount, p_payment_reference
  );
end;
$$;

revoke execute on function public.record_popup_sale(jsonb, public.payment_method, uuid, text, integer, text, text, text) from public, anon;
grant execute on function public.record_popup_sale(jsonb, public.payment_method, uuid, text, integer, text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Owner: cancel an order and put its stock back. Safe to run twice.
-- -----------------------------------------------------------------------------
create function public.cancel_order(p_order_id uuid, p_note text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.order_status;
  r record;
begin
  if not public.is_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  select status into v_status from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_status = 'cancelled' then
    return jsonb_build_object('ok', true, 'already_cancelled', true);
  end if;

  -- Tell the guard trigger this cancellation is coming from here
  perform set_config('app.cancelling_order', 'on', true);
  update public.orders
  set status = 'cancelled',
      cancelled_at = now(),
      notes = case
        when nullif(trim(p_note), '') is null then notes
        else concat_ws(E'\n', notes, 'Cancelled: ' || trim(p_note))
      end
  where id = p_order_id;
  perform set_config('app.cancelling_order', 'off', true);

  for r in
    select variant_id, qty from public.order_items where order_id = p_order_id order by variant_id
  loop
    perform private.apply_stock_change(r.variant_id, r.qty, 'cancelled', p_note, p_order_id);
  end loop;

  return jsonb_build_object('ok', true, 'already_cancelled', false);
end;
$$;

revoke execute on function public.cancel_order(uuid, text) from public, anon;
grant execute on function public.cancel_order(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Owner: restock, correct a count, log a return or damaged item
-- -----------------------------------------------------------------------------
create function public.adjust_stock(
  p_variant_id uuid,
  p_delta integer,
  p_reason public.stock_reason,
  p_note text default null
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  if p_reason not in ('restock', 'adjustment', 'return', 'damaged') then
    raise exception 'Sales and cancellations are recorded through orders';
  end if;
  if p_reason in ('restock', 'return') and p_delta <= 0 then
    raise exception 'A % adds stock, so the number must be positive', p_reason;
  end if;
  if p_reason = 'damaged' and p_delta >= 0 then
    raise exception 'Damaged stock is removed, so the number must be negative';
  end if;
  return private.apply_stock_change(p_variant_id, p_delta, p_reason, p_note);
end;
$$;

revoke execute on function public.adjust_stock(uuid, integer, public.stock_reason, text) from public, anon;
grant execute on function public.adjust_stock(uuid, integer, public.stock_reason, text) to authenticated;
