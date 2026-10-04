import { requireAdmin } from "@/lib/auth"
import { formatPopupTime } from "@/lib/format"

// Phase 1 placeholder dashboard. It proves the owner login works and that
// the owner can see things shoppers can't (drafts, orders, stock levels).

export default async function AdminHomePage() {
  const { supabase, email } = await requireAdmin()

  const [active, drafts, pending, variants, popup] = await Promise.all([
    supabase.from("products").select("id", { count: "exact", head: true }).eq("status", "active"),
    supabase.from("products").select("id", { count: "exact", head: true }).eq("status", "draft"),
    supabase.from("orders").select("id", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("variants").select("stock_qty, low_stock_threshold"),
    supabase
      .from("popups")
      .select("title, location, starts_at, ends_at, is_published")
      .gt("ends_at", new Date().toISOString())
      .order("starts_at")
      .limit(1)
      .maybeSingle(),
  ])

  const lowStock = (variants.data ?? []).filter((v) => v.stock_qty <= v.low_stock_threshold).length
  const error = active.error ?? drafts.error ?? pending.error ?? variants.error ?? popup.error

  const stats = [
    { label: "Active products", value: active.count ?? 0 },
    { label: "Drafts", value: drafts.count ?? 0 },
    { label: "Orders to handle", value: pending.count ?? 0 },
    { label: "Sizes low or sold out", value: lowStock },
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Today</h1>
        <p className="text-sm text-muted-foreground">Signed in as {email}</p>
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm text-destructive">
          Couldn&apos;t load everything: {error.message}
        </p>
      )}

      <dl className="grid grid-cols-2 gap-3">
        {stats.map((stat) => (
          <div key={stat.label} className="rounded-xl border bg-background p-4">
            <dt className="text-sm text-muted-foreground">{stat.label}</dt>
            <dd className="mt-1 text-2xl font-semibold tabular-nums">{stat.value}</dd>
          </div>
        ))}
      </dl>

      <section className="rounded-xl border bg-background p-4">
        <h2 className="text-sm text-muted-foreground">Next pop-up</h2>
        {popup.data ? (
          <>
            <p className="mt-1 font-medium">{formatPopupTime(popup.data.starts_at, popup.data.ends_at)}</p>
            <p className="text-sm">
              {popup.data.location}
              {!popup.data.is_published && " · not published"}
            </p>
          </>
        ) : (
          <p className="mt-1">None scheduled</p>
        )}
      </section>
    </div>
  )
}
