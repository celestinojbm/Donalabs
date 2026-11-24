const STEPS = [
  { className: "text-xs", label: "text-xs · 16px mobile, 18px desktop" },
  { className: "text-sm", label: "text-sm · 18px mobile, 20px desktop" },
  { className: "text-base", label: "text-base · 18px mobile, 22px desktop" },
  { className: "text-lg", label: "text-lg · 22px mobile, 26px desktop" },
  { className: "text-xl", label: "text-xl · 26px mobile, 32px desktop" },
  { className: "text-2xl", label: "text-2xl · 32px mobile, 40px desktop" },
  { className: "text-3xl", label: "text-3xl · 40px mobile, 52px desktop" },
  { className: "text-4xl", label: "text-4xl · 44px mobile, 60px desktop" },
  { className: "text-hero", label: "text-hero · clamp 44px to 96px" },
] as const

export function TypeScale() {
  return (
    <div className="min-w-0 space-y-5">
      {STEPS.map((step) => (
        <div
          key={step.className}
          className="flex min-w-0 flex-wrap items-baseline justify-between gap-x-4 gap-y-2 border-b pb-4 last:border-0"
        >
          <span className={`min-w-0 text-balance ${step.className}`}>
            DonaLabs Design System
          </span>
          <span className="font-mono text-xs text-muted-foreground">
            {step.label}
          </span>
        </div>
      ))}
      <div className="grid gap-4 pt-2 sm:grid-cols-3">
        <div className="rounded-lg border p-5">
          <p className="font-sans text-sm font-medium">font-sans</p>
          <p className="font-sans text-2xl">Geist</p>
        </div>
        <div className="rounded-lg border p-5">
          <p className="font-mono text-sm font-medium">font-mono</p>
          <p className="font-mono text-2xl">Geist Mono</p>
        </div>
        <div className="rounded-lg border p-5">
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
