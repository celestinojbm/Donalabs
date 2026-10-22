import type { Metadata } from "next"
import { notFound } from "next/navigation"

import { LandingPage } from "@/components/landing-page"
import { getDictionary } from "@/lib/content"
import { isLocale, locales } from "@/lib/i18n"

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }))
}

export const dynamicParams = false

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>
}): Promise<Metadata> {
  const { locale } = await params
  if (!isLocale(locale)) return {}
  const t = getDictionary(locale)
  return {
    title: t.meta.title,
    description: t.meta.description,
    alternates: {
      canonical: `/${locale}`,
      languages: {
        en: "/en",
        es: "/es",
      },
    },
  }
}

export default async function Page({
  params,
}: {
  params: Promise<{ locale: string }>
}) {
  const { locale } = await params
  if (!isLocale(locale)) notFound()
  return <LandingPage locale={locale} t={getDictionary(locale)} />
}
