# Maintenance

## Updating an existing component

Components are owned source (see [`components.md`](components.md)), so
there is no version to bump. To pull an upstream fix or refresh a component
you haven't customized:

```bash
cd apps/showcase
pnpm dlx shadcn@latest add <component> --overwrite
```

If you *have* customized the component, diff the incoming version first —
`--overwrite` replaces the file wholesale, it doesn't merge.

## Adding a new shadcn/ui component

```bash
cd apps/showcase
pnpm dlx shadcn@latest add <component>
```

Always confirm afterwards with `pnpm typecheck` (root) — twice during this
build the CLI placed a supporting file (a hook, a config) in the wrong
package for a monorepo, and `tsc` caught it immediately.

## Adding a Magic UI / Aceternity / Origin UI component

Same CLI, pointed at that registry's URL or shorthand:

```bash
pnpm dlx shadcn@latest add @magicui/<name>
pnpm dlx shadcn@latest add https://ui.aceternity.com/registry/<name>.json
pnpm dlx shadcn@latest add https://coss.com/origin/r/<name>.json   # NOT originui.com — see evaluated-libraries.md
```

After installing, check for two recurring issues (both hit during this
build, on official/vendored code — not hypothetical):

1. **Missing `"use client"`.** If the component uses `useState`/hooks and
   gets imported into a Server Component page, the Next.js build fails
   (not a lint warning) with *"You're importing a module that depends on
   `useState` into a React Server Component module."* Add the directive.
2. **`noUncheckedIndexedAccess` violations.** This project's shared
   `tsconfig` is stricter than many upstream registries assume. Array
   indexing (`arr[0]`) is typed `T | undefined` here; fix with an explicit
   guard (`if (arr[0]) ...`) rather than a non-null assertion, at the call
   site — don't loosen the shared tsconfig to accommodate vendored code.

## Upgrading dependencies

| Dependency | Notes |
|---|---|
| `next`, `react`, `react-dom` | Next.js 16 uses Turbopack by default and requires Node 20.9+. Read `node_modules/next/dist/docs/01-app/02-guides/upgrading/version-16.md` (bundled with the installed package) before any major bump — breaking changes move fast enough that cached/training knowledge of Next.js APIs should not be trusted without checking. |
| `tailwindcss`, `@tailwindcss/postcss` | Keep in lockstep (same version) — they publish together. |
| `radix-ui` | Single unified package; keep it, don't reintroduce scoped `@radix-ui/react-*` packages alongside it. |
| `motion` | Never add `framer-motion` alongside it — see `stack-decisions.md`. |
| `shadcn` (CLI) | Always invoke via `pnpm dlx shadcn@latest ...` rather than installing it — this ensures every run uses the current CLI/registry, which matters given how fast this ecosystem changes. |

## The pnpm monorepo dependency rule

If application code in `apps/showcase` directly imports a third-party
library (not just a re-exported `@donalabs/ui` component), that library must
be a **direct dependency of `apps/showcase`'s own `package.json`** — pnpm's
strict linking does not let an app resolve a dependency that only
`packages/ui` declares. This was hit repeatedly while building the showcase
(`motion`, `recharts`, `sonner`, `react-hook-form`, `@hookform/resolvers`,
`zod`) — fix with:

```bash
pnpm add <package> --filter @donalabs/showcase
```

## Build-script allowlist (`pnpm-workspace.yaml`)

pnpm blocks postinstall/build scripts for dependencies by default (a
supply-chain safety default). Native dependencies that need their install
script to run are explicitly allow-listed in `pnpm-workspace.yaml`'s
`onlyBuiltDependencies`. If a fresh `pnpm install` warns "Ignored build
scripts: `<package>`", and that package is a build-time necessity (a native
binary, a codegen step), add it to that list and re-run install — don't run
`pnpm approve-builds` interactively in CI.

## Continuous integration

The **Design System CI** workflow (`.github/workflows/design-system.yml` at the
repo root) runs on every change under `design-system/**`:

```
pnpm install --frozen-lockfile   # in design-system/, fails on a stale lockfile
pnpm typecheck                    # tsc --noEmit across all packages (via turbo)
pnpm lint                         # eslint across all packages
pnpm build                        # next build (all showcase routes → static)
```

Notes and the reasons behind the pins:

- **Runner order matters:** `pnpm/action-setup` runs **before** `actions/setup-node`
  so that `setup-node`'s pnpm store cache can resolve pnpm on `PATH`.
- **pnpm is pinned to `10.33.0`** (the action's `version:` input) to match the
  committed lockfile. Do **not** let it float to pnpm 11 — pnpm 11 refuses a
  lockfile written by pnpm 10 and the job fails. When you intentionally bump pnpm,
  update the `packageManager` field, the lockfile, and the workflow's `version:`
  together.
- **`cache-dependency-path: design-system/pnpm-lock.yaml`** is required because the
  lockfile is not at the repo root.
- **Node 22** (`>= 20.9` is the Next.js 16 minimum). Actions are pinned to current
  majors on the Node 24 runtime (`checkout@v7`, `setup-node@v6`, `action-setup@v6`)
  to avoid the Node-20-runtime deprecation.
- **The build needs outbound HTTPS** to `fonts.googleapis.com` / `fonts.gstatic.com`
  because `next/font/google` (Geist) fetches and self-hosts the font at build time.
  GitHub-hosted runners have this; a locked-down/self-hosted runner would need those
  hosts allow-listed, or the fonts switched to `next/font/local` with committed
  `woff2` files.
- **Telemetry/TTY** are silenced via job env (`NEXT_TELEMETRY_DISABLED`,
  `TURBO_TELEMETRY_DISABLED`, `DO_NOT_TRACK`, `TURBO_UI=false`).

Infrastructure (compose/scripts) is validated by a separate `infra.yml` workflow —
see the "Continuous Integration (CI)" section in the root `README.md`.

## Extracting `packages/ui` into a different repository

The design system is meant to be reused beyond this monorepo. To lift it
out:

1. Copy `packages/ui/` (and `packages/eslint-config/`,
   `packages/typescript-config/` if the new project wants the same lint/TS
   conventions) into the target repo.
2. If the target repo isn't a pnpm workspace with the same `@donalabs/*`
   scope, either set one up (recommended — keeps `workspace:*` resolution
   working) or publish `@donalabs/ui` to a private registry and switch the
   consuming `package.json` to a real semver dependency instead of
   `workspace:*`.
3. Copy `packages/ui/src/styles/globals.css`'s `@source` globs and adjust
   the relative path depth for the new repo's directory structure — verify
   with `realpath`, don't eyeball it (see the note in `stack-decisions.md`
   about this exact path being wrong by one level in the original scaffold).

## Known, accepted lint warnings

`pnpm lint` reports a handful of **warnings** (never errors) in vendored
registry code: `react-hooks/set-state-in-effect` and `react-hooks/refs` in
`magic-card.tsx`, `particles.tsx`, and `use-mobile.ts` (all official shadcn/
Magic UI output), and `@typescript-eslint/no-explicit-any` /
`@next/next/no-img-element` in the vendored Origin UI file-upload hook.
These are left as-is deliberately: fixing them means diverging from the
upstream registry source, which makes future `shadcn add --overwrite`
upgrades produce a diff against code we didn't actually change. This is the
same "you own the code, but some of that code isn't yours to rewrite
line-by-line" trade-off shadcn/ui's own philosophy accepts.
