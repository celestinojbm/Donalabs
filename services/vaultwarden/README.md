# Vaultwarden — central password & secrets manager for DonaLabs

## 1. Overview

Vaultwarden is a lightweight, Bitwarden-compatible server written in Rust. In DonaLabs it is the **single source of truth for passwords, API keys, and admin credentials** — including the admin tokens and database passwords of the other services in this stack. Any official Bitwarden client (desktop, browser extension, mobile, or the `bw` CLI) can point at it, so it doubles as shared secrets infrastructure that other projects on the `donalabs_edge` network can consume. It runs from a single container with a built-in SQLite database and no external dependencies.

## 2. Image & versions

| Component | Image | Pinned version | Notes |
|-----------|-------|----------------|-------|
| Vaultwarden server | `vaultwarden/server` | `1.36.0-alpine` (`VW_IMAGE_TAG`) | Only container. Bundles the SQLite DB — no separate db/cache image. |

The database is SQLite by default (stored in the data volume). For higher scale you can point Vaultwarden at an external PostgreSQL by setting a `DATABASE_URL` (e.g. `postgresql://user:pass@host/db`); this is **not** wired into the current compose/`.env` and would need to be added.

## 3. Quick start

The shared external network (`donalabs_edge`) is created automatically by `start.sh`, so start via the helper when you can. All commands are run from the repo root.

```bash
# Start (creates donalabs_edge if missing, loads ../../.env)
./start.sh vaultwarden
# or, equivalently:
docker compose -f services/vaultwarden/docker-compose.yml --env-file .env up -d
```

```bash
# Stop
docker compose -f services/vaultwarden/docker-compose.yml down
```

```bash
# Update (pull the pinned tag, then recreate)
docker compose -f services/vaultwarden/docker-compose.yml pull
./start.sh vaultwarden
```

```bash
# Backup the data volume (SQLite DB, JWT keys, attachments, sends, config.json)
docker run --rm \
  -v donalabs_vaultwarden_data:/data:ro \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/vaultwarden-backup-$(date +%F).tar.gz -C /data .
```

## 4. Configuration

All variables live in the repo-root `.env` (copy from `.env.example`, then run `./scripts/generate-secrets.sh`).

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `VW_IMAGE_TAG` | Vaultwarden image tag to run | `1.36.0-alpine` |
| `VW_HOST_PORT` | Host port published for the web vault | `8200` |
| `VW_DOMAIN` | Exact external URL of the vault. Required for attachments, passkeys/WebAuthn, and Sends. Must match how you actually reach it. | `http://localhost:8200` (works locally because `localhost` is a browser secure context; set your HTTPS URL for real deployments) |
| `VW_SIGNUPS_ALLOWED` | Allow self-registration | `true` for first run, then set `false` and restart |
| `VW_ADMIN_TOKEN` | Unlocks the `/admin` panel | `GENERATE` — filled by `./scripts/generate-secrets.sh` (`openssl rand -base64 48`) |

Global variables that also affect this service:

| Variable | Purpose | Default |
|----------|---------|---------|
| `BIND_ADDR` | Host interface the published port binds to | `127.0.0.1` (local/Caddy only) |
| `TZ` | Container timezone | `UTC` |
| `EDGE_NETWORK` | Name of the shared external network | `donalabs_edge` |

Two settings are hard-coded in the compose file (not env-driven): `ENABLE_WEBSOCKET=true` (live sync over the main HTTP port; the old port 3012 was removed in v1.31) and `ROCKET_PORT=80` (the internal listen port).

## 5. Access & first-run

- **Local URL:** `http://localhost:8200` (published host port `VW_HOST_PORT`, bound to `127.0.0.1`).
- **Admin panel:** `http://localhost:8200/admin` (unlocked with `VW_ADMIN_TOKEN`).

First-run steps:

1. Ensure `VW_SIGNUPS_ALLOWED=true` in `.env`, then start: `./start.sh vaultwarden`.
2. Open `http://localhost:8200` and **Create account** (this is your personal vault owner).
3. Lock registration back down: set `VW_SIGNUPS_ALLOWED=false` in `.env`.
4. Apply it: `./start.sh vaultwarden` (recreates the container with the new value).

## 6. Consume from other projects

Other containers on the `donalabs_edge` network reach Vaultwarden by its **service name and internal port**:

```
http://vaultwarden:80
```

- **Internal (container-to-container):** `vaultwarden:80` — this is the `ROCKET_PORT`, not the published port.
- **Published (host browser):** `127.0.0.1:8200` — for the web UI and any client running on the host.

