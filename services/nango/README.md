# Nango in DonaLabs

Nango is the shared integration/authentication layer for Dona, Nova Context, Hermes, and future products. It centralizes OAuth/API-key connections instead of implementing token storage and refresh logic separately in every product.

## DonaLabs role

- Internal API: `http://nango-server:3003` on `donalabs_edge`
- Host API: `http://127.0.0.1:${NANGO_HOST_PORT:-3003}`
- Connect UI: `http://127.0.0.1:${NANGO_CONNECT_UI_PORT:-3009}`
- Private dependencies: Postgres and Redis

Dona should primarily use Nango for actions and connected-account access. Nova Context can use scoped syncs/context ingestion. Hermes can consume approved tools through the same shared integration layer.

## Start

```bash
./scripts/generate-secrets.sh
./start.sh nango-server
```

Nango is in the Compose `agents` profile, so the default DonaLabs stack stays lightweight. Explicitly targeting `nango-server` activates it and its dependencies.

The first deployment should be validated locally before configuring external OAuth callback URLs.

## OAuth callback URLs

For providers such as Google, GitHub, Slack, Microsoft, etc., Nango eventually needs a stable HTTPS callback URL. Keep the local values while developing. When moving to a real domain, expose only the required Nango endpoints through the DonaLabs edge/proxy and set `NANGO_SERVER_URL`, `NANGO_PUBLIC_SERVER_URL`, and `NANGO_PUBLIC_CONNECT_URL` accordingly.

## Security boundary

OAuth tokens and API credentials are high-value secrets.

- Nango's encryption key is generated locally and must be backed up securely.
- Postgres/Redis are private and never published.
- Product code should not read Nango's database directly.
- Dona/Nova/Hermes should use Nango's API through a service adapter or the future Tool Gateway.
- Destructive/write actions should be classified by the Tool Gateway and may require user approval.

## Architecture rule

Do not let each product define its own provider credentials and token-refresh implementation. Nango is the shared credential/integration control plane; products own business intent and authorization policy.

## License

Nango is distributed under the Elastic License 2.0. The free self-hosted edition has a smaller feature set than Nango Cloud/Enterprise. DonaLabs uses it as an internal infrastructure component, not as a re-hosted Nango service offered directly to customers. Re-check the applicable license/feature boundaries before commercial production.
