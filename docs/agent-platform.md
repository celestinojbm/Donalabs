# Agent infrastructure in DonaLabs

DonaLabs is the shared service plane for the Dona ecosystem. Products remain separate repositories and consume platform capabilities over stable service interfaces.

## Current agent-facing layers

| Layer | Service | Responsibility |
|---|---|---|
| Web data | Firecrawl | Search, scrape and crawl public web content |
| Connected apps | Nango | OAuth/API credentials, token refresh, proxy/sync primitives |
| Search | SearXNG | Self-hosted metasearch backend for Firecrawl/agents |
| Workflows | n8n | Deterministic automations, webhooks and scheduled workflows |
| Observability | Langfuse | LLM/agent traces, costs, prompts, evaluations and failures |
| Object storage | MinIO | Shared S3-compatible media/artifact/blob storage |
| Secrets | Vaultwarden | Operator/admin secrets; not a substitute for Nango's per-user OAuth store |
| AI UI | Open WebUI | Shared operator-facing model/chat interface |
| Design | Penpot | Shared design system and agent-accessible design tooling |

## Product boundary

```text
Dona ─────────┐
Nova Context ─┼──> Tool Gateway / adapters ──> Firecrawl / Nango / n8n / future tools
Hermes ───────┘
```

The products should not import or fork third-party service source. They should call DonaLabs services through HTTP/MCP/typed adapters so a provider can be upgraded or replaced without rewriting each product.

## Tool Gateway target

The next shared component should be a small DonaLabs-owned gateway rather than direct model access to every backend. It should eventually provide:

- a tool registry with stable business-level names;
- tenant/workspace identity propagation;
- read/write/destructive action classification;
- approval requirements;
- idempotency keys;
- rate/cost limits;
- audit records with source, action, result and latency;
- timeouts/retries/circuit breakers;
- provider routing and fallbacks.

Do not build a large agent framework inside the gateway. Keep model/orchestration logic in the product/agent layer and infrastructure policy in DonaLabs.

## Added in the agent-infrastructure expansion

- **SearXNG** — self-hosted metasearch backend, wired to Firecrawl through `FIRECRAWL_SEARXNG_ENDPOINT`.
- **Langfuse** — LLM/agent traces, prompts, costs and evaluations. Plausible remains product/web analytics.
- **MinIO** — shared S3-compatible object storage for Langfuse now and Nova Context/media/artifacts later.

## High-value next services

1. **LiteLLM Proxy** — only when DonaLabs actually needs one model-provider gateway across Dona/Nova/Hermes.
2. **Temporal** — later, for long-running durable workflows that exceed n8n's comfort zone.
3. **Tool Gateway** — this is more important than adding additional third-party services; it should become the policy/audit/routing boundary in front of Nango, Firecrawl, SearXNG and future action providers.

This list is intentionally short: infrastructure that has no current consumer should remain a documented candidate rather than a running container.
