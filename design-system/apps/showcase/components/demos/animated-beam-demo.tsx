"use client"

import { useRef } from "react"
import { KeyRoundIcon, CalendarIcon, BarChart3Icon } from "lucide-react"

import { AnimatedBeam } from "@donalabs/ui/components/animated-beam"
import { cn } from "@donalabs/ui/lib/utils"

function Node({
  innerRef,
  children,
}: {
  innerRef: React.RefObject<HTMLDivElement | null>
  children: React.ReactNode
}) {
  return (
    <div
      ref={innerRef}
      className={cn(
        "z-10 flex size-12 items-center justify-center rounded-full border-2 bg-background shadow-sm"
      )}
    >
      {children}
    </div>
  )
}

export function AnimatedBeamDemo() {
  const containerRef = useRef<HTMLDivElement>(null)
  const centerRef = useRef<HTMLDivElement>(null)
  const vaultRef = useRef<HTMLDivElement>(null)
  const calRef = useRef<HTMLDivElement>(null)
  const analyticsRef = useRef<HTMLDivElement>(null)

  return (
    <div
      ref={containerRef}
      className="relative flex h-48 w-full max-w-md items-center justify-between rounded-xl border bg-muted/30 p-8"
    >
      <div className="flex flex-col justify-between gap-6">
        <Node innerRef={vaultRef}>
          <KeyRoundIcon className="size-5" />
        </Node>
        <Node innerRef={calRef}>
          <CalendarIcon className="size-5" />
        </Node>
        <Node innerRef={analyticsRef}>
          <BarChart3Icon className="size-5" />
        </Node>
      </div>
      <Node innerRef={centerRef}>
        <span className="text-sm font-semibold">D</span>
      </Node>

      <AnimatedBeam containerRef={containerRef} fromRef={vaultRef} toRef={centerRef} curvature={-40} />
      <AnimatedBeam containerRef={containerRef} fromRef={calRef} toRef={centerRef} />
      <AnimatedBeam containerRef={containerRef} fromRef={analyticsRef} toRef={centerRef} curvature={40} />
    </div>
  )
}
