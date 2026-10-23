# SearXNG in DonaLabs

SearXNG is the shared self-hosted metasearch backend for Firecrawl, Dona, Nova Context, Hermes, and future agents.

## Start

```bash
./scripts/generate-secrets.sh
./start.sh searxng
```

- Host UI/API: `http://127.0.0.1:${SEARXNG_HOST_PORT:-8088}`
- Internal address: `http://searxng:8080`
- JSON search: `GET /search?q=<query>&format=json`

The service is in the `agents` profile and does not start with the default stack.

## Firecrawl

Set:

```env
FIRECRAWL_SEARXNG_ENDPOINT=http://searxng:8080
```

Firecrawl and SearXNG share `donalabs_edge`; Valkey stays private.

## Security

Only the app container joins `donalabs_edge`. The host port binds to `127.0.0.1` by default. Do not expose the raw search endpoint publicly without rate limiting and authentication at the edge.

The checked-in settings file intentionally contains a placeholder secret because the actual secret is injected from the root environment. If a SearXNG release stops honoring the environment override, render the secret into a runtime-only config rather than committing it.
