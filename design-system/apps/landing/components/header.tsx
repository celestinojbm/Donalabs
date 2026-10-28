"use client"

import { Menu, X } from "lucide-react"
import Link from "next/link"
import { useEffect, useId, useRef, useState } from "react"

import { GithubIcon } from "@/components/github-icon"
import { LanguageSwitcher } from "@/components/language-switcher"
import { LogoMark } from "@/components/logo"
import type { Dictionary } from "@/lib/content"
import type { Locale } from "@/lib/i18n"
import { repoLinks } from "@/lib/site"

type HeaderProps = {
  locale: Locale
  t: Dictionary
}

const links = [
  { href: "#services", key: "services" },
  { href: "#architecture", key: "architecture" },
  { href: "#docs", key: "docs" },
  { href: "#health", key: "health" },
  { href: "#costs", key: "costs" },
] as const

export function Header({ locale, t }: HeaderProps) {
  const [open, setOpen] = useState(false)
  const menuId = useId()
  const buttonRef = useRef<HTMLButtonElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false)
        buttonRef.current?.focus()
      }
    }
    document.addEventListener("keydown", onKey)
    // Close when the viewport reaches xl (panel is hidden there), else the
    // body scroll lock would stay on with no visible menu.
    const desktop = window.matchMedia("(min-width: 80rem)")
    const onDesktop = () => {
      if (desktop.matches) setOpen(false)
    }
    desktop.addEventListener("change", onDesktop)
    const previous = document.body.style.overflow
    document.body.style.overflow = "hidden"
    panelRef.current?.querySelector<HTMLElement>("a")?.focus()
    return () => {
      document.removeEventListener("keydown", onKey)
      desktop.removeEventListener("change", onDesktop)
      document.body.style.overflow = previous
    }
  }, [open])

  return (
    <header className="border-ink bg-paper sticky top-0 z-30 border-b">
      <div className="mx-auto flex h-[72px] max-w-[1600px] items-center gap-4 px-5 md:px-16">
        <Link
          href={`/${locale}`}
          className="flex items-center gap-2.5"
          onClick={() => setOpen(false)}
        >
          <LogoMark className="h-7 w-auto" />
          <span className="display text-[22px] leading-none">donalabs</span>
        </Link>

        <nav aria-label={t.nav.primary} className="ml-8 hidden xl:block">
          <ul className="flex items-center gap-7">
            {links.map((link) => (
              <li key={link.href}>
                <a
                  href={link.href}
                  className="inline-flex h-11 items-center text-[15px]"
                >
                  {t.nav[link.key]}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div className="ml-auto flex items-center gap-2 sm:gap-3">
          <LanguageSwitcher
            locale={locale}
            label={t.langLabel}
            names={t.languages}
          />
          <a
            href={repoLinks.root}
            className="btn btn-secondary hidden sm:inline-flex"
          >
            <GithubIcon />
            {t.nav.github}
          </a>
          <button
            ref={buttonRef}
            type="button"
            className="icon-btn xl:hidden"
            aria-expanded={open}
            aria-controls={menuId}
            onClick={() => setOpen((value) => !value)}
          >
            {open ? (
              <X strokeWidth={1.5} size={20} aria-hidden="true" />
            ) : (
              <Menu strokeWidth={1.5} size={20} aria-hidden="true" />
            )}
            <span className="sr-only">
              {open ? t.nav.closeMenu : t.nav.openMenu}
            </span>
          </button>
        </div>
      </div>

      {open ? (
        <div
          id={menuId}
          ref={panelRef}
          className="border-ink bg-paper max-h-[calc(100dvh-72px)] overflow-y-auto border-t xl:hidden"
        >
          <nav
            aria-label={t.nav.mobile}
            className="mx-auto max-w-[1600px] px-5 md:px-16"
          >
            <ul>
              {links.map((link) => (
                <li key={link.href} className="border-line border-b">
                  <a
                    href={link.href}
                    className="flex h-12 items-center text-[18px] font-semibold"
                    onClick={() => setOpen(false)}
                  >
                    {t.nav[link.key]}
                  </a>
                </li>
              ))}
            </ul>
            <div className="flex flex-col gap-4 py-5">
              <LanguageSwitcher
                locale={locale}
                label={t.langLabel}
                names={t.languages}
                verbose
              />
              <a href={repoLinks.root} className="btn btn-secondary w-full">
                <GithubIcon />
                {t.nav.github}
              </a>
            </div>
          </nav>
        </div>
      ) : null}
    </header>
  )
}
