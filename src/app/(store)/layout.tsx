import Link from "next/link"

import { Logo } from "@/components/logo"

export default function StoreLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className="border-b">
        <div className="mx-auto flex h-16 max-w-5xl items-center px-4">
          <Link href="/" className="-my-2 py-2">
            <Logo className="w-24" />
          </Link>
        </div>
      </header>
      <div className="flex-1">{children}</div>
      <footer className="border-t">
        <div className="mx-auto max-w-5xl px-4 py-6 text-sm text-muted-foreground">
          © {new Date().getFullYear()} Jorts &amp; Co. · Accra, Ghana
        </div>
      </footer>
    </>
  )
}
