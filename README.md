# Jorts & Co.

Online store and inventory admin for Jorts & Co., Accra.
Built with Next.js, Supabase, Tailwind and shadcn/ui.

- Spec: [docs/SPEC.md](docs/SPEC.md)
- Decisions: [docs/DECISIONS.md](docs/DECISIONS.md)

## First-time setup

1. Install dependencies: `npm install`
2. Copy `.env.example` to `.env.local` and fill in the values from your Supabase
   project (Project Settings → API Keys).
3. Connect the Supabase CLI to your project (opens a browser to log in):
   ```bash
   npx supabase login
   npx supabase link
   ```
4. Create the database tables, rules and categories, plus demo products:
   ```bash
   npx supabase db push --include-seed
   ```
5. Generate TypeScript types from the database: `npm run db:types`
6. Start the app: `npm run dev`, then open http://localhost:3000

## Owner account

Nobody signs up on the site. Create the owner once:

1. Supabase dashboard → Authentication → Sign In / Providers → turn off
   "Allow new users to sign up". (`supabase/config.toml` only affects a local
   Supabase, not the hosted project.)
2. Authentication → Users → Add user → Create new user.
   Tick "Auto Confirm User".
3. SQL Editor → run (with the owner's email):
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'owner@example.com';
   ```
4. Log in at http://localhost:3000/admin

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Run the app locally |
| `npm run build` | Production build |
| `npm run typecheck` | Check TypeScript |
| `npm run lint` | Check code style |
| `npm run test:db` | Run all migrations against an in-memory Postgres and test the stock, order and access rules (no Docker needed) |
| `npm run db:push` | Apply new migrations to Supabase |
| `npm run db:types` | Regenerate `src/types/database.ts` from Supabase |
