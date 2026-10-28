import { DrawRule } from "@/components/motion"

type SectionHeadingProps = {
  index?: string
  title: string
  aside?: string
  id?: string
}

export function SectionHeading({
  index,
  title,
  aside,
  id,
}: SectionHeadingProps) {
  return (
    <div>
      <div className="grid items-end gap-6 md:grid-cols-12">
        <div className="md:col-span-7">
          {index ? <p className="kicker mb-4">{index}</p> : null}
          <h2 id={id} className="display text-[clamp(3rem,6.5vw,4.75rem)]">
            {title}
          </h2>
        </div>
        {aside ? (
          <p className="max-w-xs text-[16px] leading-snug md:col-span-5 md:ml-auto md:text-right">
            {aside}
          </p>
        ) : null}
      </div>
      <DrawRule className="mt-6 md:mt-8" />
    </div>
  )
}
