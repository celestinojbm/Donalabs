# MinIO in DonaLabs

MinIO is the shared S3-compatible object store for large binary/object data. It is not a replacement for Postgres.

Initial buckets are created idempotently:

- `langfuse` — Langfuse event/media/export objects
- `nova-context` — future Nova Context media/context blobs
- `agent-artifacts` — shared generated files and agent artifacts

## Start

```bash
./scripts/generate-secrets.sh
./start.sh minio minio-init
```

- S3 API: `http://minio:9000` internally; host `http://127.0.0.1:${MINIO_API_HOST_PORT:-9000}`
- Console: `http://127.0.0.1:${MINIO_CONSOLE_HOST_PORT:-9001}`

The root credentials are generated locally. Product applications should eventually receive scoped service-account credentials instead of the root key.

## Why shared

Langfuse needs S3-compatible storage, and Nova Context will need durable storage for screenshots/audio/media. Keeping one object-store service avoids embedding blob storage into individual products while preserving separate buckets and policies.
