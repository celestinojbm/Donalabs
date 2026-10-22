import Link from "next/link"

import { Button } from "@donalabs/ui/components/button"

import { ThemeToggle } from "@/components/theme-toggle"

const LINKS = [
  { href: "#como-funciona", label: "Cómo funciona" },
  { href: "#servicios", label: "Servicios" },
  { href: "#escribir", label: "Escribir" },
] as const

export function SiteHeader() {
  return (
    <header className="flex flex-col gap-4 border-b px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-8">
      <Link href="#contenido" className="flex items-center gap-2.5">
        <span className="flex size-8 items-center justify-center rounded-md bg-primary text-sm font-semibold text-primary-foreground">
          D
        </span>
        <span className="font-semibold tracking-tight">DonaLabs</span>
      </Link>
      <nav className="flex flex-wrap items-center gap-1" aria-label="Secciones">
        {LINKS.map((link) => (
          <Button key={link.href} variant="ghost" size="sm" asChild>
            <a href={link.href}>{link.label}</a>
          </Button>
        ))}
        <ThemeToggle />
      </nav>
    </header>
  )
}
