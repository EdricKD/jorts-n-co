# Project: Denim storefront + inventory admin

> **Incomplete:** the copy pasted into the build chat ended at the `## Admin` heading,
> so the Admin section and the Build order are missing below. Paste them in here.
> Decisions made since the spec was written are in [DECISIONS.md](DECISIONS.md).

## Context
Build a Shopify-style online store for a small clothing business in Accra, Ghana.
It sells jeans, denim and streetwear, mainly through pop-up shops at a university,
plus online orders. One owner runs everything from a phone. Customers are students
browsing on mobile, often on limited data. Currency is Ghana cedis (GH₵).

Two surfaces:
1. Storefront (public): browse, filter, view products, add to cart, place an order.
2. Admin (owner only): add products with photos taken on a phone, manage stock per
   size, handle orders, record pop-up sales.

## How to work
- Read this whole spec first. Propose the folder structure and database schema,
  list any questions, and wait for my go-ahead before writing code.
- Build phase by phase (see Build order). After each phase: commit, tell me how to
  test it, and wait for me to confirm.
- Briefly explain key design decisions as you go. I'm learning from this build.
- If you want to deviate from the spec, say why and ask first.

## Stack
- Next.js (App Router, latest stable), TypeScript, Tailwind CSS, shadcn/ui
- Supabase: Postgres, Auth (owner login only), Storage (product images)
- Zustand for the cart, persisted to localStorage (guest carts, no customer accounts)
- Zod + React Hook Form for forms
- Deployable to Vercel. Secrets in .env.local with a .env.example

## Data model
- categories: name, slug, parent_id (two levels), measurement_template, sort_order
- products: title, slug, description, category_id, department (men/women/unisex),
  brand, price, compare_at_price, cost_price (admin only, never sent to storefront),
  status (draft/active/archived), attributes (jsonb), tags, created_at
- product_images: product_id, storage_path, alt, position (first = cover),
  optional colour link
- variants: product_id, sku (auto-generated), size_label, colour, stock_qty,
  low_stock_threshold, measurements (jsonb, stored in cm)
- stock_movements: variant_id, delta, reason (restock, online_sale, popup_sale,
  adjustment, return, damaged), note, order_id, created_at
- orders: order_number, customer_name, phone, fulfilment (pickup at pop-up /
  delivery), location, status (pending, confirmed, ready, completed, cancelled),
  payment_method (cash, MoMo), payment_status, payment_reference, totals,
  channel (online/popup), created_at
- order_items: order_id, variant_id, snapshot of title/size/price, qty

Stock rules:
- Stock lives on the variant. Every change goes through a Postgres function that
  writes a stock_movement and updates stock_qty in one transaction.
- Checkout is a single RPC that checks stock for every cart line and decrements
  atomically. If anything sold out, fail with a clear per-item message.
- Cancelling an order restores its stock.
- Row Level Security: public can read active products only; all writes are owner only.

## Category taxonomy (seed this)
- Jeans: Baggy, Straight, Slim, Skinny, Wide-leg, Bootcut & Flare, Cargo jeans,
  Carpenter, Ripped & Distressed
- Shorts: Jorts, Jogger shorts, Cargo shorts, Sweat shorts, Mesh shorts
- Pants: Cargo pants, Joggers, Sweatpants, Track pants, Chinos
- Tops: T-shirts, Graphic tees, Shirts, Polos, Tank tops, Crop tops, Jerseys
- Outerwear: Denim jackets, Hoodies, Sweatshirts, Jackets, Vests
- Skirts & Dresses: Denim skirts, Skirts, Dresses
- Sets: Denim sets, Tracksuits, Co-ords
- Jewelry: Chains & Necklaces, Pendants, Bracelets, Rings, Earrings, Anklets, Watches
- Accessories: Belts, Caps & Hats, Bags, Sunglasses, Socks, Wallets
- Footwear: Sneakers, Slides, Boots

Filterable attributes, independent of category: department, size, colour, fit,
rise, wash (light, mid, dark, black, grey, acid, raw), material, stretch, price.
Jewelry attributes: material, plating, stone, water/tarnish resistance.
Tags drive collections: New arrivals (also automatic by date), Best sellers, Sale,
Pop-up drop.

## Measurements
Each category points to a measurement template that decides which fields the admin
form shows and what the storefront size guide displays:
- Long bottoms: waist, hip, front rise, thigh, knee, leg opening, inseam, outseam
- Shorts: waist, hip, front rise, thigh, leg opening, inseam
- Tops & outerwear: chest (pit to pit), length, shoulder, sleeve
- Skirts & dresses: waist, hip, length
- Necklaces: length, thickness, pendant size
- Bracelets & anklets: length, width
- Rings: ring size, inner diameter
- Earrings: drop length, width
- Belts: total length, width, fits waist range
- Caps & bags: dimensions
- Footwear: EU/UK size, insole length
Measurements are stored per variant in cm, with a cm/inch toggle on the storefront.

## Storefront
- Home: hero, category tiles, New arrivals, Best sellers, next pop-up date/location
  banner (editable in admin).
- Category/listing pages: filter drawer (all attributes above plus "in stock only"),
  sort, active filter chips, product count, infinite scroll or load more.
- Product card: cover image, swipe or hover for second image, price, sale badge,
  sold-out state, available sizes, quick add (pick size without leaving the grid).
- Product page: swipeable image gallery with thumbnails, pinch/tap zoom and
  fullscreen; size selector that shows stock per size ("Only 2 left", sold-out
  sizes disabled); measurement table for the selected size with a labelled diagram;
  size guide modal; fit and fabric details; sticky add-to-cart bar on mobile;
  related items; recently viewed.
- Cart drawer: slides in on add, quantity stepper capped at available stock,
  remove, subtotal, live stock re-check.
- Checkout: name, phone, pickup at next pop-up or delivery, payment method (cash or
  MoMo on pickup/delivery). Confirmation page with order number and a "Send order
  on WhatsApp" button with a prefilled message to the owner's number (env var).
- Also: instant search, wishlist (localStorage), "Ask about this item" WhatsApp
  link, share button.
- Feel: fast and tactile. Optimistic updates, skeleton loaders, subtle motion on
  add to cart, toasts, clear empty states. Respect reduced motion.

## Admin (mobile-first, behind owner login)

_(missing: paste the rest of this section here)_

## Build order

_(missing)_
