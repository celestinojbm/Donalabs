# Penpot — collaborative design & prototyping platform

## 1. Overview

Penpot is the DonaLabs open-source design tool for building UI mockups, interactive prototypes, and shared design assets in the browser. It is the "design" pillar of the shared stack — a self-hosted, multi-user workspace where teams create and comment on designs without an external SaaS. The stack is six containers (frontend, backend, exporter, MCP, Postgres, Valkey), but only the **frontend** (an nginx web UI + internal reverse proxy) is exposed; everything else stays on a private internal network. It runs on the shared `donalabs_edge` network alongside the other DonaLabs services.

## 2. Image & versions

All four Penpot application images are pinned together via `PENPOT_IMAGE_TAG` (default `2.16.2`). Postgres and Valkey are pinned independently.

| Image | Role | Container name | Port |
|-------|------|----------------|------|
| `penpotapp/frontend:2.16.2` | nginx web UI + reverse proxy (**only exposed service**) | `donalabs-penpot-frontend` | `8080` internal → published on host `9001` |
| `penpotapp/backend:2.16.2` | API / application server | `donalabs-penpot-backend` | `6060` internal only |
| `penpotapp/exporter:2.16.2` | headless PDF/PNG/SVG renderer | `donalabs-penpot-exporter` | internal only |
| `penpotapp/mcp:2.16.2` | MCP server for AI/agent access to designs (`enable-mcp`) | `donalabs-penpot-mcp` | internal only |
| `postgres:15` | primary datastore | `donalabs-penpot-db` | `5432` internal only |
| `valkey/valkey:8.1` | redis-compatible store for realtime/websocket notifications | `donalabs-penpot-valkey` | `6379` internal only |

Named volumes: `donalabs_penpot_postgres_v15` (Postgres data — the `v15` in the name pins the Postgres **major** version; a major upgrade needs a dump/restore, not just an image bump) and `donalabs_penpot_assets` (uploaded design assets, `fs` storage backend at `/opt/data/assets`).

## 3. Quick start

There is no single `penpot` compose service — the stack is six services. Starting `penpot-frontend` transitively brings up its dependencies (backend, exporter, mcp → Postgres, Valkey). Run from the repo root, or use the relative path shown from `services/penpot/`. The shared `donalabs_edge` network is auto-created by `start.sh`.

```bash
# Start the whole Penpot stack (frontend pulls in every dependency)
./start.sh penpot-frontend                 # from repo root
../../start.sh penpot-frontend             # from services/penpot/
docker compose up -d penpot-frontend       # from repo root, raw compose

# Stop (data in named volumes is preserved)
./stop.sh penpot-frontend penpot-backend penpot-exporter penpot-mcp penpot-postgres penpot-valkey

# Update (bump PENPOT_IMAGE_TAG in .env first; backs up automatically, then pulls + recreates)
./update.sh penpot-frontend penpot-backend penpot-exporter penpot-mcp

# Backup (all DBs + data volumes + .env — includes the Penpot pg dump and the assets volume)
./backup.sh
```

## 4. Configuration

Exact variable names from `.env.example` (the `PENPOT_*` block) plus the shared globals that affect this service. Secrets marked `GENERATE` are filled by `./scripts/generate-secrets.sh`.

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `PENPOT_IMAGE_TAG` | Tag for all four `penpotapp/*` images | `2.16.2` |
| `PENPOT_HOST_PORT` | Host port the frontend is published on | `9001` |
| `PENPOT_PUBLIC_URI` | Public base URL baked into links/assets | `http://localhost:9001` |
| `PENPOT_SECRET_KEY` | Master key from which all subsystem keys derive | `GENERATE` → `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` |
| `PENPOT_FLAGS` | Feature flags (see Access & Security) | `enable-registration enable-login-with-password disable-email-verification disable-secure-session-cookies enable-prepl-server enable-mcp` |
| `PENPOT_DB_USER` | Postgres username | `penpot` |
| `PENPOT_DB_PASSWORD` | Postgres password | `GENERATE` → `openssl rand -hex 24` |
| `PENPOT_DB_NAME` | Postgres database name | `penpot` |
| `PENPOT_DISABLE_IPV6_LISTEN` | Disable the frontend's IPv6 nginx listener | `true` (required on Docker bridges without IPv6) |
| `PENPOT_SMTP_HOST` | Optional real SMTP host (invites / resets) | blank = email disabled |
| `PENPOT_SMTP_PORT` | SMTP port | `587` |
| `PENPOT_SMTP_USER` | SMTP username | blank |
| `PENPOT_SMTP_PASSWORD` | SMTP password | blank |
| `PENPOT_SMTP_FROM` | From / reply-to address | `no-reply@example.com` |
| `BIND_ADDR` (global) | Host interface the published port binds to | `127.0.0.1` (host-only; expose via Caddy) |
| `EDGE_NETWORK` (global) | Name of the shared external network | `donalabs_edge` |
| `TZ` (global) | Timezone for the containers | `UTC` |

> Note: SMTP variables only take effect when `enable-smtp` is added to `PENPOT_FLAGS`; without it, mail goes to a console/log backend.

## 5. Access & first-run

- **Local URL (browser):** http://localhost:9001 (host port `PENPOT_HOST_PORT`, bound to `127.0.0.1` by default).

First run:

1. `cp .env.example .env`, run `./scripts/generate-secrets.sh` (fills `PENPOT_SECRET_KEY` and `PENPOT_DB_PASSWORD`), then `./start.sh penpot-frontend`.
2. Open http://localhost:9001 and **register the first account**. Email verification is disabled locally (`disable-email-verification`), so no confirmation email is required.
3. **Lock signups** once your accounts exist: remove `enable-registration` from `PENPOT_FLAGS` in `.env`, then recreate the app containers:
   ```bash
   docker compose up -d penpot-frontend penpot-backend
   ```

