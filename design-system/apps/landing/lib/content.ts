import type { Locale } from "@/lib/i18n"
import type { ServiceId } from "@/lib/site"

export type Dictionary = {
  meta: { title: string; description: string }
  skip: string
  langLabel: string
  languages: Record<Locale, string>
  nav: {
    services: string
    architecture: string
    docs: string
    health: string
    costs: string
    github: string
    openMenu: string
    closeMenu: string
    primary: string
    mobile: string
  }
  hero: {
    conjunction: string
    accent: string
    lede: string
    ledeShort: string
    cta: string
    ctaLabel: string
  }
  commands: {
    index: string
    title: string
    aside: string
    steps: { title: string; lead: string; rest: string }[]
  }
  serviceSection: {
    index: string
    title: string
    aside: string
    items: Record<ServiceId, { name: string; summary: string; blurb: string }>
  }
  architecture: {
    index: string
    title: string
    aside: string
    treeLabel: string
    cli: string
    networkKicker: string
    networkBody: string
  }
  principles: {
    index: string
    title: string
    aside: string
    stats: { value: number; suffix: string; label: string; spoken: string }[]
  }
  costs: {
    titleLine1: string
    titleLine2: string
    aside: string
    example: string
    banner: string
    perMonth: string
    guide: string
    deploy: string
    plans: {
      index: string
      name: string
      price: string
      priceSpoken: string
      spec: string
      features: string[]
    }[]
  }
  faq: {
    index: string
    title: string
    aside: string
    items: { q: string; a: string }[]
  }
  cta: {
    line1: string
    line2: string
    button: string
  }
  footer: {
    line1: string
    line2: string
    services: string
    docs: string
    project: string
    links: {
      start: string
      backups: string
      security: string
      github: string
      dona: string
      changes: string
    }
  }
}

