# n8n — workflow automation & orchestration for DonaLabs

## 1. Overview

n8n is DonaLabs' workflow automation platform — the layer that wires the other services together and connects them to external APIs, apps, webhooks, and AI tools. It runs as shared infrastructure on the `donalabs_edge` network, so it is both reachable by other projects (via its REST API and webhooks) and able to reach every other DonaLabs service by name. In practice n8n is the **orchestrator**: it consumes Vaultwarden, Cal.com, Plausible, Penpot, and Open WebUI rather than the other way around. State (workflows, credentials, executions) lives in a dedicated Postgres 16 database.

## 2. Image & versions

| Component | Image | Role |
|-----------|-------|------|
| n8n (app) | `n8nio/n8n:2.29.8` | Workflow engine + editor UI + REST API (pinned via `N8N_IMAGE_TAG`) |
| Database  | `postgres:16-alpine` | Dedicated Postgres for workflows, credentials, executions (service `n8n_db`) |

## 3. Quick start

All commands are run from the repository root. The shared `donalabs_edge` network is **auto-created by `start.sh`**; if you use raw `docker compose`, create it first with `docker network create donalabs_edge`.

```bash
# Start (creates the shared network, then brings up n8n + its Postgres)
./start.sh n8n
# or, from the repo root, with the network already created:
docker compose up -d n8n

# Stop
docker compose stop n8n n8n_db

# Update (bump N8N_IMAGE_TAG in .env if changing versions, then re-pull + recreate)
docker compose pull n8n && docker compose up -d n8n

# Backup (logical pg_dump of the n8n DB + tarball of donalabs_n8n_data + .env)
./backup.sh
# restore later with: ./scripts/restore.sh backups/<timestamp>
```

## 4. Configuration

Variables live in the root `.env` (copied from `.env.example`). Only the values below are consumed by this service's compose file.

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `N8N_IMAGE_TAG` | n8n app image tag to run | `2.29.8` |
| `N8N_HOST_PORT` | Published host port for the editor UI/API | `5678` |
| `N8N_HOSTNAME` | Host used to build webhook/callback URLs (`N8N_HOST`) | `localhost` |
| `N8N_PROTOCOL` | Protocol for generated URLs (`http`/`https`) | `http` |
| `N8N_WEBHOOK_URL` | Public webhook base URL — **must end with a trailing `/`** | `http://localhost:5678/` |
| `N8N_SECURE_COOKIE` | Require HTTPS for the auth cookie | `false` for local http; set `true` behind Caddy |
| `N8N_ENCRYPTION_KEY` | **Master key for stored credentials** — if lost, all saved credentials become unreadable | `GENERATE` → `openssl rand -hex 32`; back it up |
| `N8N_DB_USER` | Postgres user | `n8n` |
| `N8N_DB_PASSWORD` | Postgres password | `GENERATE` → `openssl rand -hex 24` |
| `N8N_DB_NAME` | Postgres database name | `n8n` |

Shared variables that also apply: `BIND_ADDR` (host interface the port binds to, default `127.0.0.1`), `EDGE_NETWORK` (default `donalabs_edge`), and `TZ`.

The compose file also sets two values as **fixed literals** (not env-configurable):

- `N8N_LISTEN_ADDRESS=0.0.0.0` — binds IPv4 explicitly; n8n's default `::` fails on Docker bridges without IPv6.
- `N8N_RUNNERS_ENABLED=true` — enables v2 task runners, which execute Code nodes in an isolated runner process.

## 5. Access & first-run

- **Local URL:** http://localhost:5678 (published as `127.0.0.1:${N8N_HOST_PORT:-5678}:5678`, i.e. bound to localhost only by default via `BIND_ADDR`).
- **First run:**
  1. Open http://localhost:5678.
  2. Create the **owner account** (email + password) — the first account becomes the instance owner/admin.
  3. Restrict who can register: n8n has no open self-signup, but for anything public-facing keep the instance behind Caddy and only invite the users you trust. Generate a **REST API key** later under **Settings → n8n API** for programmatic access.

## 6. Consume from other projects

Any container on the `donalabs_edge` network reaches n8n at its **service name + internal container port**: `n8n:5678` (the internal port is `5678`, the same number the app listens on). Do **not** rely on the published host port `5678` from other containers — it is bound to `127.0.0.1` on the host, not the shared network.

**n8n → other services (n8n as orchestrator).** Inside your n8n workflows, address the other DonaLabs services by their internal hostname:port on `donalabs_edge`:

