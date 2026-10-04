import { Logo } from "@/components/logo"
import { formatPopupTime } from "@/lib/format"
import { createPublicClient } from "@/lib/supabase/public"

// Phase 1 placeholder home page. It proves the storefront can read the
// public catalogue. The real home page is built in the storefront phase.

// Rebuild this page in the background at most once a minute, so shoppers
// get a cached copy instantly instead of waiting on the database.
export const revalidate = 60

export default async function HomePage() {
  const supabase = createPublicClient()

  const [categories, popup, products] = await Promise.all([
    supabase.from("categories").select("id, name, parent_id").order("sort_order"),
    supabase
      .from("popups")
      .select("title, location, starts_at, ends_at")
      .gt("ends_at", new Date().toISOString())
      .order("starts_at")
      .limit(1)
      .maybeSingle(),
    supabase.from("products").select("id", { count: "exact", head: true }),
  ])

  const error = categories.error ?? popup.error ?? products.error
  const topLevel = (categories.data ?? []).filter((c) => c.parent_id === null)
  const childrenOf = (id: string) => (categories.data ?? []).filter((c) => c.parent_id === id)

  return (
    <main className="mx-auto max-w-5xl px-4 py-10">
      <section className="flex flex-col items-center gap-4 py-8 text-center">
        <Logo className="w-56 sm:w-72" />
        <p className="max-w-md text-balance text-muted-foreground">
          Jeans, denim and streetwear. Find us at campus pop-ups or order online.
        </p>
      </section>

      {error ? (
        <p role="alert" className="rounded-lg border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">
          Couldn&apos;t load the store data: {error.message}. Check the Supabase values in .env.local.
        </p>
      ) : (
        <>
          {popup.data && (
            <section className="mb-10 rounded-xl bg-foreground p-5 text-background">
              <p className="text-xs font-medium tracking-widest uppercase opacity-70">Next pop-up</p>
              <p className="mt-1 text-lg font-semibold">{formatPopupTime(popup.data.starts_at, popup.data.ends_at)}</p>
              <p className="opacity-80">{popup.data.location}</p>
            </section>
          )}

          <section>
            <div className="mb-4 flex items-baseline justify-between">
              <h2 className="text-lg font-semibold">Categories</h2>
              <p className="text-sm text-muted-foreground">{products.count ?? 0} products live</p>
            </div>
            <ul className="grid gap-3 sm:grid-cols-2">
              {topLevel.map((category) => (
                <li key={category.id} className="rounded-xl border p-4">
                  <p className="font-medium">{category.name}</p>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {childrenOf(category.id)
                      .map((c) => c.name)
                      .join(" · ")}
                  </p>
                </li>
              ))}
            </ul>
          </section>
        </>
      )}
    </main>
  )
}
