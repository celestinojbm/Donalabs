import {
  Archive,
  Calendar,
  ChartColumn,
  KeyRound,
  MessageSquare,
  PenTool,
  Workflow,
  type LucideIcon,
} from "lucide-react"

import { SectionHeading } from "@/components/section-heading"
import type { Dictionary } from "@/lib/content"
import { services, type ServiceId } from "@/lib/site"

const icons: Record<ServiceId, LucideIcon> = {
  vaultwarden: KeyRound,
  calcom: Calendar,
  plausible: ChartColumn,
  penpot: PenTool,
  n8n: Workflow,
  openwebui: MessageSquare,
  ytdlp: Archive,
}

export function Services({ t }: { t: Dictionary }) {
  return (
    <section
      id="services"
      className="section section-fade mx-auto max-w-[1600px] px-5 py-16 md:px-16 md:py-24"
    >
      <SectionHeading
        index={t.serviceSection.index}
        title={t.serviceSection.title}
        aside={t.serviceSection.aside}
      />
      <ul className="grid md:grid-cols-3">
        {services.map((service, index) => {
          const Icon = icons[service.id]
          const copy = t.serviceSection.items[service.id]
          const wide = service.id === "ytdlp"
          return (
            <li
              key={service.id}
              className={
                wide
                  ? "border-line border-b py-7 md:col-span-3"
                  : "border-line border-b py-7 md:border-r md:px-6 md:[&:nth-child(3n)]:border-r-0 md:[&:nth-child(3n)]:pr-0 md:[&:nth-child(3n+1)]:pl-0"
              }
            >
              <div className={wide ? "max-w-md" : undefined}>
                <div className="flex items-center justify-between">
                  <span className="kicker text-muted">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  <Icon size={20} strokeWidth={1.5} aria-hidden="true" />
                </div>
                <h3 className="mt-8 text-[28px] font-semibold tracking-[-0.03em]">
                  {copy.name}
                </h3>
                <p className="mt-2 max-w-sm text-[15px] text-muted">
                  {copy.blurb}
                </p>
              </div>
            </li>
          )
        })}
      </ul>
    </section>
  )
}
