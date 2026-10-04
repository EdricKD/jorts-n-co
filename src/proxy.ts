import { NextResponse, type NextRequest } from "next/server"

import { updateSession } from "@/lib/supabase/proxy"

/**
 * Runs before every /admin request: keeps the owner's session fresh and sends
 * logged-out visitors to the login page.
 *
 * This is only the first gate. Admin pages and server actions check again
 * with requireAdmin(), and the database checks again with Row Level Security.
 */
export async function proxy(request: NextRequest) {
  const { response, claims } = await updateSession(request)

  if (!claims && request.nextUrl.pathname !== "/admin/login") {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = "/admin/login"
    loginUrl.search = ""
    return NextResponse.redirect(loginUrl)
  }

  return response
}

export const config = {
  // Storefront pages skip this entirely, since shoppers never log in.
  matcher: ["/admin/:path*"],
}
