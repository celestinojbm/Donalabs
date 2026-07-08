import type { Metadata } from "next"
import {
  ActivityIcon,
  CalendarIcon,
  KeyRoundIcon,
  PaletteIcon,
  WorkflowIcon,
} from "lucide-react"

import { PageHeader, Section } from "@/components/page-header"
import { AnimatedBeamDemo } from "@/components/demos/animated-beam-demo"
import { Marquee } from "@donalabs/ui/components/marquee"
import { BentoCard, BentoGrid } from "@donalabs/ui/components/bento-grid"
import { BorderBeam } from "@donalabs/ui/components/border-beam"
import { Particles } from "@donalabs/ui/components/particles"
import { ShinyButton } from "@donalabs/ui/components/shiny-button"
import { MagicCard } from "@donalabs/ui/components/magic-card"
import { NumberTicker } from "@donalabs/ui/components/number-ticker"
import { Card } from "@donalabs/ui/components/card"

export const metadata: Metadata = { title: "Marketing (Magic UI)" }

const LOGOS = ["Vaultwarden", "Cal.com", "Plausible", "Penpot", "n8n", "Open WebUI"]

const BENTO_ITEMS = [
  {
    name: "Vaultwarden",
    description: "Central secrets manager for every service credential.",
    Icon: KeyRoundIcon,
    href: "#",
    cta: "Learn more",
    className: "col-span-3 lg:col-span-1",
    background: <div />,
  },
  {
    name: "Cal.com",
    description: "Bookings, calls, and demos — scheduled without leaving DonaLabs.",
    Icon: CalendarIcon,
    href: "#",
    cta: "Learn more",
    className: "col-span-3 lg:col-span-2",
    background: <div />,
  },
  {
    name: "n8n",
    description: "The automation hub wiring every other service together.",
    Icon: WorkflowIcon,
    href: "#",
    cta: "Learn more",
    className: "col-span-3 lg:col-span-2",
    background: <div />,
  },
  {
    name: "Plausible",
    description: "Privacy-friendly analytics for every landing page.",
    Icon: ActivityIcon,
    href: "#",
    cta: "Learn more",
    className: "col-span-3 lg:col-span-1",
    background: <div />,
  },
]

export default function MarketingPage() {
  return (
    <div className="space-y-12">
      <PageHeader
        title="Marketing (Magic UI)"
        description="Magic UI is adopted selectively — pulled in per-component via the shadcn CLI for high-impact visual moments. It is an effects/polish layer, not a replacement for shadcn's form and interaction primitives."
      />

      <Section title="Hero background (Particles)">
        <div className="relative flex h-48 items-center justify-center overflow-hidden rounded-xl border bg-background">
          <Particles className="absolute inset-0" quantity={80} ease={80} color="#888888" refresh />
          <ShinyButton>Explore the platform</ShinyButton>
        </div>
      </Section>

      <Section title="Marquee" description="Infinite auto-scrolling row — logos, testimonials, feature callouts.">
        <Marquee pauseOnHover className="[--duration:25s]">
          {LOGOS.map((logo) => (
            <div
              key={logo}
              className="mx-2 flex h-12 items-center rounded-lg border bg-card px-6 text-sm font-medium text-muted-foreground"
            >
              {logo}
            </div>
          ))}
        </Marquee>
      </Section>

      <Section title="Bento grid" description="Asymmetric feature/dashboard-widget layout.">
        <BentoGrid>
          {BENTO_ITEMS.map((item) => (
            <BentoCard key={item.name} {...item} />
          ))}
        </BentoGrid>
      </Section>

      <Section title="Border beam" description="An animated light traveling around a card border — highlighted CTAs, pricing cards.">
        <Card className="relative w-full max-w-sm overflow-hidden p-6">
          <p className="font-medium">Premium plan</p>
          <p className="text-sm text-muted-foreground">Everything, self-hosted.</p>
          <BorderBeam duration={6} size={100} />
        </Card>
      </Section>

      <Section title="Magic card" description="A subtle spotlight that follows the cursor — a premium hover treatment for feature cards.">
        <MagicCard className="flex h-32 w-full max-w-sm items-center justify-center rounded-xl border p-6" gradientColor="var(--muted)">
          <p className="text-sm text-muted-foreground">Hover this card</p>
        </MagicCard>
      </Section>

      <Section title="Number ticker" description="Animated counting — KPI tiles, pricing pages.">
        <p className="text-4xl font-semibold tabular-nums">
          <NumberTicker value={2847} />
          <span className="text-muted-foreground"> deployments</span>
        </p>
      </Section>

      <Section
        title="Animated beam"
        description="A gradient beam connecting DOM nodes — 'how it works' and integration diagrams."
      >
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <PaletteIcon className="size-3.5" /> Vaultwarden, Cal.com &amp; Plausible feeding into DonaLabs
        </div>
        <AnimatedBeamDemo />
      </Section>
    </div>
  )
}
