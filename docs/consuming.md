# Consuming DonaLabs services from other projects

DonaLabs is a shared platform: other projects reach its services over the shared
Docker network **`donalabs_edge`**, or over the host/reverse-proxy for external
clients. This guide shows the integration surface for each service.

## Join the shared network

Add the external network to your project's compose file and attach the containers
that need to reach DonaLabs services:

```yaml
services:
  my-app:
    image: my-app:latest
    networks: [default, donalabs_edge]   # keep your own network too

networks:
  donalabs_edge:
    external: true
```

Now your container resolves each service by name. Use the **internal** container
port (not the host-published port):

| Service | Internal address | Primary integration surface |
|---|---|---|
| Vaultwarden | `http://vaultwarden:80` | Bitwarden-compatible API; `/alive` health |
| Cal.com | `http://calcom:3000` | REST API v1 `/api/v1/*` (API key), booking pages, webhooks |
| Plausible | `http://plausible:8000` | Tracking snippet, Stats API `/api/v1/stats`, events `/api/event` |
| Penpot | `http://penpot-frontend:8080` | Web app + MCP server; exporter for PDF/PNG/SVG |
| n8n | `http://n8n:5678` | REST API `/api/v1`, webhooks `/webhook/<path>` |
| Open WebUI | `http://open-webui:8080` | OpenAI-compatible API `/api` (Bearer key) |

> An external client (browser, mobile app, another host) reaches services through
> the published host port or, preferably, the Caddy reverse proxy over HTTPS.

---

## Vaultwarden — central secrets

Vaultwarden is the platform's secrets manager. Store every other service's admin
credentials and API keys here. Programmatic access uses the Bitwarden CLI/SDK
pointed at the vault URL:

```bash
export BW_SERVER=http://vaultwarden:80        # inside the network, or your public URL
bw config server "$BW_SERVER"
bw login && bw sync
bw get password "n8n admin"
```

Health/monitoring: `GET http://vaultwarden:80/alive` → `200`.

---

## Cal.com — scheduling

Create an API key in Cal.com settings (prefix `cal_`), then call the REST API:

```bash
curl "http://calcom:3000/api/v1/bookings?apiKey=cal_xxx"
```

Event-driven integration (recommended): configure a webhook in Cal.com to POST
`BOOKING_CREATED` / `BOOKING_CANCELLED` / `BOOKING_RESCHEDULED` to another service,
e.g. an n8n webhook `http://n8n:5678/webhook/cal-booking`. Public booking pages
live at `<CALCOM_WEBAPP_URL>/<username>/<event>`; embed with `<url>/embed/embed.js`.

---

## Plausible — analytics

Add the tracking snippet to any website or landing page:

```html
<script defer data-domain="yourdomain.com"
        src="http://localhost:8210/js/script.js"></script>
```

(Use your public `PLAUSIBLE_BASE_URL` in production.) Query stats from another
service with a Stats-API key:

```bash
curl -H "Authorization: Bearer plausible_key" \
  "http://plausible:8000/api/v1/stats/aggregate?site_id=yourdomain.com&metrics=visitors,pageviews"
```

Send custom events server-side via `POST http://plausible:8000/api/event`.

---

## n8n — automation hub

n8n is both a consumer and a provider. It reaches the other services by name on
`donalabs_edge` (e.g. an HTTP Request node to `http://open-webui:8080/api/chat/completions`
or `http://calcom:3000/api/v1/...`). Other projects trigger n8n via webhooks:

```bash
curl -X POST http://n8n:5678/webhook/my-flow -d '{"hello":"world"}'
```

Manage workflows programmatically through the REST API at `http://n8n:5678/api/v1`
with an API key from **Settings → n8n API**.

---

## Open WebUI — AI interface

Open WebUI exposes an OpenAI-compatible API. Create a key in **Settings → Account**
and call it from any service or SDK:

```bash
curl http://open-webui:8080/api/chat/completions \
  -H "Authorization: Bearer sk-xxxx" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hi"}]}'
```

Because it speaks the OpenAI protocol, point any OpenAI SDK at
`http://open-webui:8080/api` with that key.

---

## Penpot — design

Penpot is primarily an interactive web app for design collaboration. For
automation/AI, the bundled **MCP server** (`penpot-mcp`, enabled by the
`enable-mcp` flag) exposes designs to agents, and the exporter renders
PDF/PNG/SVG. End users open the frontend at `http://localhost:9001`.

---

## yt-dlp — media utility

yt-dlp has no network port by design. Other scripts call the safe wrapper:

```bash
./services/ytdlp/ytdlp.sh audio https://example.com/watch?v=ID
./services/ytdlp/ytdlp.sh meta  https://example.com/watch?v=ID | jq .title
```

Or run the pinned image directly for advanced, still-sandboxed use:

```bash
docker run --rm -v "$PWD/out:/downloads" donalabs/ytdlp:2026.7.4 \
  --ignore-config -x --audio-format mp3 -- "https://example.com/watch?v=ID"
```
