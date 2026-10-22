import type { Metadata } from "next"
import { Geist_Mono, Inter, Inter_Tight } from "next/font/google"
import type { ReactNode } from "react"

import "./globals.css"

const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "600"],
  variable: "--font-inter",
  display: "swap",
  preload: false,
})

const interTight = Inter_Tight({
  subsets: ["latin"],
  weight: ["700"],
  variable: "--font-inter-tight",
  display: "swap",
  preload: true,
})

const geistMono = Geist_Mono({
  subsets: ["latin"],
  weight: ["400"],
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
