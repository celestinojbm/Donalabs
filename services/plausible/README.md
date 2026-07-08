# Plausible Analytics — privacy-friendly web analytics for DonaLabs

## 1. Overview

Plausible (Community Edition) is DonaLabs' self-hosted, privacy-friendly web analytics platform — a lightweight, cookie-free alternative to Google Analytics. It runs as shared infrastructure on the `donalabs_edge` network so any project in the lab can ship a single `<script>` tag to a website and see traffic, referrers, and events in one dashboard, without third-party trackers or GDPR cookie banners. The stack is fully self-contained: the Plausible app plus its own dedicated Postgres (metadata) and ClickHouse (the analytics event store).

## 2. Image & versions

| Component | Image | Role |
|---|---|---|
| App | `ghcr.io/plausible/community-edition:v3.2.1` | Plausible dashboard + ingestion API (pinned via `PLAUSIBLE_IMAGE_TAG`) |
| Metadata DB | `postgres:16-alpine` | Users, sites, API keys, settings |
| Event store | `clickhouse/clickhouse-server:24.12-alpine` | Columnar analytics dataset (pageviews/events) |

> The three ClickHouse config overrides bind-mounted from `services/plausible/clickhouse/` (`logs.xml`, `ipv4-only.xml`, `low-resources.xml`, `default-profile-low-resources-overrides.xml`) are **required** — they tame ClickHouse's logging/memory footprint and force IPv4-only listening. Do not remove them.

## 3. Quick start

All commands run from the **repo root**. The shared `donalabs_edge` network is created automatically by `start.sh`; if you use raw `docker compose` you must create it yourself first.

```bash
# Start (preferred — also creates the shared network + checks .env)
./start.sh plausible

# Start (raw compose — network must already exist)
docker network create donalabs_edge   # one-time, only if not using start.sh
docker compose up -d plausible

# Stop (app + its dedicated DB/ClickHouse)
docker compose stop plausible plausible_db plausible_events_db

# Update (bump PLAUSIBLE_IMAGE_TAG in .env first, then)
docker compose pull plausible plausible_db plausible_events_db
docker compose up -d plausible

# Backup (logical Postgres dump + volume tarballs for the whole lab)
./backup.sh                 # or ./backup.sh --consistent for crash-consistent volume copies
# Restore a specific snapshot:
./scripts/restore.sh backups/<timestamp>
```

## 4. Configuration

Set in the root `.env` (copy `.env.example` → `.env`, then run `./scripts/generate-secrets.sh` to fill every `GENERATE`). Plausible-specific variables:

| Variable | Purpose | Default / How-to |
|---|---|---|
| `PLAUSIBLE_IMAGE_TAG` | App image tag to run | `v3.2.1` |
| `PLAUSIBLE_HOST_PORT` | Host port the dashboard is published on | `8210` |
| `PLAUSIBLE_BASE_URL` | Public URL of the dashboard; also baked into the tracking snippet | `http://localhost:8210` |
| `PLAUSIBLE_DISABLE_REGISTRATION` | Blocks open sign-ups | `false` for first run (to create the owner), then set `true` and restart |
| `PLAUSIBLE_SECRET_KEY_BASE` | App session/signing secret | `GENERATE` — `openssl rand -base64 48` |
| `PLAUSIBLE_TOTP_VAULT_KEY` | Encrypts stored 2FA/TOTP secrets | `GENERATE` — `openssl rand -base64 32` |
| `PLAUSIBLE_DB_USER` | Postgres username | `plausible` |
| `PLAUSIBLE_DB_PASSWORD` | Postgres password | `GENERATE` — `openssl rand -hex 24` |
| `PLAUSIBLE_DB_NAME` | Postgres database name | `plausible` |
| `PLAUSIBLE_CH_NOFILE` | ClickHouse file-descriptor (nofile) limit | `262144` — lower only on constrained hosts where `ulimit -Hn` is below this |
| `PLAUSIBLE_APP_NOFILE` | App container file-descriptor limit | `65535` — lower only if the host hard limit is below this |

Shared globals that also apply: `TZ` (timezone), `BIND_ADDR` (host interface published ports bind to, default `127.0.0.1`), `EDGE_NETWORK` (shared network name, `donalabs_edge`).

## 5. Access & first-run

- **Local dashboard:** `http://localhost:8210` (published on `PLAUSIBLE_HOST_PORT`, bound to `127.0.0.1` by default).

First-run steps:

1. Ensure `PLAUSIBLE_DISABLE_REGISTRATION=false` in `.env`, then `./start.sh plausible`.
2. Open the dashboard and **register the owner account** (the first account created becomes the admin).
3. Add your first site (enter its domain, e.g. `example.com`) and copy the tracking snippet it shows.
4. Lock it down: set `PLAUSIBLE_DISABLE_REGISTRATION=true` in `.env` and restart:
   ```bash
   docker compose up -d plausible
   ```

## 6. Consume from other projects

Only the **app** container joins `donalabs_edge`; the Postgres and ClickHouse containers stay on the private `donalabs_plausible_internal` network and are **not** reachable from other projects. Another container on `donalabs_edge` reaches Plausible at its **internal** address:

```
http://plausible:8000
```

