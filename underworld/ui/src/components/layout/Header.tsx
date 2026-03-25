// ============================================================
// UNDERWORLD — Panel Header (v3)
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { OrgTypeBadge, HeatBadge } from '../ui/Badge'
import { formatMoney } from '../../lib/utils'
import { TIER_NAMES } from '../../types/org'
import { nuiPost } from '../../lib/utils'

export function Header() {
  const data = useOrgStore(s => s.data)
  const setIsOpen = useOrgStore(s => s.setIsOpen)

  if (!data) return null
  const { org, diplomacy } = data

  const handleClose = () => {
    nuiPost('closePanel')
    setIsOpen(false)
  }

  const tierLabel = TIER_NAMES[org.tier] ?? `Tier ${org.tier}`
  const activeWars = diplomacy?.wars?.filter(w => w.status === 'active')?.length ?? 0

  return (
    <div className="flex items-start justify-between px-6 pt-5 pb-4 border-b border-white/5">
      <div className="flex flex-col gap-2">
        {/* Org name + type */}
        <div className="flex items-center gap-3">
          <h1 className="text-xl font-bold text-white tracking-tight">{org.label}</h1>
          <OrgTypeBadge type={org.type} />
          {org.level >= 10 && (
            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-bold bg-yellow-500/20 text-yellow-300 border border-yellow-400/40">
              EMPIRE
            </span>
          )}
          {activeWars > 0 && (
            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-bold bg-red-500/20 text-red-400 border border-red-500/40 animate-pulse-slow">
              AT WAR
            </span>
          )}
        </div>

        {/* Tier + level */}
        <div className="flex items-center gap-3 text-sm text-zinc-400">
          <span>{tierLabel} Tier</span>
          <span className="text-zinc-700">|</span>
          <span>Level {org.level}</span>
          <span className="text-zinc-700">|</span>
          <HeatBadge label={org.heatLabel} />
        </div>
      </div>

      {/* Right: Vault + Close */}
      <div className="flex items-center gap-4">
        <div className="text-right">
          <div className="text-xs text-zinc-500 uppercase tracking-wider">Vault</div>
          <div className="text-lg font-bold font-mono text-green-400">{formatMoney(org.vault)}</div>
        </div>
        <button
          onClick={handleClose}
          className="w-8 h-8 flex items-center justify-center rounded-lg bg-surface-3 hover:bg-red-500/20 hover:text-red-400 text-zinc-400 transition-all duration-150 text-lg leading-none"
        >
          x
        </button>
      </div>
    </div>
  )
}
