# DonaLabs — Caddy reverse proxy (optional)

A single HTTPS entrypoint for all DonaLabs services, with **automatic TLS**
(Let's Encrypt for real domains, an internal CA for `*.localhost`) and
transparent WebSocket support. It is opt-in: the core services run fine over
`http://localhost` without it.

## What it does

Caddy runs on the shared `donalabs_edge` network and routes each hostname to the
right service's **internal** port:

| Hostname (`.env`) | → | Service |
|---|---|---|
| `CADDY_VAULTWARDEN_DOMAIN` | → | `vaultwarden:80` |
| `CADDY_CALCOM_DOMAIN` | → | `calcom:3000` |
| `CADDY_PLAUSIBLE_DOMAIN` | → | `plausible:8000` |
| `CADDY_PENPOT_DOMAIN` | → | `penpot-frontend:8080` |
| `CADDY_N8N_DOMAIN` | → | `n8n:5678` |
| `CADDY_OPENWEBUI_DOMAIN` | → | `open-webui:8080` |

## Usage

```bash
./scripts/proxy.sh up         # start Caddy (ports 80/443)
./scripts/proxy.sh down       # stop and remove Caddy
./scripts/proxy.sh validate   # check the Caddyfile
./scripts/proxy.sh logs       # follow logs
```

Prerequisites: the core services are running (`./start.sh`) and the
`donalabs_edge` network exists (created automatically).

## Local testing

The defaults use `*.localhost` hostnames. Caddy issues certificates from its own
internal CA, so you'll get a browser trust warning unless you install Caddy's root
(`docker exec donalabs-caddy cat /data/caddy/pki/authorities/local/root.crt`).
`http://localhost:<port>` direct access remains available regardless.

## Production

1. Point DNS `A`/`AAAA` records for each hostname at this host.
2. In `.env`, set the `CADDY_*_DOMAIN` values to your real domains and set
   `CADDY_ACME_EMAIL` (then uncomment the global `email` block in
   `caddy/Caddyfile` for expiry notifications).
3. Open ports **80** and **443** on the host/firewall.
4. `./scripts/proxy.sh up` — Caddy obtains and renews Let's Encrypt certificates
   automatically.

### Cal.com note

Cal.com bakes its public URL into the image at build time. To serve it on a real
domain you must **rebuild** the Cal.com image with
`NEXT_PUBLIC_WEBAPP_URL=https://<your cal domain>` and set `CALCOM_WEBAPP_URL`
accordingly — see [`../services/calcom/README.md`](../services/calcom/README.md).
Routing alone is not enough for Cal.com.

## Data

Certificates and Caddy state persist in the `donalabs_caddy_data` and
`donalabs_caddy_config` volumes, so restarts don't re-issue certificates.
