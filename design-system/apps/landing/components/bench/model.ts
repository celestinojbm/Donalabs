export const BAYS = [
  {
    id: "vaultwarden",
    name: "Vaultwarden",
    line: "Contraseñas y secretos. Aquí guardas las credenciales del resto.",
  },
  {
    id: "cal",
    name: "Cal.com",
    line: "Agenda para reservas, llamadas y demos.",
  },
  {
    id: "plausible",
    name: "Plausible",
    line: "Analítica web que no persigue a quien visita.",
  },
  {
    id: "penpot",
    name: "Penpot",
    line: "Diseño y prototipos, para trabajar en compañía.",
  },
  {
    id: "n8n",
    name: "n8n",
    line: "Automatización que une al resto de servicios.",
  },
  {
    id: "webui",
    name: "Open WebUI",
    line: "Chat con los modelos, en una sola interfaz.",
  },
] as const

export type Bay = (typeof BAYS)[number]

export const LOOSE_TOOL = {
  id: "ytdlp",
  name: "yt-dlp",
  line: "Utilidad de medios, solo cuando hace falta. No entra en la red común y no se queda encendida.",
} as const

export function bayAt(index: number): Bay {
  const bay = BAYS[index]
  return bay ?? BAYS[0]
}

export function readoutOf(name: string) {
  return `${name} · en el borde · el cajón sigue cerrado`
}
