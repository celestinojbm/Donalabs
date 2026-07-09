# DonaLabs

**Personal AI infrastructure & shared services platform.**

DonaLabs is not a product. It is a reusable, self-hosted platform that provides
shared services — password management, scheduling, analytics, design, automation,
media tooling, and an AI interface — for all of my current and future projects
(Dona and beyond). Everything is defined as code, version-pinned, persisted,
health-checked, backed up, and ready to be consumed by other projects.

---

## Services

| Service | Role | Local URL (default) | Internal address (on `donalabs_edge`) |
|---|---|---|---|
| **Vaultwarden** | Password & secrets manager (Bitwarden-compatible) | http://localhost:8200 | `http://vaultwarden:80` |
| **Cal.com** | Scheduling — bookings, calls, demos | http://localhost:3000 | `http://calcom:3000` |
| **Plausible** | Privacy-friendly web analytics | http://localhost:8210 | `http://plausible:8000` |
| **Penpot** | Collaborative design & prototyping | http://localhost:9001 | `http://penpot-frontend:8080` |
| **n8n** | Workflow automation | http://localhost:5678 | `http://n8n:5678` |
| **Open WebUI** | Unified AI chat interface | http://localhost:3001 | `http://open-webui:8080` |
| **yt-dlp** | Media utility (CLI, on demand) | — (`./services/ytdlp/ytdlp.sh`) | — |

Each service has its own detailed guide under [`services/<name>/README.md`](services/).

---

## Quick start

```bash
# 1. Generate the environment file and all secrets
./scripts/generate-secrets.sh          # creates .env from .env.example, fills secrets

# 2. (Optional) review non-secret settings — ports, domains, feature flags
$EDITOR .env

# 3. Start everything (creates the shared network, pulls images, starts services)
./start.sh

# 4. Check health
./scripts/health.sh
```

First boot pulls several GB of images and Cal.com/Plausible run database
migrations, so the first `health.sh` may take a couple of minutes to go green.

Then open the URLs above and create your first account in each service. See each
service README for the first-run steps (most default to open signup for the first
account, which you should lock down afterwards).

**Requirements:** Docker Engine 24+ and Docker Compose v2, ~8 GB RAM and ~30 GB
disk to run the full stack, plus `openssl` and `bash` for the scripts.

---

## Architecture at a glance

- **Modular stacks, one orchestrator.** Every service is a self-contained stack
  under `services/<name>/docker-compose.yml`. The root `docker-compose.yml` pulls
  them together with Compose `include:`, so you can run one service or all of them.
- **Shared network for consumption.** App-facing containers join an external
  bridge network, **`donalabs_edge`**. Other projects attach to this network to
  reach these services by name. Databases stay on private per-service networks and
  never touch the edge.
- **Isolated, version-matched databases.** Cal.com, Plausible, Penpot and n8n each
  get their own database (Postgres / ClickHouse / Valkey) pinned to the version
  the upstream project targets. Vaultwarden and Open WebUI use their built-in
  SQLite (with a documented Postgres upgrade path).
- **Single source of truth.** All configuration lives in the root `.env`
  (documented by `.env.example`). Secrets are generated locally and never committed.
- **Safe defaults.** Published ports bind to `127.0.0.1` only; expose services
  publicly through the optional **Caddy** reverse proxy (automatic HTTPS).

Full rationale and trade-offs: [`docs/architecture.md`](docs/architecture.md).

---

## Repository structure

```
donalabs/
├── services/
│   ├── vaultwarden/      # password/secrets manager
│   ├── calcom/           # scheduling
│   ├── plausible/        # analytics (+ clickhouse/ config overrides)
│   ├── penpot/           # design
│   ├── ytdlp/            # media utility (Dockerfile + safe wrapper)
│   ├── n8n/              # automation
│   └── open-webui/       # AI interface
│   (each has its own docker-compose.yml and README.md)
├── design-system/        # shared UI component library + showcase app
├── proxy/                # optional Caddy reverse proxy (HTTPS)
├── scripts/             # generate-secrets, health, restore, proxy, lib, ...
├── backups/             # timestamped backups (git-ignored)
├── docs/                # architecture, consuming, security
├── .github/workflows/    # CI: design-system.yml, infra.yml
├── .env.example         # the configuration contract
├── docker-compose.yml   # root orchestration (Compose include)
├── start.sh  stop.sh  update.sh  backup.sh
└── README.md
```

---

## Operations

| Task | Command |
|---|---|
| Start all (or a subset) | `./start.sh` · `./start.sh n8n vaultwarden` |
| Stop (keep data) | `./stop.sh` · `./stop.sh --down` (remove containers, keep volumes) |
| Update to pinned tags | `./update.sh` (backs up first, then pulls + recreates) |
| Back up | `./backup.sh` · `./backup.sh --consistent` (brief downtime, crash-consistent) |
| Restore | `./scripts/restore.sh backups/<timestamp>` |
| Health check | `./scripts/health.sh` |
| Reverse proxy (HTTPS) | `./scripts/proxy.sh up` · `down` · `validate` |
| Create shared network | `./scripts/init-network.sh` (also done by `start.sh`) |

