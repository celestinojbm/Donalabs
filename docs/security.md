# DonaLabs — Security considerations

A practical checklist for running DonaLabs safely. None of this is exotic — it is
the set of defaults and habits that keep a self-hosted platform out of trouble.

## Secrets

- **Generated locally, never committed.** `scripts/generate-secrets.sh` creates
  `.env` with strong random secrets and `chmod 600`s it. `.env`, `backups/`, and
  runtime data are git-ignored — only `.env.example` (placeholders) is tracked.
- **Vaultwarden is the source of truth for credentials.** After first-run, store
  every service's admin login and API keys in Vaultwarden. Don't scatter secrets
  across notes and shell history.
- **Encryption keys are irreplaceable — back them up.** If these are lost, the
  corresponding data becomes unreadable:
  - `N8N_ENCRYPTION_KEY` — decrypts stored n8n credentials.
  - `CALCOM_ENCRYPTION_KEY` — decrypts stored calendar/OAuth tokens (never change
    it after first use).
  - `OPENWEBUI_SECRET_KEY` — sessions and encrypted data (if it changes, everyone
    is logged out).
  - Vaultwarden's `/data/rsa_key.pem` — JWT signing keys; losing it logs out all
    clients. It lives in the `donalabs_vaultwarden_data` volume and is captured by
    `./backup.sh`.

## Network exposure

- **Default is local-only.** Published ports bind to `127.0.0.1` (`BIND_ADDR`).
  Nothing is reachable from the LAN/Internet until you change that or add a proxy.
- **Databases are private.** They sit on per-service internal networks and never
  join `donalabs_edge`, so no other project (or attacker on the edge) can reach
  them directly.
- **Expose through Caddy, not by widening binds.** For public access, set real
  domains and `CADDY_ACME_EMAIL`, run `./scripts/proxy.sh up`, and open only
  80/443 on the host. Caddy terminates TLS and forwards to the internal ports.
- **HTTPS is required for real Vaultwarden use** (its web vault needs a secure
  context). `http://localhost` counts as secure for local use; a public plain-HTTP
  deployment will not work — always front it with Caddy.

## Accounts & access

- **Lock down signups after first-run.** Each service defaults to allowing the
  first account so you can bootstrap. Then set and re-apply:
  - `VW_SIGNUPS_ALLOWED=false` (Vaultwarden)
  - `PLAUSIBLE_DISABLE_REGISTRATION=true` (Plausible)
  - `OPENWEBUI_ENABLE_SIGNUP=false` (Open WebUI)
  - Penpot: for public use, remove `disable-email-verification` from `PENPOT_FLAGS`.
- **Protect admin surfaces.** Vaultwarden's `/admin` is gated by `VW_ADMIN_TOKEN`
  (upgradable to an Argon2 hash). Don't expose Cal.com's Prisma Studio publicly.
- **Restrict CORS** for public deployments (e.g. Open WebUI's `CORS_ALLOW_ORIGIN`).

## The yt-dlp wrapper

- **No unsafe execution.** `services/ytdlp/ytdlp.sh` never forwards arbitrary
  flags (which could enable yt-dlp `--exec`, i.e. command execution), runs with
  `--ignore-config` (so a planted config can't inject flags), only accepts
  `http(s)` URLs (rejecting `file://` and option-injection like `--exec=...`),
  passes URLs as `argv` after `--`, and runs as a non-root user in a throwaway
  container. Bump `YTDLP_VERSION` regularly — extractors and security fixes ship
  fast (use ≥ `2026.07.04`, which fixes CVE-2026-55404).

## Updates & backups

- **Pin versions; update deliberately.** Images are pinned in `.env`. Review
  upstream release notes before a major bump, then `./update.sh <service>` (it
  takes a safety backup first).
- **Back up regularly and keep backups private.** `./backup.sh` includes a copy of
  `.env` (with all keys). Store backups somewhere encrypted/off-host; a backup is
  as sensitive as the live platform.

## Host hygiene

- Keep Docker Engine and the host patched.
- Run the platform as an unprivileged operator where possible; the containers
  themselves drop to non-root users where the images support it.
- Monitor with `./scripts/health.sh` (or wire the endpoints into your uptime tool).