const en: Dictionary = {
  meta: {
    title: "DonaLabs",
    description:
      "A reusable, self-hosted platform with the shared services for all of my projects, current and future.",
  },
  skip: "Skip to content",
  langLabel: "Language",
  languages: { en: "English", es: "Español" },
  nav: {
    services: "Services",
    architecture: "Architecture",
    docs: "Docs",
    health: "Health",
    costs: "Costs",
    github: "GitHub",
    openMenu: "Open menu",
    closeMenu: "Close menu",
    primary: "Primary",
    mobile: "Mobile",
  },
  hero: {
    conjunction: "and",
    accent: "beyond.",
    lede: "A reusable, self-hosted platform with the shared services for all of my projects, current and future.",
    ledeShort:
      "A self-hosted platform with the shared services for all of my projects.",
    cta: "./start.sh",
    ctaLabel: "Jump to the four commands, starting with ./start.sh",
  },
  commands: {
    index: "01",
    title: "Four commands.",
    aside: "Everything is code, version-pinned, persistent, and checked.",
    steps: [
      {
        title: "Generate secrets",
        lead: "./scripts/generate-secrets.sh",
        rest: "creates .env and fills in the keys.",
      },
      {
        title: "Adjust",
        lead: "",
        rest: "Ports, domains, and flags in .env, versioned.",
      },
      {
        title: "Start",
        lead: "./start.sh",
        rest: "creates the donalabs_edge network and brings everything up.",
      },
      {
        title: "Check",
        lead: "",
        rest: "Health checks per service and scheduled backups.",
      },
    ],
  },
  serviceSection: {
    index: "02",
    title: "Seven services.",
    aside: "Each service has a guide at services/<name>/README.md.",
    items: {
      vaultwarden: {
        name: "Secrets",
        summary: "Password and secrets manager",
        blurb: "Vaultwarden, compatible with Bitwarden.",
      },
      calcom: {
        name: "Scheduling",
        summary: "Scheduling and bookings",
        blurb: "Cal.com for calls and demos.",
      },
      plausible: {
        name: "Analytics",
        summary: "Analytics that respects privacy",
        blurb: "Plausible, no cookies.",
      },
      penpot: {
        name: "Design",
        summary: "Design and prototypes",
        blurb: "Collaborative Penpot.",
      },
      n8n: {
        name: "Automation",
        summary: "Workflow automation",
        blurb: "n8n with internal webhooks.",
      },
      openwebui: {
        name: "AI",
        summary: "AI chat interface",
        blurb: "One Open WebUI.",
      },
      ytdlp: {
        name: "Media",
        summary: "Media utility",
        blurb: "yt-dlp, on-demand CLI. It does not join donalabs_edge.",
      },
    },
  },
  architecture: {
    index: "03",
    title: "As code.",
    aside: "One tree, one network, one command.",
    treeLabel: "Repository tree and default port map",
    cli: "CLI on demand",
    networkKicker: "Shared network",
    networkBody:
      "Projects reach services by internal name, not by host port. Dona calls http://n8n:5678. Published ports bind to 127.0.0.1. yt-dlp is a CLI and does not join the network.",
  },
  principles: {
    index: "04",
    title: "No magic.",
    aside:
      "Versioned, persistent, checked, and backed up. Documented in the first person.",
    stats: [
      {
        value: 7,
        suffix: "",
        label: "services in the repo",
        spoken: "7 services in the repository",
      },
      {
        value: 100,
        suffix: "%",
        label: "defined as code",
        spoken: "100 percent defined as code",
      },
      {
        value: 24,
        suffix: "h",
        label: "between backups",
        spoken: "24 hours between backups, the documented daily cron",
      },
      {
        value: 0,
        suffix: "",
        label: "third-party SaaS dependencies",
        spoken: "0 third-party SaaS dependencies",
      },
    ],
  },
  costs: {
    titleLine1: "Free.",
    titleLine2: "Your hardware.",
    aside:
      "The software is free. The server is what costs money. Example estimates, not prices.",
    example: "Example",
    banner:
      "Example estimates. These figures are placeholders, not a price list, a quote, or an offer. The euros are not measured in this repo.",
    perMonth: "/month",
    guide: "View guide",
    deploy: "Deploy",
    plans: [
      {
        index: "01",
        name: "Minimum",
        price: "5",
        priceSpoken: "Example estimate: 5 euros per month",
        spec: "VPS 2 vCPU · 4 GB",
        features: [
          "Vaultwarden, Plausible, n8n",
          "Daily backups",
          "Without Penpot",
        ],
      },
      {
        index: "02",
        name: "Recommended",
        price: "12",
        priceSpoken: "Example estimate: 12 euros per month",
        spec: "4 vCPU · 8 GB",
        features: ["All 7 services", "Backups + replica", "Room for Dona"],
      },
      {
        index: "03",
        name: "Local",
        price: "0",
        priceSpoken: "Example estimate: 0 euros per month",
        spec: "your machine",
        features: [
          "Everything on localhost",
          "Ideal for development",
          "No domain",
        ],
      },
    ],
  },
  faq: {
    index: "05",
    title: "Questions.",
    aside: "Short answers, in the first person.",
    items: [
      {
        q: "Is it a product?",
        a: "No. It is the shared infrastructure behind Dona and my future projects.",
      },
      {
        q: "What do I need to run it?",
        a: "Docker Engine 24+ and Docker Compose v2, about 8 GB of RAM and 30 GB of disk, plus openssl and bash.",
      },
      {
        q: "How do backups work?",
        a: "./backup.sh writes a timestamped folder under backups/: a pg_dump of every Postgres, tar.gz snapshots of the volumes, and a copy of .env. Retention defaults to 7. The example cron runs it once a day.",
      },
      {
        q: "Can I add a service?",
        a: "Yes. Add a stack at services/<name>/docker-compose.yml and include it from the root compose file. Databases stay on a private network. Only the app-facing container joins donalabs_edge.",
      },
      {
        q: "What if a service goes down?",
        a: "Stacks are isolated. A failure or a restore in one service does not take the others with it. Restart policy is unless-stopped, and ./scripts/health.sh checks each service.",
      },
    ],
  },
  cta: {
    line1: "Clone.",
    line2: "Start.",
    button: "View on GitHub",
  },
  footer: {
    line1: "Personal infrastructure and shared services.",
    line2: "A personal project.",
    services: "Services",
    docs: "Docs",
    project: "Project",
    links: {
      start: "Getting started",
      backups: "Backups",
      security: "Security",
      github: "GitHub",
      dona: "Dona",
      changes: "Changes",
    },
  },
}

