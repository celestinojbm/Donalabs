"use client"

import { useState } from "react"
import { motion } from "motion/react"

const TABS = ["Overview", "Usage", "API"] as const

export function MotionLayoutDemo() {
  const [active, setActive] = useState<(typeof TABS)[number]>("Overview")

  return (
    <div className="inline-flex gap-1 rounded-lg border bg-muted/50 p-1">
      {TABS.map((tab) => (
        <button
          key={tab}
          onClick={() => setActive(tab)}
          className="relative rounded-md px-3 py-1.5 text-sm font-medium text-muted-foreground transition-colors data-[active=true]:text-foreground"
          data-active={active === tab}
        >
          {active === tab && (
            <motion.div
              layoutId="motion-layout-demo-pill"
              className="absolute inset-0 rounded-md bg-background shadow-xs"
              transition={{ type: "spring", stiffness: 500, damping: 35 }}
            />
          )}
          <span className="relative z-10">{tab}</span>
        </button>
      ))}
    </div>
  )
}
