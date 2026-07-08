import { SidebarTrigger } from "@donalabs/ui/components/sidebar"
import { Separator } from "@donalabs/ui/components/separator"

import { ThemeToggle } from "@/components/theme-toggle"

export function SiteHeader() {
  return (
    <header className="flex h-14 shrink-0 items-center gap-2 border-b px-4">
      <SidebarTrigger className="-ml-1" />
      <Separator orientation="vertical" className="mr-2 h-4" />
      <div className="flex-1" />
      <ThemeToggle />
    </header>
  )
}
