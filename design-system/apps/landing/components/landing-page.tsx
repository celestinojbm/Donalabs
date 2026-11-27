import { Architecture } from "@/components/architecture"
import { Commands } from "@/components/commands"
import { Costs } from "@/components/costs"
import { Cta } from "@/components/cta"
import { Faq } from "@/components/faq"
import { Footer } from "@/components/footer"
import { Header } from "@/components/header"
import { Hero } from "@/components/hero"
import { MotionRoot } from "@/components/motion"
import { Principles } from "@/components/principles"
import { Services } from "@/components/services"
import type { Dictionary } from "@/lib/content"
import type { Locale } from "@/lib/i18n"

export function LandingPage({ locale, t }: { locale: Locale; t: Dictionary }) {
  return (
    <MotionRoot>
      <a href="#content" className="skip-link">
        {t.skip}
      </a>
      <Header locale={locale} t={t} />
      <main id="content">
        <Hero t={t} />
        <Commands t={t} />
        <Services t={t} />
        <Architecture t={t} />
        <Principles t={t} />
        <Costs t={t} />
        <Faq t={t} />
        <Cta t={t} />
      </main>
      <Footer locale={locale} t={t} />
    </MotionRoot>
  )
}
