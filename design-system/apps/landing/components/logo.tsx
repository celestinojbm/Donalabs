type LogoMarkProps = {
  className?: string
}

export function LogoMark({ className }: LogoMarkProps) {
  return (
    <svg
      viewBox="4 0 92 102"
      className={className}
      aria-hidden="true"
      focusable="false"
    >
      <polygon
        points="88.1,28.0 88.1,72.0 50.0,94.0 11.9,72.0 11.9,28.0 50.0,6.0"
        fill="none"
        stroke="#0A0A0A"
        strokeWidth="8"
        strokeLinejoin="miter"
      />
      <polygon
        points="67.3,40.0 67.3,60.0 50.0,70.0 32.7,60.0 32.7,40.0 50.0,30.0"
        fill="#FF4F00"
      />
    </svg>
  )
}
