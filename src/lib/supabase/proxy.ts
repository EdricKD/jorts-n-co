import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"

import type { Database } from "@/types/database"
import { getSupabaseEnv } from "./env"

/**
 * Refreshes the login session cookie (if it's about to expire) and returns
 * the user's claims, or null when nobody is logged in.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request })
  const { url, key } = getSupabaseEnv()

  const supabase = createServerClient<Database>(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
        // Stops a CDN from caching one person's session cookie and serving it to someone else
        Object.entries(headers).forEach(([name, value]) => response.headers.set(name, value))
      },
    },
  })

  // Must run before anything else reads the session: it's what triggers the refresh.
  const { data } = await supabase.auth.getClaims()

  return { response, claims: data?.claims ?? null }
}
