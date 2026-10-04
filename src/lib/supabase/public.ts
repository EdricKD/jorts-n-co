import { createClient as createSupabaseClient } from "@supabase/supabase-js"

import type { Database } from "@/types/database"
import { getSupabaseEnv } from "./env"

/**
 * Anonymous Supabase client for storefront reads. It sends no cookies, so it
 * sees exactly what any shopper sees, and pages using it can be cached and
 * served instantly instead of rendering on every visit.
 */
export function createPublicClient() {
  const { url, key } = getSupabaseEnv()
  return createSupabaseClient<Database>(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}
