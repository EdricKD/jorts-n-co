// Runs every migration plus seed.sql against PGlite (real Postgres compiled to
// WebAssembly, so no Docker needed) and checks the stock, order and access rules.
//
//   npm run test:db
//
// Supabase's auth/storage schemas and API roles are stubbed below with just
// enough to run the migrations.

import { PGlite } from '@electric-sql/pglite'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const SUPABASE_DIR = join(dirname(fileURLToPath(import.meta.url)), '..')
const db = new PGlite()

let pass = 0
let fail = 0
const ok = (cond, msg) => {
  if (cond) {
    pass++
    console.log('  ✓', msg)
  } else {
    fail++
    console.log('  ✗', msg)
  }
}

// --- Minimal stand-ins for what Supabase provides ---------------------------
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create schema storage;
  create schema extensions;
  create table auth.users (id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated;
  grant usage on schema public to anon, authenticated;
  create table storage.buckets (id text primary key, name text not null, public boolean default false,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets(id), name text, owner uuid);
  alter table storage.objects enable row level security;
  grant usage on schema storage to anon, authenticated;
  grant all on storage.objects to anon, authenticated;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`)

// --- Run migrations + seed ---------------------------------------------------
const migrations = readdirSync(join(SUPABASE_DIR, 'migrations'))
  .filter((f) => f.endsWith('.sql'))
  .sort()
for (const file of [...migrations.map((f) => join('migrations', f)), 'seed.sql']) {
  try {
    await db.exec(readFileSync(join(SUPABASE_DIR, file), 'utf8'))
    console.log('ran', file)
  } catch (e) {
    console.log('FAILED', file, '\n', e.message)
    process.exit(1)
  }
}

// --- Helpers -------------------------------------------------------------------
const ADMIN = '11111111-1111-1111-1111-111111111111'
const STRANGER = '22222222-2222-2222-2222-222222222222'
await db.exec(`
  insert into auth.users values ('${ADMIN}', 'owner@example.com'), ('${STRANGER}', 'someone@example.com');
  insert into public.admins (user_id) values ('${ADMIN}');
`)

async function as(role, uid, fn) {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false);`)
  try {
    return await fn()
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`)
  }
}
const anon = (fn) => as('anon', null, fn)
const stranger = (fn) => as('authenticated', STRANGER, fn)
const admin = (fn) => as('authenticated', ADMIN, fn)

const q = async (sql, params) => (await db.query(sql, params)).rows
const one = async (sql, params) => (await q(sql, params))[0]
const err = async (fn) => {
  try {
    await fn()
    return ''
  } catch (e) {
    return e.message
  }
}
const count = async (sql, params) => Number((await one(`select count(*)::int as n from ${sql}`, params)).n)
const stock = async (id) => (await one('select stock_qty from variants where id = $1', [id])).stock_qty
const variantId = async (slug, size, colour = null) =>
  (
    await one(
      `select v.id from variants v join products p on p.id = v.product_id
       where p.slug = $1 and v.size_label = $2 and v.colour is not distinct from $3`,
      [slug, size, colour],
    )
  ).id

const placeOrder = async (items, o = {}) =>
  (
    await one(
      `select public.place_order($1::jsonb, $2, $3, $4::fulfilment, $5::payment_method, $6, $7, $8, $9) as r`,
      [
        JSON.stringify(items),
        o.name ?? 'Ama Mensah',
        o.phone ?? '+233241234567',
        o.fulfilment ?? 'pickup',
        o.payment ?? 'momo',
        o.popup ?? null,
        o.zone ?? null,
        o.address ?? null,
        o.notes ?? null,
      ],
    )
  ).r

// --- Schema & seed -------------------------------------------------------------
console.log('\nSchema & seed')
ok((await count('categories')) === 62, 'taxonomy: 10 top-level + 52 subcategories')
ok((await count('products')) === 6, '6 demo products')
const skus = (await q('select sku from variants')).map((r) => r.sku)
ok(
  skus.includes('JC-0001-28') && skus.includes('JC-0003-M-BLA') && skus.includes('JC-0004-50CM'),
  'readable SKUs generated (JC-0001-28, JC-0003-M-BLA, JC-0004-50CM)',
)

const baggy30 = await variantId('baggy-light-wash-jeans', '30')
const baggy32 = await variantId('baggy-light-wash-jeans', '32')
const baggy36 = await variantId('baggy-light-wash-jeans', '36')
const teeMBlack = await variantId('boxy-graphic-tee', 'M', 'Black')
const draftVariant = await variantId('carpenter-jeans-draft', '32')
const popupId = (await one('select id from popups')).id
const zone = Object.fromEntries((await q('select name, id from delivery_zones')).map((r) => [r.name, r.id]))

ok((await stock(baggy30)) === 5 && (await stock(baggy32)) === 0, 'opening stock set')
ok((await count(`stock_movements where reason = 'restock'`)) === 16, 'opening stock went through the ledger')
ok(
  (await err(() =>
    q(`insert into categories (name, slug, parent_id) values ('Too deep', 'too-deep', (select id from categories where slug = 'baggy'))`),
  )).includes('two levels'),
  'categories cannot go three levels deep',
)

// --- Shopper (not logged in) ---------------------------------------------------
console.log('\nShopper (not logged in)')
await anon(async () => {
  ok((await q('select id from products')).length === 5, 'sees the 5 active products, not the draft')
  ok((await q('select id from variants where id = $1', [draftVariant])).length === 0, 'cannot see sizes of a draft')
  ok((await q('select id from popups')).length === 1, 'sees the published pop-up')
  ok((await err(() => q('select * from product_costs'))).includes('permission denied'), 'cannot read cost prices')
  ok((await err(() => q('select * from orders'))).includes('permission denied'), 'cannot read orders')
  ok((await err(() => q('select * from stock_movements'))).includes('permission denied'), 'cannot read stock history')
  ok(
    (await err(() => q(`insert into products (title, slug, category_id, price) values ('x', 'x', (select id from categories limit 1), 1)`)))
      .includes('permission denied'),
    'cannot add products',
  )
  ok((await err(() => q('update variants set stock_qty = 100'))).includes('permission denied'), 'cannot change stock')
  ok((await err(() => q('select public.is_admin()'))).includes('permission denied'), 'cannot call is_admin()')
  ok((await err(() => q('select public.cancel_order(gen_random_uuid())'))).includes('permission denied'), 'cannot call cancel_order()')
  ok(
    (await err(() => q(`select public.adjust_stock(gen_random_uuid(), 1, 'restock')`))).includes('permission denied'),
    'cannot call adjust_stock()',
  )
  ok(
    (await err(() => q(`insert into storage.objects (bucket_id, name) values ('product-images', 'x.webp')`))).includes('row-level security'),
    'cannot upload photos',
  )
})

// --- Checkout ------------------------------------------------------------------
console.log('\nCheckout')
const ordersBefore = await count('orders')
const first = await anon(() =>
  placeOrder(
    [
      { variant_id: baggy30, qty: 1 },
      { variant_id: teeMBlack, qty: 1 },
      { variant_id: baggy30, qty: 1 }, // duplicate line gets merged
    ],
    { popup: popupId },
  ),
)
ok(first.ok === true && /^JC-\d+$/.test(first.order_number), `order placed: ${first.order_number}`)
ok(first.total === 2 * 25000 + 12000, 'total uses database prices: GH₵ 620')
ok((await stock(baggy30)) === 3 && (await stock(teeMBlack)) === 2, 'stock went down (jeans 30: 5→3, tee: 3→2)')
ok((await count(`stock_movements where reason = 'online_sale'`)) === 2, 'two online_sale movements logged')
ok((await count('order_items where order_id = $1', [first.order_id])) === 2, 'duplicate cart lines merged')

const failed = await anon(() =>
  placeOrder([
    { variant_id: baggy30, qty: 1 },
    { variant_id: baggy32, qty: 1 },
    { variant_id: baggy36, qty: 2 },
    { variant_id: draftVariant, qty: 1 },
  ]),
)
const reasons = Object.fromEntries((failed.problems ?? []).map((p) => [p.variant_id, p.reason]))
ok(failed.ok === false && failed.problems.length === 3, 'cart with problems is rejected, listing all 3')
ok(reasons[baggy32] === 'sold_out', 'size 32: sold_out')
ok(reasons[baggy36] === 'not_enough' && failed.problems.find((p) => p.variant_id === baggy36).available === 1, 'size 36: not_enough, 1 left')
ok(reasons[draftVariant] === 'unavailable', 'draft product: unavailable')
ok((await count('orders')) === ordersBefore + 1 && (await stock(baggy30)) === 3, 'rejected checkout wrote nothing')

const delivered = await anon(() =>
  placeOrder([{ variant_id: teeMBlack, qty: 1 }], {
    phone: '+233551112222',
    fulfilment: 'delivery',
    zone: zone['Near campus'],
    address: 'Hall 3, Room 12',
  }),
)
ok(delivered.total === 12000 + 2000, 'delivery fee comes from the chosen area (GH₵ 120 + 20)')

const tbc = await anon(() =>
  placeOrder([{ variant_id: baggy36, qty: 1 }], {
    phone: '+233551112222',
    fulfilment: 'delivery',
    zone: zone['Outside Accra'],
    address: 'Kumasi, Adum',
  }),
)
const tbcRow = await one('select delivery_fee, total from orders where id = $1', [tbc.order_id])
ok(tbcRow.delivery_fee === null && tbcRow.total === 25000, 'area with no set fee: fee left empty, total = subtotal')

await anon(async () => {
  ok(
    (await err(() => placeOrder([{ variant_id: baggy30, qty: 1 }], { phone: '0241234567' }))).includes('valid Ghana phone'),
    'phone must be normalised to +233…',
  )
  ok((await err(() => placeOrder([{ variant_id: baggy30, qty: 11 }]))).includes('between 1 and 10'), 'max 10 of one item online')
  ok(
    (await err(() => placeOrder([{ variant_id: baggy30, qty: 1 }], { fulfilment: 'delivery', zone: zone['On campus'] })))
      .includes('delivery address'),
    'delivery needs an address',
  )
  await placeOrder([{ variant_id: baggy30, qty: 1 }], { phone: '+233551112222' }) // 3rd pending order
  ok(
    (await err(() => placeOrder([{ variant_id: baggy30, qty: 1 }], { phone: '+233551112222' }))).includes('3 orders waiting'),
    'max 3 pending orders per phone number',
  )

  const view = (await one('select public.get_order($1) as o', [first.token])).o
  ok(
    view.order_number === first.order_number && view.items.length === 2 && view.popup?.title === 'Campus pop-up',
    'get_order(token) returns the order for the confirmation page',
  )
  ok((await one('select public.get_order(gen_random_uuid()) as o')).o === null, 'unknown token returns nothing')
})

// --- Logged in, but not the owner -----------------------------------------------
console.log('\nLogged in, but not the owner')
await stranger(async () => {
  ok((await q('select id from products')).length === 5, 'sees only active products')
  ok((await q('select id from orders')).length === 0, 'sees no orders')
  ok((await q('select * from product_costs')).length === 0, 'sees no cost prices')
  ok(
    (await err(() => q(`insert into products (title, slug, category_id, price) values ('x', 'x', (select id from categories limit 1), 1)`)))
      .includes('row-level security'),
    'cannot add products',
  )
  ok((await err(() => q(`select public.adjust_stock($1, 5, 'restock')`, [baggy30]))).includes('Not allowed'), 'cannot adjust stock')
  ok((await err(() => q('select public.cancel_order($1)', [first.order_id]))).includes('Not allowed'), 'cannot cancel orders')
})

// --- Owner -------------------------------------------------------------------------
console.log('\nOwner')
await admin(async () => {
  ok((await q('select id from products')).length === 6, 'sees all 6 products, including the draft')
  ok((await q('select * from product_costs')).length === 2, 'sees cost prices')
  ok((await q('select id from orders')).length === 4, 'sees orders')

  ok(
    (await err(() => q('update variants set stock_qty = 99 where id = $1', [baggy30]))).includes('permission denied'),
    'cannot set stock_qty directly, even as owner',
  )
  await q('update variants set low_stock_threshold = 1 where id = $1', [baggy30])
  ok((await one('select low_stock_threshold from variants where id = $1', [baggy30])).low_stock_threshold === 1, 'can edit other size fields')

  const restocked = (await one(`select public.adjust_stock($1, 4, 'restock', 'New bale') as n`, [baggy32])).n
  ok(restocked === 4, 'restock +4 on the sold-out size')
  ok((await err(() => q(`select public.adjust_stock($1, 2, 'damaged')`, [baggy30]))).includes('negative'), 'damaged must remove stock')
  ok((await err(() => q(`select public.adjust_stock($1, -50, 'adjustment')`, [baggy30]))).includes('Not enough stock'), 'stock cannot go below zero')
  ok((await err(() => q(`select public.adjust_stock($1, -1, 'online_sale')`, [baggy30]))).includes('through orders'), 'sales only go through orders')

  ok((await err(() => q('update orders set subtotal = 1 where id = $1', [first.order_id]))).includes('permission denied'), 'cannot edit order totals')
  ok(
    (await err(() => q(`update orders set status = 'cancelled' where id = $1`, [first.order_id]))).includes('cancel_order'),
    'cannot cancel by just changing the status',
  )
  await q(`update orders set status = 'confirmed', payment_status = 'paid', payment_reference = 'MOMO123' where id = $1`, [first.order_id])
  ok((await one('select status from orders where id = $1', [first.order_id])).status === 'confirmed', 'can confirm an order and record a MoMo payment')

  const before = await stock(baggy30)
  const c1 = (await one(`select public.cancel_order($1, 'Changed mind') as r`, [first.order_id])).r
  const after = await stock(baggy30)
  ok(c1.ok && after === before + 2, `cancelling restores stock (jeans 30: ${before}→${after})`)
  const c2 = (await one('select public.cancel_order($1) as r', [first.order_id])).r
  ok(c2.already_cancelled && (await stock(baggy30)) === after, 'cancelling twice changes nothing')
  ok(
    (await err(() => q(`update orders set status = 'pending' where id = $1`, [first.order_id]))).includes('cannot be reopened'),
    'a cancelled order cannot be reopened',
  )

  const sale = (
    await one(`select public.record_popup_sale($1::jsonb, 'cash', $2, null, 1000) as r`, [
      JSON.stringify([{ variant_id: baggy30, qty: 1 }]),
      popupId,
    ])
  ).r
  const saleRow = await one('select status, payment_status, total from orders where id = $1', [sale.order_id])
  ok(
    sale.ok && saleRow.status === 'completed' && saleRow.payment_status === 'paid' && saleRow.total === 24000,
    'pop-up sale: completed, paid, GH₵ 10 discount applied',
  )
  ok((await count(`stock_movements where reason = 'popup_sale'`)) === 1, 'pop-up sale logged as popup_sale')
  const draftSale = (await one(`select public.record_popup_sale($1::jsonb, 'momo') as r`, [JSON.stringify([{ variant_id: draftVariant, qty: 1 }])])).r
  ok(draftSale.ok === false && draftSale.problems[0].reason === 'sold_out', 'pop-up can sell drafts, but still checks stock')

  ok(
    (await err(() => q(`delete from products where slug = 'baggy-light-wash-jeans'`))).includes('foreign key'),
    'a product with orders cannot be deleted (archive it instead)',
  )
  await q(`insert into storage.objects (bucket_id, name) values ('product-images', 'products/x.webp')`)
  ok((await count(`storage.objects where bucket_id = 'product-images'`)) === 1, 'can upload photos')
})

const mismatched = await q(`
  select v.sku from variants v left join stock_movements m on m.variant_id = v.id
  group by v.id having v.stock_qty <> coalesce(sum(m.delta), 0)`)
ok(mismatched.length === 0, 'every size: stock_qty equals the sum of its stock movements')

console.log(`\n${pass} passed, ${fail} failed`)
process.exit(fail ? 1 : 0)
