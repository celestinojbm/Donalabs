import localFont from "next/font/local"

export const inter = localFont({
  // Inter (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/inter/files/inter-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-inter",
  display: "swap",
  preload: false,
})

export const interTight = localFont({
  // Inter Tight (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/inter-tight/files/inter-tight-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-inter-tight",
  display: "swap",
  preload: true,
})

export const geistMono = localFont({
  // Geist Mono (variable, latin subset), self-hosted via @fontsource-variable (OFL-1.1)
  src: "../node_modules/@fontsource-variable/geist-mono/files/geist-mono-latin-wght-normal.woff2",
  weight: "100 900",
  style: "normal",
  variable: "--font-geist-mono",
  display: "swap",
  preload: false,
})

export const fontVariables = `${inter.variable} ${interTight.variable} ${geistMono.variable}`
