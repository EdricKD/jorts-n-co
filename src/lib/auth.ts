import { redirect } from "next/navigation"
import { cache } from "react"

import { createClient } from "@/lib/supabase/server"

/**
 * Call at the top of every admin page and admin server action. Redirects to
 * the login page unless the visitor is logged in as the store owner.
 *
 * cache() means calling it from both a layout and its page only checks once
 * per request.
 */
export const requireAdmin = cache(async () => {
  const supabase = await createClient()

  const { data } = await supabase.auth.getClaims()
  if (!data?.claims) redirect("/admin/login")

  const { data: isAdmin } = await supabase.rpc("is_admin")
  if (!isAdmin) redirect("/admin/login?error=not-owner")

  return {
    supabase,
    userId: data.claims.sub,
    email: typeof data.claims.email === "string" ? data.claims.email : null,
  }
})
