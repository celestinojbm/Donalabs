# Animations

Motion (`motion/react` — the current name for Framer Motion) is the standard
animation library for DonaLabs. Live, working versions of every pattern
below are in `apps/showcase/app/animations/page.tsx` and
`apps/showcase/components/demos/motion-*.tsx`.

## Setup

```bash
pnpm add motion --filter <your-app-or-package>
```

```tsx
"use client"
import { motion, AnimatePresence } from "motion/react"
```

Any file using `motion.div`, `useMotionValue`, `useSpring`, or
`AnimatePresence` needs `"use client"` — Motion relies on refs and hooks and
cannot render in a Server Component. This is a real, easy-to-miss failure
mode: a component imported into a Server Component page that's missing this
directive fails at build time with *"You're importing a module that depends
on `useState` into a React Server Component module"* — hit once during this
build (a vendored third-party registry component was missing the directive)
and it is a build-blocking error, not a lint warning, so it surfaces late if
you only `typecheck` and never `build`.

## Patterns

### Fade / slide-in

The default entrance for cards, panels, anything appearing on mount:

```tsx
<motion.div
  initial={{ opacity: 0, y: 12 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.35, ease: "easeOut" }}
>
```

Animate **transform (x/y/scale) and opacity only** — see Performance below
for why.

### Layout animation (shared element)

A single element with a stable `layoutId` animates automatically between two
positions when it re-mounts in a different place (e.g. an active-tab
indicator moving between tabs) — no manual coordinate math:

```tsx
{active === tab && (
  <motion.div layoutId="active-pill" transition={{ type: "spring", stiffness: 500, damping: 35 }} />
)}
```

### AnimatePresence (enter/exit)

```tsx
<AnimatePresence initial={false}>
  {items.map((item) => (
    <motion.li key={item.id} layout initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }}>
      ...
    </motion.li>
  ))}
</AnimatePresence>
```

Exiting children need a **stable, unique `key`** and must be a **direct
child** of `AnimatePresence` — violate either and the exit animation silently
never fires (no error, it just doesn't animate out).

### Stagger

A parent `variants` object with `staggerChildren` cascades the animation
across children without per-item delay math:

```tsx
const container = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }
const item = { hidden: { opacity: 0, y: 8 }, show: { opacity: 1, y: 0 } }

<motion.div variants={container} initial="hidden" animate="show">
  {children.map((c) => <motion.div key={c.id} variants={item}>{c.content}</motion.div>)}
</motion.div>
```

### Scroll-triggered (NumberTicker and similar)

Magic UI's `NumberTicker` uses `useInView` internally — the count-up only
starts once the element scrolls into the viewport. **This is correct
behavior, not a bug**: on a long page, a ticker placed below the fold will
show its starting value (usually `0`) until the user scrolls to it. Verify
placement above the fold if a ticker needs to animate immediately on page
load (e.g. a dashboard's top-row stat cards).

## Performance rules

1. **Animate `transform` and `opacity` only.** Both run on the compositor
   thread. Animating `width`, `height`, `top`/`left`, or `box-shadow` forces
   layout/paint on the main thread — use the `layout` prop instead when a
   size change is unavoidable, and avoid animating `width`/`height` directly
   alongside it (they fight for the same visual result via different
   mechanisms and can look distorted mid-animation).
2. **Don't blanket-apply `will-change`.** Motion deliberately does not
   auto-apply it everywhere — doing so across many elements causes real GPU
   memory pressure on mid-range Android. Apply it narrowly, only around the
   actual animation window, if at all.
3. **Respect `prefers-reduced-motion` explicitly.** The OS setting is *not*
   respected automatically. Wrap the app in `<MotionConfig reducedMotion="user">`
   or call `useReducedMotion()` in a specific component — this must be an
   explicit opt-in.
4. **Combining `layoutId` with border-radius/box-shadow changes** can look
   distorted mid-transition unless wrapped in `LayoutGroup`. Test the actual
   transition, not just the two end states.

## What NOT to import

Never import from the bare `framer-motion` package or from `"motion"`
without `/react` — both still exist and still resolve (Motion wraps
`framer-motion` internally and both are versioned in lockstep), but every
current example, migration guide, and this codebase's own conventions use
`motion/react` exclusively. A stray `framer-motion` import copied from an
older tutorial doesn't break anything technically, but it's an inconsistency
worth catching in review — grep for it if in doubt:

```bash
grep -rn "from \"framer-motion\"" packages/ui/src apps/*/components apps/*/app
```
