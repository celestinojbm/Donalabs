"use client"

import { Loader2Icon, MailIcon, SendIcon } from "lucide-react"

import { Button } from "@donalabs/ui/components/button"

const VARIANTS = ["default", "secondary", "outline", "ghost", "destructive", "link"] as const

export function ButtonDemo() {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-3">
        {VARIANTS.map((variant) => (
          <Button key={variant} variant={variant}>
            {variant}
          </Button>
        ))}
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button size="xs">Extra small</Button>
        <Button size="sm">Small</Button>
        <Button size="default">Default</Button>
        <Button size="lg">Large</Button>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button>
          <MailIcon /> Send email
        </Button>
        <Button variant="secondary">
          Continue <SendIcon />
        </Button>
        <Button disabled>
          <Loader2Icon className="animate-spin" /> Loading
        </Button>
        <Button size="icon" variant="outline" aria-label="Send">
          <SendIcon />
        </Button>
      </div>
    </div>
  )
}