- **`plausible`** = the compose service name (its network alias).
- **`8000`** = the app's INTERNAL container port (`HTTP_PORT`). This is **not** the published `8210` — that host port is for the browser on your machine, not for container-to-container calls.

Ways to consume it:

- **Tracking snippet** (add to any website's `<head>`; `src` uses `PLAUSIBLE_BASE_URL`, the browser-reachable URL):
  ```html
  <script defer data-domain="yourdomain.com" src="http://localhost:8210/js/script.js"></script>
  ```
- **Stats API** — read your analytics with a Bearer API key created under the site's settings in the dashboard:
  ```bash
  # from another container on donalabs_edge (internal port 8000)
  curl -H "Authorization: Bearer $PLAUSIBLE_API_KEY" \
    "http://plausible:8000/api/v1/stats/aggregate?site_id=yourdomain.com&metrics=visitors,pageviews"
  ```
- **Events API** — send custom/pageview events server-side to `POST /api/event`:
  ```bash
  curl -X POST http://plausible:8000/api/event \
    -H "Content-Type: application/json" \
    -H "User-Agent: MyServer/1.0" \
    -d '{"name":"pageview","url":"https://yourdomain.com/pricing","domain":"yourdomain.com"}'
  ```

## 7. Usage examples

**Track a static site / SPA** — drop the snippet in your HTML `<head>`, using the domain exactly as registered in Plausible:

```html
<script defer data-domain="donalabs.example" src="http://localhost:8210/js/script.js"></script>
```

**Pull yesterday's visitor count from a script/CI runner on the network:**

```bash
curl -s -H "Authorization: Bearer $PLAUSIBLE_API_KEY" \
  "http://plausible:8000/api/v1/stats/aggregate?site_id=donalabs.example&period=day&date=2026-07-07&metrics=visitors" | jq
```

**Record a custom conversion event server-side** (e.g. a signup), from a backend on `donalabs_edge`:

```bash
curl -X POST http://plausible:8000/api/event \
  -H "Content-Type: application/json" \
  -H "User-Agent: signup-service/1.0" \
  -d '{"name":"Signup","url":"https://donalabs.example/welcome","domain":"donalabs.example"}'
```

## 8. Security considerations

- **Lock registration after setup.** The first account is the admin; leaving `PLAUSIBLE_DISABLE_REGISTRATION=false` lets anyone who reaches the dashboard create an account. Set it to `true` and restart once the owner exists.
- **Keep it behind HTTPS for real use.** Ports bind to `127.0.0.1` by default; expose Plausible publicly only through the Caddy reverse proxy (`./start.sh proxy`) so traffic and the ingestion endpoint are served over TLS.
- **The ClickHouse `ipv4-only.xml` override is load-bearing** on Docker bridges without IPv6 — without it ClickHouse tries to bind an IPv6 address and fails to start. Keep all four `clickhouse/*.xml` mounts in place.
- **Protect the secrets.** `PLAUSIBLE_SECRET_KEY_BASE` and `PLAUSIBLE_TOTP_VAULT_KEY` sign sessions and encrypt 2FA secrets; rotating them invalidates sessions and stored TOTP. API keys are Bearer tokens — treat them like passwords and scope them per site.
- **The event store is private.** Postgres and ClickHouse are only on `donalabs_plausible_internal`, never on `donalabs_edge` — don't move them onto the shared network.

## 9. Health check

The app exposes `GET /api/health`, which returns JSON reporting each dependency, e.g.:

```json
{"clickhouse":"ok","postgres":"ok","sessions":"ok","sites_cache":"ok"}
```

Check it via the lab-wide probe (queries `http://127.0.0.1:${PLAUSIBLE_HOST_PORT}/api/health` and prints a table plus container health):

```bash
./scripts/health.sh
```

Or hit the endpoint directly:

```bash
curl -fsS http://localhost:8210/api/health
```

## 10. Troubleshooting

- **Dashboard won't come up / restart loops:** the app waits for both databases to report healthy (`depends_on: service_healthy`). Check `docker compose logs plausible_db plausible_events_db` first.
- **ClickHouse fails to start (IPv6 / bind errors):** confirm the four `services/plausible/clickhouse/*.xml` files exist and are mounted read-only; `ipv4-only.xml` is required on IPv6-less bridges.
- **ClickHouse exits on file-descriptor / ulimit errors:** the host's hard limit is below the default `262144`. Lower `PLAUSIBLE_CH_NOFILE` (and `PLAUSIBLE_APP_NOFILE`) in `.env` to at or under `ulimit -Hn`, then restart.
- **Another container can't reach it:** use `http://plausible:8000` (internal service name + port 8000), **not** `localhost:8210`. Confirm the calling container is attached to `donalabs_edge`.
- **No data appears for a site:** the `data-domain` in the snippet must match the site's domain in Plausible exactly, and ad blockers may block `/js/script.js` — verify with a server-side `/api/event` call.
- **Can't create an account:** registration is disabled (`PLAUSIBLE_DISABLE_REGISTRATION=true`). Set it to `false`, restart, create the owner, then re-lock it.
- **`start.sh` errors about a missing network:** it normally auto-creates `donalabs_edge`; with raw `docker compose` run `docker network create donalabs_edge` first.
