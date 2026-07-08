# Design tokens

Every visual value in this system — color, type, spacing, radius, shadow —
is a token, not a hardcoded value. They live in one file:
`packages/ui/src/styles/globals.css`, defined via Tailwind v4's `@theme`
directive. Live, interactive reference: run the showcase app and open
`/foundations`.

## Color system

Semantic tokens defined as OKLCH triples, with a `.dark` override block for
every token — components never reference a raw color, only the semantic
name:

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  /* ...card, popover, secondary, muted, accent, destructive, border, input, ring */
}
.dark {
  --background: oklch(0.145 0 0);
  /* ... */
}
```

`@theme inline` re-exposes each as a Tailwind color utility
(`--color-background`, `--color-primary`, ...), so `bg-background`,
`text-primary-foreground`, etc. work everywhere. **Why OKLCH:** perceptually
uniform lightness/chroma — interpolating or adjusting a token (e.g. a hover
state via `color-mix(in oklch, ...)`) doesn't produce the muddy midpoints RGB
or HSL interpolation can.

A separate 5-step `--chart-1` … `--chart-5` palette exists for data
visualization (used by `chart.tsx`), and a `--sidebar-*` set for the sidebar
layout (`sidebar.tsx`) — both light/dark paired the same way.

**Changing the brand color:** edit `--primary` (and `--primary-foreground`
for contrast) in both the `:root` and `.dark` blocks. Every component that
uses `bg-primary`/`text-primary` picks it up with no further changes.

## Typography

- **Sans:** Geist, loaded via `next/font/google` in `apps/showcase/app/layout.tsx`, exposed as the `--font-sans` CSS variable.
- **Mono:** Geist Mono, same mechanism, `--font-mono`.
- **Scale:** Tailwind's default type scale (`text-xs` through `text-4xl` and beyond) — not customized. There was no gap to fill here; the default scale is well-considered and widely understood.

## Spacing scale

Tailwind v4 generates its entire spacing scale (used by `p-4`, `gap-2`,
`w-64`, etc.) from a single base unit:

```css
--spacing: 0.25rem;
```

Every spacing utility is a multiple of that one variable. This was left at
the default — one number to change if the whole system ever needs to feel
denser or airier, rather than a scale to hand-author.

## Border radius

A 6-step scale, all derived from one base value so every corner in the
system stays proportionally consistent:

```css
--radius: 0.625rem;
--radius-sm: calc(var(--radius) * 0.6);
--radius-md: calc(var(--radius) * 0.8);
--radius-lg: var(--radius);
--radius-xl: calc(var(--radius) * 1.4);
--radius-2xl: calc(var(--radius) * 1.8);
--radius-3xl: calc(var(--radius) * 2.2);
```

Changing `--radius` alone rescales every rounded corner in the system.

## Shadows

Tailwind's default elevation scale (`shadow-xs` → `shadow-2xl`) is used
as-is — no custom shadow tokens were added. **The convention actually worth
documenting** is how the generated components use it, since that convention
is what keeps elevation consistent across the system, not the raw utility
scale itself:

| Surface | Treatment |
|---|---|
| Resting cards | No shadow — a flat `border` only |
| Popovers / dropdown menus | `shadow-md` + `ring-1 ring-foreground/10` |
| Nested/submenus | `shadow-lg` + the same ring |

The ring alongside the shadow is what makes floating surfaces read crisply
in both light and dark mode — a shadow alone gets muddy on a dark
background. When building a new floating-surface component, match this
pair rather than introducing a new elevation treatment.

## Icons

[Lucide](https://lucide.dev) — 1,600+ icons, tree-shakable via plain named
imports:

```tsx
import { Settings } from "lucide-react"

<Settings className="size-4" />
```

Defaults: `size={24}`, `stroke-width={2}`, `color="currentColor"` (so icons
inherit the surrounding text color automatically). Use `absoluteStrokeWidth`
only if an icon needs a constant stroke weight across very different
rendered sizes — by default, scaling `size` scales stroke thickness
proportionally, which is usually what you want.
