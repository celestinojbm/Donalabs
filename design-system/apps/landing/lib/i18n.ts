/**
 * Default locale is English because the repository README and the docs
 * (architecture, security, operations) are written in English.
 * Spanish is the language of the v2 mockups and is offered as a full translation.
 */
export const locales = ["en", "es"] as const

export type Locale = (typeof locales)[number]

export const defaultLocale: Locale = "en"

export function isLocale(value: string): value is Locale {
  return locales.some((locale) => locale === value)
}
