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
├── proxy/                # optional Caddy reverse proxy (HTTPS)
├── scripts/             # generate-secrets, health, restore, proxy, lib, ...
├── backups/             # timestamped backups (git-ignored)
├── docs/                # architecture, consuming, security
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