To **upgrade** a service, bump its `*_IMAGE_TAG` in `.env`, review the upstream
release notes, then run `./update.sh <service>`.

### Backups

`./backup.sh` writes a timestamped folder under `backups/` containing logical
`pg_dump`s of every Postgres database, `tar.gz` snapshots of each data volume
(Vaultwarden, Open WebUI, n8n, Penpot assets, Plausible app data, ClickHouse
events), and a copy of `.env` (which holds the encryption keys required to read
the restored data — **keep backups private**). Old backups beyond
`BACKUP_RETENTION` (default 7) are pruned. Schedule it with cron:

```bash
0 3 * * *  cd /path/to/donalabs && ./backup.sh >> backups/backup.log 2>&1
```

---

## Continuous Integration (CI)

Two GitHub Actions workflows (in `.github/workflows/`) keep the repository
stable. Both are **validation-only** — they never start a service, pull an
image, or need secrets — so they're fast and safe to run on every change.

| Workflow | File | What it checks | Runs when |
|---|---|---|---|
| **Design System CI** | `design-system.yml` | `pnpm install --frozen-lockfile`, then `pnpm typecheck`, `pnpm lint`, `pnpm build` for the monorepo | changes under `design-system/**` |
| **Infrastructure Validation** | `infra.yml` | `docker compose config` for the root + every service + the proxy; every helper script is executable; ShellCheck on all scripts | changes under `services/**`, `proxy/**`, `scripts/**`, `docker-compose.yml`, `*.sh`, or `.env.example` |

Each workflow only runs when files in its area change (path-filtered), and
superseded runs on the same branch are cancelled automatically.

**How infra validation stays hermetic:** `docker compose config` is a
client-side parse — it validates and interpolates the compose files (including
the root `include:` and the external `donalabs_edge` network) **without a
running Docker daemon and without pulling images**. The job generates a throwaway
`.env` with `./scripts/generate-secrets.sh` purely so interpolation has values.

**Run the same checks locally before pushing:**

```bash
# Design system (from design-system/)
pnpm install --frozen-lockfile && pnpm typecheck && pnpm lint && pnpm build

# Infrastructure (from repo root)
./scripts/generate-secrets.sh                       # create .env for interpolation
docker compose config -q                            # root (include of all services)
for f in services/*/docker-compose.yml; do (cd "$(dirname "$f")" && docker compose --env-file "$OLDPWD/.env" config -q); done
docker compose -f proxy/docker-compose.yml --env-file .env config -q
shellcheck --severity=warning --external-sources start.sh stop.sh update.sh backup.sh scripts/*.sh services/ytdlp/ytdlp.sh
```

ShellCheck gates on **warning** and **error** severity; `info`/`style` notes are
advisory and don't fail CI. Library variables in `scripts/lib.sh` that are only
consumed by scripts which `source` it carry an inline `# shellcheck disable=SC2034`
so the linter can run clean at warning level.

Action versions are pinned to current majors (`actions/checkout@v7`,
`actions/setup-node@v6`, `pnpm/action-setup@v6`) which run on the Node 24 runtime;
pnpm is pinned to `10.33.0` to match the committed lockfile. See
[`design-system/docs/maintenance.md`](design-system/docs/maintenance.md#continuous-integration)
for the design-system CI details and how to bump these.

---

## Consuming these services from other projects

Attach your project's containers to the shared network and reach services by name:

```yaml
# In another project's docker-compose.yml
services:
  my-app:
    # ...
    networks: [donalabs_edge]
networks:
  donalabs_edge:
    external: true
```

Then, for example, `http://vaultwarden:80`, `http://n8n:5678`,
`http://open-webui:8080/api`. Full patterns and examples (APIs, webhooks,
tracking snippets, secrets): [`docs/consuming.md`](docs/consuming.md).

---

## Security

Highlights (full checklist in [`docs/security.md`](docs/security.md)):

- Secrets live only in `.env` (git-ignored, `chmod 600`) and are generated locally.
- Ports bind to `127.0.0.1` by default; public exposure goes through Caddy with TLS.
- Lock down first-run signups after creating your account in each service.
- **Store all the services' admin credentials and API keys in Vaultwarden** — it
  is the central secrets manager for the platform.
- Keep encryption keys (`N8N_ENCRYPTION_KEY`, `CALCOM_ENCRYPTION_KEY`,
  `OPENWEBUI_SECRET_KEY`, Vaultwarden's `/data/rsa_key.pem`) stable and backed up.

---

## Next steps

1. Run `./scripts/generate-secrets.sh` and `./start.sh`.
2. Create your account in each service and lock down signups.
3. Save every service's admin credentials into **Vaultwarden**.
4. Point a model provider at **Open WebUI** (Ollama or an OpenAI-compatible API).
5. For public access, set real domains + `CADDY_ACME_EMAIL` in `.env` and run
   `./scripts/proxy.sh up`.
6. Schedule `./backup.sh` via cron.
