// ============================================================
// UNDERWORLD — Ledger Tab
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { formatMoney, formatDateTime } from '../../lib/utils'
import type { LedgerEntry } from '../../types/org'

const TYPE_LABELS: Record<string, string> = {
  deposit:           'Deposit',
  withdrawal:        'Withdrawal',
  mission_reward:    'Mission Reward',
  passive_income:    'Passive Income',
  salary:            'Salary',
  zone_bonus:        'Zone Bonus',
  leaderboard_reward:'Leaderboard Prize',
  org_creation:      'Founding Fee',
}

const TYPE_COLORS: Record<string, string> = {
  deposit:           '#4caf50',
  mission_reward:    '#4caf50',
  passive_income:    '#4caf50',
  zone_bonus:        '#4caf50',
  leaderboard_reward:'#f7c948',
  withdrawal:        '#f44336',
  salary:            '#f44336',
  org_creation:      '#f44336',
}

export function Ledger() {
  const data = useOrgStore(s => s.data)
  if (!data) return null

  const { ledger } = data

  if (!ledger.length) {
    return (
      <div className="text-center py-12 text-zinc-500 text-sm">
        No transactions yet.
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-1.5">
      {ledger.map((entry: LedgerEntry) => {
        const isPositive = entry.amount > 0
        const color = isPositive
          ? (TYPE_COLORS[entry.type] ?? '#4caf50')
          : '#f44336'
        const label = TYPE_LABELS[entry.type] ?? entry.type.replace(/_/g, ' ')

        return (
          <div
            key={entry.id}
            className="flex items-center gap-3 bg-surface-2 border border-white/4 rounded-lg px-4 py-2.5"
          >
            {/* Color dot */}
            <div
              className="w-1.5 h-1.5 rounded-full flex-shrink-0"
              style={{ backgroundColor: color }}
            />

            {/* Label + description */}
            <div className="flex-1 min-w-0">
              <div className="text-sm text-zinc-200">{label}</div>
              {entry.description && (
                <div className="text-xs text-zinc-600 truncate">{entry.description}</div>
              )}
            </div>

            {/* Amount */}
            <div className="text-sm font-mono font-bold flex-shrink-0" style={{ color }}>
              {isPositive ? '+' : ''}{formatMoney(entry.amount)}
            </div>

            {/* Date */}
            <div className="text-xs text-zinc-600 flex-shrink-0 w-32 text-right">
              {formatDateTime(entry.created_at)}
            </div>
          </div>
        )
      })}
    </div>
  )
}
