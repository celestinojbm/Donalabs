# Agent infrastructure in DonaLabs

DonaLabs is the shared service plane for the Dona ecosystem. Products remain separate repositories and consume platform capabilities over stable service interfaces.

## Current agent-facing layers

| Layer | Service | Responsibility |
|---|---|---|
| Web data | Firecrawl | Search, scrape and crawl public web content |
| Connected apps | Nango | OAuth/API credentials, token refresh, proxy/sync primitives |
| Workflows | n8n | Deterministic automations, webhooks and scheduled workflows |
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

## High-value next services

1. **SearXNG** — self-hosted metasearch backend. Firecrawl already has a SearXNG endpoint setting, so this is the cleanest next addition for independent search.
2. **Langfuse** — LLM/agent traces, prompts, costs and evaluations. Plausible measures websites; it does not give agent-level observability.
3. **LiteLLM Proxy** — only if DonaLabs needs one model-provider gateway across Dona/Nova/Hermes. Avoid adding it while each project has only one provider because it becomes another failure point.
4. **MinIO/S3-compatible object storage** — when Nova/media pipelines need durable shared blobs. Do not add it merely as another database.
5. **Temporal** — later, for long-running durable agent/business workflows that exceed n8n's comfort zone. It is not justified yet if n8n handles the workload.

This list is intentionally short: infrastructure that has no current consumer should remain a documented candidate rather than a running container.
