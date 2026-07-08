# Components

## Philosophy: owned source, not a dependency

Every component in `packages/ui/src/components/` is a plain `.tsx` file you
can open and edit — vendored via the shadcn CLI, not pulled in as an opaque
`node_modules` dependency. There is no version of `@donalabs/ui` to bump for
a component tweak; you edit the file. This is shadcn/ui's own philosophy
("you own the code") and it's why the design system can diverge
per-DonaLabs-need without forking anything.

**Consequence:** re-running `shadcn add <component>` on a component you've
customized will offer to overwrite your edits. Diff before accepting, or
apply the upstream fix by hand.

## Composition over customization

Prefer composing existing primitives into a new file over adding
configuration flags to an existing one. `StatCard` and `EmptyState`
(`packages/ui/src/components/composite/`) exist because they're genuine,
repeated patterns (a KPI tile; a "no data yet" placeholder) built entirely
from primitives already in the system — `Card`, `NumberTicker`, `Badge` for
the former; a styled `div` for the latter. Neither needed a new primitive,
just a composed convention. Reach for a new primitive only when no
combination of existing ones produces the right behavior (not just the right
look).

## Inventory

| Category | Components |
|---|---|
| Buttons | `button` |
| Forms | `field`, `field-group`, `field-label`, `field-description`, `field-error` (+ `react-hook-form`, `@hookform/resolvers`, `zod`) |
| Inputs | `input`, `input-group`, `textarea`, `checkbox`, `switch`, `select`, `label` |
| Cards | `card` |
| Tables | `table` |
| Navigation | `navigation-menu`, `breadcrumb`, `tabs`, `sidebar` |
| Dialogs / Modals | `dialog`, `sheet` |
| Dropdowns / Overlays | `dropdown-menu`, `popover`, `command` |
| Tooltips | `tooltip` |
| Notifications | `sonner` (toasts), `alert`, `skeleton` |
| Layout | `separator`, `scroll-area` |
| Dashboard | `sidebar`, `chart` (recharts wrapper), `composite/stat-card`, `composite/empty-state` |
| Marketing (Magic UI) | `marquee`, `bento-grid`, `border-beam`, `particles`, `shiny-button`, `number-ticker`, `magic-card`, `animated-beam` |
| Evaluated | `card-hover-effect` (Aceternity UI) · Origin UI file-upload demo lives in `apps/showcase/components/evaluated/` (app-local, not promoted to the shared package — see below) |

Live, working examples of every row: run the showcase app, visit
`/components`, `/dashboard`, `/marketing`, and `/evaluated`.

## Forms: the current pattern (not the one you remember)

shadcn/ui's monolithic `Form`/`FormField`/`FormItem`/`FormControl`/
`FormMessage` wrapper (the one most existing tutorials and cached training
data describe) has been replaced. The current registry `form` item is now
an empty stub — the real pattern lives under **three form-library-specific
guides** (React Hook Form, TanStack Form, Formisch), and for React Hook Form
specifically it's `Controller` (from `react-hook-form` directly) composed
with a generic `Field`/`FieldLabel`/`FieldDescription`/`FieldError`/
`FieldGroup` primitive set — not form-library-specific components:

```tsx
<Controller
  name="email"
  control={form.control}
  render={({ field, fieldState }) => (
    <Field data-invalid={fieldState.invalid}>
      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
      <Input {...field} id={field.name} aria-invalid={fieldState.invalid} />
      <FieldError errors={fieldState.error ? [fieldState.error] : []} />
    </Field>
  )}
/>
```

A full working example is in `apps/showcase/components/demos/form-demo.tsx`.

## Monorepo dependency rule (a real gotcha, hit repeatedly during this build)

pnpm's workspace linking is strict: if a file in `apps/showcase` directly
`import`s a library (e.g. `motion`, `recharts`, `sonner`, `react-hook-form`),
that library must be a **direct dependency of `apps/showcase`'s own
`package.json`** — even if `packages/ui` already depends on it. Importing
`@donalabs/ui`'s re-exported *components* is fine without this; importing a
third-party library *directly* in app code is not. `tsc`/Turbopack will fail
with "Cannot find module" if this is missed — it was missed and hit multiple
times while building this showcase, each time fixed with:

```bash
pnpm add <package> --filter @donalabs/showcase
```

## Sidebar & dashboard layout

`sidebar.tsx` is shadcn's full composable dashboard-shell primitive
(`SidebarProvider`, `Sidebar`, `SidebarInset`, `SidebarMenu*`, collapsible to
icon-only, mobile-responsive via a `Sheet`). It is wired into
`apps/showcase/app/layout.tsx` once, at the root, so every route in the
showcase app automatically gets the sidebar chrome — see
`apps/showcase/components/app-sidebar.tsx` and `site-header.tsx` for the
concrete composition. Reuse this same pattern (`SidebarProvider` in the root
layout, an `AppSidebar` component listing routes) for any new DonaLabs
project that needs a dashboard shell.

## Adding a new component

```bash
cd apps/showcase   # any app in the workspace works — the CLI resolves the shared package
pnpm dlx shadcn@latest add <component>
```

The CLI reads `apps/showcase/components.json`, which points `tailwind.css`
at `packages/ui/src/styles/globals.css` and aliases `ui`/`components` to
`@donalabs/ui/components` — so primitives land in the shared package
automatically. Verify this after adding anything non-trivial: the CLI has
occasionally misplaced a supporting hook file into the app instead of the
shared package (this happened with `sidebar`'s `use-mobile.ts` dependency
during this build — the file landed in `apps/showcase/hooks/` while
`sidebar.tsx` imported it from `@donalabs/ui/hooks/use-mobile`). Check any
new hook/util file lands next to the component that needs it, and run
`pnpm typecheck` immediately — it will catch a misplaced import.
