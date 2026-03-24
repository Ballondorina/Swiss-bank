// ============================================================
// UNDERWORLD — Members Tab
// ============================================================

import { useState } from 'react'
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

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between mb-1">
        <span className="text-sm text-zinc-400">{members.length} member{members.length !== 1 ? 's' : ''}</span>
      </div>

      {members.map(member => {
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
            <div className="grid grid-cols-3 gap-2 text-xs text-zinc-500">
              <div>
                <div className="text-zinc-400 font-medium">{formatMoney(member.weekly_contribution)}</div>
                <div>This week</div>
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

                {/* Kick */}
                <Button size="sm" variant="danger" onClick={() => handleKick(member.citizen_id)}>
                  Remove
                </Button>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
