"use client"

import dynamic from "next/dynamic"
import { useCallback, useState } from "react"

const BenchLive = dynamic(() => import("./live").then((mod) => mod.BenchLive), {
  ssr: false,
})

export function BenchStage() {
  const [ready, setReady] = useState(false)
  const markReady = useCallback(() => setReady(true), [])

  return (
    <div className="bench-live" data-ready={ready ? "" : undefined}>
      <BenchLive onReady={markReady} />
    </div>
  )
}
