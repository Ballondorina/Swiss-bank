// ============================================================
// UNDERWORLD — Missions Tab
// ============================================================

import { useState, useEffect } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { MissionStatusBadge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { formatMoney, formatCooldown } from '../../lib/utils'
import { nuiPost } from '../../lib/utils'
import type { Mission } from '../../types/org'

const MISSION_LABELS: Record<string, string> = {
  supply_run:      'Supply Run',
  debt_collection: 'Debt Collection',
  patrol:          'Territory Patrol',
  dirty_work:      'Dirty Work',
  delivery:        'Contract Delivery',
  vip_transport:   'VIP Transport',
  inspection:      'Site Inspection',
  negotiation:     'Business Negotiation',
}

const MISSION_DESCS: Record<string, string> = {
  supply_run:      'Pick up supplies from the source and deliver them.',
  debt_collection: 'Locate the target and collect what is owed.',
  patrol:          'Hold the designated zone for the required time.',
  dirty_work:      'Eliminate the target. Clean job. No witnesses.',
  delivery:        'Deliver the cargo to the client on time.',
  vip_transport:   'Transport the VIP safely to the destination.',
  inspection:      'Visit all sites and submit the inspection report.',
  negotiation:     'Meet the contact and close the deal.',
}

const RANK_REQ: Record<string, number> = {
  supply_run: 2, debt_collection: 2, patrol: 2, dirty_work: 3,
  delivery: 2, vip_transport: 2, inspection: 2, negotiation: 3,
}

export function Missions() {
  const data = useOrgStore(s => s.data)
  const [cooldownDisplay, setCooldownDisplay] = useState('')

  useEffect(() => {
    if (!data?.myCooldownEnds) return
    const interval = setInterval(() => {
      const cd = formatCooldown(data.myCooldownEnds)
      setCooldownDisplay(cd)
      if (!cd) clearInterval(interval)
    }, 1000)
    setCooldownDisplay(formatCooldown(data.myCooldownEnds))
    return () => clearInterval(interval)
  }, [data?.myCooldownEnds])

  if (!data) return null
  const { missions, myRank, myCooldownEnds } = data
  const onCooldown = myCooldownEnds > Math.floor(Date.now() / 1000)

  const handleStart = (missionId: number) => {
    nuiPost('startMission', { missionId })
  }

  const pending   = missions.filter(m => m.status === 'pending')
  const active    = missions.filter(m => m.status === 'active')
  const done      = missions.filter(m => ['completed', 'failed', 'expired'].includes(m.status))

  const renderMission = (m: Mission) => {
    const label   = MISSION_LABELS[m.mission_type] ?? m.mission_type
    const desc    = MISSION_DESCS[m.mission_type] ?? ''
    const minRank = RANK_REQ[m.mission_type] ?? 2
    const meetsRank = myRank >= minRank
    const canTake = m.status === 'pending' && meetsRank && !onCooldown

    return (
      <div
        key={m.id}
        className={`bg-surface-2 border rounded-xl p-4 flex flex-col gap-2 transition-all ${
          m.status === 'active' ? 'border-amber-500/30' : 'border-white/5'
        }`}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex flex-col gap-1 flex-1">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-white">{label}</span>
              {m.zone_id && (
                <span className="text-xs px-1.5 py-0.5 rounded bg-accent/10 text-accent/80 border border-accent/20">
                  {m.zone_id.replace('_', ' ')}
                </span>
              )}
            </div>
            <span className="text-xs text-zinc-500">{desc}</span>
          </div>
          <div className="flex flex-col items-end gap-1.5">
            <MissionStatusBadge status={m.status} />
            <span className="text-sm font-mono font-bold text-green-400">{formatMoney(m.reward)}</span>
          </div>
        </div>

        {m.status === 'pending' && (
          <div className="flex items-center justify-between border-t border-white/5 pt-2 mt-1">
            <span className="text-xs text-zinc-500">
              {!meetsRank ? `Requires Rank ${minRank}` : onCooldown ? `Cooldown: ${cooldownDisplay}` : 'Available'}
            </span>
            <Button
              size="sm"
              variant="primary"
              disabled={!canTake}
              onClick={() => handleStart(m.id)}
            >
              Take Mission
            </Button>
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Cooldown banner */}
      {onCooldown && (
        <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl px-4 py-3 flex items-center gap-2">
          <span className="text-amber-300 text-sm">
            ⏱ Mission cooldown: <span className="font-mono font-bold">{cooldownDisplay}</span>
          </span>
        </div>
      )}

      {active.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="text-xs text-amber-400 uppercase tracking-wider font-semibold">Active</h3>
          {active.map(renderMission)}
        </section>
      )}

      {pending.length > 0 ? (
        <section className="flex flex-col gap-2">
          <h3 className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Available</h3>
          {pending.map(renderMission)}
        </section>
      ) : (
        active.length === 0 && (
          <div className="text-center py-8 text-zinc-500 text-sm">No missions available today.</div>
        )
      )}

      {done.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="text-xs text-zinc-600 uppercase tracking-wider font-semibold">Completed / Failed</h3>
          {done.map(renderMission)}
        </section>
      )}
    </div>
  )
}
