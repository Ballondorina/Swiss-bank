// ============================================================
// UNDERWORLD — Ledger Tab (v3 — with filters)
// ============================================================

import { useState, useMemo } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { formatMoney, formatDateTime } from '../../lib/utils'
import type { LedgerEntry } from '../../types/org'

const TYPE_LABELS: Record<string, string> = {
  deposit:            'Deposit',
  withdrawal:         'Withdrawal',
  mission_reward:     'Mission Reward',
  passive_income:     'Passive Income',
  salary:             'Salary',
  zone_bonus:         'Zone Bonus',
  leaderboard_reward: 'Leaderboard Prize',
  org_creation:       'Founding Fee',
  tier_upgrade:       'Tier Upgrade',
  war_declared:       'War Declared',
  war_accepted:       'War Accepted',
  war_penalty:        'War Penalty',
  war_spoils:         'War Spoils',
  alliance_formed:    'Alliance Formed',
  leadership_transfer:'Leadership Transfer',
}

const TYPE_COLORS: Record<string, string> = {
  deposit:            '#4caf50',
  mission_reward:     '#4caf50',
  passive_income:     '#4caf50',
  zone_bonus:         '#4caf50',
  war_spoils:         '#4caf50',
  leaderboard_reward: '#f7c948',
  alliance_formed:    '#2196F3',
  withdrawal:         '#f44336',
  salary:             '#f44336',
  org_creation:       '#f44336',
  tier_upgrade:       '#f44336',
  war_penalty:        '#f44336',
}

const FILTER_OPTIONS = [
  { id: 'all', label: 'All' },
  { id: 'income', label: 'Income' },
  { id: 'expenses', label: 'Expenses' },
  { id: 'missions', label: 'Missions' },
  { id: 'war', label: 'War' },
]

export function Ledger() {
  const data = useOrgStore(s => s.data)
  const [filter, setFilter] = useState('all')
  const [search, setSearch] = useState('')

  if (!data) return null
  const { ledger } = data

  const filtered = useMemo(() => {
    let list = [...ledger]

    // Category filter
    if (filter === 'income') {
      list = list.filter(e => e.amount > 0)
    } else if (filter === 'expenses') {
      list = list.filter(e => e.amount < 0)
    } else if (filter === 'missions') {
      list = list.filter(e => e.type === 'mission_reward')
    } else if (filter === 'war') {
      list = list.filter(e => ['war_declared', 'war_accepted', 'war_penalty', 'war_spoils'].includes(e.type))
    }

    // Text search
    if (search.trim()) {
      const q = search.toLowerCase()
      list = list.filter(e =>
        (e.description ?? '').toLowerCase().includes(q) ||
        (TYPE_LABELS[e.type] ?? e.type).toLowerCase().includes(q)
      )
    }

    return list
  }, [ledger, filter, search])

  // Summary stats
  const totalIn = ledger.filter(e => e.amount > 0).reduce((s, e) => s + e.amount, 0)
  const totalOut = ledger.filter(e => e.amount < 0).reduce((s, e) => s + Math.abs(e.amount), 0)

  if (!ledger.length) {
    return (
      <div className="text-center py-12 text-zinc-500 text-sm">
        No transactions yet.
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-surface-2 border border-white/5 rounded-lg px-3 py-2 text-center">
          <div className="text-xs text-zinc-500">Total In</div>
          <div className="text-sm font-mono font-bold text-green-400">+{formatMoney(totalIn)}</div>
        </div>
        <div className="bg-surface-2 border border-white/5 rounded-lg px-3 py-2 text-center">
          <div className="text-xs text-zinc-500">Total Out</div>
          <div className="text-sm font-mono font-bold text-red-400">-{formatMoney(totalOut)}</div>
        </div>
        <div className="bg-surface-2 border border-white/5 rounded-lg px-3 py-2 text-center">
          <div className="text-xs text-zinc-500">Net</div>
          <div className={`text-sm font-mono font-bold ${totalIn - totalOut >= 0 ? 'text-green-400' : 'text-red-400'}`}>
            {formatMoney(totalIn - totalOut)}
          </div>
        </div>
      </div>

      {/* Filter bar */}
      <div className="flex items-center gap-2">
        <div className="flex gap-1">
          {FILTER_OPTIONS.map(f => (
            <button
              key={f.id}
              onClick={() => setFilter(f.id)}
              className={`px-2.5 py-1.5 text-xs rounded-lg border transition-all ${
                filter === f.id
                  ? 'border-accent/40 text-accent bg-accent/10'
                  : 'border-white/8 text-zinc-500 hover:text-zinc-300'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search..."
          className="flex-1 bg-surface-3 border border-white/8 rounded-lg px-3 py-1.5 text-xs text-white placeholder-zinc-600 outline-none focus:border-accent/60"
        />
        <span className="text-xs text-zinc-500">{filtered.length} entries</span>
      </div>

      {/* Transaction list */}
      <div className="flex flex-col gap-1.5">
        {filtered.map((entry: LedgerEntry) => {
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

      {filtered.length === 0 && (
        <div className="text-center py-8 text-zinc-500 text-sm">No matching transactions.</div>
      )}
    </div>
  )
}
