import Link from "next/link"
import {
  ArrowRightIcon,
  BlocksIcon,
  LayoutDashboardIcon,
  PaletteIcon,
  SquareDashedMousePointerIcon,
  WandIcon,
} from "lucide-react"

import { Badge } from "@donalabs/ui/components/badge"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@donalabs/ui/components/card"

const STACK = [
  "Tailwind CSS v4",
  "shadcn/ui",
  "Radix UI",
  "Motion",
  "Magic UI",
  "Lucide Icons",
]

const SECTIONS = [
  {
    href: "/foundations",
    icon: PaletteIcon,
    title: "Foundations",
    description: "Color, typography, spacing, radius, shadows, and icons.",
  },
  {
    href: "/components",
    icon: BlocksIcon,
    title: "Components",
    description: "Buttons, forms, cards, tables, navigation, overlays, notifications.",
  },
  {
    href: "/dashboard",
    icon: LayoutDashboardIcon,
    title: "Dashboard example",
    description: "The sidebar shell, stat cards, and chart composed into a real screen.",
  },
  {
    href: "/animations",
    icon: WandIcon,
    title: "Animations",
    description: "Motion patterns — fade, layout, presence, stagger — and the rules to follow.",
  },
  {
    href: "/marketing",
    icon: SquareDashedMousePointerIcon,
    title: "Marketing (Magic UI)",
    description: "Marquee, bento grid, border beam, particles, and more.",
  },
] as const

export default function OverviewPage() {
  return (
    <div className="space-y-12">
      <div className="space-y-4 border-b pb-8">
        <Badge variant="secondary">Design System</Badge>
        <h1 className="max-w-2xl text-3xl font-semibold tracking-tight sm:text-4xl">
          The shared design platform for DonaLabs
        </h1>
        <p className="max-w-2xl text-muted-foreground">
          One design system, owned as source code, consumed by every DonaLabs project.
          Built on Tailwind CSS v4, shadcn/ui (on Radix UI primitives), Motion, Magic UI,
          and Lucide — unified rather than stitched together.
        </p>
        <div className="flex flex-wrap gap-2 pt-2">
          {STACK.map((tech) => (
            <Badge key={tech} variant="outline">
              {tech}
            </Badge>
          ))}
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {SECTIONS.map((section) => (
          <Link key={section.href} href={section.href} className="group">
            <Card className="h-full transition-colors group-hover:border-primary/50">
              <CardHeader>
                <section.icon className="size-5 text-muted-foreground" />
                <CardTitle className="flex items-center gap-1.5">
                  {section.title}
                  <ArrowRightIcon className="size-3.5 opacity-0 transition-opacity group-hover:opacity-100" />
                </CardTitle>
                <CardDescription>{section.description}</CardDescription>
              </CardHeader>
              <CardContent />
            </Card>
          </Link>
        ))}
        <Link href="/evaluated" className="group">
          <Card className="h-full border-dashed transition-colors group-hover:border-primary/50">
            <CardHeader>
              <CardTitle className="flex items-center gap-1.5">
                Evaluated libraries
                <ArrowRightIcon className="size-3.5 opacity-0 transition-opacity group-hover:opacity-100" />
              </CardTitle>
              <CardDescription>
                Aceternity UI and Origin UI (adopted selectively) · HeroUI (documented, not adopted).
              </CardDescription>
            </CardHeader>
            <CardContent />
          </Card>
        </Link>
      </div>

      <div className="text-xs text-muted-foreground">
        Press <kbd className="rounded border bg-muted px-1.5 py-0.5 font-mono">d</kbd> to toggle dark mode.
      </div>
    </div>
  )
}
