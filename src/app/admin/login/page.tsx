import type { Metadata } from "next"
import { redirect } from "next/navigation"

import { Logo } from "@/components/logo"
import { createClient } from "@/lib/supabase/server"
import { LoginForm } from "./login-form"

export const metadata: Metadata = {
  title: "Owner login",
  robots: { index: false },
}

export default async function LoginPage({ searchParams }: PageProps<"/admin/login">) {
  // Already logged in as the owner? Skip straight to admin.
  const supabase = await createClient()
  const { data } = await supabase.auth.getClaims()
  if (data?.claims) {
    const { data: isAdmin } = await supabase.rpc("is_admin")
    if (isAdmin) redirect("/admin")
  }

  const { error } = await searchParams

  return (
    <main className="flex flex-1 items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        <Logo className="mx-auto mb-8 w-40" />
        <h1 className="mb-6 text-center text-xl font-semibold">Owner login</h1>
        {error === "not-owner" && (
          <p role="alert" className="mb-6 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">
            That account isn&apos;t set up as the store owner.
          </p>
        )}
        <LoginForm />
      </div>
    </main>
  )
}
