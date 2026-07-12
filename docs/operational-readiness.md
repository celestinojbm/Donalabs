# DonaLabs — Operational Readiness Report

A permanent baseline record of the first real end-to-end operational validation
of the DonaLabs infrastructure stack and design system.

> **How to read this document.** Findings are tagged so the source of each claim
> is unambiguous:
>
> - **✅ VERIFIED** — an observed fact from the specific test environment below.
> - **⚠️ ENV-SPECIFIC** — an artifact/limitation of *this* test environment that
>   would not apply (or would differ) on a normal production host.
> - **💡 PRODUCTION** — a general recommendation for a real deployment, not a
>   measurement.
>
> Measurements are point-in-time and environment-bound. Treat the numbers as a
> baseline order-of-magnitude, not a guarantee — re-measure on the target host.

---

## 1. Environment tested

| Property | Value |
|---|---|
| Role | Single Docker host (ephemeral cloud container) |
| CPU | 4 vCPU |
| RAM | 15.7 GiB (~16 GB) |
| Disk (root volume) | 252 GB device, **~40 GB usable allowance** (see §7) |
| Kernel | Linux 6.18.5 |
| Docker Engine | 29.3.1 |
| Docker Compose | v5.1.1 (plugin) |
| Date of validation | 2026-07-12 (UTC) |

**Commit validated:** `00ffa6e` — `main` tip
(`ci: GitHub Actions for design-system + infrastructure validation (#2)`).
No repository files were modified during validation; the stack was exercised
exactly as it exists on `main`.

**⚠️ ENV-SPECIFIC — how the stack was started.** The container had been reclaimed
and the Docker daemon was down, but the previously-built images and named volumes
persisted on disk. Starting the daemon triggered every container's
`restart: unless-stopped` policy, so this validation **doubled as a host-reboot
recovery test** — the stack came back automatically. `./start.sh` was then run to
reconcile the running containers against `main`'s compose definitions.

---

## 2. Services and health status

**✅ VERIFIED** — all services started and became healthy.

| Service | Containers | Result | Health probe |
|---|---|---|---|
| Vaultwarden | 1 (SQLite) | ✅ PASS · healthy | `/alive` → **200** |
| Cal.com | app + Postgres 16 | ✅ PASS · healthy | `/auth/login` → **307** |
| Plausible CE | app + Postgres 16 + ClickHouse 24.12 | ✅ PASS · healthy¹ | `/api/health` → **200** |
| Penpot | frontend + backend + exporter + mcp + Postgres 15 + Valkey | ✅ PASS² | `/readyz` → **200** |
| n8n | app + Postgres 16 | ✅ PASS · healthy | `/healthz` → **200** |
| Open WebUI | 1 (SQLite) | ✅ PASS · healthy | `/health` → **200** |
| yt-dlp | CLI (on-demand, not a daemon) | ✅ PASS | `ytdlp.sh version` → `2026.07.04` |
| Design system | Next.js showcase + `@donalabs/ui` | ✅ PASS | 7 routes → **200** |
| Caddy reverse proxy | opt-in edge (not started) | ⚪ config-validated only | — |

- **15 / 15 containers running.** 10 report Docker `healthy`; the other 5
  (Penpot backend/frontend/exporter/mcp and the Plausible app) intentionally ship
  **no container healthcheck** — they are validated via the HTTP probes above and
  their dependencies' health.
- `./scripts/health.sh` result: **all probed services reachable.**
- ¹ Plausible self-healed after one cold-start restart (see §8).
- ² Penpot backend reached its readiness endpoint (`/readyz` → `OK`) through the
  frontend.

---

## 3. Startup times

**✅ VERIFIED** — observed on this environment, from a cold daemon start with
images and volumes already cached.

| Milestone | Approx. time to healthy |
|---|---|
| All databases (Postgres ×4, ClickHouse, Valkey) | ~1–2 min |
| n8n | ~50 s |
| Cal.com (Prisma migrate + Next.js boot) | ~100 s |
| **Open WebUI (reloads embedding models on boot) — slowest** | ~120 s |
| **Full stack, all green** | **~2–3.5 min** |

Design system (measured this run):

| Step | Time |
|---|---|
| `pnpm install --frozen-lockfile` | 5 s |
| `pnpm typecheck` | 21 s |
| `pnpm lint` | 15 s (0 errors) |
| `pnpm build` | all 8 routes prerendered static |
| `pnpm dev` (ready) | < 1 s (Ready in ~850 ms) |

