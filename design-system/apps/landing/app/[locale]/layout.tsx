import type { ReactNode } from "react"
import { notFound } from "next/navigation"

import { isLocale, locales, type Locale } from "@/lib/i18n"

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }))
}

export const dynamicParams = false

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
    <div lang={locale as Locale}>
      <script
        dangerouslySetInnerHTML={{
          __html: `document.documentElement.lang=${JSON.stringify(locale)}`,
        }}
      />
      {children}
    </div>
  )
}
