import type { Metadata } from "next"
import { CheckCircle2Icon, XCircleIcon } from "lucide-react"

import { PageHeader, Section } from "@/components/page-header"
import { HoverEffect } from "@donalabs/ui/components/card-hover-effect"
import OriginFileUploadDemo from "@/components/evaluated/origin-file-upload"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@donalabs/ui/components/card"
import { Badge } from "@donalabs/ui/components/badge"

export const metadata: Metadata = { title: "Evaluated libraries" }

const HOVER_ITEMS = [
  { title: "Vaultwarden", description: "Secrets manager", link: "#" },
  { title: "Cal.com", description: "Scheduling", link: "#" },
  { title: "Plausible", description: "Analytics", link: "#" },
]

export default function EvaluatedPage() {
  return (
    <div className="space-y-12">
      <PageHeader
        title="Evaluated libraries"
        description="Three additional libraries were evaluated for compatibility with the core stack (Tailwind v4 + shadcn/ui + Radix + Motion + Lucide) before deciding whether to integrate them. Two are adopted selectively, with a live proof-of-concept below; one is documented and explicitly not adopted."
      />

      <Section title="Aceternity UI — adopted selectively">
        <div className="mb-4 flex items-start gap-3 rounded-lg border bg-card p-4">
          <CheckCircle2Icon className="mt-0.5 size-5 shrink-0 text-emerald-600 dark:text-emerald-400" />
          <div className="space-y-1 text-sm">
            <p className="font-medium">Clean fit for decorative/marketing components.</p>
            <p className="text-muted-foreground">
              Current registry components declare <code className="font-mono">motion</code> (not legacy
              framer-motion) and reuse the identical clsx+tailwind-merge <code className="font-mono">cn()</code> —
              no duplicate dependencies. They are hand-rolled (not Radix-based), so use shadcn/Radix for
              accessibility-sensitive interactive UI (dialogs, menus, forms) and Aceternity only for visual
              flourishes. Installed here via{" "}
              <code className="font-mono">shadcn add https://ui.aceternity.com/registry/card-hover-effect.json</code>.
            </p>
          </div>
        </div>
        <HoverEffect items={HOVER_ITEMS} />
      </Section>

      <Section title="Origin UI (legacy, coss.com/origin) — adopted selectively">
        <div className="mb-4 flex items-start gap-3 rounded-lg border bg-card p-4">
          <CheckCircle2Icon className="mt-0.5 size-5 shrink-0 text-emerald-600 dark:text-emerald-400" />
          <div className="space-y-1 text-sm">
            <p className="font-medium">A genuine drop-in for the exact stack we already have.</p>
            <p className="text-muted-foreground">
              Originui.com now redirects to coss.com, which split the project: the frozen legacy snapshot at{" "}
              <code className="font-mono">coss.com/origin</code> is still Radix + shadcn + Lucide + cn() — zero
              duplicate dependencies — while the actively-developed successor (&quot;coss ui&quot;) rebuilt on
              Base UI is a competing foundation and was deliberately{" "}
              <span className="font-medium">not</span> used. Cherry-pick from the legacy set for rich
              inputs, file upload, data tables, and calendars — areas stock shadcn/ui is thin. Installed via{" "}
              <code className="font-mono">shadcn add https://coss.com/origin/r/comp-125.json</code>.
            </p>
          </div>
        </div>
        <Card className="max-w-md">
          <CardHeader>
            <CardTitle className="text-sm">Basic image uploader</CardTitle>
            <CardDescription>coss.com/origin · comp-125</CardDescription>
          </CardHeader>
          <CardContent>
            <OriginFileUploadDemo />
          </CardContent>
        </Card>
      </Section>

      <Section title="HeroUI — evaluated, not adopted">
        <div className="flex items-start gap-3 rounded-lg border bg-card p-4">
          <XCircleIcon className="mt-0.5 size-5 shrink-0 text-destructive" />
          <div className="space-y-2 text-sm">
            <p className="font-medium">
              A strong library, but a second full component system — not integrated.
              <Badge variant="outline" className="ml-2">No components installed</Badge>
            </p>
            <p className="text-muted-foreground">
              HeroUI v3 is genuinely current (Tailwind v4-native, provider-free, no more Framer Motion
              runtime), but it runs on React Aria Components — a second headless-interaction library
              alongside Radix — and its <code className="font-mono">@heroui/styles</code> theme reuses the exact
              same CSS variable names shadcn/ui does (<code className="font-mono">--background</code>,{" "}
              <code className="font-mono">--foreground</code>, <code className="font-mono">--radius</code>).
              Importing both stylesheets means whichever loads last silently overwrites the other&apos;s
              palette, and shipping two accessibility/interaction runtimes for a stack that already has
              Radix solving that problem isn&apos;t worth it. <code className="font-mono">@heroui/react</code>{" "}
              even ships its own <code className="font-mono">@radix-ui/react-avatar</code> dependency, so the
              &quot;cleanly separate&quot; framing doesn&apos;t hold up under inspection either.
            </p>
            <p className="text-muted-foreground">
              If a future project needs one of React Aria&apos;s genuinely hard-to-build-well primitives
              (internationalized Calendar/DateRangePicker/TimeField, ColorArea/ColorWheel), use HeroUI&apos;s
              documented headless mode — skip <code className="font-mono">@heroui/styles</code> entirely and
              hand-style the component logic with the existing Tailwind/shadcn classes — rather than
              importing its full theme.
            </p>
          </div>
        </div>
      </Section>
    </div>
  )
}
