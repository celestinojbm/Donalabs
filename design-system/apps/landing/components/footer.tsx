import Link from "next/link"

import { LogoMark } from "@/components/logo"
import type { Dictionary } from "@/lib/content"
import type { Locale } from "@/lib/i18n"
import { footerServices, repoLinks, services } from "@/lib/site"

export function Footer({ locale, t }: { locale: Locale; t: Dictionary }) {
  const listed = footerServices.map((id) =>
    services.find((service) => service.id === id)
  )

  return (
    <footer className="border-ink border-t">
      <div className="mx-auto grid max-w-[1600px] gap-10 px-5 py-12 md:px-16 lg:grid-cols-12">
        <div className="lg:col-span-5">
          <Link
            href={`/${locale}`}
            className="inline-flex items-center gap-2.5"
          >
            <LogoMark className="h-7 w-auto" />
            <span className="display text-[22px] leading-none">donalabs</span>
          </Link>
          <p className="mt-4 max-w-xs text-[14px] leading-relaxed text-muted">
            {t.footer.line1}
            <br />
            {t.footer.line2}
          </p>
        </div>
        <div className="grid gap-8 sm:grid-cols-3 lg:col-span-7">
          <div>
            <p className="kicker tracking-[0.14em] uppercase">
              {t.footer.services}
            </p>
            <ul className="mt-4 space-y-2 text-[14px]">
              {listed.map((service) =>
                service ? (
                  <li key={service.id}>
                    <a
                      href={repoLinks.service(service.dir)}
                      className="hover:underline"
                    >
                      {service.product}
                    </a>
                  </li>
                ) : null
              )}
            </ul>
          </div>
          <div id="footer-docs">
            <p className="kicker tracking-[0.14em] uppercase">
              {t.footer.docs}
            </p>
            <ul className="mt-4 space-y-2 text-[14px]">
              <li>
                <a href={repoLinks.quickStart} className="hover:underline">
                  {t.footer.links.start}
                </a>
              </li>
              <li>
                <a href={repoLinks.backups} className="hover:underline">
                  {t.footer.links.backups}
                </a>
              </li>
              <li>
                <a href={repoLinks.security} className="hover:underline">
                  {t.footer.links.security}
                </a>
              </li>
            </ul>
          </div>
          <div>
            <p className="kicker tracking-[0.14em] uppercase">
              {t.footer.project}
            </p>
            <ul className="mt-4 space-y-2 text-[14px]">
              <li>
                <a href={repoLinks.root} className="hover:underline">
                  {t.footer.links.github}
                </a>
              </li>
              <li>
                <a href={repoLinks.readme} className="hover:underline">
                  {t.footer.links.dona}
                </a>
              </li>
              <li>
                <a href={repoLinks.commits} className="hover:underline">
                  {t.footer.links.changes}
                </a>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </footer>
  )
}
