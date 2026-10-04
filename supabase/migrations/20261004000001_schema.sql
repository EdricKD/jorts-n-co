-- =============================================================================
-- Jorts & Co. core schema
--
-- Conventions
--   * Money is stored as whole pesewas (GH₵ 1.00 = 100) in integer columns.
--     Integers add up exactly; floating-point numbers don't.
--   * Measurements are stored in centimetres. Widths (waist, chest, thigh…)
--     are measured flat, the way you'd lay a garment on a table.
--   * stock_qty is never written directly. It only changes through the
--     functions in the stock/orders migration, which also log every change.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Enums: fixed lists. Generated TypeScript types turn these into exact unions.
-- -----------------------------------------------------------------------------
create type public.department as enum ('men', 'women', 'unisex');

create type public.product_status as enum ('draft', 'active', 'archived');

-- Which measurement fields a category uses. The field definitions (labels,
-- units, diagrams) live in src/lib/measurements.ts.
create type public.measurement_template as enum (
  'long_bottoms',
  'shorts',
  'tops',
  'skirts_dresses',
  'sets',
  'necklaces',
  'bracelets',
  'rings',
  'earrings',
  'belts',
  'caps_bags',
  'footwear',
  'none'
);

create type public.stock_reason as enum (
  'restock',
  'online_sale',
  'popup_sale',
  'adjustment',
  'return',
  'damaged',
  'cancelled'
);

create type public.order_status as enum ('pending', 'confirmed', 'ready', 'completed', 'cancelled');
create type public.fulfilment as enum ('pickup', 'delivery');
create type public.payment_method as enum ('cash', 'momo');
create type public.payment_status as enum ('unpaid', 'paid', 'refunded');
create type public.sales_channel as enum ('online', 'popup');

-- -----------------------------------------------------------------------------
-- Shared trigger: keep updated_at current
-- -----------------------------------------------------------------------------
create function public.set_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Categories (two levels: Jeans → Baggy)
-- -----------------------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 60),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  parent_id uuid references public.categories (id) on delete restrict,
  -- null on a subcategory means "use the parent's template"
  measurement_template public.measurement_template,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  check (parent_id is distinct from id)
);

create index categories_parent_id_idx on public.categories (parent_id);

create function public.enforce_category_depth() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.parent_id is not null then
    if exists (select 1 from public.categories where id = new.parent_id and parent_id is not null) then
      raise exception 'Categories can only be two levels deep';
    end if;
    if exists (select 1 from public.categories where parent_id = new.id) then
      raise exception 'A category that has subcategories cannot itself become a subcategory';
    end if;
  end if;
  return new;
end;
$$;

create trigger categories_enforce_depth
before insert or update of parent_id on public.categories
for each row execute function public.enforce_category_depth();

-- -----------------------------------------------------------------------------
-- Products
-- -----------------------------------------------------------------------------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  -- Short running number used to build readable SKUs (JC-0042-32-BLA)
  code integer generated always as identity unique,
  title text not null check (length(trim(title)) between 1 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text not null default '',
  category_id uuid not null references public.categories (id) on delete restrict,
  department public.department not null default 'unisex',
  brand text,
  price integer not null check (price >= 0),
  -- "Was" price. Only valid when higher than price; that's what makes it a sale.
  compare_at_price integer check (compare_at_price > price),
  status public.product_status not null default 'draft',
  -- fit, rise, wash, material, stretch, plating, stone, water_resistant…
  attributes jsonb not null default '{}' check (jsonb_typeof(attributes) = 'object'),
  -- Drive collections: best-seller, sale, popup-drop
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_category_id_idx on public.products (category_id);
create index products_status_created_at_idx on public.products (status, created_at desc);
create index products_attributes_idx on public.products using gin (attributes);
create index products_tags_idx on public.products using gin (tags);

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

-- Cost price lives in its own table because Row Level Security works on rows,
-- not columns. Shoppers can read products; nobody but the owner can read this.
create table public.product_costs (
  product_id uuid primary key references public.products (id) on delete cascade,
  cost_price integer not null check (cost_price >= 0),
  updated_at timestamptz not null default now()
);

create trigger product_costs_set_updated_at
before update on public.product_costs
for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Product images (files live in the product-images storage bucket)
-- -----------------------------------------------------------------------------
create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  storage_path text not null unique,
  alt text not null default '',
  position integer not null default 0, -- 0 is the cover
  colour text, -- optional: show this photo when that colour is picked
  width integer check (width > 0),
  height integer check (height > 0),
  created_at timestamptz not null default now()
);

create index product_images_product_id_position_idx on public.product_images (product_id, position);

-- -----------------------------------------------------------------------------
-- Variants: one row per size (and colour). Stock lives here.
-- -----------------------------------------------------------------------------
create table public.variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  sku text not null default '' unique, -- '' means "generate one" (see trigger)
  size_label text not null check (length(trim(size_label)) between 1 and 20),
  colour text,
  position integer not null default 0, -- size order: 28 < 30 < 32, S < M < L
  stock_qty integer not null default 0 check (stock_qty >= 0),
  low_stock_threshold integer not null default 2 check (low_stock_threshold >= 0),
  measurements jsonb not null default '{}' check (jsonb_typeof(measurements) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (product_id, size_label, colour)
);

create index variants_product_id_position_idx on public.variants (product_id, position);

create trigger variants_set_updated_at
before update on public.variants
for each row execute function public.set_updated_at();

