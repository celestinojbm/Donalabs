import type { Metadata } from "next"
import { Geist, Geist_Mono } from "next/font/google"

import "@donalabs/ui/globals.css"
import { TooltipProvider } from "@donalabs/ui/components/tooltip"
import { cn } from "@donalabs/ui/lib/utils"

import { ThemeProvider } from "@/components/theme-provider"

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" })
const geistMono = Geist_Mono({ subsets: ["latin"], variable: "--font-mono" })

export const metadata: Metadata = {
  title: {
    default: "DonaLabs",
    template: "%s · DonaLabs",
  },
  description:
    "Infraestructura self-hosted para tus proyectos. Una red común, servicios en su sitio y las bases en su cajón.",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html
      lang="es"
      suppressHydrationWarning
      className={cn("antialiased", geistMono.variable, "font-sans", geist.variable)}
    >
      <body>
        <ThemeProvider>
          <TooltipProvider delayDuration={200}>{children}</TooltipProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
