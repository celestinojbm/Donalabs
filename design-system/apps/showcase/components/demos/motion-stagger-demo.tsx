"use client"

import { useState } from "react"
import { motion } from "motion/react"
import { RotateCcwIcon } from "lucide-react"

import { Button } from "@donalabs/ui/components/button"

const container = {
  hidden: {},
  show: {
    transition: { staggerChildren: 0.06 },
  },
}

const item = {
  hidden: { opacity: 0, y: 8 },
  show: { opacity: 1, y: 0 },
}

export function MotionStaggerDemo() {
  const [key, setKey] = useState(0)

  return (
    <div className="space-y-3">
      <motion.div
        key={key}
        variants={container}
        initial="hidden"
        animate="show"
        className="grid grid-cols-4 gap-2 sm:grid-cols-8"
      >
        {Array.from({ length: 8 }).map((_, i) => (
          <motion.div
            key={i}
            variants={item}
            className="flex aspect-square items-center justify-center rounded-lg border bg-muted text-xs text-muted-foreground"
          >
            {i + 1}
          </motion.div>
        ))}
      </motion.div>
      <Button variant="outline" size="sm" onClick={() => setKey((k) => k + 1)}>
        <RotateCcwIcon /> Replay
      </Button>
    </div>
  )
}