## 6. Consume from other projects

Penpot is primarily an **end-user web app** — teammates just open http://localhost:9001 (or the Caddy HTTPS domain) in a browser. For programmatic access from another container:

- **On the `donalabs_edge` network, reach the frontend at `http://penpot-frontend:8080`** — the compose **service name** (`penpot-frontend`) plus its **internal container port `8080`**, not the published host port `9001`. Port `9001` is a host-only binding (`127.0.0.1`) for the local browser and is not how containers reach each other.
- Only `penpot-frontend` is attached to `donalabs_edge`. The backend, exporter, MCP, Postgres, and Valkey live on the private `donalabs_penpot_internal` network and are **not** reachable from other projects; the frontend proxies API traffic to them internally.

Example — from another container on `donalabs_edge`:

```bash
# Readiness / reachability probe (frontend proxies /readyz to the backend)
curl -fsS http://penpot-frontend:8080/readyz         # -> OK

# The app and its REST API are served under the same origin
curl -fsS http://penpot-frontend:8080/api/rpc/command/get-profile
```

- **MCP access:** the `penpot-mcp` service (enabled by the `enable-mcp` flag) lets AI/agents work with designs. It runs on the private internal network only, so it is not directly reachable cross-project without additional wiring.
- **Exports:** PDF/PNG/SVG are produced by the `penpot-exporter` service, driven from within the app UI.

## 7. Usage examples

```bash
# 1. Bring the design workspace up and confirm it is healthy
./start.sh penpot-frontend
curl -fsS http://127.0.0.1:9001/readyz            # -> OK

# 2. Close open registration after onboarding the team
#    edit .env: PENPOT_FLAGS=enable-login-with-password disable-email-verification disable-secure-session-cookies enable-prepl-server enable-mcp
docker compose up -d penpot-frontend penpot-backend

# 3. Another DonaLabs project checks Penpot is up before linking to it
curl -fsS http://penpot-frontend:8080/readyz      # from a container on donalabs_edge
```

## 8. Security considerations

- **Change `PENPOT_SECRET_KEY` from the placeholder.** It is the master key that derives every subsystem/session key; `./scripts/generate-secrets.sh` sets a strong random value. Never leave it blank (the backend depends on it) and avoid rotating it casually — active sessions and derived tokens break.
- **The default `PENPOT_FLAGS` is tuned for local HTTP** and is unsafe on the public internet: it keeps `disable-email-verification` and `disable-secure-session-cookies`. For a public HTTPS deployment, **remove** `disable-email-verification` and `disable-secure-session-cookies`, **add** `enable-secure-session-cookies`, configure real SMTP (`PENPOT_SMTP_*`), and front the frontend with Caddy/HTTPS.
- **`enable-registration` is on by default** — anyone who can reach the URL can self-register. Remove it after onboarding, and rely on `BIND_ADDR=127.0.0.1` (or Caddy auth) to keep the port off the LAN/Internet.
- **Attack surface is minimized:** only `penpot-frontend` is published, and only on `127.0.0.1`. Backend, Postgres, Valkey, exporter, and MCP stay on the private `donalabs_penpot_internal` network.
- **Telemetry is off** (`PENPOT_TELEMETRY_ENABLED=false`) by default.
- **`enable-mcp` exposes an MCP server** with programmatic access to designs — keep it internal-only unless you intentionally wire agents to it.

## 9. Health check

The backend serves `GET /readyz` → `200 OK`, and the frontend nginx proxies it at the same path, so the published port is enough to probe the full request path.

```bash
# DonaLabs helper — probes http://127.0.0.1:9001/readyz and prints container status
./scripts/health.sh

# Raw endpoint (host)
curl -fsS http://127.0.0.1:9001/readyz            # -> OK

# From a container on donalabs_edge
curl -fsS http://penpot-frontend:8080/readyz      # -> OK

# Container-level status (Postgres and Valkey have compose healthchecks)
docker ps --filter name=donalabs-penpot
```

## 10. Troubleshooting

- **`/readyz` returns `000`/502 or the UI is blank right after start:** the backend gates on Postgres and Valkey being healthy — give it a few seconds. Inspect with `docker logs donalabs-penpot-backend` and `docker ps --filter name=donalabs-penpot-db`.
- **Frontend nginx fails to bind / IPv6 errors on a bridge without IPv6:** ensure `PENPOT_DISABLE_IPV6_LISTEN=true` (the default).
- **Another project can't reach Penpot at `localhost:9001`:** that port is host-only. From a container use the internal address `http://penpot-frontend:8080` and make sure the caller is on the `donalabs_edge` network.
- **Login/session breaks after moving to HTTPS (or back to HTTP):** the cookie flag must match the scheme — use `enable-secure-session-cookies` on HTTPS and `disable-secure-session-cookies` on plain HTTP. A mismatch silently drops the session cookie.
- **Backend won't start:** most often `PENPOT_SECRET_KEY` or `PENPOT_DB_PASSWORD` is empty — run `./scripts/generate-secrets.sh`.
- **Exports (PDF/PNG/SVG) fail:** the `penpot-exporter` and `penpot-valkey` containers must be healthy; the exporter renders via `http://penpot-frontend:8080`.
- **Postgres won't come up after bumping its image:** the `donalabs_penpot_postgres_v15` volume is tied to Postgres **15**. A major-version upgrade requires a logical dump/restore (`./backup.sh` → new volume → restore), not just changing the image.
