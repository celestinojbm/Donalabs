import { buttonVariants } from "@donalabs/ui/components/button"
import { cn } from "@donalabs/ui/lib/utils"

import { BenchScene } from "./art"
import { BAYS, bayAt, readoutOf } from "./model"
import { BenchPlate } from "./plate"

export function BenchPoster() {
  return (
    <div className="flex flex-col gap-4">
      <BenchPlate>
        <BenchScene />
      </BenchPlate>
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap gap-2" aria-hidden="true">
          {BAYS.map((bay, index) => (
            <span
              key={bay.id}
              className={cn(
                buttonVariants({
                  variant: index === 0 ? "default" : "outline",
                  size: "sm",
                })
              )}
            >
              {bay.name}
            </span>
          ))}
        </div>
        <p className="text-sm text-muted-foreground">{readoutOf(bayAt(0).name)}</p>
      </div>
    </div>
  )
}