const es: Dictionary = {
  meta: {
    title: "DonaLabs",
    description:
      "Una plataforma reutilizable y autoalojada con los servicios compartidos de todos mis proyectos, actuales y futuros.",
  },
  skip: "Saltar al contenido",
  langLabel: "Idioma",
  languages: { en: "English", es: "Español" },
  nav: {
    services: "Servicios",
    architecture: "Arquitectura",
    docs: "Docs",
    health: "Salud",
    costs: "Costes",
    github: "GitHub",
    openMenu: "Abrir menú",
    closeMenu: "Cerrar menú",
    primary: "Principal",
    mobile: "Móvil",
  },
  hero: {
    conjunction: "y",
    accent: "más allá.",
    lede: "Una plataforma reutilizable y autoalojada con los servicios compartidos de todos mis proyectos, actuales y futuros.",
    ledeShort:
      "Plataforma autoalojada con los servicios compartidos de todos mis proyectos.",
    cta: "./start.sh",
    ctaLabel: "Ir a los cuatro comandos, empezando por ./start.sh",
  },
  commands: {
    index: "01",
    title: "Cuatro comandos.",
    aside: "Todo es código, fijado por versión, persistente y comprobado.",
    steps: [
      {
        title: "Genera secretos",
        lead: "./scripts/generate-secrets.sh",
        rest: "crea .env y rellena claves.",
      },
      {
        title: "Ajusta",
        lead: "",
        rest: "Puertos, dominios y flags en .env, versionado.",
      },
      {
        title: "Arranca",
        lead: "./start.sh",
        rest: "crea la red donalabs_edge y levanta todo.",
      },
      {
        title: "Comprueba",
        lead: "",
        rest: "Health-checks por servicio y backups programados.",
      },
    ],
  },
  serviceSection: {
    index: "02",
    title: "Siete servicios.",
    aside: "Cada servicio con su guía en services/<nombre>/README.md.",
    items: {
      vaultwarden: {
        name: "Secretos",
        summary: "Gestor de contraseñas y secretos",
        blurb: "Vaultwarden compatible con Bitwarden.",
      },
      calcom: {
        name: "Agenda",
        summary: "Agenda y reservas",
        blurb: "Cal.com para llamadas y demos.",
      },
      plausible: {
        name: "Analítica",
        summary: "Analítica que respeta la privacidad",
        blurb: "Plausible, sin cookies.",
      },
      penpot: {
        name: "Diseño",
        summary: "Diseño y prototipos",
        blurb: "Penpot colaborativo.",
      },
      n8n: {
        name: "Automatización",
        summary: "Automatización de flujos",
        blurb: "n8n con webhooks internos.",
      },
      openwebui: {
        name: "IA",
        summary: "Interfaz de chat con IA",
        blurb: "Open WebUI unificada.",
      },
      ytdlp: {
        name: "Medios",
        summary: "Utilidad de medios",
        blurb: "yt-dlp, CLI bajo demanda. No entra en donalabs_edge.",
      },
    },
  },
  architecture: {
    index: "03",
    title: "Como código.",
    aside: "Un árbol, una red, un comando.",
    treeLabel: "Árbol del repositorio y mapa de puertos por defecto",
    cli: "CLI bajo demanda",
    networkKicker: "Red compartida",
    networkBody:
      "Los proyectos consumen servicios por nombre interno, no por puerto. Dona llama a http://n8n:5678. Los puertos publicados escuchan en 127.0.0.1. yt-dlp es un CLI y no entra en la red.",
  },
  principles: {
    index: "04",
    title: "Sin magia.",
    aside:
      "Versionado, persistente, comprobado y respaldado. Documentado en primera persona.",
    stats: [
      {
        value: 7,
        suffix: "",
        label: "servicios en el repositorio",
        spoken: "7 servicios en el repositorio",
      },
      {
        value: 100,
        suffix: "%",
        label: "definido como código",
        spoken: "100 por cien definido como código",
      },
      {
        value: 24,
        suffix: "h",
        label: "entre backups",
        spoken: "24 horas entre backups, el cron diario documentado",
      },
      {
        value: 0,
        suffix: "",
        label: "dependencias de terceros SaaS",
        spoken: "0 dependencias de terceros SaaS",
      },
    ],
  },
  costs: {
    titleLine1: "Gratis.",
    titleLine2: "Tu hierro.",
    aside:
      "El software es libre. Lo que cuesta es el servidor. Estimaciones de ejemplo, no tarifas.",
    example: "Ejemplo",
    banner:
      "Estimaciones de ejemplo. Estas cifras son marcadores de posición, no una tarifa, un presupuesto ni una oferta. Los euros no están medidos en este repo.",
    perMonth: "/mes",
    guide: "Ver guía",
    deploy: "Desplegar",
    plans: [
      {
        index: "01",
        name: "Mínimo",
        price: "5",
        priceSpoken: "Estimación de ejemplo: 5 euros al mes",
        spec: "VPS 2 vCPU · 4 GB",
        features: [
          "Vaultwarden, Plausible, n8n",
          "Backups diarios",
          "Sin Penpot",
        ],
      },
      {
        index: "02",
        name: "Recomendado",
        price: "12",
        priceSpoken: "Estimación de ejemplo: 12 euros al mes",
        spec: "4 vCPU · 8 GB",
        features: ["Los 7 servicios", "Backups + réplica", "Margen para Dona"],
      },
      {
        index: "03",
        name: "Local",
        price: "0",
        priceSpoken: "Estimación de ejemplo: 0 euros al mes",
        spec: "tu máquina",
        features: ["Todo en localhost", "Ideal para desarrollo", "Sin dominio"],
      },
    ],
  },
  faq: {
    index: "05",
    title: "Preguntas.",
    aside: "Respuestas cortas, en primera persona.",
    items: [
      {
        q: "¿Es un producto?",
        a: "No. Es la infraestructura compartida detrás de Dona y de mis proyectos futuros.",
      },
      {
        q: "¿Qué necesito para arrancarla?",
        a: "Docker Engine 24+ y Docker Compose v2, unos 8 GB de RAM y 30 GB de disco, además de openssl y bash.",
      },
      {
        q: "¿Cómo se hacen los backups?",
        a: "./backup.sh escribe una carpeta con fecha en backups/: pg_dump de cada Postgres, tar.gz de los volúmenes y una copia de .env. La retención por defecto es 7. El cron de ejemplo lo lanza una vez al día.",
      },
      {
        q: "¿Puedo añadir un servicio?",
        a: "Sí. Un stack en services/<nombre>/docker-compose.yml, incluido desde el compose raíz. Las bases de datos se quedan en su red privada. Solo el contenedor de cara al usuario entra en donalabs_edge.",
      },
      {
        q: "¿Qué pasa si un servicio cae?",
        a: "Los stacks están aislados. Una caída o una restauración no arrastra al resto. El reinicio es unless-stopped y ./scripts/health.sh comprueba cada servicio.",
      },
    ],
  },
  cta: {
    line1: "Clona.",
    line2: "Arranca.",
    button: "Ver en GitHub",
  },
  footer: {
    line1: "Infraestructura personal y servicios compartidos.",
    line2: "Proyecto personal.",
    services: "Servicios",
    docs: "Docs",
    project: "Proyecto",
    links: {
      start: "Arranque",
      backups: "Backups",
      security: "Seguridad",
      github: "GitHub",
      dona: "Dona",
      changes: "Cambios",
    },
  },
}

const dictionaries: Record<Locale, Dictionary> = { en, es }

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale]
}