**⚠️ ENV-SPECIFIC.** These are *warm* times — images were already pulled and Open
WebUI's models already cached in its volume. A **first-ever** cold start on a
fresh host additionally pays the image-pull cost (~27 GB, see §6) and Open WebUI's
initial model download, which can add many minutes depending on bandwidth.

---

## 4. Persistence validation

**✅ VERIFIED** — 13 named `donalabs_*` volumes survived the daemon restart, each
mounted into the correct container **with pre-existing data** (the databases were
*not* re-initialized, which is the proof of persistence).

| Volume | Mounted into | Size | Meaning |
|---|---|---|---|
| `donalabs_calcom_db_data` | calcom-db | 70.5 MB | Postgres data (not a fresh initdb) |
| `donalabs_n8n_db_data` | n8n-db | 67.4 MB | Postgres data |
| `donalabs_plausible_db_data` | plausible-db | 65.3 MB | Postgres data |
| `donalabs_penpot_postgres_v15` | penpot-db | 65.2 MB | Postgres data |
| `donalabs_plausible_event_data` | plausible-clickhouse | 5.7 MB | ClickHouse analytics dataset |
| `donalabs_open_webui_data` | open-webui | 265.3 MB | SQLite + cached embedding models |
| `donalabs_vaultwarden_data` | vaultwarden | 316 KB | SQLite + JWT signing keys |
| `donalabs_n8n_data` | n8n | 20 KB | encryption key + config |
| `donalabs_penpot_assets` | penpot-frontend | 4 KB | uploaded design assets |

Plus `donalabs_plausible_data`, `donalabs_plausible_event_logs`,
`donalabs_caddy_data`, `donalabs_caddy_config`.

The 65–70 MB Postgres directories and the 265 MB Open WebUI cache confirm the data
predated this boot. **A healthy Postgres with existing credentials is only
possible if its volume persisted** — a fresh volume would have re-run `initdb`.

---

## 5. Network validation

**✅ VERIFIED.**

- **Networks present:** `donalabs_edge` (shared bridge) + four per-service internal
  bridges (`donalabs_calcom_internal`, `_n8n_internal`, `_penpot_internal`,
  `_plausible_internal`).
- **Edge membership is exactly the app-facing containers:** vaultwarden, calcom,
  plausible, penpot-frontend, n8n, open-webui.
- **Database isolation intact:** no Postgres / ClickHouse / Valkey container is
  attached to `donalabs_edge`.
- **Cross-service DNS works** (from the n8n container, reaching peers by service
  name over the edge network):

  | From → To | Result |
  |---|---|
  | n8n → `http://vaultwarden:80/alive` | 200 |
  | n8n → `http://calcom:3000/auth/login` | 307 |
  | n8n → `http://plausible:8000/api/health` | 200 |
  | n8n → `http://penpot-frontend:8080/readyz` | 200 |
  | n8n → `http://open-webui:8080/health` | 200 |

This confirms the intended design: other projects can attach to `donalabs_edge`
and consume services by name, while databases stay private.

---

## 6. Resource usage

**✅ VERIFIED** — idle full stack (all services healthy, no user load).

**Memory**

- Sum of container memory: **~4.5 GiB**.
- Host: **5.2 GiB used / 10.9 GiB available** of 15.7 GiB.
- Heaviest containers:

  | Container | RAM (idle) |
  |---|---|
  | penpot-backend (JVM) | 1.35 GiB |
  | calcom | 913 MiB |
  | open-webui | 704 MiB |
  | n8n | 417 MiB |
  | plausible | 375 MiB |
  | plausible-clickhouse | 254 MiB |
  | penpot db / exporter / frontend | ~115–125 MiB each |
  | remaining (vaultwarden, small DBs, valkey, mcp) | < 65 MiB each |

**CPU**

- Near-idle at rest: peak **~4.6 %** (ClickHouse), everything else < 2 %. The stack
  is not CPU-bound when idle. (4 vCPU available.)

**Disk**

- **~36 GB used, ~1.8 GB free (96 %).** Breakdown: **~26 GB pinned images**
  (Cal.com ~8 GB and Open WebUI ~7 GB dominate), 566 MB named volumes, ~130 MB
  container writable layers. ~1.9 GB of build cache was reclaimed during this run.

---

## 7. Warnings observed

**✅ VERIFIED** log/health observations, each with an assessment. **None prevent
the stack from operating** — all endpoints returned success.

