// ============================================================
// UNDERWORLD — Progress Bar Component
// ============================================================

interface ProgressBarProps {
  value: number       // 0–100
  color?: string
  height?: string
  glow?: boolean
  animated?: boolean
  className?: string
}

export function ProgressBar({
  value,
  color = '#7c6af7',
  height = 'h-1.5',
  glow = false,
  animated = false,
  className = '',
}: ProgressBarProps) {
  const pct = Math.max(0, Math.min(100, value))

  return (
    <div className={`w-full bg-surface-3 rounded-full overflow-hidden ${height} ${className}`}>
      <div
        className={`h-full rounded-full transition-all duration-500 ${animated ? 'animate-pulse-slow' : ''}`}
        style={{
          width: `${pct}%`,
          backgroundColor: color,
          boxShadow: glow ? `0 0 8px ${color}88` : undefined,
        }}
      />
    </div>
  )
}
