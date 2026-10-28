import type { Metadata } from "next"
import Link from "next/link"

import { fontVariables } from "@/lib/fonts"

import "./globals.css"

export const metadata: Metadata = { title: "404 · DonaLabs" }

export default function GlobalNotFound() {
  return (
    <html lang="en" className={fontVariables}>
      <body className="antialiased">
    <main className="mx-auto flex min-h-screen max-w-[1600px] flex-col justify-center px-5 md:px-16">
      <p className="kicker">404</p>
      <h1 className="display mt-4 text-[clamp(3rem,8vw,6rem)]">
        Not in the tree.
      </h1>
      <p className="mt-6 max-w-md text-[15px] text-muted">
        This page is not part of the landing. The repository README and the docs
        are in English, so that is the default.
      </p>
      <div className="mt-8 flex gap-3">
        <Link href="/en" className="btn btn-secondary" lang="en">
          English
        </Link>
        <Link href="/es" className="btn btn-secondary" lang="es">
          Español
        </Link>
      </div>
    </main>
      </body>
    </html>
  )
}
