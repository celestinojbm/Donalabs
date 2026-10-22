import { SectionHeading } from "@/components/section-heading"
import type { Dictionary } from "@/lib/content"

export function Faq({ t }: { t: Dictionary }) {
  return (
    <section
      id="faq"
      className="section section-fade mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <SectionHeading
        index={t.faq.index}
        title={t.faq.title}
        aside={t.faq.aside}
      />
      <div>
        {t.faq.items.map((item, index) => (
          <details
            key={item.q}
            open={index === 0}
            className="border-line border-b"
          >
            <summary className="flex min-h-16 items-center justify-between gap-6 py-4 text-[18px] font-semibold">
              {item.q}
              <span aria-hidden="true" className="w-4 text-right">
                <span className="faq-plus">+</span>
                <span className="faq-minus">–</span>
              </span>
            </summary>
            <p className="max-w-3xl pb-5 text-[15px] leading-relaxed text-muted">
              {item.a}
            </p>
          </details>
        ))}
      </div>
    </section>
  )
}
