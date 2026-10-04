-- =============================================================================
-- Category taxonomy
--
-- This is real store data, not demo data, so it's a migration (it runs on
-- every database) rather than part of seed.sql (which is for demo content).
-- A subcategory with no measurement_template uses its parent's.
-- =============================================================================

insert into public.categories (name, slug, measurement_template, sort_order) values
  ('Jeans',            'jeans',          'long_bottoms',   1),
  ('Shorts',           'shorts',         'shorts',         2),
  ('Pants',            'pants',          'long_bottoms',   3),
  ('Tops',             'tops',           'tops',           4),
  ('Outerwear',        'outerwear',      'tops',           5),
  ('Skirts & Dresses', 'skirts-dresses', 'skirts_dresses', 6),
  ('Sets',             'sets',           'sets',           7),
  ('Jewelry',          'jewelry',        'none',           8),
  ('Accessories',      'accessories',    'none',           9),
  ('Footwear',         'footwear',       'footwear',       10);

insert into public.categories (name, slug, parent_id, measurement_template, sort_order)
select c.name, c.slug, p.id, c.template::public.measurement_template, c.sort_order
from (values
  ('jeans', 'Baggy',               'baggy',             null, 1),
  ('jeans', 'Straight',            'straight',          null, 2),
  ('jeans', 'Slim',                'slim',              null, 3),
  ('jeans', 'Skinny',              'skinny',            null, 4),
  ('jeans', 'Wide-leg',            'wide-leg',          null, 5),
  ('jeans', 'Bootcut & Flare',     'bootcut-flare',     null, 6),
  ('jeans', 'Cargo jeans',         'cargo-jeans',       null, 7),
  ('jeans', 'Carpenter',           'carpenter',         null, 8),
  ('jeans', 'Ripped & Distressed', 'ripped-distressed', null, 9),

  ('shorts', 'Jorts',         'jorts',         null, 1),
  ('shorts', 'Jogger shorts', 'jogger-shorts', null, 2),
  ('shorts', 'Cargo shorts',  'cargo-shorts',  null, 3),
  ('shorts', 'Sweat shorts',  'sweat-shorts',  null, 4),
  ('shorts', 'Mesh shorts',   'mesh-shorts',   null, 5),

  ('pants', 'Cargo pants', 'cargo-pants', null, 1),
  ('pants', 'Joggers',     'joggers',     null, 2),
  ('pants', 'Sweatpants',  'sweatpants',  null, 3),
  ('pants', 'Track pants', 'track-pants', null, 4),
  ('pants', 'Chinos',      'chinos',      null, 5),

  ('tops', 'T-shirts',     't-shirts',     null, 1),
  ('tops', 'Graphic tees', 'graphic-tees', null, 2),
  ('tops', 'Shirts',       'shirts',       null, 3),
  ('tops', 'Polos',        'polos',        null, 4),
  ('tops', 'Tank tops',    'tank-tops',    null, 5),
  ('tops', 'Crop tops',    'crop-tops',    null, 6),
  ('tops', 'Jerseys',      'jerseys',      null, 7),

  ('outerwear', 'Denim jackets', 'denim-jackets', null, 1),
  ('outerwear', 'Hoodies',       'hoodies',       null, 2),
  ('outerwear', 'Sweatshirts',   'sweatshirts',   null, 3),
  ('outerwear', 'Jackets',       'jackets',       null, 4),
  ('outerwear', 'Vests',         'vests',         null, 5),

  ('skirts-dresses', 'Denim skirts', 'denim-skirts', null, 1),
  ('skirts-dresses', 'Skirts',       'skirts',       null, 2),
  ('skirts-dresses', 'Dresses',      'dresses',      null, 3),

  ('sets', 'Denim sets', 'denim-sets', null, 1),
  ('sets', 'Tracksuits', 'tracksuits', null, 2),
  ('sets', 'Co-ords',    'co-ords',    null, 3),

  ('jewelry', 'Chains & Necklaces', 'chains-necklaces', 'necklaces', 1),
  ('jewelry', 'Pendants',           'pendants',         'necklaces', 2),
  ('jewelry', 'Bracelets',          'bracelets',        'bracelets', 3),
  ('jewelry', 'Rings',              'rings',            'rings',     4),
  ('jewelry', 'Earrings',           'earrings',         'earrings',  5),
  ('jewelry', 'Anklets',            'anklets',          'bracelets', 6),

  ('accessories', 'Belts',       'belts',       'belts',     1),
  ('accessories', 'Caps & Hats', 'caps-hats',   'caps_bags', 2),
  ('accessories', 'Bags',        'bags',        'caps_bags', 3),
  ('accessories', 'Sunglasses',  'sunglasses',  null,        4),
  ('accessories', 'Socks',       'socks',       null,        5),
  ('accessories', 'Wallets',     'wallets',     null,        6),

  ('footwear', 'Sneakers', 'sneakers', null, 1),
  ('footwear', 'Slides',   'slides',   null, 2),
  ('footwear', 'Boots',    'boots',    null, 3)
) as c(parent_slug, name, slug, template, sort_order)
join public.categories p on p.slug = c.parent_slug;
