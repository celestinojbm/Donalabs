import type { Dictionary } from "@/lib/content"
import { cloneCommand, repoLinks } from "@/lib/site"

export function Cta({ t }: { t: Dictionary }) {
  return (
    <section
      id="start"
      className="section mx-auto max-w-[1600px] px-5 pt-8 pb-16 md:px-16 md:pt-12 md:pb-20"
    >
      <h2 className="display text-[clamp(4.5rem,10vw,8.5rem)]">
        <span className="block">{t.cta.line1}</span>
        <span className="block">{t.cta.line2}</span>
      </h2>
      <div className="rule mt-6 md:mt-8" aria-hidden="true" />
      <div className="mt-6 flex flex-col gap-5 md:mt-8 md:flex-row md:items-center md:justify-between">
        <p
          className="overflow-x-auto font-mono text-[13px] md:text-[14px]"
          translate="no"
        >
          <span className="text-muted">$ </span>
          {cloneCommand}
        </p>
        <a
          href={repoLinks.root}
          className="btn btn-cta w-full shrink-0 md:w-auto"
        >
          {t.cta.button}
        </a>
      </div>
    </section>
  )
}
