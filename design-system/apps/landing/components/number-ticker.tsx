"use client"

import { useEffect, useRef } from "react"

type NumberTickerProps = {
  value: number
  suffix?: string
}

export function NumberTicker({ value, suffix = "" }: NumberTickerProps) {
  const ref = useRef<HTMLSpanElement>(null)

  useEffect(() => {
    const node = ref.current
    if (!node) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (value === 0) return

    const reducedRect = node.getBoundingClientRect()
    const alreadyVisible =
      reducedRect.top < window.innerHeight && reducedRect.bottom > 0
    if (alreadyVisible) return

    let frame = 0
    const duration = 480
    const paint = (next: number) => {
      node.textContent = `${next}${suffix}`
    }

    const start = () => {
      const t0 = performance.now()
      const step = (now: number) => {
        const progress = Math.min(1, (now - t0) / duration)
        const eased = 1 - (1 - progress) ** 3
        paint(Math.round(eased * value))
        if (progress < 1) frame = requestAnimationFrame(step)
      }
      paint(0)
      frame = requestAnimationFrame(step)
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries[0]?.isIntersecting) return
        observer.disconnect()
        start()
      },
      { threshold: 0.5 }
    )
    observer.observe(node)
    return () => {
      observer.disconnect()
      cancelAnimationFrame(frame)
    }
  }, [suffix, value])

  return (
    <span ref={ref} aria-hidden="true">
      {value}
      {suffix}
    </span>
  )
}

type IndexTickerProps = {
  value: number
  delay: number
}

export function IndexTicker({ value, delay }: IndexTickerProps) {
  const ref = useRef<HTMLSpanElement>(null)
  const padded = String(value).padStart(2, "0")

  useEffect(() => {
    const node = ref.current
    if (!node) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    let current = 0
    let interval = 0
    const timeout = window.setTimeout(() => {
      node.textContent = "00"
      interval = window.setInterval(() => {
        current += 1
        node.textContent = String(current).padStart(2, "0")
        if (current >= value) window.clearInterval(interval)
      }, 40)
    }, delay)

    return () => {
      window.clearTimeout(timeout)
      window.clearInterval(interval)
    }
  }, [delay, value])

  return (
    <span ref={ref} aria-hidden="true">
      {padded}
    </span>
  )
}
