"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  Blocks,
  LayoutDashboard,
  Palette,
  Sparkles,
  SquareDashedMousePointer,
  Wand2,
} from "lucide-react"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@donalabs/ui/components/sidebar"
import { Badge } from "@donalabs/ui/components/badge"

const NAV_ITEMS = [
  { title: "Overview", href: "/", icon: Sparkles },
  { title: "Foundations", href: "/foundations", icon: Palette },
  { title: "Components", href: "/components", icon: Blocks },
  { title: "Dashboard example", href: "/dashboard", icon: LayoutDashboard },
  { title: "Animations", href: "/animations", icon: Wand2 },
  { title: "Marketing (Magic UI)", href: "/marketing", icon: SquareDashedMousePointer },
] as const

export function AppSidebar() {
  const pathname = usePathname()

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href="/">
                <div className="flex size-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
                  <span className="text-sm font-semibold">D</span>
                </div>
                <div className="flex flex-col gap-0.5 leading-none">
                  <span className="font-semibold">DonaLabs</span>
                  <span className="text-xs text-muted-foreground">
                    Design System
                  </span>
                </div>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Design system</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {NAV_ITEMS.map((item) => (
                <SidebarMenuItem key={item.href}>
                  <SidebarMenuButton
                    asChild
                    isActive={pathname === item.href}
                    tooltip={item.title}
                  >
                    <Link href={item.href}>
                      <item.icon />
                      <span>{item.title}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
              <SidebarMenuItem>
                <SidebarMenuButton
                  asChild
                  isActive={pathname === "/evaluated"}
                  tooltip="Evaluated libraries"
                >
                  <Link href="/evaluated">
                    <SquareDashedMousePointer />
                    <span>Evaluated libraries</span>
                    <Badge variant="secondary" className="ml-auto text-[10px]">
                      3
                    </Badge>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter>
        <div className="px-2 py-1.5 text-xs text-muted-foreground group-data-[collapsible=icon]:hidden">
          Tailwind v4 · shadcn/ui · Radix · Motion
        </div>
      </SidebarFooter>
    </Sidebar>
  )
}
