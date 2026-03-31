// ============================================================
// UNDERWORLD — Members Tab (v3 — with search + transfer)
// ============================================================

import { useState, useMemo } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { RankBadge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { formatMoney } from '../../lib/utils'
import { RANK_NAMES } from '../../types/org'
import { nuiPost } from '../../lib/utils'

export function Members() {
  const data = useOrgStore(s => s.data)
  const [rankTarget, setRankTarget] = useState<string | null>(null)
  const [salaryTarget, setSalaryTarget] = useState<string | null>(null)
  const [rankValue, setRankValue] = useState(1)
  const [salaryValue, setSalaryValue] = useState(0)
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState<'rank' | 'contribution' | 'name'>('rank')

  if (!data) return null
  const { members, myRank, myCitizenId } = data

  const canManage = myRank >= 4
  const isDirektor = myRank === 5

  const handleKick = (citizenId: string) => {
    nuiPost('kickMember', { citizenId })
  }

  const handleSetRank = (citizenId: string) => {
    nuiPost('setRank', { citizenId, rank: rankValue })
    setRankTarget(null)
  }

  const handleSetSalary = (citizenId: string) => {
    nuiPost('setSalary', { citizenId, salary: salaryValue })
    setSalaryTarget(null)
  }

  const handleTransfer = (citizenId: string) => {
    nuiPost('transferLeadership', { citizenId })
  }

  const filtered = useMemo(() => {
    let list = [...members]

    // Search filter
    if (search.trim()) {
      const q = search.toLowerCase()
      list = list.filter(m =>
        m.name.toLowerCase().includes(q) ||
        (RANK_NAMES[m.rank] ?? '').toLowerCase().includes(q) ||
        (m.division ?? '').toLowerCase().includes(q)
      )
    }

    // Sort
    if (sortBy === 'contribution') {
      list.sort((a, b) => b.weekly_contribution - a.weekly_contribution)
    } else if (sortBy === 'name') {
      list.sort((a, b) => a.name.localeCompare(b.name))
    } else {
      list.sort((a, b) => b.rank - a.rank)
    }

    return list
  }, [members, search, sortBy])

  return (
    <div className="flex flex-col gap-3">
      {/* Search + sort bar */}
      <div className="flex items-center gap-3 mb-1">
        <div className="flex-1 relative">
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search members..."
            className="w-full bg-surface-3 border border-white/8 rounded-lg px-3 py-2 text-sm text-white placeholder-zinc-600 outline-none focus:border-accent/60"
          />
          {search && (
            <button
              onClick={() => setSearch('')}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 text-xs"
            >
              x
            </button>
          )}
        </div>
        <div className="flex gap-1">
          {(['rank', 'contribution', 'name'] as const).map(s => (
            <button
              key={s}
              onClick={() => setSortBy(s)}
              className={`px-2.5 py-1.5 text-xs rounded-lg border transition-all ${
                sortBy === s
                  ? 'border-accent/40 text-accent bg-accent/10'
                  : 'border-white/8 text-zinc-500 hover:text-zinc-300'
              }`}
            >
              {s === 'contribution' ? 'Earned' : s.charAt(0).toUpperCase() + s.slice(1)}
            </button>
          ))}
        </div>
        <span className="text-sm text-zinc-500">{filtered.length}/{members.length}</span>
      </div>

      {filtered.map(member => {
        const isMe = member.citizen_id === myCitizenId
        const rankName = RANK_NAMES[member.rank] ?? `Rank ${member.rank}`
        const canAct = canManage && !isMe && member.rank < myRank

        return (
          <div
            key={member.citizen_id}
            className={`bg-surface-2 border rounded-xl p-4 flex flex-col gap-3 transition-all ${isMe ? 'border-accent/30' : 'border-white/5'}`}
          >
            {/* Top row */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-surface-4 flex items-center justify-center text-sm font-bold text-zinc-400">
                  {member.name.charAt(0).toUpperCase()}
                </div>
                <div className="flex flex-col">
                  <span className="text-sm font-medium text-white">
                    {member.name} {isMe && <span className="text-accent text-xs">(You)</span>}
                  </span>
                  {member.division && (
                    <span className="text-xs text-zinc-500">{member.division}</span>
                  )}
                </div>
              </div>
              <RankBadge rank={member.rank} name={rankName} />
            </div>

            {/* Stats row */}
            <div className="grid grid-cols-4 gap-2 text-xs text-zinc-500">
              <div>
                <div className="text-zinc-400 font-medium">{formatMoney(member.weekly_contribution)}</div>
                <div>This week</div>
              </div>
              <div>
                <div className="text-zinc-400 font-medium">{formatMoney(member.total_contribution)}</div>
                <div>All time</div>
              </div>
              <div>
                <div className="text-zinc-400 font-medium">{member.loyalty}%</div>
                <div>Loyalty</div>
              </div>
              <div>
                <div className="text-zinc-400 font-medium">{member.salary > 0 ? formatMoney(member.salary) : '—'}</div>
                <div>Salary/wk</div>
              </div>
            </div>

            {/* Action row */}
            {canAct && (
              <div className="flex gap-2 border-t border-white/5 pt-3 flex-wrap">
                {/* Rank manager */}
                {isDirektor && (
                  rankTarget === member.citizen_id ? (
                    <div className="flex items-center gap-2">
                      <select
                        value={rankValue}
                        onChange={e => setRankValue(Number(e.target.value))}
                        className="bg-surface-3 border border-white/10 rounded px-2 py-1 text-xs text-white"
                      >
                        {[1, 2, 3, 4].map(r => (
                          <option key={r} value={r}>{RANK_NAMES[r]}</option>
                        ))}
                      </select>
                      <Button size="sm" variant="primary" onClick={() => handleSetRank(member.citizen_id)}>
                        Set
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => setRankTarget(null)}>
                        Cancel
                      </Button>
                    </div>
                  ) : (
                    <Button size="sm" variant="outline" onClick={() => { setRankTarget(member.citizen_id); setRankValue(member.rank) }}>
                      Set Rank
                    </Button>
                  )
                )}

                {/* Salary manager */}
                {isDirektor && (
                  salaryTarget === member.citizen_id ? (
                    <div className="flex items-center gap-2">
                      <input
                        type="number"
                        min={0}
                        value={salaryValue}
                        onChange={e => setSalaryValue(Number(e.target.value))}
                        className="w-28 bg-surface-3 border border-white/10 rounded px-2 py-1 text-xs text-white"
                        placeholder="Amount"
                      />
                      <Button size="sm" variant="primary" onClick={() => handleSetSalary(member.citizen_id)}>
                        Set
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => setSalaryTarget(null)}>
                        Cancel
                      </Button>
                    </div>
                  ) : (
                    <Button size="sm" variant="outline" onClick={() => { setSalaryTarget(member.citizen_id); setSalaryValue(member.salary) }}>
                      Set Salary
                    </Button>
                  )
                )}

                {/* Transfer leadership */}
                {isDirektor && member.rank >= 3 && (
                  <Button size="sm" variant="outline" onClick={() => handleTransfer(member.citizen_id)}>
                    Transfer Lead
                  </Button>
                )}

                {/* Kick */}
                <Button size="sm" variant="danger" onClick={() => handleKick(member.citizen_id)}>
                  Remove
                </Button>
              </div>
            )}
          </div>
        )
      })}

      {filtered.length === 0 && (
        <div className="text-center py-8 text-zinc-500 text-sm">
          {search ? 'No members match your search.' : 'No members.'}
        </div>
      )}
    </div>
  )
}
