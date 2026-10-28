import type { Metadata } from "next"
import type { ReactNode } from "react"
import { notFound } from "next/navigation"

import { fontVariables } from "@/lib/fonts"
import { isLocale, locales } from "@/lib/i18n"
import { siteUrl } from "@/lib/site"

import "../globals.css"

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }))
}

export const dynamicParams = false

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: "DonaLabs",
  description:
    "A reusable, self-hosted platform with the shared services for all of my projects, current and future.",
}

// Root layout per locale, so the served HTML already has the right <html lang>.
export default async function LocaleLayout({
  children,
  params,
}: {
  children: ReactNode
  params: Promise<{ locale: string }>
}) {
  const { locale } = await params
  if (!isLocale(locale)) notFound()

  return (
    <html lang={locale} className={fontVariables}>
      <body className="antialiased">{children}</body>
    </html>
  )
}
