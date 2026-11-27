"use client"

import { LazyMotion, MotionConfig, domAnimation } from "motion/react"
import * as m from "motion/react-m"
import type { ReactNode } from "react"

const easeSwiss = [0.65, 0, 0.35, 1] as const

export function MotionRoot({ children }: { children: ReactNode }) {
  return (
    <LazyMotion features={domAnimation} strict>
      <MotionConfig reducedMotion="user">{children}</MotionConfig>
    </LazyMotion>
  )
}

export function DrawRule({ className = "" }: { className?: string }) {
  return (
    <m.div
      aria-hidden="true"
      className={`rule ${className}`}
      initial={{ scaleX: 0 }}
      whileInView={{ scaleX: 1 }}
      viewport={{ once: true, margin: "0px 0px -8% 0px" }}
      transition={{ duration: 0.48, ease: easeSwiss }}
      style={{ originX: 0 }}
    />
  )
}
