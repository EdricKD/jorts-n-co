-- =============================================================================
-- Demo data for development. Not needed in the live store.
--
-- Load it with:  npx supabase db push --include-seed
-- Remove it later by deleting the demo products in admin (or archiving them
-- once they have orders).
-- =============================================================================

-- Delivery areas: placeholders until the real list and fees are set in admin
insert into public.delivery_zones (name, fee, sort_order) values
  ('On campus',          1000, 1),
  ('Near campus',        2000, 2),
  ('Elsewhere in Accra', 3500, 3),
  ('Outside Accra',      null, 4) -- null fee = confirmed on WhatsApp
on conflict (name) do nothing;

-- Next pop-up, five days from now, 2pm to 6pm (Ghana is on UTC all year)
insert into public.popups (title, location, starts_at, ends_at, is_published)
values (
  'Campus pop-up',
  'Location to be confirmed',
  date_trunc('day', now()) + interval '5 days 14 hours',
  date_trunc('day', now()) + interval '5 days 18 hours',
  true
);

-- Demo products, their sizes and opening stock
do $$
declare
  v_product uuid;
  v_variant uuid;
  r record;
begin
  -- 1. Baggy jeans, one size sold out
  insert into public.products (title, slug, description, category_id, department, brand, price, status, attributes, tags)
  values (
    'Baggy Light Wash Jeans', 'baggy-light-wash-jeans',
    'Loose through the hip and thigh with a relaxed straight leg. Heavy cotton denim that softens with wear.',
    (select id from public.categories where slug = 'baggy'), 'unisex', null, 25000, 'active',
    '{"fit": "baggy", "rise": "mid", "wash": "light", "material": "100% cotton", "stretch": "none"}',
    '{best-seller}'
  ) returning id into v_product;
  insert into public.product_costs (product_id, cost_price) values (v_product, 12000);

  for r in select * from (values
    ('28', 1, 2, '{"waist": 37, "hip": 50, "front_rise": 29, "thigh": 32, "knee": 24, "leg_opening": 22, "inseam": 78, "outseam": 107}'),
    ('30', 2, 5, '{"waist": 39, "hip": 52, "front_rise": 30, "thigh": 33, "knee": 25, "leg_opening": 23, "inseam": 79, "outseam": 109}'),
    ('32', 3, 0, '{"waist": 41, "hip": 54, "front_rise": 31, "thigh": 34, "knee": 26, "leg_opening": 23, "inseam": 80, "outseam": 111}'),
    ('34', 4, 3, '{"waist": 43, "hip": 56, "front_rise": 32, "thigh": 35, "knee": 27, "leg_opening": 24, "inseam": 80, "outseam": 112}'),
    ('36', 5, 1, '{"waist": 45, "hip": 58, "front_rise": 33, "thigh": 36, "knee": 28, "leg_opening": 25, "inseam": 81, "outseam": 114}')
  ) as t(size_label, position, stock, measurements) loop
    insert into public.variants (product_id, size_label, position, measurements)
    values (v_product, r.size_label, r.position, r.measurements::jsonb)
    returning id into v_variant;
    if r.stock > 0 then
      perform private.apply_stock_change(v_variant, r.stock, 'restock', 'Opening stock');
    end if;
  end loop;

  -- 2. Jorts on sale
  insert into public.products (title, slug, description, category_id, department, price, compare_at_price, status, attributes, tags)
  values (
    'Washed Black Jorts', 'washed-black-jorts',
    'Knee-length denim shorts in a faded black wash. Wide leg, raw hem.',
    (select id from public.categories where slug = 'jorts'), 'men', 15000, 18000, 'active',
    '{"fit": "baggy", "rise": "mid", "wash": "black", "material": "100% cotton", "stretch": "none"}',
    '{sale}'
  ) returning id into v_product;
  insert into public.product_costs (product_id, cost_price) values (v_product, 7000);

  for r in select * from (values
    ('30', 1, 4, '{"waist": 39, "hip": 53, "front_rise": 30, "thigh": 35, "leg_opening": 31, "inseam": 25}'),
    ('32', 2, 4, '{"waist": 41, "hip": 55, "front_rise": 31, "thigh": 36, "leg_opening": 32, "inseam": 25}'),
    ('34', 3, 2, '{"waist": 43, "hip": 57, "front_rise": 32, "thigh": 37, "leg_opening": 33, "inseam": 26}')
  ) as t(size_label, position, stock, measurements) loop
    insert into public.variants (product_id, size_label, position, measurements)
    values (v_product, r.size_label, r.position, r.measurements::jsonb)
    returning id into v_variant;
    perform private.apply_stock_change(v_variant, r.stock, 'restock', 'Opening stock');
  end loop;

  -- 3. Graphic tee in two colours
  insert into public.products (title, slug, description, category_id, department, price, status, attributes, tags)
  values (
    'Boxy Graphic Tee', 'boxy-graphic-tee',
    'Heavyweight cotton tee with a boxy, slightly cropped fit and a back print.',
    (select id from public.categories where slug = 'graphic-tees'), 'unisex', 12000, 'active',
    '{"fit": "boxy", "material": "100% cotton"}',
    '{popup-drop}'
  ) returning id into v_product;

  for r in select * from (values
    ('M',  'Black', 1, 3, '{"chest": 57, "length": 68, "shoulder": 54, "sleeve": 22}'),
    ('L',  'Black', 2, 2, '{"chest": 60, "length": 70, "shoulder": 56, "sleeve": 23}'),
    ('XL', 'Black', 3, 1, '{"chest": 63, "length": 72, "shoulder": 58, "sleeve": 24}'),
    ('M',  'White', 1, 2, '{"chest": 57, "length": 68, "shoulder": 54, "sleeve": 22}'),
    ('L',  'White', 2, 0, '{"chest": 60, "length": 70, "shoulder": 56, "sleeve": 23}')
  ) as t(size_label, colour, position, stock, measurements) loop
    insert into public.variants (product_id, size_label, colour, position, measurements)
    values (v_product, r.size_label, r.colour, r.position, r.measurements::jsonb)
    returning id into v_variant;
    if r.stock > 0 then
      perform private.apply_stock_change(v_variant, r.stock, 'restock', 'Opening stock');
    end if;
  end loop;

  -- 4. Chain
  insert into public.products (title, slug, description, category_id, department, price, status, attributes)
  values (
    'Cuban Link Chain', 'cuban-link-chain',
    '6 mm Cuban link with a box clasp. Stainless steel, so it won''t turn your neck green.',
    (select id from public.categories where slug = 'chains-necklaces'), 'unisex', 9000, 'active',
    '{"material": "stainless steel", "plating": "18k gold", "stone": "none", "water_resistant": true, "tarnish_resistant": true}'
  ) returning id into v_product;

  for r in select * from (values
    ('50 cm', 1, 6, '{"length": 50, "thickness": 0.6}'),
    ('60 cm', 2, 4, '{"length": 60, "thickness": 0.6}')
  ) as t(size_label, position, stock, measurements) loop
    insert into public.variants (product_id, size_label, position, measurements)
    values (v_product, r.size_label, r.position, r.measurements::jsonb)
    returning id into v_variant;
    perform private.apply_stock_change(v_variant, r.stock, 'restock', 'Opening stock');
  end loop;

  -- 5. Denim skirt
  insert into public.products (title, slug, description, category_id, department, price, status, attributes, tags)
  values (
    'Denim Mini Skirt', 'denim-mini-skirt',
    'Mid-wash mini with a raw hem and a little stretch.',
    (select id from public.categories where slug = 'denim-skirts'), 'women', 14000, 'active',
    '{"wash": "mid", "material": "98% cotton, 2% elastane", "stretch": "slight"}',
    '{}'
  ) returning id into v_product;

  for r in select * from (values
    ('S', 1, 2, '{"waist": 35, "hip": 47, "length": 38}'),
    ('M', 2, 3, '{"waist": 37, "hip": 49, "length": 39}'),
    ('L', 3, 1, '{"waist": 39, "hip": 51, "length": 40}')
  ) as t(size_label, position, stock, measurements) loop
    insert into public.variants (product_id, size_label, position, measurements)
    values (v_product, r.size_label, r.position, r.measurements::jsonb)
    returning id into v_variant;
    perform private.apply_stock_change(v_variant, r.stock, 'restock', 'Opening stock');
  end loop;

  -- 6. A draft, to check shoppers can't see unpublished products
  insert into public.products (title, slug, category_id, department, price, status)
  values (
    'Carpenter Jeans (draft)', 'carpenter-jeans-draft',
    (select id from public.categories where slug = 'carpenter'), 'men', 28000, 'draft'
  ) returning id into v_product;
  insert into public.variants (product_id, size_label, position) values (v_product, '32', 1);
end;
$$;
