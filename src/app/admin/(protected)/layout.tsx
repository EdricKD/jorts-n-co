import type { Metadata } from "next"
import Link from "next/link"

import { Logo } from "@/components/logo"
import { Button } from "@/components/ui/button"
import { requireAdmin } from "@/lib/auth"
import { signOut } from "../actions"

export const metadata: Metadata = {
  title: "Admin",
  robots: { index: false },
}

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  await requireAdmin()

  return (
    <div className="flex flex-1 flex-col bg-muted/40">
      <header className="sticky top-0 z-10 border-b bg-background/95 backdrop-blur">
        <div className="mx-auto flex h-14 max-w-3xl items-center justify-between px-4">
          <Link href="/admin" className="-my-2 py-2">
            <Logo className="w-20" title="Jorts & Co. admin" />
          </Link>
          <form action={signOut}>
            <Button type="submit" variant="ghost">
              Sign out
            </Button>
          </form>
        </div>
      </header>
      <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-6">{children}</main>
    </div>
  )
}
