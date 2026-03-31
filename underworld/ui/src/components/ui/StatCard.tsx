// ============================================================
// UNDERWORLD — Stat Card Component
// ============================================================

interface StatCardProps {
  label: string
  value: string | number
  sub?: string
  color?: string
  icon?: string   // emoji or short text icon
}

export function StatCard({ label, value, sub, color, icon }: StatCardProps) {
  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-1">
      {icon && (
        <span className="text-lg mb-1">{icon}</span>
      )}
      <span className="text-xs text-zinc-500 uppercase tracking-wider font-medium">{label}</span>
      <span
        className="text-xl font-bold font-mono"
        style={color ? { color } : undefined}
      >
        {value}
      </span>
      {sub && <span className="text-xs text-zinc-500">{sub}</span>}
    </div>
  )
}
