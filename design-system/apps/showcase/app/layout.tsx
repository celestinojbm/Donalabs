import type { Metadata } from "next"
import { Geist, Geist_Mono } from "next/font/google"

import "@donalabs/ui/globals.css"
import { cn } from "@donalabs/ui/lib/utils"
import { TooltipProvider } from "@donalabs/ui/components/tooltip"
import { Toaster } from "@donalabs/ui/components/sonner"
import { SidebarProvider, SidebarInset } from "@donalabs/ui/components/sidebar"

import { ThemeProvider } from "@/components/theme-provider"
import { AppSidebar } from "@/components/app-sidebar"
import { SiteHeader } from "@/components/site-header"

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" })

const fontMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
})

export const metadata: Metadata = {
  title: {
    default: "DonaLabs Design System",
    template: "%s · DonaLabs Design System",
  },
  description:
    "The shared design platform for DonaLabs — Tailwind v4, shadcn/ui, Radix UI, Motion, Magic UI, and Lucide, unified for every future project.",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={cn("antialiased", fontMono.variable, "font-sans", geist.variable)}
    >
      <body>
        <ThemeProvider>
          <TooltipProvider delayDuration={200}>
            <SidebarProvider>
              <AppSidebar />
              <SidebarInset>
                <SiteHeader />
                <div className="flex flex-1 flex-col gap-4 p-4 md:p-8">
                  {children}
                </div>
              </SidebarInset>
            </SidebarProvider>
            <Toaster />
          </TooltipProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
