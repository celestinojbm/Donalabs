# Langfuse in DonaLabs

Langfuse is the shared observability/evaluation layer for LLM and agent workloads.

It is meant to answer questions that Plausible cannot: which model/tool call happened, latency, tokens/cost, traces, failures, prompt versions, evaluations, and agent behavior.

## Start

```bash
./scripts/generate-secrets.sh
./start.sh minio minio-init langfuse-web langfuse-worker
```

- UI/API on host: `http://127.0.0.1:${LANGFUSE_HOST_PORT:-3010}`
- Internal address: `http://langfuse-web:3000`

Langfuse uses its own Postgres, Redis and ClickHouse. It reuses the shared DonaLabs MinIO bucket `langfuse` for event/media/export objects.

MinIO is intentionally not declared as a Compose dependency inside the Langfuse service file so the service stack remains standalone-valid under DonaLabs CI. Start MinIO first (or in the same root command shown above).

## Product integration

Dona, Nova Context and Hermes should create their own Langfuse projects/keys but send traces to the same platform. Keep product identity/workspace identifiers in trace metadata so cross-product analysis remains possible without collapsing tenancy.

## Telemetry

DonaLabs defaults `LANGFUSE_TELEMETRY_ENABLED=false`. Change it only intentionally.
