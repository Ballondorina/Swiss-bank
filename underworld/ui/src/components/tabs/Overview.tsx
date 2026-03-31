// ============================================================
// UNDERWORLD — Overview Tab (v3)
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { StatCard } from '../ui/StatCard'
import { ProgressBar } from '../ui/ProgressBar'
import { formatMoney, xpPercent, formatDateTime } from '../../lib/utils'
import { RANK_NAMES, TIER_NAMES, HEAT_COLORS } from '../../types/org'

const LEVEL_THRESHOLDS: Record<number, number> = {
  1: 0, 2: 500, 3: 1500, 4: 3500, 5: 7500,
  6: 15000, 7: 30000, 8: 60000, 9: 100000, 10: 200000,
}

const LEVEL_UNLOCKS: Record<number, string> = {
  2: 'Harder missions',
  3: 'Stash capacity +',
  4: 'Influence zones',
  5: '2nd office',
  6: 'Cooldown reduced',
  8: 'Tier discount 10%',
  10: 'Empire status',
}

export function Overview() {
  const data = useOrgStore(s => s.data)
  if (!data) return null

  const { org, members, missions, announcements, diplomacy } = data
  const tier    = { 1: { req: 3, max: 50000 }, 2: { req: 5, max: 200000 }, 3: { req: 8, max: 500000 }, 4: { req: 12, max: 1000000 } }[org.tier] ?? { req: 3, max: 50000 }
  const completed  = missions.filter(m => m.status === 'completed').length
  const ratio      = Math.min(completed / tier.req, 1.0)
  const passivePct = ratio * 100

  const xpPct = xpPercent(org.xp, org.level, LEVEL_THRESHOLDS)
  const nextXp = org.nextLevelXp ?? null

  const topContributors = [...members]
    .sort((a, b) => b.weekly_contribution - a.weekly_contribution)
    .slice(0, 5)

  const heatColor = HEAT_COLORS[org.heatLabel]

  const myRankName = RANK_NAMES[data.myRank] ?? 'Unknown'

  // Pinned announcement
  const pinned = announcements?.find(a => a.pinned)

  // Active wars/alliances count
  const activeWars = diplomacy?.wars?.filter(w => w.status === 'active').length ?? 0
  const activeAlliances = diplomacy?.alliances?.filter(a => a.status === 'active').length ?? 0

  return (
    <div className="flex flex-col gap-5">
      {/* Pinned announcement banner */}
      {pinned && (
        <div className="bg-accent/10 border border-accent/30 rounded-xl px-4 py-3 flex items-start gap-3">
          <span className="text-accent text-sm mt-0.5">PIN</span>
          <div className="flex-1">
            <p className="text-sm text-zinc-200">{pinned.content}</p>
            <p className="text-xs text-zinc-500 mt-1">— {pinned.author_name}, {formatDateTime(pinned.created_at)}</p>
          </div>
        </div>
      )}

      {/* Stats grid */}
      <div className="grid grid-cols-4 gap-3">
        <StatCard
          label="Members"
          value={members.length}
          sub={`Max: ${[10,25,50,100][org.tier-1] ?? '?'}`}
          icon="◈"
        />
        <StatCard
          label="Missions"
          value={`${completed}/${tier.req}`}
          sub="completed today"
          color={completed >= tier.req ? '#4caf50' : '#f7c948'}
          icon="◎"
        />
        <StatCard
          label="Your Rank"
          value={myRankName}
          sub={`Rank ${data.myRank}`}
          color="#7c6af7"
          icon="◈"
        />
        <StatCard
          label="Vault"
          value={formatMoney(org.vault)}
          sub="organization funds"
          color="#4caf50"
          icon="◇"
        />
      </div>

      {/* Diplomacy summary (if any active) */}
      {(activeWars > 0 || activeAlliances > 0) && (
        <div className="grid grid-cols-2 gap-3">
          {activeWars > 0 && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-red-400">Active War{activeWars > 1 ? 's' : ''}</div>
                <div className="text-xs text-zinc-500">Check Settings tab for details</div>
              </div>
              <span className="text-lg font-bold text-red-400">{activeWars}</span>
            </div>
          )}
          {activeAlliances > 0 && (
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl px-4 py-3 flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-blue-400">Active Alliance{activeAlliances > 1 ? 's' : ''}</div>
                <div className="text-xs text-zinc-500">Shared territorial advantage</div>
              </div>
              <span className="text-lg font-bold text-blue-400">{activeAlliances}</span>
            </div>
          )}
        </div>
      )}

      {/* XP / Level progress */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-white">Level {org.level}</span>
            {org.level < 10 && (
              <span className="text-xs text-zinc-500">→ Level {org.level + 1}</span>
            )}
            {LEVEL_UNLOCKS[org.level + 1] && (
              <span className="text-xs text-accent/80 ml-1">({LEVEL_UNLOCKS[org.level + 1]})</span>
            )}
          </div>
          <span className="text-xs font-mono text-zinc-400">
            {org.xp.toLocaleString()} XP{nextXp ? ` / ${nextXp.toLocaleString()}` : ' (MAX)'}
          </span>
        </div>
        <ProgressBar value={xpPct} color="#7c6af7" height="h-2" glow />
        {/* All unlocks row */}
        <div className="flex flex-wrap gap-1.5 mt-1">
          {Object.entries(LEVEL_UNLOCKS).map(([lvl, unlock]) => {
            const unlocked = org.level >= Number(lvl)
            return (
              <span
                key={lvl}
                className={`text-xs px-2 py-0.5 rounded border ${unlocked ? 'border-accent/40 text-accent bg-accent/10' : 'border-zinc-700/40 text-zinc-600 bg-transparent'}`}
              >
                L{lvl} {unlock}
              </span>
            )
          })}
        </div>
      </div>

      {/* Passive income + heat row */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-zinc-300">Passive Rate</span>
            <span className="text-xs text-zinc-500">{passivePct.toFixed(0)}%</span>
          </div>
          <ProgressBar
            value={passivePct}
            color={passivePct >= 100 ? '#4caf50' : passivePct >= 60 ? '#f7c948' : '#f44336'}
            height="h-2"
            glow={passivePct >= 100}
          />
          <span className="text-xs text-zinc-500">
            Max/day: {formatMoney(tier.max)}
          </span>
        </div>

        <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-zinc-300">Heat Level</span>
            <span className="text-xs font-medium capitalize" style={{ color: heatColor }}>
              {org.heatLabel}
            </span>
          </div>
          <ProgressBar
            value={org.heat}
            color={heatColor}
            height="h-2"
            glow={org.heat >= 61}
            animated={org.heat >= 91}
          />
          <span className="text-xs text-zinc-500">
            {org.heat}/100 — {org.heat >= 91 ? 'Vault locked, no passive' : org.heat >= 61 ? 'Income penalised' : org.heat >= 31 ? 'Minor penalty' : 'All clear'}
          </span>
        </div>
      </div>

      {/* Top contributors */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
        <span className="text-sm font-semibold text-white">Top Contributors (This Week)</span>
        {topContributors.length === 0 ? (
          <span className="text-sm text-zinc-500 italic">No contributions yet.</span>
        ) : (
          <div className="flex flex-col gap-2">
            {topContributors.map((m, i) => (
              <div key={m.citizen_id} className="flex items-center gap-3">
                <span className="text-sm font-mono text-zinc-600 w-4">#{i + 1}</span>
                <span className="text-sm text-zinc-200 flex-1">{m.name}</span>
                <span className="text-sm font-mono text-green-400">{formatMoney(m.weekly_contribution)}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