-- Builds SKUs like JC-0042-32 or JC-0042-M-BLA. If two colours abbreviate the
-- same way (Grey/Green → GRE), a number is added so SKUs stay unique.
create function public.set_variant_sku() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_base text;
  v_candidate text;
  v_n integer := 1;
begin
  if trim(new.sku) <> '' then
    new.sku := upper(trim(new.sku));
    return new;
  end if;

  select 'JC-' || lpad(p.code::text, 4, '0') into v_base
  from public.products p
  where p.id = new.product_id;

  v_base := v_base || '-' || coalesce(
    nullif(upper(regexp_replace(new.size_label, '[^a-zA-Z0-9]', '', 'g')), ''),
    'OS'
  );

  if nullif(trim(new.colour), '') is not null then
    v_base := v_base || '-' || upper(left(regexp_replace(new.colour, '[^a-zA-Z]', '', 'g'), 3));
  end if;

  v_candidate := v_base;
  while exists (select 1 from public.variants where sku = v_candidate) loop
    v_n := v_n + 1;
    v_candidate := v_base || '-' || v_n;
  end loop;

  new.sku := v_candidate;
  return new;
end;
$$;

create trigger variants_set_sku
before insert on public.variants
for each row execute function public.set_variant_sku();

-- -----------------------------------------------------------------------------
-- Pop-ups and delivery areas
-- -----------------------------------------------------------------------------
create table public.popups (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 80),
  location text not null check (length(trim(location)) between 1 and 160),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index popups_starts_at_idx on public.popups (starts_at);

create table public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(trim(name)) between 1 and 60),
  fee integer check (fee >= 0), -- null = "fee confirmed on WhatsApp"
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Orders
-- -----------------------------------------------------------------------------
create sequence public.order_number_seq start with 1001;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('JC-' || nextval('public.order_number_seq')),
  -- Random, unguessable id for the customer's confirmation page link
  public_token uuid not null unique default gen_random_uuid(),
  channel public.sales_channel not null default 'online',
  status public.order_status not null default 'pending',
  customer_name text check (length(trim(customer_name)) between 1 and 80),
  phone text check (phone ~ '^\+233[25][0-9]{8}$'), -- Ghana mobile, stored as +233…
  fulfilment public.fulfilment not null default 'pickup',
  popup_id uuid references public.popups (id) on delete set null,
  delivery_zone_id uuid references public.delivery_zones (id) on delete set null,
  delivery_zone_name text, -- snapshot, in case the zone is renamed later
  delivery_address text check (length(delivery_address) <= 300),
  payment_method public.payment_method not null default 'cash',
  payment_status public.payment_status not null default 'unpaid',
  payment_reference text, -- MoMo transaction ID
  subtotal integer not null check (subtotal >= 0),
  delivery_fee integer check (delivery_fee >= 0), -- null = not quoted yet
  discount integer not null default 0 check (discount >= 0),
  -- Computed by the database so it can never disagree with its parts
  total integer generated always as (subtotal + coalesce(delivery_fee, 0) - discount) stored,
  notes text,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_online_needs_contact
    check (channel = 'popup' or (customer_name is not null and phone is not null)),
  constraint orders_delivery_needs_address
    check (fulfilment = 'pickup' or delivery_address is not null),
  constraint orders_total_not_negative
    check (subtotal + coalesce(delivery_fee, 0) - discount >= 0)
);

create index orders_status_created_at_idx on public.orders (status, created_at desc);
create index orders_phone_idx on public.orders (phone);
create index orders_popup_id_idx on public.orders (popup_id);

create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

-- Cancelling must go through cancel_order() so stock is put back, and a
-- cancelled order can't be reopened (its stock has already been returned).
create function public.guard_order_status() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'cancelled' and new.status <> 'cancelled' then
    raise exception 'A cancelled order cannot be reopened';
  end if;
  if new.status = 'cancelled' and old.status <> 'cancelled'
     and coalesce(current_setting('app.cancelling_order', true), '') <> 'on' then
    raise exception 'Use cancel_order() so the stock is restored';
  end if;
  return new;
end;
$$;

create trigger orders_guard_status
before update of status on public.orders
for each row execute function public.guard_order_status();

-- Each line is a snapshot: later edits to a product don't change past orders.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  -- restrict: a product that has been sold can be archived, not deleted
  variant_id uuid not null references public.variants (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  title text not null,
  size_label text not null,
  colour text,
  sku text not null,
  unit_price integer not null check (unit_price >= 0),
  qty integer not null check (qty > 0),
  line_total integer generated always as (unit_price * qty) stored
);

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_variant_id_idx on public.order_items (variant_id);
create index order_items_product_id_idx on public.order_items (product_id);

-- -----------------------------------------------------------------------------
-- Stock ledger: one row per change, with the balance after it
-- -----------------------------------------------------------------------------
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.variants (id) on delete cascade,
  delta integer not null check (delta <> 0),
  stock_after integer not null check (stock_after >= 0),
  reason public.stock_reason not null,
  note text,
  order_id uuid references public.orders (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index stock_movements_variant_id_created_at_idx on public.stock_movements (variant_id, created_at desc);
create index stock_movements_order_id_idx on public.stock_movements (order_id);

-- -----------------------------------------------------------------------------
-- Admins: which logged-in users count as the owner
-- -----------------------------------------------------------------------------
create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
