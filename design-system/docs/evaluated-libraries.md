# Evaluated libraries

Three additional component libraries were evaluated for compatibility with
the core stack (Tailwind v4 + shadcn/ui + Radix UI + Motion + Lucide) before
deciding whether to integrate them, per the instruction to evaluate before
adopting. Live proof-of-concept demos for the two adopted ones are in the
showcase app's `/evaluated` route.

## Aceternity UI — adopted selectively

**ui.aceternity.com.** A shadcn-registry-compatible collection of hand-rolled,
heavily animated marketing/landing-page components (3D cards, moving
borders, animated modals, text effects).

- **Compatible today:** current registry items declare `motion` (not the
  legacy `framer-motion` package) and reuse the identical
  `clsx` + `tailwind-merge` `cn()` shadcn already provides — verified by
  reading the actual registry JSON payloads, not just the marketing docs.
  Zero duplicate dependencies when cherry-picked this way.
- **Not Radix-based.** Components are hand-rolled with context/hooks +
  Motion, not built on Radix primitives. That means they generally lack the
  accessibility scaffolding (focus trapping, ARIA roles, keyboard nav,
  `prefers-reduced-motion` handling) Radix-backed shadcn components get for
  free. **Do not substitute an Aceternity "modal" for shadcn/Radix `Dialog`**
  in accessibility-sensitive app UI — use it for decorative/marketing
  components only.
- **A real (but narrow) v4 gap:** a subset of *older*, pre-registry
  copy-paste components rely on a custom Tailwind plugin
  (`addVariablesForColors`/`flattenColorPalette`) written for the old
  JS-config model, which doesn't translate cleanly to Tailwind v4's
  CSS-first `@theme`. Newer, registry-distributed components (including the
  one installed here) sidestep this since they ship v4-native. Check any
  *manually copy-pasted* (non-registry) snippet's generated CSS before
  trusting it's v4-clean.

**Installed:** `card-hover-effect` (`HoverEffect`), via
`pnpm dlx shadcn@latest add https://ui.aceternity.com/registry/card-hover-effect.json`.
It needed one fix on install: the registry payload was missing a `"use
client"` directive (it uses `useState`), which fails the Next.js build (not
just a lint warning) when the component is imported into a Server Component
page. Added it manually after install — check for this on any future
Aceternity component that uses hooks.

## Origin UI (legacy, `coss.com/origin`) — adopted selectively

**A genuine drop-in for this exact stack — but the brand split, and the
naming is a trap.** In Oct 2025, Origin UI's creators merged the project
into Cal.com's `coss.com` holding company. `originui.com` now permanently
redirects to `coss.com/ui`. That destination is a **different, actively
developed project** ("coss ui") rebuilt from scratch on **Base UI**, marketed
explicitly as a migration path *away from* Radix/shadcn — not the library
this evaluation is about.

The classic, Radix-based Origin UI still exists, frozen and in
maintenance-only mode, at a different URL: **`coss.com/origin`**. That's the
one that's a real drop-in:

- Same `radix-ui` unified package, same `lucide-react`, same
  `class-variance-authority` + `cn()` convention as the rest of this stack —
  verified by reading `apps/origin/package.json` in the `cosscom/coss`
  monorepo directly.
- MIT-licensed (confirmed in the same `package.json`) — though other parts of
  that monorepo (the Cal.com product itself) are AGPLv3, so don't assume the
  whole repo shares one license.
- Strong exactly where stock shadcn/ui is thin: rich input variants
  (OTP/tags/phone/payment), **file upload**, data tables (TanStack Table),
  tree views, drag-and-drop sortable lists, calendars, steppers.

**The trap:** any pre-2026 tutorial, blog post, or cached reference to
`originui.com/r/{name}.json` is now dead — it 301-redirects to an HTML
marketing page, not JSON, and `shadcn add` will fail against it. The correct
registry host for the Radix-compatible set is `coss.com/origin/r/{name}.json`.

**Installed:** the "Basic image uploader" pattern (`comp-125.tsx` +
`use-file-upload.ts` hook), via
`pnpm dlx shadcn@latest add https://coss.com/origin/r/comp-125.json`.
Landed in `apps/showcase/components/evaluated/` and
`apps/showcase/hooks/use-file-upload.ts` (app-local — the registry item type
is `registry:component`, not `registry:ui`, so the CLI correctly treated it
as app-level composition rather than a shared-package primitive). Needed
three small fixes after install: this project's shared `tsconfig` enables
`noUncheckedIndexedAccess` (stricter than what the upstream registry code
assumes), which surfaced three real possibly-undefined array-index accesses
in the vendored hook and demo component — each fixed with an explicit guard
rather than a type assertion.

## HeroUI — evaluated, not adopted

**heroui.com** (formerly NextUI). HeroUI v3, current as of mid-2026, is a
genuinely strong, current, Tailwind-v4-native, provider-free component
library — the old objections to it (a required `HeroUIProvider`, a legacy
Tailwind plugin, a bundled Framer Motion runtime) are all gone in v3.

**Why it's still not integrated:**

1. **A second full headless-interaction runtime.** HeroUI v3 runs on
   **React Aria Components** (Adobe), not Radix. Running both means shipping
   two accessibility/interaction foundations in the same app for no real
   benefit — Radix already solves the problem HeroUI would be solving again.
   `react-aria-components` also has a documented history of poor
   tree-shaking in Next.js (Adobe react-spectrum issues #4356, #5639).
2. **Token collision, not namespacing.** HeroUI's theme variables
   (`--background`, `--foreground`, `--radius`) are mapped through Tailwind
   v4's `@theme` directive — the exact same mechanism and the exact same
   variable *names* shadcn/ui uses for its own tokens. Importing both
   `@heroui/styles` and this project's `globals.css` into the same cascade
   means whichever loads last **silently overwrites** the other's palette.
   There is no automatic namespacing; avoiding this requires deliberate
   `@layer` ordering or confining each library to a separate subtree.
3. **The "cleanly separate" framing doesn't hold up.** `@heroui/react`'s own
   published `package.json` depends directly on `@radix-ui/react-avatar` —
   so even choosing HeroUI doesn't actually avoid a second Radix version
   floating in the dependency tree.

**Verdict: not adopted, no components installed.** If a future project needs
one of React Aria's genuinely hard-to-build-well primitives —
internationalized `Calendar`/`DateRangePicker`/`TimeField`,
`ColorArea`/`ColorWheel` — the documented path is HeroUI's **headless mode**:
skip `@heroui/styles` entirely, import only the component logic, and
hand-style it with this project's existing Tailwind/shadcn classes. Never
import HeroUI's full themed stylesheet into an app that also loads this
design system's `globals.css`.

## Penpot design tokens → code sync

Out of scope for automation. Penpot's native Design Tokens panel (W3C DTCG
format, stable spec since Oct 2025) is a real, mature design-time feature,
but Penpot's own docs still list a public plugin/tokens API as "coming soon"
— there is no official, maintained Style Dictionary format for either
Tailwind v4's `@theme` or shadcn's CSS-variable convention.

**Recommendation for a team this size: manual sync, not a pipeline.** Treat
Penpot's token panel as the shared design vocabulary/documentation; keep
`packages/ui/src/styles/globals.css` hand-maintained by engineers as the
actual source of truth for the codebase. When a design token changes in
Penpot, export the JSON, eyeball the diff, and update the handful of
affected CSS variables by hand — this costs far less than building and
maintaining a Style-Dictionary-based Penpot → Tailwind pipeline for a token
set small enough to diff in minutes. Revisit only if the team scales to
multiple brands/themes or very frequent token churn.
