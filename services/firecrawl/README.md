# Firecrawl in DonaLabs

Firecrawl is the shared web-data service for Dona, Nova Context, Hermes, and future agents. It handles web search/scraping/crawling behind one internal service instead of embedding a crawler in every product.

## DonaLabs role

- Internal API: `http://firecrawl-api:3002` on `donalabs_edge`
- Host API: `http://127.0.0.1:${FIRECRAWL_HOST_PORT:-3002}`
- Private dependencies: Playwright, Redis, RabbitMQ, and NuQ Postgres
- Default mode: self-hosted, no Firecrawl Cloud credits
- Cloud should remain an optional fallback for capabilities that are not available or practical self-hosted.

## Start

From the repository root:

```bash
./scripts/generate-secrets.sh
./start.sh firecrawl-api
curl http://127.0.0.1:3002/v0/health/liveness
```

Starting `firecrawl-api` pulls in its dependencies automatically.

## Security boundary

The self-hosted API runs with `USE_DB_AUTHENTICATION=false`. That is intentional for a private DonaLabs deployment. Do **not** expose the Firecrawl API directly to the public Internet. Consumers should reach it on `donalabs_edge`, and future external access should go through the DonaLabs Tool Gateway with authentication, policy checks, quotas, and audit logging.

Dependency ports are never published.

## Model-backed features

Basic scraping/crawling does not require a commercial LLM key. Features that need a model can be pointed to Ollama or an OpenAI-compatible endpoint using the `FIRECRAWL_*MODEL*` / base URL settings in the root environment file.

## Search backend

`FIRECRAWL_SEARXNG_ENDPOINT` is intentionally available so DonaLabs can later add a self-hosted SearXNG service and avoid coupling web search to a single upstream search provider.

## Versioning

The Firecrawl API image is pinned in `.env.example`. The Playwright and NuQ helper images currently use upstream `latest` by default because upstream's self-host compose documents them that way; pin them when upstream publishes stable matching version tags for the deployment you validate.

Before any upgrade, compare the selected release with Firecrawl's upstream self-host compose and release notes.

## Persistence

Unlike the upstream development-oriented compose baseline, DonaLabs persists NuQ Postgres, Redis, and RabbitMQ state and includes those resources in the platform backup inventory where appropriate.

## License

Firecrawl's main repository is AGPL-3.0. DonaLabs runs it as an independent service and talks to it over HTTP; it does not copy Firecrawl source into Dona/Nova/Hermes.