| Service | Internal URL |
|---------|--------------|
| Vaultwarden | `http://vaultwarden:80` |
| Cal.com | `http://calcom:3000` |
| Plausible | `http://plausible:8000` |
| Penpot | `http://penpot-frontend:8080` |
| Open WebUI | `http://open-webui:8080` |

**Other apps → n8n.** Two surfaces:

- **REST API:** `http://n8n:5678/api/v1` — authenticate with an API key from **Settings → n8n API** (header `X-N8N-API-KEY`).
- **Webhooks:** trigger workflows at `http://n8n:5678/webhook/<path>` (or `/webhook-test/<path>` while editing).

```bash
# From another donalabs_edge container: list workflows via the REST API
curl -H "X-N8N-API-KEY: <your-api-key>" http://n8n:5678/api/v1/workflows

# Trigger a workflow's webhook
curl -X POST http://n8n:5678/webhook/my-hook \
  -H "Content-Type: application/json" \
  -d '{"hello":"world"}'
```

## 7. Usage examples

**a. Webhook-triggered workflow.** Add a **Webhook** node with path `my-hook`; other services POST to `http://n8n:5678/webhook/my-hook` (internal) or `http://localhost:5678/webhook/my-hook` (local). Because `N8N_WEBHOOK_URL` must end in `/`, the production webhook URL n8n advertises is `http://localhost:5678/webhook/my-hook`.

**b. Call Open WebUI's OpenAI-compatible API.** From an HTTP Request node, POST to `http://open-webui:8080/api/chat/completions` with a Bearer token, to run chat completions against your local models as a workflow step.

**c. Create a Cal.com booking.** From an HTTP Request node, call the Cal.com API at `http://calcom:3000/...` to create or look up bookings as part of an automation (e.g. after a form submission).

## 8. Security considerations

- **Guard `N8N_ENCRYPTION_KEY` above all.** It encrypts every stored credential. Keep it **stable** and **backed up** — if it changes or is lost, all saved credentials become permanently unreadable. A mirror of it is persisted in the `donalabs_n8n_data` volume (`/home/node/.n8n`), so back up the key value itself separately from the volume.
- **Public exposure needs HTTPS.** Set `N8N_SECURE_COOKIE=true` and front n8n with the Caddy reverse proxy (`CADDY_N8N_DOMAIN`) before exposing it; over plain `http://localhost` keep it `false` so you can still log in.
- **Lock down registration.** The first account is the owner; do not hand out access broadly. Treat REST API keys like passwords.
- **Code node isolation.** `N8N_RUNNERS_ENABLED=true` runs Code node logic in an isolated task runner rather than the main process — keep it enabled.
- **Localhost binding.** The UI/API port is bound to `127.0.0.1` by default (`BIND_ADDR`); reach it from other containers over the `donalabs_edge` network, not the host port.

## 9. Health check

The container healthcheck probes `GET http://127.0.0.1:5678/healthz` (liveness → `200`). For DB-ready checks use `GET /healthz/readiness`.

```bash
# Repo-wide health probe (checks n8n's /healthz on N8N_HOST_PORT)
./scripts/health.sh

# Raw endpoints
curl -i http://localhost:5678/healthz            # liveness -> 200
curl -i http://localhost:5678/healthz/readiness  # DB-ready
```

## 10. Troubleshooting

- **Can't log in / redirected back to login:** over plain HTTP this is almost always `N8N_SECURE_COOKIE`. Keep it `false` for `http://localhost`; only set `true` when serving over HTTPS via Caddy.
- **Webhook URLs look wrong:** ensure `N8N_WEBHOOK_URL` ends with a trailing `/`, and that `N8N_HOSTNAME`/`N8N_PROTOCOL` match how the instance is actually reached.
- **Container won't bind / listen errors on startup:** n8n's default listen address `::` fails on Docker bridges without IPv6 — this compose already forces `N8N_LISTEN_ADDRESS=0.0.0.0`; don't override it back to `::`.
- **"Credentials could not be decrypted":** `N8N_ENCRYPTION_KEY` changed or was regenerated. Restore the original key value.
- **n8n stuck starting / DB errors:** it waits for `n8n_db` to be healthy (`depends_on: service_healthy`). Check `docker logs donalabs-n8n-db` and confirm `N8N_DB_PASSWORD` is set.
- **Other containers can't reach n8n on `localhost:5678`:** that port is host-bound to `127.0.0.1`. From the `donalabs_edge` network use `http://n8n:5678` instead.
