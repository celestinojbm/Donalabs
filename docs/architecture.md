# DonaLabs — Architecture

This document explains how DonaLabs is put together and **why**. The goal is a
reusable shared-services platform: modular, isolated where it matters, and easy
for other projects to consume.

## Goals

1. **Reusable** — other projects consume these services without coupling to them.
2. **Modular** — each service is self-contained and independently runnable.
3. **Isolated** — a failure or restore in one service does not affect others.
4. **Reproducible** — pinned versions, declarative config, one source of truth.
5. **Safe by default** — local-only binding, generated secrets, optional TLS edge.

---

## 1. Composition: modular stacks + a root `include`

Each service lives in `services/<name>/docker-compose.yml` as a **complete stack**
(the app plus its own database/cache). The root `docker-compose.yml` ties them
together with Compose's [`include:`](https://docs.docker.com/compose/multiple-compose-files/include/)
directive:

```yaml
name: donalabs
include:
  - path: services/vaultwarden/docker-compose.yml
  - path: services/calcom/docker-compose.yml
  # ...
```

**Why:** you get both worlds. From the repo root, `docker compose up -d` (via
`./start.sh`) runs everything as one project. But any single service is still a
standalone stack you can run on its own (`cd services/n8n && docker compose
--env-file ../../.env up -d`) or copy into another project. `include` resolves
each file's relative paths (bind mounts, build contexts) against that file's own
directory, so the stacks stay portable.

**Explicit resource names.** Every volume and network sets an explicit `name:`
(e.g. `donalabs_n8n_data`, `donalabs_edge`). Without this, Compose would prefix
resources with the project name, so a service started standalone (`project =
n8n`) and the same service started from the root (`project = donalabs`) would get
*different* volumes and silently lose data. Explicit names make persistence
identical no matter how a service is launched.

---

## 2. Networking: a shared edge, private databases

```
                 ┌─────────────────── donalabs_edge (shared, external) ───────────────────┐
   other project │  vaultwarden   calcom   plausible   penpot-frontend   n8n   open-webui  │
   containers ───┤       │           │         │             │            │        │       │
                 └───────┼───────────┼─────────┼─────────────┼────────────┼────────┼───────┘
                         │           │         │             │            │        │
              (no db on edge)   calcom_db  plausible_db   penpot_*      n8n_db   (sqlite)
                                          + clickhouse    postgres+valkey
                                   ── each on its own private <svc>_internal network ──
```

- **`donalabs_edge`** is an *external* bridge network with a fixed name. Only
  app-facing containers join it. This is the surface other projects attach to in
  order to consume services by name, and what the reverse proxy routes to.
- **`<svc>_internal`** networks are private per service. Databases and caches live
  here and are **never** placed on the edge network, so nothing outside a service
  can reach its database.
- Because the edge network is external with a fixed name, other projects reference
  it as `external: true` and immediately get name-based DNS to every service.

**Why external + fixed name:** it decouples the lifecycle of the network from any
single compose project and gives consumers a stable, predictable name.
`./start.sh` (and `scripts/init-network.sh`) create it idempotently.

---

## 3. Databases: isolated and version-matched

| Service | Datastore | Rationale |
|---|---|---|
| Cal.com | Postgres 16 | Required; own DB for isolated backup/restore |
| Plausible | Postgres 16 + ClickHouse 24.12 | Required; ClickHouse holds the analytics dataset |
| Penpot | Postgres 15 + Valkey 8.1 | Upstream pins PG 15 (volume encodes the major version) |
| n8n | Postgres 16 | Recommended over SQLite for the automation hub |
| Vaultwarden | SQLite (built-in) | Fine for personal scale; Postgres possible via `DATABASE_URL` |
| Open WebUI | SQLite (built-in) | Fine for single-user; Postgres via `DATABASE_URL` for concurrency |

**Why per-service databases rather than one shared Postgres:** each upstream
project tests against a specific database version (Penpot on 15, others on 16,
Plausible additionally on ClickHouse). Isolated databases mean version conflicts
are impossible, one database going down can't take out unrelated services, and
each service can be backed up and restored independently. With ~15 GB RAM the
extra idle memory of a few Alpine Postgres containers is negligible.

---

## 4. Configuration & secrets

- **One source of truth:** the root `.env`, documented by `.env.example`. Compose
  files interpolate `${VAR}` from it and provide safe defaults (`${VAR:-default}`)
  for non-secret settings so standalone runs still work.
- **No inline comments after values** in `.env` files — a `#` after a value can be
  parsed as part of the value. All comments sit on their own lines.
- **Generated locally:** `scripts/generate-secrets.sh` fills every `GENERATE`
  placeholder with a strong random secret (`openssl` / `secrets.token_urlsafe`),
  is idempotent (won't overwrite existing values), and `chmod 600`s the file.
- **Never committed:** `.env`, `backups/`, and runtime data are git-ignored.

---

## 5. Reliability & operations

- **Health checks** on every service (and every database) with `depends_on:
  condition: service_healthy` so apps wait for their database.
- **Restart policy** `unless-stopped` on every container.
- **Log rotation** via a `json-file` driver capped at 10 MB × 3 files per service.
- **Backups** are logical (`pg_dump`) for Postgres and volume `tar` snapshots for
  everything else, with an optional `--consistent` mode that briefly stops writers.

---

## 6. The edge: optional Caddy reverse proxy

By default, published ports bind to `127.0.0.1` — services are reachable only
from the host (and via the proxy). For public access, the optional Caddy stack in
`proxy/` provides a single HTTPS entrypoint with **automatic TLS** (Let's Encrypt
for real domains, an internal CA for `*.localhost`) and transparent WebSocket
support. Enable it with `./scripts/proxy.sh up`.

**Why opt-in:** a personal/local setup works out of the box over `http://localhost`
(which browsers treat as a secure context, so even Vaultwarden's web-crypto vault
functions locally). TLS and a public edge are a deliberate step you take when you
expose the platform.

---

## Environment-specific notes

A couple of settings exist purely to tolerate constrained or IPv6-less hosts:

- **`PENPOT_DISABLE_IPV6_LISTEN` / n8n `N8N_LISTEN_ADDRESS=0.0.0.0`** — Docker
  bridge networks often have no IPv6; without these, nginx (Penpot frontend) and
  n8n fail to bind their default `::` listener.
- **`PLAUSIBLE_CH_NOFILE` / `PLAUSIBLE_APP_NOFILE`** — default to the official
  file-descriptor limits (262144 / 65535) but can be lowered on hosts whose
  `ulimit -Hn` is below that (Docker can't raise a container's hard limit above
  the host's).
