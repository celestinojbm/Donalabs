import type { Metadata } from "next"
import localFont from "next/font/local"
import type { ReactNode } from "react"

import "./globals.css"

const inter = localFont({
  // Inter (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/inter/files/inter-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-inter",
  display: "swap",
  preload: false,
})

const interTight = localFont({
  // Inter Tight (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/inter-tight/files/inter-tight-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-inter-tight",
  display: "swap",
  preload: true,
})

const geistMono = localFont({
  // Geist Mono (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/geist-mono/files/geist-mono-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-geist-mono",
  display: "swap",
  preload: false,
})

export const metadata: Metadata = {
  title: "DonaLabs",
  description:
    "A reusable, self-hosted platform with the shared services for all of my projects, current and future.",
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${interTight.variable} ${geistMono.variable}`}
    >
      <body className="antialiased">{children}</body>
    </html>
  )
}
