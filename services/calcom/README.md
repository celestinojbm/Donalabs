# Cal.com — self-hosted scheduling & bookings for DonaLabs

## 1. Overview

Cal.com is the DonaLabs scheduling platform: it powers booking pages, discovery calls, and product demos with availability, event types, calendar sync, and webhooks. It runs as a stateless Next.js app backed by a dedicated PostgreSQL 16 database — all state (users, event types, bookings, encrypted calendar credentials) lives in Postgres, so the app container can be recreated freely. As shared infrastructure it sits on the `donalabs_edge` network, letting other DonaLabs projects (n8n, apps, sites) create bookings and receive booking webhooks internally, without going through the public internet.

## 2. Image & versions

| Component | Image | Role |
|-----------|-------|------|
| App (`calcom`) | `calcom/cal.com:v6.2.0` | Cal.com web app + REST API (Next.js) |
| Database (`calcom_db`) | `postgres:16-alpine` | Dedicated Postgres, DB name `calendso` |

The app tag is pinned via `CALCOM_IMAGE_TAG` (default `v6.2.0`). To upgrade, bump that variable in `.env` and re-run the update flow below — review Cal.com release notes first, since Prisma migrations run automatically on startup.

## 3. Quick start

Run everything from the **repo root**. The shared `donalabs_edge` network is created automatically by `start.sh` (via `ensure_network`) — you don't need to create it by hand.

```bash
# Start Cal.com (+ its Postgres) — pulls dependencies as needed
./start.sh calcom
# or, equivalently:
docker compose up -d calcom
```

```bash
# Stop (containers stopped, data volumes preserved)
./stop.sh calcom
# Stop and remove containers/networks (named volumes kept)
./stop.sh --down calcom
```

```bash
# Update to the tag pinned in .env (takes a safety backup, pulls, recreates)
./update.sh calcom
```

```bash
# Backup — dumps every Postgres DB (incl. calendso) + data volumes + .env
./backup.sh
# Restore a specific snapshot
./scripts/restore.sh backups/<timestamp>
```

> First-time setup: copy `.env.example` to `.env` and fill the `GENERATE` placeholders (see Configuration). `./scripts/generate-secrets.sh` can produce the secret values.

## 4. Configuration

All variables live in the repo-root `.env` (see `.env.example`). Only the variables below are consumed by `services/calcom/docker-compose.yml`.

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `CALCOM_IMAGE_TAG` | App image tag | `v6.2.0` |
| `CALCOM_HOST_PORT` | Published host port for local browser access | `3000` |
| `CALCOM_WEBAPP_URL` | Public URL — sets `NEXT_PUBLIC_WEBAPP_URL` **and** `NEXTAUTH_URL` | `http://localhost:3000` — **keep this unless you rebuild the image** (see §10) |
| `CALCOM_LICENSE_CONSENT` | Accept Cal.com self-hosting license terms | `agree` |
| `CALCOM_DB_NAME` | Postgres database name | `calendso` |
| `CALCOM_DB_USER` | Postgres user | `calcom` |
| `CALCOM_DB_PASSWORD` | Postgres password | `GENERATE` — `openssl rand -hex 24` |
| `CALCOM_NEXTAUTH_SECRET` | NextAuth session/JWT signing secret | `GENERATE` — `openssl rand -base64 32` |
| `CALCOM_ENCRYPTION_KEY` | AES-256 key for stored OAuth/calendar credentials → `CALENDSO_ENCRYPTION_KEY`. **NEVER change after first use** | `GENERATE` — `openssl rand -base64 24` (32-byte key) |
| `CALCOM_EMAIL_FROM` | From address for booking emails (optional) | empty = email disabled |
| `CALCOM_SMTP_HOST` | SMTP server host (optional) | empty |
| `CALCOM_SMTP_PORT` | SMTP server port | `587` |
| `CALCOM_SMTP_USER` | SMTP username (optional) | empty |
| `CALCOM_SMTP_PASSWORD` | SMTP password (optional) | empty |
| `BIND_ADDR` | Host interface the published port binds to | `127.0.0.1` (local only) |
| `TZ` | Container timezone | `UTC` |

The compose file derives `DATABASE_URL` and `DATABASE_DIRECT_URL` from the DB variables above (`postgresql://…@calcom_db:5432/calendso`) — you don't set them directly.

## 5. Access & first-run

- **Local URL:** `http://localhost:3000` (host port `CALCOM_HOST_PORT`, bound to `BIND_ADDR`, default `127.0.0.1`).
- **First run:**
  1. Open `http://localhost:3000`. With no admin yet, Cal.com redirects to `/auth/setup`.
  2. Create the **admin account** (email + password) on the setup screen.
  3. Complete the onboarding wizard (username, timezone, availability, optional calendar connection).
- After creating the admin, treat this as an internal-only instance: signups are open by default on self-hosted Cal.com, so keep the port bound to `127.0.0.1` and front it with Caddy for any external access rather than exposing `3000` directly.

## 6. Consume from other projects (on `donalabs_edge`)

The `calcom` container joins the shared `donalabs_edge` network, so other services on that network reach it at its **internal** address:

