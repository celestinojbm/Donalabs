# DonaLabs Design System

The shared, reusable design platform for DonaLabs and every project built on
top of it — components, tokens, and conventions defined once and consumed
everywhere, rather than re-decided per project.

## Stack

| Layer | Choice | Role |
|---|---|---|
| Styling | **Tailwind CSS v4** | CSS-first tokens (`@theme`), utility classes |
| Components | **shadcn/ui** (CLI, `-b radix`, `radix-nova` preset) | Owned, editable component source |
| Primitives | **Radix UI** (`radix-ui` unified package) | Accessible, unstyled interaction behavior |
| Animation | **Motion** (`motion/react`) | The current name for Framer Motion |
| Marketing/effects | **Magic UI** | Selective, high-impact visual components |
| Icons | **Lucide** (`lucide-react`) | Tree-shakable icon set |

Full rationale for every choice — including why shadcn/ui's Radix mode was
selected explicitly over its new Base UI default — is in
[`docs/stack-decisions.md`](docs/stack-decisions.md).

## Structure

```
design-system/
├── apps/
│   └── showcase/          Next.js 16 app — the living style guide (this is what you run)
├── packages/
│   ├── ui/                 @donalabs/ui — the component library other projects import
│   │   └── src/
│   │       ├── components/         shadcn/ui + Magic UI + evaluated-library components
│   │       │   └── composite/      StatCard, EmptyState — built from the primitives above
│   │       ├── hooks/
│   │       ├── lib/utils.ts        cn() — clsx + tailwind-merge
│   │       └── styles/globals.css  design tokens (Tailwind v4 @theme)
│   ├── eslint-config/       shared flat ESLint config
│   └── typescript-config/   shared tsconfig bases
├── docs/                    architecture & reference docs (this folder)
├── turbo.json                task pipeline (build/lint/typecheck/dev)
└── pnpm-workspace.yaml
```

## Quick start

```bash
cd design-system
pnpm install
pnpm dev        # starts the showcase app — http://localhost:3000
```

```bash
pnpm build      # production build (all apps/packages, via Turborepo)
pnpm lint       # ESLint, all packages
pnpm typecheck  # tsc --noEmit, all packages
```

## Using the design system in another project

`@donalabs/ui` is a workspace package, not an npm-published one. To consume it
from a new app inside this same monorepo:

```json
// apps/your-app/package.json
{
  "dependencies": {
    "@donalabs/ui": "workspace:*"
  }
}
```

```ts
// app/layout.tsx
import "@donalabs/ui/globals.css"
import { Button } from "@donalabs/ui/components/button"
```

To consume it from a **separate** repository, copy `packages/ui` in (the
shadcn/ui philosophy: components are owned source, not a dependency you
`npm install` and lose the ability to edit). See
[`docs/maintenance.md`](docs/maintenance.md) for the exact steps and what to
rename.

## Documentation

- [`docs/stack-decisions.md`](docs/stack-decisions.md) — why each technology, and how they fit together
- [`docs/design-tokens.md`](docs/design-tokens.md) — color, typography, spacing, radius, shadows, icons
- [`docs/components.md`](docs/components.md) — the component inventory, composition philosophy, when to use what
- [`docs/animations.md`](docs/animations.md) — Motion patterns and performance rules
- [`docs/evaluated-libraries.md`](docs/evaluated-libraries.md) — Aceternity UI, HeroUI, Origin UI: what was adopted and why
- [`docs/maintenance.md`](docs/maintenance.md) — upgrading components, bumping versions, known warnings

## The showcase app

`apps/showcase` is both the development environment for the component library
and its documentation site. Every page renders real, working components (not
static images) — routes:

| Route | Content |
|---|---|
| `/` | Overview |
| `/foundations` | Design tokens: color, typography, spacing, radius, shadows, icons |
| `/components` | Buttons, forms, cards, tables, navigation, dialogs, notifications |
| `/dashboard` | A composed, realistic dashboard screen |
| `/animations` | Motion patterns + performance/accessibility rules |
| `/marketing` | Magic UI components |
| `/evaluated` | Aceternity UI / Origin UI live demos + the HeroUI verdict |
