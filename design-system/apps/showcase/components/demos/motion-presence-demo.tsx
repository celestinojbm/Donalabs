"use client"

import { useState } from "react"
import { AnimatePresence, motion } from "motion/react"
import { PlusIcon, XIcon } from "lucide-react"

import { Button } from "@donalabs/ui/components/button"

let nextId = 4

export function MotionPresenceDemo() {
  const [items, setItems] = useState([
    { id: 1, label: "Vaultwarden" },
    { id: 2, label: "Cal.com" },
    { id: 3, label: "Plausible" },
  ])

  return (
    <div className="space-y-3">
      <ul className="flex flex-col gap-2">
        <AnimatePresence initial={false}>
          {items.map((item) => (
            <motion.li
              key={item.id}
              layout
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.2 }}
              className="flex items-center justify-between overflow-hidden rounded-md border bg-card px-3 py-2 text-sm"
            >
              {item.label}
              <button
                aria-label={`Remove ${item.label}`}
                onClick={() =>
                  setItems((prev) => prev.filter((i) => i.id !== item.id))
                }
                className="text-muted-foreground hover:text-destructive"
              >
                <XIcon className="size-3.5" />
              </button>
            </motion.li>
          ))}
        </AnimatePresence>
      </ul>
      <Button
        variant="outline"
        size="sm"
        onClick={() =>
          setItems((prev) => [...prev, { id: nextId++, label: `Service ${nextId}` }])
        }
      >
        <PlusIcon /> Add item
      </Button>
    </div>
  )
}
