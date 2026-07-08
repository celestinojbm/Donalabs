import type { Metadata } from "next"

import { PageHeader, Section } from "@/components/page-header"
import { MotionFadeDemo } from "@/components/demos/motion-fade-demo"
import { MotionLayoutDemo } from "@/components/demos/motion-layout-demo"
import { MotionPresenceDemo } from "@/components/demos/motion-presence-demo"
import { MotionStaggerDemo } from "@/components/demos/motion-stagger-demo"
import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "@donalabs/ui/components/alert"
import { InfoIcon } from "lucide-react"

export const metadata: Metadata = { title: "Animations" }

export default function AnimationsPage() {
  return (
    <div className="space-y-12">
      <PageHeader
        title="Animations"
        description="Motion (motion.dev, the current name for Framer Motion) is the standard animation library for DonaLabs — import from motion/react, never the legacy framer-motion package."
      />

      <Section
        title="Fade / slide-in"
        description="The default entrance for cards, panels, and anything appearing on mount. Animate transform (x/y/scale) and opacity only — both run on the compositor thread, so they stay smooth even during heavy React re-renders."
      >
        <MotionFadeDemo />
      </Section>

      <Section
        title="Layout animation (shared element)"
        description="A single motion.div with a shared layoutId animates between positions automatically when it re-mounts under a different tab — no manual coordinate math."
      >
        <MotionLayoutDemo />
      </Section>

      <Section
        title="AnimatePresence (enter/exit)"
        description="Exiting elements need a stable, unique key and must be a direct child of AnimatePresence — otherwise the exit animation silently doesn't fire."
      >
        <MotionPresenceDemo />
      </Section>

      <Section
        title="Stagger"
        description="A parent variants object with staggerChildren cascades the animation across children — no manual per-item delay math."
      >
        <MotionStaggerDemo />
      </Section>

      <Section title="Performance & accessibility rules">
        <div className="space-y-3">
          <Alert>
            <InfoIcon />
            <AlertTitle>Prefer transform and opacity</AlertTitle>
            <AlertDescription>
              Animating width, height, top/left, or box-shadow forces layout/paint on
              the main thread. Animate transform (x, y, scale) and opacity instead —
              use the layout prop when a size change is unavoidable.
            </AlertDescription>
          </Alert>
          <Alert>
            <InfoIcon />
            <AlertTitle>Don&apos;t blanket-apply will-change</AlertTitle>
            <AlertDescription>
              Motion does not auto-apply will-change everywhere on purpose — doing so
              on many elements causes real GPU memory pressure on mid-range Android.
              Apply it narrowly, only around the animation window, if you add it at all.
            </AlertDescription>
          </Alert>
          <Alert>
            <InfoIcon />
            <AlertTitle>Respect prefers-reduced-motion</AlertTitle>
            <AlertDescription>
              Wrap the app in MotionConfig with reducedMotion=&quot;user&quot; (or call
              useReducedMotion in a specific component) — the OS setting is not
              respected automatically and must be opted into explicitly.
            </AlertDescription>
          </Alert>
          <Alert>
            <InfoIcon />
            <AlertTitle>&quot;use client&quot; is required</AlertTitle>
            <AlertDescription>
              Any file using motion.div, useMotionValue, or AnimatePresence needs a
              &quot;use client&quot; directive — Motion relies on refs and hooks and
              cannot render in a Server Component.
            </AlertDescription>
          </Alert>
        </div>
      </Section>
    </div>
  )
}