**API surface:** Vaultwarden implements the Bitwarden API, so point official Bitwarden clients or the `bw` CLI at `VW_DOMAIN`. Health/monitoring probes should hit `/alive`.

Attach another project's container to the shared network and reach the vault internally:

```yaml
# in the other project's docker-compose.yml
services:
  my-app:
    networks: [edge]
networks:
  edge:
    external: true
    name: donalabs_edge
```

```bash
# from inside a container on donalabs_edge
curl -fsS http://vaultwarden:80/alive        # -> 200

# Bitwarden CLI, pointed at the vault's external URL
bw config server http://localhost:8200       # or your VW_DOMAIN
bw login
bw get password "n8n admin"
```

Vaultwarden is the **recommended place to store the other DonaLabs services' admin credentials and API keys** (e.g. n8n's admin login, Plausible/Penpot DB passwords), rather than leaving them only in `.env`.

## 7. Usage examples

**Retrieve a secret programmatically with the `bw` CLI:**

```bash
export BW_SESSION="$(bw unlock --raw)"
bw get item "Calcom encryption key" | jq -r '.notes'
```

**Health probe from another service (e.g. an n8n HTTP node or a monitoring job):**

```bash
curl -fsS http://vaultwarden:80/alive && echo "vault up"
```

**Rotate the admin token to a hashed value** (see Security below), then reopen `/admin` with the plaintext you hashed.

## 8. Security considerations

- **HTTPS for anything real.** The web-crypto vault only works over a secure context. `http://localhost:8200` is fine locally because `localhost` is treated as secure, but any non-localhost deployment must be served over HTTPS — put it behind the Caddy reverse proxy (`./start.sh proxy`, `CADDY_VAULTWARDEN_DOMAIN`).
- **Close signups after setup.** Set `VW_SIGNUPS_ALLOWED=false` once your account exists, or anyone reaching the URL can register.
- **Persist `/data/rsa_key.pem`.** These are the JWT signing keys. If the volume is lost or the key regenerates, **every session/token is invalidated** and all clients must log in again. Keep the `donalabs_vaultwarden_data` volume backed up.
- **Protect and harden `VW_ADMIN_TOKEN`.** It unlocks the full `/admin` panel. Prefer an Argon2 hash over a plaintext token — generate one with:
  ```bash
  docker run --rm -it vaultwarden/server /vaultwarden hash
  ```
  Paste the resulting `$argon2...` string as `VW_ADMIN_TOKEN` (keep it single-quoted in `.env` so the `$` is safe).
- **Keep the port on `127.0.0.1`.** `BIND_ADDR=127.0.0.1` keeps the published port off the LAN; only expose it through Caddy.

## 9. Health check

The container has a built-in healthcheck that curls the `/alive` endpoint every 30s:

```
GET /alive  ->  200
```

Check it via the stack's helper or directly:

```bash
# Stack health helper
./scripts/health.sh

# Raw endpoint (host)
curl -fsS http://localhost:8200/alive

# Raw endpoint (from a container on donalabs_edge)
curl -fsS http://vaultwarden:80/alive

# Docker's own view of the healthcheck
docker inspect --format '{{.State.Health.Status}}' donalabs-vaultwarden
```

## 10. Troubleshooting

- **Vault UI errors about crypto / "insecure context":** you opened it on a non-`localhost` host over plain HTTP. Use `http://localhost:8200` or serve it over HTTPS via Caddy, and make sure `VW_DOMAIN` matches the URL in your address bar.
- **Everyone got logged out after a restart:** the `donalabs_vaultwarden_data` volume (and `rsa_key.pem`) was recreated or lost. Restore from backup; never delete the volume casually.
- **`/admin` returns "unauthorized" or won't load:** `VW_ADMIN_TOKEN` is unset/mismatched. Set it in `.env` and recreate with `./start.sh vaultwarden`. If you hashed it, enter the original plaintext at the prompt.
- **Can't self-register:** `VW_SIGNUPS_ALLOWED=false`. Set it to `true`, recreate, create the account, then set it back to `false`.
- **Another container can't reach it:** confirm it's attached to `donalabs_edge` and that it uses the **internal** address `http://vaultwarden:80` — not `localhost:8200` (which only exists on the host).
- **Attachments / passkeys / Sends fail:** `VW_DOMAIN` doesn't exactly match the external URL. Fix it and recreate the container.
