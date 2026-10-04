# Decisions

What was agreed on top of [SPEC.md](SPEC.md), and why. Newest at the bottom.

## Answers to the planning questions (4 Oct 2026)

| Question | Answer |
|---|---|
| Jeans sizes | Waist only (`30`, `32`). Leg length goes in the measurements. |
| Measurement unit | Inches shown first on the storefront, cm toggle remembered. |
| Delivery fee | Set per delivery area. Areas and fees are editable in admin. An area with no fee means "confirmed on WhatsApp". |
| Uncollected orders | Owner cancels them by hand. Admin flags pending orders older than 3 days. |
| Watches | Not sold. Removed from the Jewelry subcategories. |
| Other measurements | Sets show a top table and a bottom table. Sunglasses, socks and wallets have none. |
| Department filter | Men shows men + unisex. Women shows women + unisex. |
| Owner login | Email and password. |
| Logo | Redrawn as SVG from the original artwork. Black and white. |
| GitHub | Commits stay local for now. |

## Changes from the spec

1. **`cost_price` lives in its own table** (`product_costs`), readable only by the owner.
   Row Level Security filters rows, not columns, so a column on `products` could be
   read by any shopper through the public API.
2. **`popups` table** instead of a single banner setting. Several pop-ups can be
   scheduled; the banner shows the next published one; pickup orders link to one.
3. **Confirmation page uses a random token** (`/order/<token>`), not the order number,
   because order numbers go up by one and would expose other customers' details.
4. **Extra stock reason `cancelled`**, so cancellations don't look like customer returns.
5. **`delivery_zones` table** for per-area delivery fees.
6. **Small additions**: `admins` table, `variants.position` (size order),
   `products.code` (short number used in SKUs), `stock_movements.stock_after`,
   and on orders `delivery_fee`, `discount`, `delivery_address`, `notes`, `popup_id`.

## Design decisions

- **Money is stored as whole pesewas** in integer columns (GH₵ 250 = `25000`).
- **Widths are measured flat** (like "pit to pit"), in cm.
- **Measurement templates are defined in code** (`src/lib/measurements.ts`); the
  database only stores which template a category uses.
- **Stock can only change through database functions.** Even the owner's login
  can't write `variants.stock_qty` directly (column-level grants), so every change
  is in `stock_movements` and stock always equals the sum of its movements.
- **Checkout prices come from the database**, never from the cart in the browser.
- **Checkout limits**: max 10 of one item, 30 lines, and 3 pending orders per phone
  number, so one person can't reserve all the stock with orders they never collect.
- **Cancelling** works at any status and is safe to run twice. A cancelled order
  can't be reopened.
- **Pop-up sales** can include draft products (things not listed online yet).
- **Products that have been sold can't be deleted**, only archived, so order
  history stays intact.
- **Storefront pages read through a cookie-less client** so they can be cached;
  only `/admin` touches the login session.
- **Photos are resized in the browser before upload** (WebP, ~1600px plus a
  thumbnail), and the storage bucket rejects files over 2 MB.
- **One Supabase project** for now (no Docker locally). Migrations are SQL files in
  `supabase/migrations`, tested with `npm run test:db` (PGlite, no Docker needed).
