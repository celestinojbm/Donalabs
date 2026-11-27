import { Check } from "lucide-react"

import type { Dictionary } from "@/lib/content"

export function Costs({ t }: { t: Dictionary }) {
  return (
    <section
      id="costs"
      className="section section-fade mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <div className="grid items-end gap-6 md:grid-cols-12">
        <h2 className="display text-[clamp(4rem,9vw,8rem)] md:col-span-7">
          <span className="block">{t.costs.titleLine1}</span>
          <span className="block">{t.costs.titleLine2}</span>
        </h2>
        <p className="max-w-sm text-[16px] leading-snug md:col-span-5 md:ml-auto md:text-right">
          {t.costs.aside}
        </p>
      </div>
      <div className="rule mt-6 md:mt-8" aria-hidden="true" />
      <p
        role="note"
        className="border-ink border-b py-4 font-mono text-[13px] leading-relaxed"
      >
        {t.costs.banner}
      </p>
      <div className="grid lg:grid-cols-3">
        {t.costs.plans.map((plan, index) => {
          const featured = index === 1
          return (
            <article
              key={plan.index}
              className="border-ink flex flex-col border-b py-8 lg:border-r lg:border-b-0 lg:px-6 lg:first:pl-0 lg:last:border-r-0 lg:last:pr-0"
            >
              <div className="flex items-center justify-between gap-3">
                <p className="kicker">
                  {plan.index}
                  <span aria-hidden="true"> — </span>
                  {plan.name}
                </p>
                <span className="border-ink inline-flex h-6 items-center border px-2 font-mono text-[12px] tracking-[0.08em] uppercase">
                  {t.costs.example}
                </span>
              </div>
              <p className="display mt-8 text-[clamp(4.5rem,8vw,7rem)]">
                <span className="sr-only">{plan.priceSpoken}</span>
                <span aria-hidden="true">€{plan.price}</span>
              </p>
              <p className="mt-3 font-mono text-[13px] text-muted">
                {t.costs.perMonth} · {plan.spec}
              </p>
              <ul className="border-ink mt-6 border-t">
                {plan.features.map((feature) => (
                  <li
                    key={feature}
                    className="border-line flex items-center gap-3 border-b py-3 text-[15px]"
                  >
                    <Check size={16} strokeWidth={1.5} aria-hidden="true" />
                    {feature}
                  </li>
                ))}
              </ul>
              <a
                href={featured ? "#start" : "#docs"}
                className={`btn mt-8 w-full ${featured ? "btn-cta" : "btn-secondary"}`}
              >
                {featured ? t.costs.deploy : t.costs.guide}
              </a>
            </article>
          )
        })}
      </div>
    </section>
  )
}
