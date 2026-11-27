import { Geist_Mono, Inter, Inter_Tight } from "next/font/google"

export const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "600"],
  variable: "--font-inter",
  display: "swap",
  preload: false,
})

export const interTight = Inter_Tight({
  subsets: ["latin"],
  weight: ["700"],
  variable: "--font-inter-tight",
  display: "swap",
  preload: true,
})

export const geistMono = Geist_Mono({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-geist-mono",
  display: "swap",
  preload: false,
})

export const fontVariables = `${inter.variable} ${interTight.variable} ${geistMono.variable}`
