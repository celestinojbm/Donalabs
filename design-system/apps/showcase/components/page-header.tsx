export function PageHeader({
  title,
  description,
}: {
  title: string
  description?: string
}) {
  return (
    <div className="space-y-3 border-b pb-8">
      <h1 className="max-w-[22ch] text-3xl font-semibold tracking-tight text-balance">
        {title}
      </h1>
      {description ? (
        <p className="max-w-3xl text-base leading-relaxed text-muted-foreground">
          {description}
        </p>
      ) : null}
    </div>
  )
}

export function Section({
  title,
  description,
  children,
}: {
  title: string
  description?: string
  children: React.ReactNode
}) {
  return (
    <section className="space-y-5">
      <div className="space-y-2">
        <h2 className="text-xl font-medium text-balance">{title}</h2>
        {description ? (
          <p className="max-w-3xl text-base leading-relaxed text-muted-foreground">
            {description}
          </p>
        ) : null}
      </div>
      {children}
    </section>
  )
}
