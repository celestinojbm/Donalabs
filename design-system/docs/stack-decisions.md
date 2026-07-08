# Stack decisions

Why each technology was chosen, how they fit together, and the trade-offs
that were consciously made. Facts below were verified live against each
project's official docs/registry at the time of writing (mid-2026) — this
ecosystem moves fast enough that "what everyone remembers" and "what's
actually current" diverge within months.

## Tailwind CSS v4

**Adopted as the styling foundation.** v4 replaced the JS `tailwind.config.js`
model with CSS-first configuration: design tokens are declared directly in
CSS via `@theme`, and content scanning is automatic (no `content: [...]`
array to maintain or forget). This is the version the entire modern
ecosystem — including shadcn/ui — now targets by default.

**Monorepo-specific detail:** Tailwind's automatic content detection stops at
the package boundary of the CSS file's own package. Because
`packages/ui/src/styles/globals.css` needs to scan `apps/*` for utility
classes too, it declares that explicitly:

```css
@source "../../../../apps/**/*.{ts,tsx}";
```

(Four `../` to climb from `packages/ui/src/styles/` back to the monorepo
root — get this path wrong and classes used only in the app silently never
generate. This is a real trap: the shadcn monorepo scaffold as generated in
mid-2026 originally shipped this path one level too shallow, resolving to a
nonexistent `packages/apps` directory instead of `design-system/apps`. Verify
with `realpath` after any restructuring, not by eye.)

## shadcn/ui — and the Base UI vs. Radix decision

**Adopted, explicitly configured for Radix.** This needs a longer explanation
because the situation changed *this month* relative to most existing
tutorials and cached knowledge:

As of July 2026, `npx shadcn@latest init` **defaults to Base UI**, not Radix,
as the underlying primitives library. This is a genuine, recent CLI default
change (shadcn's own changelog cites Base UI reaching a stable 1.0, 6M+
weekly downloads, and users of the visual `shadcn/create` builder choosing
Base UI over Radix roughly 2:1). Radix is **not deprecated** — "we still
support it, and every update and new component will ship for both
libraries" — but it is opt-in now:

```bash
pnpm dlx shadcn@latest init -b radix       # explicit Radix
pnpm dlx shadcn@latest init                # defaults to Base UI today
```

DonaLabs' stack explicitly names **Radix UI** as a core technology, so every
`init`/`add` in this repo passes `-b radix`. This project uses the `nova`
preset (`style: "radix-nova"` in `components.json`) — one of eight new named
design presets (Vega, Nova, Maia, Lyra, Mira, Luma, Sera, Rhea) that shadcn
now ships, each available in both a Radix and a Base UI flavor. Nova pairs
with Lucide + Geist by default, matching the rest of this stack, and reads as
the current flagship look rather than the older, now-secondary `new-york`
style.

**Practical effect:** every generated component imports Radix primitives from
the single unified `radix-ui` package (see below), not the individual
`@radix-ui/react-*` packages. `components.json`'s `style` and `baseColor` are
locked at `init` time — changing them later means reinstalling every
component — so this choice is meant to be made once, deliberately, which is
exactly what happened here.

## Radix UI

**Adopted via the unified `radix-ui` package**, not the legacy per-primitive
`@radix-ui/react-*` packages. Radix's own docs are explicit: "We recommend
installing the `radix-ui` package and importing the primitives you need...
prevent version conflicts or duplication, and makes it easy to manage
updates." The scoped packages still exist and are still maintained in
lockstep, but are now the secondary path. shadcn's CLI (in Radix mode)
generates the unified import automatically:

```ts
import { Dialog as DialogPrimitive } from "radix-ui"
```

Projects that pre-date this (Feb 2026) shadcn changelog can migrate with
`pnpm dlx shadcn@latest migrate radix`. Don't mix the unified package with
several standalone scoped packages long-term — that reintroduces the
duplication problem the unified package exists to solve.

## Motion (the current name for Framer Motion)

**Adopted as the animation library**, imported as `motion/react` — never the
legacy `framer-motion` package name. Framer Motion was rebranded to Motion
(motion.dev) after going independent. Both `motion` and `framer-motion` are
still published in lockstep from the same monorepo (`framer-motion` is not
npm-deprecated), but `motion` is the actively documented, current surface —
`framer-motion` is legacy status in every current doc and migration guide.
Magic UI, Aceternity UI, and shadcn/ui's own newer components all standardize
on `motion/react` too, so there is exactly one animation runtime in this
stack, not two.

Full patterns and performance rules: [`animations.md`](animations.md).

## Magic UI

**Adopted selectively**, not as a base dependency. Magic UI is not a package
you `npm install` — it's a shadcn-registry-compatible component collection
installed per-component through the same CLI already in use:

```bash
pnpm dlx shadcn@latest add @magicui/marquee
pnpm dlx shadcn@latest add @magicui/border-beam
```

Because it piggybacks on shadcn's own registry mechanism, components land in
`packages/ui/src/components/`, reuse the same `cn()` utility, and declare
`motion` (not `framer-motion`) as their animation dependency — there is no
separate build pipeline and no duplicate dependency. It is an effects/polish
layer for marketing and dashboard-widget moments (marquee, bento grids,
border beams, number tickers), not a replacement for shadcn's interactive
primitives — dialogs, forms, and menus stay Radix-based.

## Lucide (`lucide-react`)

**Adopted as the icon library** — it's shadcn/ui's own default icon set, so
adopting anything else would mean fighting the generated component imports.
Plain named ESM imports (`import { Camera } from "lucide-react"`) tree-shake
correctly in every modern bundler; no wrapper component was built around it
since Lucide's own API (a `LucideIcon` type, consistent `size`/`strokeWidth`
props) is already the right level of abstraction — adding a name-map wrapper
on top would be an abstraction with no real payoff at this project's size.

## What ships vs. what's evaluated

The four items above are the **core, always-installed** stack. Three more
libraries were evaluated for compatibility before deciding whether to
integrate — two are adopted selectively with a live proof-of-concept in the
showcase app, one is documented and explicitly not adopted. See
[`evaluated-libraries.md`](evaluated-libraries.md) for the full reasoning.
