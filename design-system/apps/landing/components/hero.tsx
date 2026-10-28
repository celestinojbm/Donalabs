import { ArrowRight } from "lucide-react"

import { IndexTicker } from "@/components/number-ticker"
import type { Dictionary } from "@/lib/content"
import { services } from "@/lib/site"

export function Hero({ t }: { t: Dictionary }) {
  return (
    <section className="mx-auto max-w-[1600px] px-5 pt-10 pb-12 md:px-16 md:pt-16 md:pb-14">
      <div className="lg:grid lg:grid-cols-12 lg:items-center lg:gap-8">
        <h1 className="display text-[clamp(4.25rem,12vw,12.5rem)] lg:col-span-7">
          <span className="hero-line">
            <span className="hero-line-inner">Dona</span>
          </span>
          <span className="hero-line hero-line-2">
            <span className="hero-line-inner">
              <span>{t.hero.conjunction} </span>
              <span className="accent">{t.hero.accent}</span>
            </span>
          </span>
        </h1>

        <div className="mt-8 lg:hidden">
          <p className="max-w-xl text-[17px] leading-snug">
            {t.hero.ledeShort}
          </p>
          <a
            href="#docs"
            className="btn btn-cta mt-6 w-full"
            aria-label={t.hero.ctaLabel}
          >
            <span translate="no">{t.hero.cta}</span>
            <ArrowRight
              className="arrow"
              size={16}
              strokeWidth={1.5}
              aria-hidden="true"
            />
          </a>
        </div>

        <ol
          className="border-ink mt-8 border-t-2 lg:col-span-5 lg:mt-0"
          aria-label={t.serviceSection.title}
        >
          {services.map((service, index) => (
            <li
              key={service.id}
              className="hero-row border-line flex items-baseline gap-4 border-b py-3"
            >
              <span className="kicker w-8 shrink-0 text-muted">
                <span className="sr-only">
                  {String(index + 1).padStart(2, "0")}
                </span>
                <IndexTicker value={index + 1} delay={index * 40} />
              </span>
              <span className="min-w-0">
                <span
                  className="block text-[15px] font-semibold"
                  translate="no"
                >
                  {service.product}
                </span>
                <span className="block text-[14px] text-muted">
                  {t.serviceSection.items[service.id].summary}
                </span>
              </span>
            </li>
          ))}
        </ol>
      </div>

      <div
        className="rule rule-load mt-10 hidden lg:mt-14 lg:block"
        aria-hidden="true"
      />

      <div className="mt-8 hidden items-end justify-between gap-6 lg:flex">
        <p className="max-w-xl text-[18px] leading-snug">{t.hero.lede}</p>
        <a
          href="#docs"
          className="btn btn-cta shrink-0"
          aria-label={t.hero.ctaLabel}
        >
          <span translate="no">{t.hero.cta}</span>
          <ArrowRight
            className="arrow"
            size={16}
            strokeWidth={1.5}
            aria-hidden="true"
          />
        </a>
      </div>
    </section>
  )
}
