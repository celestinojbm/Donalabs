import { Button } from "@donalabs/ui/components/button"
import { Separator } from "@donalabs/ui/components/separator"

import { BenchPoster } from "@/components/bench/poster"
import { BenchStage } from "@/components/bench/stage"
import { ContactForm } from "@/components/contact-form"
import { SiteHeader } from "@/components/site-header"
import { BAYS, LOOSE_TOOL } from "@/components/bench/model"

const FACTS = [
  {
    title: "El borde",
    body: "Hay una red común, donalabs_edge. Otro proyecto se engancha a ella y llama a un servicio por su nombre. En la figura, ese enganche es el pulso: corre por el embarrado y no entra en ningún cajón.",
  },
  {
    title: "La pila",
    body: "Cada servicio es su propio aparato, con la versión fijada. Puedes tener uno en marcha o todos. El de al lado no se entera.",
  },
  {
    title: "El cajón",
    body: "La base de cada aparato se queda en una red privada. No se publica en el borde. Por eso el cajón de la figura no tiene cable.",
  },
  {
    title: "La puerta",
    body: "Por defecto un servicio solo responde en tu máquina. Abrirlo hacia fuera es un proxy aparte. En esta mesa la falleba sigue echada.",
  },
] as const

export default function HomePage() {
  return (
    <>
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:rounded-lg focus:bg-primary focus:px-3 focus:py-2 focus:text-primary-foreground"
      >
        Saltar al contenido
      </a>
      <SiteHeader />
      <main id="contenido">
        <section className="px-5 py-14 sm:px-8 sm:py-20">
          <div className="mx-auto grid max-w-6xl items-start gap-12 lg:grid-cols-12 lg:gap-10">
            <div className="flex flex-col gap-6 lg:col-span-5">
              <h1 className="max-w-[16ch] text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
                Tus proyectos se enganchan al mismo borde.
              </h1>
              <p className="max-w-[42rem] text-base leading-relaxed text-muted-foreground">
                DonaLabs no es un producto. Es la infraestructura self-hosted que
                montas una vez y reutilizas: secretos, agenda, analítica, diseño,
                automatización y un chat de IA. Tus otros proyectos se enganchan
                al borde. Las bases se quedan en su cajón.
              </p>
              <div>
                <Button asChild>
                  <a href="#escribir">Escribir</a>
                </Button>
              </div>
            </div>
            <div className="bench-slot lg:col-span-7">
              <div className="bench-poster">
                <BenchPoster />
              </div>
              <BenchStage />
            </div>
          </div>
        </section>

        <section id="como-funciona" className="scroll-mt-8 border-t px-5 py-16 sm:px-8">
          <div className="mx-auto flex max-w-6xl flex-col gap-10">
            <h2 className="max-w-[20ch] text-2xl font-semibold tracking-tight">
              Cómo está armado
            </h2>
            <div className="grid gap-8 sm:grid-cols-2">
              {FACTS.map((fact) => (
                <div key={fact.title} className="flex flex-col gap-2">
                  <h3 className="text-lg font-medium">{fact.title}</h3>
                  <p className="max-w-[46ch] text-sm leading-relaxed text-muted-foreground">
                    {fact.body}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="servicios" className="scroll-mt-8 border-t px-5 py-16 sm:px-8">
          <div className="mx-auto flex max-w-6xl flex-col gap-8">
            <h2 className="text-2xl font-semibold tracking-tight">Servicios</h2>
            <ul className="flex flex-col">
              {BAYS.map((bay) => (
                <li
                  key={bay.id}
                  className="flex flex-col gap-1 border-b py-5 sm:flex-row sm:gap-10"
                >
                  <span className="font-medium sm:w-40 sm:shrink-0">{bay.name}</span>
                  <span className="text-muted-foreground">{bay.line}</span>
                </li>
              ))}
              <li className="flex flex-col gap-1 border-b py-5 sm:flex-row sm:gap-10">
                <span className="font-medium sm:w-40 sm:shrink-0">{LOOSE_TOOL.name}</span>
                <span className="text-muted-foreground">{LOOSE_TOOL.line}</span>
              </li>
            </ul>
          </div>
        </section>

        <section id="escribir" className="scroll-mt-8 border-t px-5 py-16 sm:px-8">
          <div className="mx-auto flex max-w-6xl flex-col gap-6">
            <div className="flex max-w-xl flex-col gap-3">
              <h2 className="text-2xl font-semibold tracking-tight">
                Si quieres enganchar un proyecto, escríbeme.
              </h2>
              <p className="text-sm leading-relaxed text-muted-foreground">
                Deja tu correo. Si la hoja está conectada, lo anoto. Desde aquí
                no te mando ningún mensaje.
              </p>
            </div>
            <ContactForm />
          </div>
        </section>
      </main>
      <Separator />
      <footer className="px-5 py-8 text-sm text-muted-foreground sm:px-8">
        <div className="mx-auto max-w-6xl">
          DonaLabs · infraestructura self-hosted
        </div>
      </footer>
    </>
  )
}
