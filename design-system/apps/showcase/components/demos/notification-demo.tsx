"use client"

import { toast } from "sonner"
import { AlertCircleIcon, InfoIcon, TerminalIcon } from "lucide-react"

import { Button } from "@donalabs/ui/components/button"
import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "@donalabs/ui/components/alert"
import { Skeleton } from "@donalabs/ui/components/skeleton"

export function NotificationDemo() {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-3">
        <Button variant="outline" onClick={() => toast("Backup completed")}>
          Default toast
        </Button>
        <Button
          variant="outline"
          onClick={() =>
            toast.success("Service healthy", { description: "vaultwarden · 200 OK" })
          }
        >
          Success toast
        </Button>
        <Button
          variant="outline"
          onClick={() =>
            toast.error("Health check failed", { description: "n8n · connection refused" })
          }
        >
          Error toast
        </Button>
        <Button
          variant="outline"
          onClick={() =>
            toast.promise(new Promise((resolve) => setTimeout(resolve, 1500)), {
              loading: "Running backup...",
              success: "Backup complete",
              error: "Backup failed",
            })
          }
        >
          Promise toast
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <Alert>
          <InfoIcon />
          <AlertTitle>Heads up</AlertTitle>
          <AlertDescription>
            This is an inline, non-dismissible informational alert.
          </AlertDescription>
        </Alert>
        <Alert variant="destructive">
          <AlertCircleIcon />
          <AlertTitle>Something went wrong</AlertTitle>
          <AlertDescription>
            The destructive variant for errors that need attention in-place.
          </AlertDescription>
        </Alert>
      </div>

      <div>
        <p className="mb-2 flex items-center gap-1.5 text-sm font-medium text-muted-foreground">
          <TerminalIcon className="size-4" /> Skeleton (loading state)
        </p>
        <div className="flex items-center gap-3">
          <Skeleton className="size-10 rounded-full" />
          <div className="space-y-2">
            <Skeleton className="h-3 w-40" />
            <Skeleton className="h-3 w-24" />
          </div>
        </div>
      </div>
    </div>
  )
}
