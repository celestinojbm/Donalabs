# Open WebUI — unified AI chat interface for local & remote models

## 1. Overview

Open WebUI is DonaLabs' shared, self-hosted chat front-end for large language models. It gives every project one place to talk to models served by a local **Ollama** instance and/or any **OpenAI-compatible API** (OpenAI, LiteLLM, vLLM, OpenRouter, Groq, …), with users, chats, prompts, and document RAG all managed in one instance. It runs on the shared `donalabs_edge` network so other services in the stack can reach it internally and reuse its OpenAI-compatible REST API. State (users, chats, settings, uploads, vector store) lives in a single named Docker volume.

## 2. Image & versions

| Role | Image | Pinned version |
|------|-------|----------------|
| App (all-in-one) | `ghcr.io/open-webui/open-webui` | `v0.10.2` (`OPENWEBUI_IMAGE_TAG`) |

No separate database or cache container: Open WebUI ships with **built-in SQLite** stored inside its data volume. For production/high-concurrency you can point it at an external Postgres — see [Security considerations](#8-security-considerations) and [Troubleshooting](#10-troubleshooting).

## 3. Quick start

All commands run from the repository root. The shared `donalabs_edge` network is created automatically by `start.sh` (or `scripts/init-network.sh`) before the service comes up.

```bash
# Start (preferred wrapper)
./start.sh open-webui
# …or directly with compose
docker compose -f services/open-webui/docker-compose.yml up -d open-webui

# Stop
docker compose -f services/open-webui/docker-compose.yml down

# Update to the pinned image tag
docker compose -f services/open-webui/docker-compose.yml pull
docker compose -f services/open-webui/docker-compose.yml up -d

# Backup — everything lives in one named volume
docker run --rm \
  -v donalabs_open_webui_data:/data \
  -v "$PWD":/backup alpine \
  tar czf /backup/open-webui-data-$(date +%F).tar.gz -C /data .
```

> The volume `donalabs_open_webui_data` (mounted at `/app/backend/data`) holds **all** state — users, chats, settings, uploaded files, the RAG vector store, and model caches. Lose it and you lose everything; back it up before upgrades.

## 4. Configuration

Set these in the repo-root `.env` (copy from `.env.example`). Only variables that the compose file actually consumes are listed.

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `OPENWEBUI_IMAGE_TAG` | Pins the Open WebUI image version | `v0.10.2` |
| `OPENWEBUI_HOST_PORT` | Host port published to the browser (maps to container `8080`) | `3001` |
| `OPENWEBUI_SECRET_KEY` | **Critical** signing key for sessions/JWTs and data encryption (maps to `WEBUI_SECRET_KEY`) | `GENERATE` — `openssl rand -hex 32`. Must stay **stable**; changing it logs everyone out and breaks encrypted data. |
| `OPENWEBUI_ENABLE_SIGNUP` | Allow self-registration (maps to `ENABLE_SIGNUP`) | `true` for first run, then set `false` and restart |
| `OPENWEBUI_OLLAMA_BASE_URL` | Ollama backend URL (maps to `OLLAMA_BASE_URL`) | empty = disabled. Host Ollama: `http://host.docker.internal:11434`; container on `donalabs_edge`: `http://ollama:11434` |
| `OPENWEBUI_OPENAI_API_BASE_URL` | OpenAI-compatible API base URL (maps to `OPENAI_API_BASE_URL`) | empty = disabled. e.g. `https://api.openai.com/v1`, or a LiteLLM/vLLM/OpenRouter/Groq endpoint |
| `OPENWEBUI_OPENAI_API_KEY` | API key for the OpenAI-compatible endpoint (maps to `OPENAI_API_KEY`) | empty = disabled |
| `TZ` | Container timezone | `UTC` (global) |
| `BIND_ADDR` | Host interface the published port binds to | `127.0.0.1` (global) — keep local; expose via Caddy |

Configure **at least one** provider (`OPENWEBUI_OLLAMA_BASE_URL` or `OPENWEBUI_OPENAI_API_BASE_URL` + key) or the instance has no models to talk to.

### Connecting to a model backend

- **Ollama on the Docker host** (installed natively, not in a container): set
  `OPENWEBUI_OLLAMA_BASE_URL=http://host.docker.internal:11434`.
  The compose file adds `host.docker.internal` via `extra_hosts` so the container can reach the host.
- **Ollama as a container** on `donalabs_edge`: set
  `OPENWEBUI_OLLAMA_BASE_URL=http://ollama:11434` (use the container's service name + its internal port).
- **OpenAI / any OpenAI-compatible provider** (OpenAI, LiteLLM, vLLM, OpenRouter, Groq): set
  `OPENWEBUI_OPENAI_API_BASE_URL` to the provider's `/v1` base URL and `OPENWEBUI_OPENAI_API_KEY` to its key.

You can also add or edit these backends at runtime from **Admin Panel → Settings → Connections** without restarting.

## 5. Access & first-run

- Local URL: **http://localhost:3001** (i.e. `http://<BIND_ADDR>:<OPENWEBUI_HOST_PORT>`).

First run:

1. Open http://localhost:3001.
2. Create the first account — **the first signup automatically becomes the admin**.
3. Lock the instance: set `OPENWEBUI_ENABLE_SIGNUP=false` in `.env` and restart
   (`docker compose -f services/open-webui/docker-compose.yml up -d`). New users then require an admin invite.
4. Confirm at least one model provider is configured (Admin Panel → Settings → Connections).

## 6. Consume from other projects

Any container attached to the `donalabs_edge` network reaches Open WebUI at its **internal** address:

```
http://open-webui:8080
```

- **Internal (container-to-container):** service name `open-webui`, port **`8080`** — use this from other services (e.g. n8n).
- **Published (browser on the host):** port **`3001`** (`OPENWEBUI_HOST_PORT`) — for humans only, not for internal calls.

Open WebUI exposes an **OpenAI-compatible REST API** under `http://open-webui:8080/api`, e.g. `GET /api/models` and `POST /api/chat/completions`. Authenticate with a **per-user API key** (`Authorization: Bearer <key>`) created in **Settings → Account → API keys**.

Example — call it from another service on the network:

```bash
# List available models
curl -s http://open-webui:8080/api/models \
  -H "Authorization: Bearer $OPENWEBUI_API_KEY"

# Chat completion (OpenAI-compatible schema)
curl -s http://open-webui:8080/api/chat/completions \
  -H "Authorization: Bearer $OPENWEBUI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "llama3.1",
        "messages": [{"role": "user", "content": "Summarize this ticket in one line."}]
      }'
```

In **n8n**, add an OpenAI credential pointing its base URL at `http://open-webui:8080/api` and paste the Open WebUI API key — every node then routes through Open WebUI's configured backends.

## 7. Usage examples

**Chat with a local Ollama model.** Pull a model on the host (`ollama pull llama3.1`), set `OPENWEBUI_OLLAMA_BASE_URL=http://host.docker.internal:11434`, restart, then pick the model in the top-left selector and chat.

**Document Q&A (RAG).** Upload a PDF into a chat (or a Knowledge collection), then ask questions about it — embeddings and the vector store are kept in the data volume automatically.

**Programmatic completion from n8n.** Use an HTTP Request / OpenAI node against `http://open-webui:8080/api/chat/completions` with a Bearer API key to generate text inside an automation, reusing whichever provider Open WebUI is configured with.

## 8. Security considerations

- **Keep `OPENWEBUI_SECRET_KEY` stable and secret.** It signs sessions and encrypts stored data. Rotating or losing it logs out every user and renders encrypted data unrecoverable. Set it once (`openssl rand -hex 32`) and back it up.
- **Lock signups after the first user.** Leaving `OPENWEBUI_ENABLE_SIGNUP=true` lets anyone who reaches the port self-register. Flip it to `false` immediately after creating the admin account.
- **Keep it bound to localhost.** The port publishes on `BIND_ADDR` (default `127.0.0.1`). Do not expose it directly on `0.0.0.0` — front it with **Caddy for HTTPS** (`CADDY_OPENWEBUI_DOMAIN`, default `ai.localhost`) and restrict CORS for any public deployment.
- **Treat API keys as credentials.** Per-user keys grant full API access as that user; scope and rotate them, and store them in Vaultwarden rather than in plaintext configs.
- **SQLite is single-writer.** For production/concurrent load, move to Postgres via `DATABASE_URL` (see Troubleshooting) so you don't hit write contention or corruption under load.

## 9. Health check

The container defines a Docker healthcheck that curls the app's `/health` endpoint:

```
curl -fsS http://localhost:8080/health   # inside the container; interval 30s, 45s start period
```

Check it from the host:

```bash
# Repo helper (all services)
./scripts/health.sh

# Docker health status
docker inspect --format '{{.State.Health.Status}}' donalabs-open-webui

# Raw endpoint via the published port
curl -fsS http://localhost:3001/health   # -> 200 {"status":true}
```

## 10. Troubleshooting

- **Everyone logged out / "invalid token" after a restart:** `OPENWEBUI_SECRET_KEY` changed (or was blank and regenerated). Restore the original value and restart.
- **No models in the selector:** no backend configured or reachable. Verify `OPENWEBUI_OLLAMA_BASE_URL` / `OPENWEBUI_OPENAI_API_BASE_URL` (+ key), or add a connection in Admin Panel → Settings → Connections.
- **Can't reach host Ollama (`connection refused`):** use `http://host.docker.internal:11434`, not `http://localhost:11434` (inside the container `localhost` is the container itself). The compose `extra_hosts` entry enables this.
- **Container Ollama unreachable:** it must be on the `donalabs_edge` network and addressed as `http://ollama:11434` (service name + internal port).
- **Other services get connection errors:** they're likely using `localhost:3001`. Internal callers must use `http://open-webui:8080` and be attached to `donalabs_edge`.
- **Lost data after `docker compose down -v` or a fresh volume:** state lives only in `donalabs_open_webui_data`. Restore from your tar backup; never use `-v` on this stack unless you intend to wipe it.
- **Slow / locked under concurrent load:** the default SQLite backend is single-writer. Point the container at Postgres by adding `DATABASE_URL=postgresql://user:pass@host:5432/openwebui` to the service environment (not wired into `.env` by default) and restart.
