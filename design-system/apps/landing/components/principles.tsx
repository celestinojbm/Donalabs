import { NumberTicker } from "@/components/number-ticker"
import { SectionHeading } from "@/components/section-heading"
import type { Dictionary } from "@/lib/content"

export function Principles({ t }: { t: Dictionary }) {
  return (
    <section
      id="health"
      className="section section-fade mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <SectionHeading
        index={t.principles.index}
        title={t.principles.title}
        aside={t.principles.aside}
      />
      <ul className="grid sm:grid-cols-2 xl:grid-cols-4">
        {t.principles.stats.map((stat) => (
          <li
            key={stat.spoken}
            className="border-ink border-b py-8 sm:border-r sm:px-6 xl:border-b-0 xl:first:pl-0 xl:last:pr-0 sm:[&:nth-child(2n)]:border-r-0 xl:[&:nth-child(2n)]:border-r xl:[&:nth-child(4n)]:border-r-0"
          >
            <p className="display text-[clamp(4rem,7vw,6.5rem)]">
              <span className="sr-only">{stat.spoken}</span>
              <NumberTicker value={stat.value} suffix={stat.suffix} />
            </p>
            <p className="mt-4 max-w-[14rem] text-[15px] text-muted">
              {stat.label}
            </p>
          </li>
        ))}
      </ul>
    </section>
  )
}
