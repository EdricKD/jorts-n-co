import { createServerClient } from "@supabase/ssr"
import { cookies } from "next/headers"

import type { Database } from "@/types/database"
import { getSupabaseEnv } from "./env"

/**
 * Supabase client that acts as the logged-in user, for admin pages and
 * server actions. Reading cookies makes a page render on every request,
 * so storefront pages use the public client instead.
 *
 * Create a new one per request; never share it.
 */
export async function createClient() {
  const cookieStore = await cookies()
  const { url, key } = getSupabaseEnv()

  return createServerClient<Database>(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options))
        } catch {
          // Server Components can't set cookies. That's fine: the proxy
          // refreshes the session before the page renders.
        }
      },
    },
  })
}
