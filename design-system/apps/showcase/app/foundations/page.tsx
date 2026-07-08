import type { Metadata } from "next"

import { PageHeader, Section } from "@/components/page-header"
import { ColorSwatches } from "@/components/foundations/color-swatches"
import { TypeScale } from "@/components/foundations/type-scale"
import {
  SpacingScale,
  RadiusScale,
  ShadowScale,
} from "@/components/foundations/spacing-radius-shadow"
import { IconGrid } from "@/components/foundations/icon-grid"

export const metadata: Metadata = { title: "Foundations" }

export default function FoundationsPage() {
  return (
    <div className="space-y-10">
      <PageHeader
        title="Foundations"
        description="The design tokens every component in this system is built from — color, typography, spacing, radius, shadows, and icons. Defined once in packages/ui/src/styles/globals.css via Tailwind v4's @theme, consumed everywhere as CSS variables."
      />
      <Section
        title="Color system"
        description="OKLCH semantic tokens with automatic light/dark pairing (toggle the theme in the header). Every component references these variables, never a raw color."
      >
        <ColorSwatches />
      </Section>
      <Section
        title="Typography"
        description="Geist (sans) and Geist Mono, loaded via next/font and exposed as CSS variables. A standard Tailwind type scale — no custom overrides needed."
      >
        <TypeScale />
      </Section>
      <Section
        title="Spacing scale"
        description="Tailwind v4's default scale, generated from a single --spacing base unit (0.25rem). One knob to rescale the entire system if ever needed."
      >
        <SpacingScale />
      </Section>
      <Section
        title="Border radius"
        description="A 6-step scale derived from one --radius base value, so every corner in the system stays proportionally consistent."
      >
        <RadiusScale />
      </Section>
      <Section
        title="Shadows"
        description="Tailwind's default elevation scale. Convention used across this system: shadow-md + a subtle ring for floating surfaces (popovers, dropdowns), shadow-lg for nested menus, flat borders for resting cards."
      >
        <ShadowScale />
      </Section>
      <Section
        title="Icons"
        description="Lucide — 1,600+ tree-shakable icons, default size 24/stroke 2. Import only what you use; the bundler drops the rest."
      >
        <IconGrid />
      </Section>
    </div>
  )
}
