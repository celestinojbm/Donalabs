import type { LucideIcon } from "lucide-react"
import { TrendingDownIcon, TrendingUpIcon } from "lucide-react"

import { cn } from "@donalabs/ui/lib/utils"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@donalabs/ui/components/card"
import { Badge } from "@donalabs/ui/components/badge"
import { NumberTicker } from "@donalabs/ui/components/number-ticker"

export interface StatCardProps {
  label: string
  value: number
  /** Prefix rendered before the animated number, e.g. "$". */
  prefix?: string
  /** Suffix rendered after the animated number, e.g. "%". */
  suffix?: string
  /** Signed percentage change vs. the previous period. Positive renders as an "up" trend. */
  change?: number
  description?: string
  icon?: LucideIcon
  className?: string
}

/**
 * A KPI tile for dashboard summaries. Composes Card + NumberTicker (Magic UI)
 * + a trend Badge — the pattern most stat rows in a dashboard reduce to.
 */
export function StatCard({
  label,
  value,
  prefix,
  suffix,
  change,
  description,
  icon: Icon,
  className,
}: StatCardProps) {
  const isPositive = (change ?? 0) >= 0

  return (
    <Card className={cn("@container/card", className)}>
      <CardHeader>
        <CardDescription className="flex items-center gap-1.5">
          {Icon ? <Icon className="size-4" /> : null}
          {label}
        </CardDescription>
        <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
          {prefix}
          <NumberTicker value={value} />
          {suffix}
        </CardTitle>
        {change !== undefined ? (
          <CardAction>
            <Badge variant="outline" className="gap-1">
              {isPositive ? <TrendingUpIcon className="size-3" /> : <TrendingDownIcon className="size-3" />}
              {isPositive ? "+" : ""}
              {change}%
            </Badge>
          </CardAction>
        ) : null}
      </CardHeader>
      {description ? (
        <CardFooter className="text-sm text-muted-foreground">
          {description}
        </CardFooter>
      ) : null}
    </Card>
  )
}
