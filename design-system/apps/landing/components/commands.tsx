import { SectionHeading } from "@/components/section-heading"
import type { Dictionary } from "@/lib/content"

export function Commands({ t }: { t: Dictionary }) {
  return (
    <section
      id="docs"
      className="section mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <SectionHeading
        index={t.commands.index}
        title={t.commands.title}
        aside={t.commands.aside}
      />
      <ol className="mt-0 grid md:grid-cols-4">
        {t.commands.steps.map((step, index) => (
          <li
            key={step.title}
            className="border-ink border-b py-8 md:border-r md:border-b-0 md:px-6 md:first:pl-0 md:last:border-r-0 md:last:pr-0"
          >
            <p className="display text-[clamp(3.5rem,5vw,5rem)]">{index + 1}</p>
            <h3 className="mt-6 text-[20px] font-semibold">{step.title}</h3>
            <p className="mt-3 text-[15px] leading-relaxed text-muted">
              {step.lead ? (
                <>
                  <code
                    className="text-ink font-mono text-[13px]"
                    translate="no"
                  >
                    {step.lead}
                  </code>{" "}
                </>
              ) : null}
              {step.rest.includes(".env") ? (
                <EnvSentence text={step.rest} />
              ) : (
                step.rest
              )}
            </p>
          </li>
        ))}
      </ol>
    </section>
  )
}

function EnvSentence({ text }: { text: string }) {
  const parts = text.split(".env")
  const before = parts[0] ?? ""
  const after = parts[1] ?? ""
  return (
    <>
      {before}
      <code className="text-ink font-mono text-[13px]" translate="no">
        .env
      </code>
      {after}
    </>
  )
}
