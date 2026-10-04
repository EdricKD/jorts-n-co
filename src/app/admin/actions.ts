"use server"

import { redirect } from "next/navigation"

import { loginSchema, type LoginInput } from "@/lib/schemas/auth"
import { createClient } from "@/lib/supabase/server"

export async function signIn(input: LoginInput): Promise<{ error: string }> {
  // The form already validated this, but anyone can call a server action
  // directly, so validate again here where it counts.
  const parsed = loginSchema.safeParse(input)
  if (!parsed.success) return { error: "Enter your email and password." }

  const supabase = await createClient()
  const { error } = await supabase.auth.signInWithPassword(parsed.data)
  if (error?.code === "invalid_credentials") return { error: "That email and password don't match." }
  if (error) return { error: "Couldn't sign in right now. Check your connection and try again." }

  const { data: isAdmin } = await supabase.rpc("is_admin")
  if (!isAdmin) {
    await supabase.auth.signOut()
    return { error: "That account isn't set up as the store owner." }
  }

  redirect("/admin")
}

export async function signOut() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect("/admin/login")
}
