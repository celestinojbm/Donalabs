"use client"

import Link from "next/link"
import { useEffect, useState } from "react"

import { locales, type Locale } from "@/lib/i18n"

type LanguageSwitcherProps = {
  locale: Locale
  label: string
  names: Record<Locale, string>
  verbose?: boolean
}

export function LanguageSwitcher({
  locale,
  label,
  names,
  verbose = false,
}: LanguageSwitcherProps) {
  const [hash, setHash] = useState("")

  useEffect(() => {
    const read = () => setHash(window.location.hash)
    read()
    window.addEventListener("hashchange", read)
    return () => window.removeEventListener("hashchange", read)
  }, [])

  return (
    <nav aria-label={label} className="flex items-center">
      {locales.map((code, index) => (
        <span key={code} className="flex items-center">
          {index > 0 ? (
            <span aria-hidden="true" className="bg-ink mx-1 h-3.5 w-px" />
          ) : null}
          <Link
            href={`/${code}${hash}`}
            hrefLang={code}
            lang={code}
            aria-current={code === locale ? "page" : undefined}
            className={verbose ? "lang-link gap-2" : "lang-link"}
          >
            <span aria-hidden={verbose ? undefined : true}>
              {code.toUpperCase()}
            </span>
            {verbose ? (
              <span className="font-sans text-[15px] font-semibold">
                {names[code]}
              </span>
            ) : (
              <span className="sr-only">{names[code]}</span>
            )}
          </Link>
        </span>
      ))}
    </nav>
  )
}
