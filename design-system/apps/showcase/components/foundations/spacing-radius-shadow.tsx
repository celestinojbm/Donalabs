const SPACING_STEPS = [1, 2, 3, 4, 6, 8, 12, 16, 24]
const RADIUS_STEPS = [
  { className: "rounded-sm", label: "rounded-sm" },
  { className: "rounded-md", label: "rounded-md" },
  { className: "rounded-lg", label: "rounded-lg (base --radius)" },
  { className: "rounded-xl", label: "rounded-xl" },
  { className: "rounded-2xl", label: "rounded-2xl" },
  { className: "rounded-3xl", label: "rounded-3xl" },
]
const SHADOW_STEPS = [
  { className: "shadow-xs", label: "shadow-xs" },
  { className: "shadow-sm", label: "shadow-sm" },
  { className: "shadow-md", label: "shadow-md · floating surfaces" },
  { className: "shadow-lg", label: "shadow-lg · nested menus" },
  { className: "shadow-xl", label: "shadow-xl" },
]

export function SpacingScale() {
  return (
    <div className="space-y-2">
      {SPACING_STEPS.map((step) => (
        <div key={step} className="flex items-center gap-3">
          <span className="w-16 shrink-0 font-mono text-xs text-muted-foreground">
            spacing-{step}
          </span>
          <div className="h-4 rounded bg-primary" style={{ width: `calc(var(--spacing) * ${step})` }} />
        </div>
      ))}
    </div>
  )
}

export function RadiusScale() {
  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
      {RADIUS_STEPS.map((step) => (
        <div key={step.className} className="space-y-2">
          <div className={`h-16 border-2 border-primary/40 bg-primary/10 ${step.className}`} />
          <span className="font-mono text-xs text-muted-foreground">
            {step.label}
          </span>
        </div>
      ))}
    </div>
  )
}

export function ShadowScale() {
  return (
    <div className="grid grid-cols-2 gap-6 sm:grid-cols-3">
      {SHADOW_STEPS.map((step) => (
        <div key={step.className} className="space-y-2">
          <div className={`h-16 rounded-lg border bg-card ${step.className}`} />
          <span className="font-mono text-xs text-muted-foreground">
            {step.label}
          </span>
        </div>
      ))}
    </div>
  )
}
