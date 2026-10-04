@AGENTS.md

# Jorts & Co.

Online store and inventory admin for a denim/streetwear business in Accra.
Spec: `docs/SPEC.md`. Agreed changes and the reasons for them: `docs/DECISIONS.md`.

## Working agreement

- Build phase by phase. After each phase: commit, explain how to test it, and
  wait for the owner to confirm before starting the next one.
- Briefly explain key design decisions; the owner is learning from this build.
- Ask before deviating from the spec, and record agreed changes in `docs/DECISIONS.md`.
- Don't push to GitHub until asked.

## Conventions

- Money is integer pesewas. Format with `formatCedis()` from `src/lib/format.ts`.
- Measurements are stored in cm; field definitions live in `src/lib/measurements.ts`.
- Stock only changes through the database functions (`adjust_stock`, `place_order`,
  `record_popup_sale`, `cancel_order`). Never write `stock_qty` directly.
- Storefront reads use `createPublicClient()` (cacheable). Admin pages and actions
  start with `requireAdmin()` from `src/lib/auth.ts`.
- Schema changes are new files in `supabase/migrations/`. Never edit one that has
  been pushed. Add checks to `supabase/tests/database.test.mjs` and run
  `npm run test:db`, then `npm run db:push` and `npm run db:types`.
- Before committing: `npm run typecheck`, `npm run lint`, `npm run test:db`.
