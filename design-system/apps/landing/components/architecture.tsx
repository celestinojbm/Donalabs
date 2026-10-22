import { SectionHeading } from "@/components/section-heading"
import type { Dictionary } from "@/lib/content"
import { EDGE_NETWORK, services } from "@/lib/site"

export function Architecture({ t }: { t: Dictionary }) {
  return (
    <section
      id="architecture"
      className="section section-fade mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <SectionHeading
        index={t.architecture.index}
        title={t.architecture.title}
        aside={t.architecture.aside}
      />
      <div className="grid gap-10 lg:grid-cols-2 lg:gap-0">
        <div
          className="lg:border-ink font-mono text-[13px] leading-7 lg:border-r lg:pr-10"
          aria-label={t.architecture.treeLabel}
          role="group"
        >
          <p translate="no">donalabs/</p>
          <TreeRow glyph="├──" label="start.sh" />
          <TreeRow glyph="├──" label="scripts/generate-secrets.sh" />
          <TreeRow glyph="├──" label=".env.example" />
          <TreeRow glyph="└──" label="services/" />
          <ul className="mt-0">
            {services.map((service, index) => {
              const last = index === services.length - 1
              const mapping =
                service.hostPort && service.internal
                  ? `:${service.hostPort} → ${service.internal}`
                  : t.architecture.cli
              return (
                <li key={service.id}>
                  <TreeRow
                    glyph={last ? "└──" : "├──"}
                    label={`${service.dir}/`}
                    detail={mapping}
                    nested
                  />
                </li>
              )
            })}
          </ul>
        </div>
        <div className="lg:pl-10">
          <p className="kicker tracking-[0.14em] text-muted uppercase">
            {t.architecture.networkKicker}
          </p>
          <p
            className="display mt-4 text-[clamp(2.5rem,5vw,4.25rem)]"
            translate="no"
          >
            {EDGE_NETWORK}
          </p>
          <p className="mt-6 max-w-md text-[16px] leading-relaxed">
            {t.architecture.networkBody}
          </p>
        </div>
      </div>
    </section>
  )
}

function TreeRow({
  glyph,
  label,
  detail,
  nested = false,
}: {
  glyph: string
  label: string
  detail?: string
  nested?: boolean
}) {
  return (
    <p className={`flex gap-3 ${nested ? "pl-6" : ""}`}>
      <span aria-hidden="true" className="text-muted">
        {glyph}
      </span>
      <span
        className="flex min-w-0 flex-1 flex-wrap justify-between gap-x-6"
        translate="no"
      >
        <span>{label}</span>
        {detail ? <span>{detail}</span> : null}
      </span>
    </p>
  )
}
