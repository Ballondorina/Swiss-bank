// ============================================================
// UNDERWORLD — Territory Tab (Influence Zones)
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { ProgressBar } from '../ui/ProgressBar'
import { formatMoney } from '../../lib/utils'

export function Territory() {
  const data = useOrgStore(s => s.data)
  if (!data) return null

  const { influence, org } = data
  const levelUnlocked = org.level >= 4

  if (!levelUnlocked) {
    return (
      <div className="flex flex-col items-center justify-center py-16 gap-3">
        <div className="text-4xl opacity-30">⊕</div>
        <span className="text-zinc-400 font-medium">Territory System Locked</span>
        <span className="text-zinc-600 text-sm text-center max-w-xs">
          Reach Level 4 to unlock influence zones and begin building territory across the city.
        </span>
        <div className="mt-2 text-xs text-accent/70 bg-accent/10 border border-accent/20 rounded-lg px-4 py-2">
          Current level: {org.level} / Required: 4
        </div>
      </div>
    )
  }

  const ownedZones = influence.filter(z => z.is_owner && !z.is_contested)
  const contestedZones = influence.filter(z => z.is_contested)
  const totalBonus = ownedZones.reduce((sum, z) => sum + z.passive_bonus, 0)

  return (
    <div className="flex flex-col gap-4">
      {/* Summary row */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3 text-center">
          <div className="text-lg font-bold text-white">{ownedZones.length}</div>
          <div className="text-xs text-zinc-500 mt-0.5">Zones Controlled</div>
        </div>
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3 text-center">
          <div className="text-lg font-bold text-amber-400">{contestedZones.length}</div>
          <div className="text-xs text-zinc-500 mt-0.5">Contested</div>
        </div>
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3 text-center">
          <div className="text-lg font-bold text-green-400">+{formatMoney(totalBonus)}</div>
          <div className="text-xs text-zinc-500 mt-0.5">Zone Bonus/hr</div>
        </div>
      </div>

      {/* Zone list */}
      <div className="flex flex-col gap-2">
        {influence.map(zone => {
          let statusLabel = ''
          let statusClass = ''
          if (zone.is_owner && !zone.is_contested) {
            statusLabel = 'Controlled'
            statusClass = 'text-green-400 bg-green-500/10 border-green-500/30'
          } else if (zone.is_contested) {
            statusLabel = 'Contested'
            statusClass = 'text-amber-400 bg-amber-500/10 border-amber-500/30'
          }

          const barColor = zone.is_owner
            ? zone.is_contested ? '#f59e0b' : '#4caf50'
            : '#7c6af7'

          return (
            <div
              key={zone.zone_id}
              className={`bg-surface-2 border rounded-xl p-4 flex flex-col gap-2 ${
                zone.is_owner ? 'border-green-500/20' : 'border-white/5'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-white">{zone.label}</span>
                  {statusLabel && (
                    <span className={`text-xs px-2 py-0.5 rounded border font-medium ${statusClass}`}>
                      {statusLabel}
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-3">
                  {zone.is_owner && !zone.is_contested && zone.passive_bonus > 0 && (
                    <span className="text-xs text-green-400 font-mono">
                      +{formatMoney(zone.passive_bonus)}/hr
                    </span>
                  )}
                  <span className="text-sm font-mono text-zinc-300">{zone.my_score}/100</span>
                </div>
              </div>
              <ProgressBar value={zone.my_score} color={barColor} height="h-1.5" glow={zone.is_owner} />
              {zone.is_owner && !zone.is_contested && (
                <span className="text-xs text-zinc-500">
                  +5% mission rewards in this zone · +${zone.passive_bonus.toLocaleString()}/hr passive bonus
                </span>
              )}
              {zone.is_contested && (
                <span className="text-xs text-amber-500/80">
                  Zone is contested — no bonuses until you pull ahead by 10+ points.
                </span>
              )}
            </div>
          )
        })}
      </div>

      <div className="text-xs text-zinc-600 text-center mt-2">
        Gain influence by completing missions in zones and staying present in the area. Influence decays by 2pts/hr.
      </div>
    </div>
  )
}