- **Internal hostname:port:** `http://calcom:3000` (the container listens on **3000 internally**; the `CALCOM_HOST_PORT` published mapping is only for host-browser access and is irrelevant inside the network).
- **REST API v1:** `http://calcom:3000/api/v1/...`, authenticated with an API key generated in **Cal → Settings → Developer → API keys** (prefix `cal_`), passed as a `?apiKey=` query parameter.
- **Public booking pages:** `<CALCOM_WEBAPP_URL>/<username>/<event-type>`.
- **Embed widget:** load `<CALCOM_WEBAPP_URL>/embed/embed.js` on any page.
- **Webhooks:** configure `BOOKING_CREATED` / `BOOKING_CANCELLED` / `BOOKING_RESCHEDULED` to POST to another internal service, e.g. `http://n8n:5678/webhook/<id>`.

Example — list event types from another container on the network:

```bash
curl "http://calcom:3000/api/v1/event-types?apiKey=cal_xxxxxxxxxxxxxxxx"
```

Example — create a booking:

```bash
curl -X POST "http://calcom:3000/api/v1/bookings?apiKey=cal_xxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "eventTypeId": 1,
    "start": "2026-07-15T14:00:00Z",
    "responses": { "name": "Ada Lovelace", "email": "ada@example.com" },
    "timeZone": "UTC",
    "language": "en"
  }'
```

> Note: because the prebuilt image bakes `NEXT_PUBLIC_WEBAPP_URL` at build time, links and embeds it emits point at `http://localhost:3000` unless you rebuild (see §10). Internal API calls to `http://calcom:3000` work regardless.

## 7. Usage examples

**Fetch available slots for an event type (from n8n / a script on the edge network):**

```bash
curl "http://calcom:3000/api/v1/slots?apiKey=cal_xxx&eventTypeId=1&startTime=2026-07-14T00:00:00Z&endTime=2026-07-21T00:00:00Z&timeZone=UTC"
```

**Wire a booking into automation:** in Cal → Settings → Webhooks, add a webhook for `BOOKING_CREATED` pointing at `http://n8n:5678/webhook/new-booking`. n8n then enriches the lead, notifies Slack, or writes to a CRM — no public endpoint needed.

**Embed a booking page** on a marketing site:

```html
<script src="http://localhost:3000/embed/embed.js"></script>
<!-- swap localhost:3000 for your rebuilt domain in production -->
```

## 8. Security considerations

- **`CALCOM_ENCRYPTION_KEY` is permanent.** It encrypts stored calendar/OAuth credentials (Google/Microsoft). Changing it makes every stored credential undecryptable — rotate only by disconnecting and reconnecting all calendars. Back up `.env` (which `./backup.sh` copies as a sensitive `env.backup`) and keep it private.
- **Do not expose Prisma Studio.** Any DB admin UI must never be published; it grants full read/write to `calendso`.
- **Signups are open by default.** Keep `BIND_ADDR=127.0.0.1` so `3000` is not reachable off-host, and gate external access through Caddy.
- **TLS via Caddy.** Never publish port `3000` to the internet directly. Put Cal.com behind the Caddy reverse proxy for TLS — and remember a custom domain also requires rebuilding the image (§10).
- **Secrets hygiene.** `CALCOM_DB_PASSWORD` and `CALCOM_NEXTAUTH_SECRET` must be strong random values (the `GENERATE` placeholders in `.env.example` are not usable as-is).

## 9. Health check

- **Aggregate probe:** `./scripts/health.sh` — checks all DonaLabs services and prints container status plus endpoint results.
- **Raw endpoint:** Cal.com has **no official `/health` endpoint**; `/auth/login` returns `200` once the app is up. The health script probes:

```bash
curl -fsS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/auth/login
```

- **Container healthcheck:** compose runs a Node HTTP check against `http://localhost:3000/auth/login` (interval 30s, `start_period` 150s — the app takes a while to boot and migrate). Inspect with:

```bash
docker inspect --format '{{.State.Health.Status}}' donalabs-calcom
docker inspect --format '{{.State.Health.Status}}' donalabs-calcom-db
```

## 10. Troubleshooting

- **Custom domain doesn't work / links point at `localhost:3000`.** The prebuilt `calcom/cal.com` image bakes `NEXT_PUBLIC_WEBAPP_URL` at **build time**, so it only works at `http://localhost:3000`. To serve a real domain you must **rebuild the image**:
  ```bash
  git clone https://github.com/calcom/cal.com
  cd cal.com
  docker compose build \
    --build-arg NEXT_PUBLIC_WEBAPP_URL=https://cal.example.com
  ```
  Then point `CALCOM_IMAGE_TAG` at your rebuilt image, set `CALCOM_WEBAPP_URL=https://cal.example.com` (this also sets `NEXTAUTH_URL`), and front it with Caddy for TLS. Setting `CALCOM_WEBAPP_URL` alone, without rebuilding, will break login and embeds.
- **Slow first start / health flapping.** Initial boot runs Prisma migrations and can take a couple of minutes; the container healthcheck allows a 150s `start_period`. Watch progress with `docker compose logs -f calcom`.
- **Login loops / session errors.** `NEXTAUTH_URL` must match the URL you actually browse to and resolve from inside the container. For the default setup, keep `CALCOM_WEBAPP_URL=http://localhost:3000`.
- **Calendar credentials suddenly fail after a change.** `CALCOM_ENCRYPTION_KEY` was altered — restore the original key from your `.env` backup, or reconnect all calendars under the new key.
- **DB connection refused on startup.** `calcom` waits for `calcom_db` to be healthy (`pg_isready`). If it never comes up, check `CALCOM_DB_PASSWORD` is set and inspect `docker compose logs calcom_db`.
- **Port already in use.** Another service is on `3000`; change `CALCOM_HOST_PORT` in `.env` and restart. This only affects host access — internal consumers still use `calcom:3000`.
