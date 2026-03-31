// ============================================================
// UNDERWORLD — Leaderboard Tab
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { OrgTypeBadge } from '../ui/Badge'
import { formatMoney } from '../../lib/utils'
import type { LeaderboardEntry, OrgType } from '../../types/org'

const MEDALS = ['🥇', '🥈', '🥉', '4.', '5.']

function RankTable({
  title,
  entries,
  valueLabel,
  formatValue,
}: {
  title: string
  entries: LeaderboardEntry[]
  valueLabel: string
  formatValue: (v: number) => string
}) {
  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
      <h3 className="text-sm font-semibold text-zinc-300 uppercase tracking-wider">{title}</h3>
      {entries.length === 0 ? (
        <span className="text-sm text-zinc-600 italic">No data yet.</span>
      ) : (
        <div className="flex flex-col gap-1.5">
          {entries.map((entry, i) => (
            <div key={entry.org_id} className="flex items-center gap-3">
              <span className="text-sm w-6 flex-shrink-0">{MEDALS[i] ?? `${i + 1}.`}</span>
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <span className="text-sm text-white truncate">{entry.label}</span>
                <OrgTypeBadge type={entry.type as OrgType} />
              </div>
              <span className="text-sm font-mono text-zinc-300 flex-shrink-0">{formatValue(entry.value)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export function Leaderboard() {
  const data = useOrgStore(s => s.data)
  if (!data?.leaderboard) return null

  const { leaderboard } = data

  return (
    <div className="flex flex-col gap-4">
      <div className="text-xs text-zinc-500 text-center">
        Rankings reset every Monday. Top 3 orgs receive vault bonuses.
      </div>

      <div className="grid grid-cols-1 gap-3">
        <RankTable
          title="💰 Weekly Earnings"
          entries={leaderboard.earnings}
          valueLabel="Earned"
          formatValue={formatMoney}
        />
        <RankTable
          title="⚡ Mission Completions"
          entries={leaderboard.missions}
          valueLabel="Missions"
          formatValue={v => `${v} missions`}
        />
        <RankTable
          title="⊕ Territory Score"
          entries={leaderboard.territory}
          valueLabel="Score"
          formatValue={v => `${v} pts`}
        />
      </div>
    </div>
  )
}
