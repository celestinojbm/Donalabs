const SEMANTIC_COLORS = [
  { name: "background", fg: "foreground" },
  { name: "card", fg: "card-foreground" },
  { name: "popover", fg: "popover-foreground" },
  { name: "primary", fg: "primary-foreground" },
  { name: "secondary", fg: "secondary-foreground" },
  { name: "muted", fg: "muted-foreground" },
  { name: "accent", fg: "accent-foreground" },
  { name: "destructive", fg: "white" },
] as const

const CHART_COLORS = ["chart-1", "chart-2", "chart-3", "chart-4", "chart-5"]

export function ColorSwatches() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {SEMANTIC_COLORS.map((c) => (
          <div
            key={c.name}
            className="flex h-20 flex-col justify-between rounded-lg border p-3"
            style={{
              backgroundColor: `var(--${c.name})`,
              color: c.fg === "white" ? "#fff" : `var(--${c.fg})`,
            }}
          >
            <span className="font-mono text-xs">--{c.name}</span>
          </div>
        ))}
      </div>
      <div>
        <p className="mb-2 text-sm font-medium text-muted-foreground">
          Chart palette
        </p>
        <div className="flex gap-3">
          {CHART_COLORS.map((c) => (
            <div key={c} className="flex-1 space-y-1.5">
              <div
                className="h-12 rounded-md border"
                style={{ backgroundColor: `var(--${c})` }}
              />
              <span className="block text-center font-mono text-xs text-muted-foreground">
                --{c}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
