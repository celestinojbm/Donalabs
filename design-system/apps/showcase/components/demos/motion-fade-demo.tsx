"use client"

import { useState } from "react"
import { motion } from "motion/react"
import { RotateCcwIcon } from "lucide-react"

import { Button } from "@donalabs/ui/components/button"
import { Card, CardContent } from "@donalabs/ui/components/card"

export function MotionFadeDemo() {
  const [key, setKey] = useState(0)

  return (
    <div className="space-y-3">
      <motion.div
        key={key}
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, ease: "easeOut" }}
      >
        <Card>
          <CardContent className="py-6 text-sm text-muted-foreground">
            Fades and slides up 12px on mount — transform + opacity only, so it
            stays compositor-driven and cheap even on low-end devices.
          </CardContent>
        </Card>
      </motion.div>
      <Button variant="outline" size="sm" onClick={() => setKey((k) => k + 1)}>
        <RotateCcwIcon /> Replay
      </Button>
    </div>
  )
}