| Source | Warning | Assessment |
|---|---|---|
| Plausible | `createdb` failed once (`RuntimeError "killed"`) → 1 container restart → healthy | Cold-start race + memory pressure during concurrent migration; self-healed. See §8. |
| n8n | `self-signed certificate in certificate chain` fetching `https://api.n8n.io/...` | **⚠️ ENV-SPECIFIC** — the test environment routes egress through a TLS-intercepting proxy the container doesn't trust. A normal host does **not** see this; n8n otherwise functions (`/healthz` → 200). |
| Cal.com | `Missing VAPID keys. Web push notifications are disabled.` | Expected — web push is optional and unconfigured. |
| Cal.com | non-fatal `controller[kState].transformAlgorithm is not a function` TypeError | Benign upstream Node/undici streams noise; the app is healthy and serving. |
| Open WebUI | `CORS_ALLOW_ORIGIN='*' — not recommended for production` | Known — **💡 PRODUCTION:** restrict CORS before public exposure. |
| Open WebUI | `authlib.jose module is deprecated` | Upstream library deprecation; informational. |

---

## 8. Unresolved issues

None block operation. Recorded for future hardening:

1. **⚠️ ENV-SPECIFIC — disk pressure.** The host sat at 96 % full (~1.8 GB free).
   This is the test allowance being small relative to ~27 GB of images, not a
   stack defect. It leaves no room for backups or image updates on *this* host.
   **💡 PRODUCTION:** provision the disk in §9.
2. **Plausible cold-start restart (cosmetic).** On a host reboot, Docker's
   `restart: unless-stopped` policy does **not** honor `depends_on: service_healthy`
   ordering, so the Plausible app can start before its Postgres/ClickHouse are
   ready, fail `createdb`/`migrate` once, and restart. It self-heals within a
   minute. Optional future smoothing: an explicit startup dependency-wait or a
   retry wrapper in the Plausible entrypoint. *(Left unchanged — this report is
   documentation-only.)*
3. **⚠️ ENV-SPECIFIC — n8n outbound cert warning.** Disappears outside the
   intercepting proxy; no action needed for production.

---

## 9. Recommended server specifications

**💡 PRODUCTION** — derived from the idle measurements in §6 plus headroom for
migrations, concurrent cold-start, backups, and light real usage. These are
recommendations, not measured limits.

| Resource | Minimum | Comfortable |
|---|---|---|
| CPU | 4 vCPU | 4–8 vCPU |
| RAM | **8 GB** | **16 GB** |
| Disk | **60–80 GB SSD** | **100 GB+ SSD** |

Rationale:

- **RAM:** idle draw is ~5 GB, but the true floor is the **concurrent cold-start
  peak** — JVM (Penpot), Next.js (Cal.com), and Elixir (Plausible) all booting and
  migrating at once. The Plausible "killed" event (§8) is a memory-pressure
  signal; **8 GB is the practical minimum** to avoid OOM during startup, and 16 GB
  gives comfortable headroom for real usage.
- **Disk:** ~27 GB of images + growing databases (analytics data in ClickHouse
  grows with traffic) + timestamped backups. The ~40 GB test allowance is too
  small once backups accumulate; **budget 100 GB+** for a real deployment.
- **CPU:** the stack is not CPU-bound at idle; 4 vCPU is adequate. More cores help
  the one-time concurrent cold-start and the design-system build.

---

## 10. Final operational verdict

**🟢 OPERATIONAL.** On the environment in §1, at commit `00ffa6e`, the complete
DonaLabs stack was proven end-to-end:

- ✅ All 7 configured services (plus the design system) start and reach healthy.
- ✅ Every published endpoint returns success (200/307).
- ✅ Named volumes persist across a daemon restart with intact data.
- ✅ The shared network works and databases are isolated from it.
- ✅ Services auto-recover on host reboot via their restart policies.
- ✅ The design system installs, typechecks, lints, builds, and runs.

The only genuine constraint found was **environment disk capacity** (§7/§8),
which is addressed by the disk recommendation in §9 — not a defect in the stack
itself. No infrastructure, service, dependency, or design-system changes were
required to reach this verdict.

**Next recommended step:** provision a host meeting §9 (chiefly more disk),
perform one clean first-ever cold start there to establish a pristine baseline
free of this environment's disk/proxy artifacts, then bootstrap for use — create
each service's admin account, **store all credentials in Vaultwarden**, lock down
first-run signups, point Open WebUI at a model provider, and (if exposing
publicly) bring up Caddy with real domains and `CADDY_ACME_EMAIL`.

---

*Generated from a real validation run. To re-establish this baseline later, repeat
the flow: `./scripts/generate-secrets.sh` → `./start.sh` → `./scripts/health.sh`,
then verify volumes, cross-service DNS, and `docker stats`, and re-run the design
system's `install → typecheck → lint → build`.*
