/**
 * Technical facts checked against the repo (compose files, .env.example, README).
 * Host ports are the defaults published on 127.0.0.1. Internal addresses are
 * the service name and container port on donalabs_edge.
 * yt-dlp is an on-demand CLI (tools profile). It does not join the network.
 */

export const REPO_URL = "https://github.com/celestinojbm/Donalabs"

export const EDGE_NETWORK = "donalabs_edge"

export const services = [
  {
    id: "vaultwarden",
    product: "Vaultwarden",
    dir: "vaultwarden",
    hostPort: 8200,
    internal: "vaultwarden:80",
    edge: true,
  },
  {
    id: "calcom",
    product: "Cal.com",
    dir: "calcom",
    hostPort: 3000,
    internal: "calcom:3000",
    edge: true,
  },
  {
    id: "plausible",
    product: "Plausible",
    dir: "plausible",
    hostPort: 8210,
    internal: "plausible:8000",
    edge: true,
  },
  {
    id: "penpot",
    product: "Penpot",
    dir: "penpot",
    hostPort: 9001,
    internal: "penpot-frontend:8080",
    edge: true,
  },
  {
    id: "n8n",
    product: "n8n",
    dir: "n8n",
    hostPort: 5678,
    internal: "n8n:5678",
    edge: true,
  },
  {
    id: "openwebui",
    product: "Open WebUI",
    dir: "open-webui",
    hostPort: 3001,
    internal: "open-webui:8080",
    edge: true,
  },
  {
    id: "ytdlp",
    product: "yt-dlp",
    dir: "ytdlp",
    hostPort: null,
    internal: null,
    edge: false,
  },
] as const

export type ServiceId = (typeof services)[number]["id"]

export const footerServices = ["vaultwarden", "n8n", "plausible"] as const

export const repoLinks = {
  root: REPO_URL,
  commits: `${REPO_URL}/commits/main`,
  readme: `${REPO_URL}/blob/main/README.md`,
  quickStart: `${REPO_URL}/blob/main/README.md#quick-start`,
  backups: `${REPO_URL}/blob/main/README.md#backups`,
  security: `${REPO_URL}/blob/main/docs/security.md`,
  architecture: `${REPO_URL}/blob/main/docs/architecture.md`,
  health: `${REPO_URL}/blob/main/docs/operational-readiness.md`,
  docs: `${REPO_URL}/tree/main/docs`,
  service: (dir: string) => `${REPO_URL}/blob/main/services/${dir}/README.md`,
} as const

export const cloneCommand =
  "git clone https://github.com/celestinojbm/Donalabs && cd Donalabs && ./scripts/generate-secrets.sh && ./start.sh"

// Public origin for canonical/hreflang URLs. Set NEXT_PUBLIC_SITE_URL at build time.
export const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"
