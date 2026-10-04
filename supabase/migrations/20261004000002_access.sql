-- =============================================================================
-- Who can see and change what
--
-- Two layers:
--   1. GRANTs decide which tables/columns a role may touch at all.
--   2. Row Level Security (RLS) policies decide which rows.
--
-- Roles: "anon" is any shopper (no login). "authenticated" is anyone logged
-- in, but the policies below only let users listed in public.admins through.
-- =============================================================================

create function public.is_admin() returns boolean
language sql
stable
security definer -- reads public.admins, which nobody can query directly
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- -----------------------------------------------------------------------------
-- Grants. Supabase grants everything by default; start from nothing instead.
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- Shoppers can only read, and RLS narrows that to public rows.
grant select on
  public.categories,
  public.products,
  public.product_images,
  public.variants,
  public.popups,
  public.delivery_zones
to anon, authenticated;

-- The owner edits the catalogue directly (RLS checks is_admin() on each row).
grant insert, update, delete on
  public.categories,
  public.products,
  public.product_images,
  public.popups,
  public.delivery_zones
to authenticated;

grant select, insert, update, delete on public.product_costs to authenticated;

-- Variants: every column except stock_qty. Stock only moves through
-- adjust_stock() and the order functions, so every change is logged.
grant delete on public.variants to authenticated;
grant insert (product_id, sku, size_label, colour, position, low_stock_threshold, measurements)
  on public.variants to authenticated;
grant update (sku, size_label, colour, position, low_stock_threshold, measurements)
  on public.variants to authenticated;

-- Orders are created by functions only. The owner can read them and update
-- the fields that change while handling an order. Totals and line items are
-- fixed once placed.
grant select on public.orders, public.order_items, public.stock_movements to authenticated;
grant update (
  status,
  customer_name,
  phone,
  popup_id,
  delivery_zone_id,
  delivery_zone_name,
  delivery_address,
  payment_method,
  payment_status,
  payment_reference,
  delivery_fee,
  discount,
  notes
) on public.orders to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_costs enable row level security;
alter table public.product_images enable row level security;
alter table public.variants enable row level security;
alter table public.popups enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.admins enable row level security; -- no policies: API can't see it

-- Wrapping is_admin() in (select …) makes Postgres run it once per query
-- instead of once per row.

-- categories
create policy "Anyone can view categories"
  on public.categories for select to anon, authenticated
  using (true);
create policy "Owner manages categories"
  on public.categories for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- products
create policy "Anyone can view active products"
  on public.products for select to anon, authenticated
  using (status = 'active');
create policy "Owner manages products"
  on public.products for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- product_costs: owner only
create policy "Owner manages product costs"
  on public.product_costs for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- product_images
create policy "Anyone can view images of active products"
  on public.product_images for select to anon, authenticated
  using (exists (
    select 1 from public.products p where p.id = product_id and p.status = 'active'
  ));
create policy "Owner manages product images"
  on public.product_images for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- variants
create policy "Anyone can view variants of active products"
  on public.variants for select to anon, authenticated
  using (exists (
    select 1 from public.products p where p.id = product_id and p.status = 'active'
  ));
create policy "Owner manages variants"
  on public.variants for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- popups
create policy "Anyone can view published pop-ups"
  on public.popups for select to anon, authenticated
  using (is_published);
create policy "Owner manages pop-ups"
  on public.popups for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- delivery_zones
create policy "Anyone can view active delivery areas"
  on public.delivery_zones for select to anon, authenticated
  using (is_active);
create policy "Owner manages delivery areas"
  on public.delivery_zones for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- orders, order_items, stock_movements: owner only. Shoppers create orders
-- through place_order() and read them back through get_order().
create policy "Owner reads orders"
  on public.orders for select to authenticated
  using ((select public.is_admin()));
create policy "Owner updates orders"
  on public.orders for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "Owner reads order items"
  on public.order_items for select to authenticated
  using ((select public.is_admin()));

create policy "Owner reads stock history"
  on public.stock_movements for select to authenticated
  using ((select public.is_admin()));

-- -----------------------------------------------------------------------------
-- Product photo storage: public to view, owner-only to change
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  2097152, -- 2 MB. Photos are resized in the browser first, so this is plenty.
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do nothing;

create policy "Owner lists product images"
  on storage.objects for select to authenticated
  using (bucket_id = 'product-images' and (select public.is_admin()));
create policy "Owner uploads product images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and (select public.is_admin()));
create policy "Owner updates product images"
  on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and (select public.is_admin()));
create policy "Owner deletes product images"
  on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and (select public.is_admin()));
