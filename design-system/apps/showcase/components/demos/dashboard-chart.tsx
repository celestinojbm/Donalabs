"use client"

import { Area, AreaChart, CartesianGrid, XAxis } from "recharts"

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@donalabs/ui/components/chart"

const data = [
  { day: "Mon", requests: 420, errors: 12 },
  { day: "Tue", requests: 532, errors: 8 },
  { day: "Wed", requests: 601, errors: 14 },
  { day: "Thu", requests: 574, errors: 6 },
  { day: "Fri", requests: 689, errors: 20 },
  { day: "Sat", requests: 312, errors: 4 },
  { day: "Sun", requests: 275, errors: 3 },
]

const chartConfig = {
  requests: { label: "Requests", color: "var(--chart-1)" },
  errors: { label: "Errors", color: "var(--chart-4)" },
} satisfies ChartConfig

export function DashboardChart() {
  return (
    <ChartContainer config={chartConfig} className="aspect-auto h-64 w-full">
      <AreaChart data={data}>
        <defs>
          <linearGradient id="fillRequests" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--color-requests)" stopOpacity={0.4} />
            <stop offset="95%" stopColor="var(--color-requests)" stopOpacity={0.05} />
          </linearGradient>
        </defs>
        <CartesianGrid vertical={false} />
        <XAxis
          dataKey="day"
          tickLine={false}
          axisLine={false}
          tickMargin={8}
        />
        <ChartTooltip content={<ChartTooltipContent indicator="dot" />} />
        <Area
          dataKey="requests"
          type="monotone"
          fill="url(#fillRequests)"
          stroke="var(--color-requests)"
        />
        <Area
          dataKey="errors"
          type="monotone"
          fill="transparent"
          stroke="var(--color-errors)"
          strokeDasharray="4 4"
        />
      </AreaChart>
    </ChartContainer>
  )
}
