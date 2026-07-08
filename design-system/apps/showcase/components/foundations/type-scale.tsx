const STEPS = [
  { className: "text-xs", label: "text-xs · 0.75rem" },
  { className: "text-sm", label: "text-sm · 0.875rem" },
  { className: "text-base", label: "text-base · 1rem" },
  { className: "text-lg", label: "text-lg · 1.125rem" },
  { className: "text-xl", label: "text-xl · 1.25rem" },
  { className: "text-2xl", label: "text-2xl · 1.5rem" },
  { className: "text-3xl", label: "text-3xl · 1.875rem" },
  { className: "text-4xl", label: "text-4xl · 2.25rem" },
] as const

export function TypeScale() {
  return (
    <div className="space-y-4">
      {STEPS.map((step) => (
        <div
          key={step.className}
          className="flex flex-wrap items-baseline justify-between gap-2 border-b pb-3 last:border-0"
        >
          <span className={step.className}>DonaLabs Design System</span>
          <span className="font-mono text-xs text-muted-foreground">
            {step.label}
          </span>
        </div>
      ))}
      <div className="grid gap-3 pt-2 sm:grid-cols-3">
        <div className="rounded-lg border p-4">
          <p className="font-sans text-sm font-medium">font-sans</p>
          <p className="font-sans text-2xl">Geist</p>
        </div>
        <div className="rounded-lg border p-4">
          <p className="font-mono text-sm font-medium">font-mono</p>
          <p className="font-mono text-2xl">Geist Mono</p>
        </div>
        <div className="rounded-lg border p-4">
          <p className="text-sm font-medium">Weights</p>
          <p className="text-base">
            <span className="font-normal">Normal </span>
            <span className="font-medium">Medium </span>
            <span className="font-semibold">Semibold</span>
          </p>
        </div>
      </div>
    </div>
  )
}
