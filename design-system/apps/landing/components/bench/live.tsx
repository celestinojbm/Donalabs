"use client"

import { useEffect, useRef, useState } from "react"

import { Button } from "@donalabs/ui/components/button"

import { translateAlong } from "../iso/iso-kit"
import {
  asksForStillness,
  follow,
  useInView,
  useLoop,
  useReadout,
} from "../iso/react/live"
import { BenchScene } from "./art"
import { beadShift } from "./geometry"
import { BAYS, bayAt, readoutOf } from "./model"
import { BenchPlate } from "./plate"
import { P } from "./view"

const DWELL = 2.7

export function BenchLive({ onReady }: { onReady?: () => void }) {
  const { anchor, say } = useReadout<SVGGElement>()
  const stageRef = useRef<HTMLDivElement>(null)
  const beadRef = useRef<SVGGElement>(null)
  const inView = useInView(stageRef)
  const index = useRef(0)
  const shown = useRef(0)
  const idle = useRef(0)
  const touring = useRef(true)
  const resume = useRef(0)
  const generation = useRef(0)
  const [current, setCurrent] = useState(0)

  const apply = (offset: number, active: number) => {
    beadRef.current?.setAttribute(
      "transform",
      offset === 0 ? "" : translateAlong(P, [offset, 0, 0])
    )
    anchor.current?.querySelectorAll<SVGGElement>("[data-jumper]").forEach((node) => {
      const line = node.querySelector(".iso-line")
      if (!line) return
      const on = Number(node.dataset.jumper) === active
      line.setAttribute("data-tone", on ? "lit" : "lo")
    })
  }

  const kick = useLoop((dt, calm) => {
    const seen = generation.current
    const target = beadShift(index.current)
    if (calm) {
      shown.current = target
      apply(target, index.current)
      say(readoutOf(bayAt(index.current).name))
      return false
    }
    shown.current = follow(shown.current, target, dt, 0.38)
    apply(shown.current, index.current)
    if (
      touring.current &&
      generation.current === seen &&
      Math.abs(shown.current - target) < 0.08
    ) {
      idle.current += dt
      if (idle.current >= DWELL) {
        idle.current = 0
        index.current = (index.current + 1) % BAYS.length
        setCurrent(index.current)
        say(readoutOf(bayAt(index.current).name))
      }
    }
    return true
  }, inView)

  useEffect(() => {
    onReady?.()
    say(readoutOf(bayAt(0).name))
    return () => window.clearTimeout(resume.current)
  }, [onReady, say])

  const select = (next: number) => {
    generation.current += 1
    const safe = (next + BAYS.length) % BAYS.length
    index.current = safe
    touring.current = false
    idle.current = 0
    window.clearTimeout(resume.current)
    setCurrent(safe)
    say(readoutOf(bayAt(safe).name))
    if (asksForStillness()) {
      shown.current = beadShift(safe)
      apply(shown.current, safe)
      return
    }
    kick()
    resume.current = window.setTimeout(() => {
      touring.current = true
      kick()
    }, 9000)
  }

  return (
    <div className="flex flex-col gap-4">
      <div ref={stageRef}>
        <BenchPlate interactive>
          <g
            ref={anchor}
            onPointerDown={(event) => {
              const node = (event.target as Element | null)?.closest?.("[data-bay]")
              const value = node?.getAttribute("data-bay")
              if (value == null) return
              select(Number(value))
            }}
          >
            <BenchScene beadRef={beadRef} />
          </g>
        </BenchPlate>
      </div>
      <div
        className="flex flex-col gap-3"
        role="radiogroup"
        aria-label="Aparato en el borde"
        onKeyDown={(event) => {
          if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return
          event.preventDefault()
          select(current + (event.key === "ArrowRight" ? 1 : -1))
        }}
      >
        <div className="flex flex-wrap gap-2">
          {BAYS.map((bay, bayIndex) => {
            const selected = bayIndex === current
            return (
              <Button
                key={bay.id}
                type="button"
                role="radio"
                aria-checked={selected}
                variant={selected ? "default" : "outline"}
                size="sm"
                onClick={() => select(bayIndex)}
              >
                {bay.name}
              </Button>
            )
          })}
        </div>
        <p className="text-sm text-muted-foreground" aria-live="polite">
          {readoutOf(bayAt(current).name)}
        </p>
      </div>
    </div>
  )
}
