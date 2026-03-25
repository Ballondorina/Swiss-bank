// ============================================================
// UNDERWORLD — Operations Tab: Drug Labs + Store Robberies
// ============================================================

import { useState } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { nuiPost, formatMoney, formatTimeRemaining } from '../../lib/utils'
import type { DrugLab, LabLocation, RobberyData, WarWindow, DrugTypeConfig } from '../../types/org'

// ─── Shared warnings ─────────────────────────────────────────

function HeatWarning({ heat }: { heat: number }) {
  if (heat < 60) return null
  return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-red-500/10 border border-red-500/30 text-sm text-red-400 mb-3">
      <span>⚠</span>
      <span>
        {heat >= 91
          ? 'Heat MAXED — labs may be raided any tick. Lower heat before operating.'
          : 'Heat HIGH — police scrutiny up. Drug revenue reduced 30%.'}
      </span>
    </div>
  )
}

function WarWindowBadge({ warWindow }: { warWindow?: WarWindow }) {
  if (!warWindow?.enabled) return null
  return (
    <div className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm mb-3 ${
      warWindow.active
        ? 'bg-green-500/10 border border-green-500/30 text-green-400'
        : 'bg-zinc-800/60 border border-white/5 text-zinc-500'
    }`}>
      <span>{warWindow.active ? '⚔' : '🕐'}</span>
      <span>
        {warWindow.active
          ? `War Window ACTIVE — 3× territory gain until ${warWindow.endHour}:00`
          : `War Window closed${warWindow.nextStart != null ? ` — opens in ${warWindow.nextStart}h` : ''}`}
      </span>
    </div>
  )
}

// ─── Pipeline Steps Component ─────────────────────────────────

function PipelineSteps({ steps }: { steps: string[] }) {
  return (
    <div className="flex flex-col gap-1.5 mt-2">
      {steps.map((step, i) => (
        <div key={i} className="flex items-start gap-2.5 text-xs text-zinc-400">
          <div className="flex-shrink-0 w-5 h-5 rounded-full bg-accent/15 text-accent flex items-center justify-center font-bold text-[10px] mt-px">
            {i + 1}
          </div>
          <span className="leading-relaxed">{step}</span>
        </div>
      ))}
    </div>
  )
}

// ─── Owned Lab Card ───────────────────────────────────────────

function LabCard({ lab, typeCfg }: { lab: DrugLab; typeCfg?: DrugTypeConfig }) {
  const [confirming, setConfirming] = useState(false)
  const [expanded, setExpanded]     = useState(false)
  const stockPct = lab.max_stock > 0 ? (lab.stock / lab.max_stock) * 100 : 0

  const handleShutdown = async () => {
    if (!confirming) { setConfirming(true); return }
    await nuiPost('shutdownLab', { labId: lab.id })
    setConfirming(false)
  }

  const statusColor =
    lab.status === 'active'   ? 'text-green-400' :
    lab.status === 'raided'   ? 'text-red-400'   : 'text-zinc-500'

  const stockColor =
    stockPct >= 75 ? 'bg-green-500' :
    stockPct >= 35 ? 'bg-accent'    : 'bg-zinc-600'

  return (
    <div className="bg-surface-2 border border-white/6 rounded-xl p-4 flex flex-col gap-3">
      {/* Header */}
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="font-semibold text-white truncate">{lab.type_label}</div>
          <div className="text-xs text-zinc-500 truncate">{(lab as any).location_label}</div>
        </div>
        <div className="flex items-center gap-1.5 flex-shrink-0">
          <span className={`text-xs font-medium uppercase ${statusColor}`}>{lab.status}</span>
          <button
            onClick={handleShutdown}
            onBlur={() => setConfirming(false)}
            className={`text-xs px-2 py-1 rounded-lg transition-all ${
              confirming
                ? 'bg-red-500 text-white'
                : 'bg-surface-3 text-zinc-400 hover:text-red-400 hover:bg-red-500/10'
            }`}
          >
            {confirming ? 'Confirm?' : 'Close Lab'}
          </button>
        </div>
      </div>

      {/* Stock bar */}
      <div>
        <div className="flex justify-between text-xs mb-1">
          <span className="text-zinc-400">Product Stock</span>
          <span className={stockPct > 0 ? 'text-white' : 'text-zinc-600'}>
            {lab.stock} / {lab.max_stock} units
          </span>
        </div>
        <div className="h-2 rounded-full bg-surface-3 overflow-hidden">
          <div
            className={`h-full rounded-full transition-all ${stockColor}`}
            style={{ width: `${stockPct}%` }}
          />
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 text-xs">
        <div className="bg-surface-3 rounded-lg p-2 text-center">
          <div className="text-zinc-500 mb-0.5">Passive</div>
          <div className="text-white font-medium">+{(lab as any).units_per_hr}/hr</div>
        </div>
        <div className="bg-surface-3 rounded-lg p-2 text-center">
          <div className="text-zinc-500 mb-0.5">Price</div>
          <div className="text-green-400 font-medium">{formatMoney((lab as any).sell_price ?? 0)}/unit</div>
        </div>
        <div className="bg-surface-3 rounded-lg p-2 text-center">
          <div className="text-zinc-500 mb-0.5">Gather</div>
          <div className="text-accent font-medium">{(lab as any).raw_label?.split(' ')[0] ?? '—'}</div>
        </div>
      </div>

      {/* Pipeline steps (collapsible) */}
      {typeCfg?.steps && typeCfg.steps.length > 0 && (
        <div>
          <button
            onClick={() => setExpanded(e => !e)}
            className="flex items-center gap-1.5 text-xs text-zinc-500 hover:text-zinc-300 transition-colors"
          >
            <span>{expanded ? '▾' : '▸'}</span>
            <span>{expanded ? 'Hide pipeline' : 'How to work this lab'}</span>
          </button>
          {expanded && <PipelineSteps steps={typeCfg.steps} />}
        </div>
      )}
    </div>
  )
}

// ─── Available Location Card ──────────────────────────────────

function AvailableLabCard({ loc, canPurchase }: { loc: LabLocation; canPurchase: boolean }) {
  const [confirming, setConfirming] = useState(false)
  const data        = useOrgStore(s => s.data)
  const labData     = data?.labData
  const vaultEnough = (data?.org.vault ?? 0) >= (labData?.labCost ?? 750000)
  const disabled    = !canPurchase || !vaultEnough || !loc.available

  const handlePurchase = async () => {
    if (!confirming) { setConfirming(true); return }
    await nuiPost('purchaseLab', { locationId: loc.id })
    setConfirming(false)
  }

  const typeData = data?.labData?.typeConfig?.[loc.type]

  return (
    <div className={`bg-surface-2 border rounded-xl p-4 flex flex-col gap-2.5 transition-opacity ${
      loc.available ? 'border-white/6 opacity-90 hover:opacity-100' : 'border-white/3 opacity-40'
    }`}>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="font-medium text-white text-sm truncate">{loc.label}</div>
          <div className="text-xs text-zinc-500 mt-0.5">{loc.type_label}</div>
        </div>
        <div className="text-right flex-shrink-0">
          <div className="text-sm font-semibold text-accent">{formatMoney(labData?.labCost ?? 750000)}</div>
          <div className="text-xs text-zinc-600">setup cost</div>
        </div>
      </div>

      {typeData && (
        <div className="text-xs text-zinc-500 leading-relaxed">
          <span className="text-zinc-400">Gather:</span> {typeData.gatherLabel}
          <span className="mx-1.5 text-zinc-700">·</span>
          +{loc.production_rate}/hr passive
          <span className="mx-1.5 text-zinc-700">·</span>
          {formatMoney(loc.available ? (typeData?.sellPricePerUnit ?? 0) : 0)}/unit
        </div>
      )}

      {!loc.available && (
        <div className="text-xs text-zinc-600 italic">Occupied by another organization</div>
      )}

      {loc.available && (
        <button
          onClick={handlePurchase}
          onBlur={() => setConfirming(false)}
          disabled={disabled}
          className={`text-sm px-3 py-1.5 rounded-lg transition-all font-medium ${
            confirming
              ? 'bg-accent text-black'
              : disabled
              ? 'bg-surface-3 text-zinc-600 cursor-not-allowed'
              : 'bg-surface-3 text-zinc-300 hover:bg-accent hover:text-black'
          }`}
        >
          {confirming
            ? 'Confirm Purchase?'
            : !vaultEnough
            ? 'Insufficient Vault'
            : !canPurchase
            ? 'Lab Limit Reached'
            : 'Purchase Lab'}
        </button>
      )}
    </div>
  )
}

// ─── Drug Labs Tab Section ────────────────────────────────────

function DrugLabsSection() {
  const data    = useOrgStore(s => s.data)
  const labData = data?.labData
  const [showAvailable, setShowAvailable] = useState(false)

  if (!labData) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-3 text-center">
        <div className="text-3xl opacity-30">🧪</div>
        <div className="text-zinc-500 text-sm">Drug labs unavailable for your org type.</div>
      </div>
    )
  }

  const canPurchase = labData.labs.length < labData.maxLabs
  const activeLabs  = labData.labs.filter(l => l.status === 'active')

  return (
    <div className="flex flex-col gap-4">

      {/* Slot usage */}
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-zinc-300 uppercase tracking-wider">Owned Labs</h3>
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            {Array.from({ length: labData.maxLabs }).map((_, i) => (
              <div
                key={i}
                className={`w-3 h-3 rounded-sm ${i < activeLabs.length ? 'bg-accent' : 'bg-surface-3'}`}
              />
            ))}
          </div>
          <span className="text-xs text-zinc-500">{activeLabs.length}/{labData.maxLabs} slots</span>
        </div>
      </div>

      {/* Owned lab cards */}
      {activeLabs.length > 0 ? (
        <div className="grid grid-cols-2 gap-3">
          {activeLabs.map(lab => (
            <LabCard
              key={lab.id}
              lab={lab}
              typeCfg={labData.typeConfig?.[lab.lab_type]}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-6 text-zinc-600 text-sm bg-surface-2 rounded-xl border border-white/5">
          No active labs. Purchase a location below to start operations.
        </div>
      )}

      {/* Deal points info */}
      {activeLabs.length > 0 && labData.sellPoints.length > 0 && (
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">
            Deal Points ({labData.sellPoints.length})
          </div>
          <div className="grid grid-cols-2 gap-1.5">
            {labData.sellPoints.map(sp => (
              <div key={sp.id} className="flex items-center gap-2 text-xs text-zinc-400">
                <span className="w-1.5 h-1.5 rounded-full bg-green-400 flex-shrink-0" />
                {sp.label}
              </div>
            ))}
          </div>
          <div className="text-xs text-zinc-600 mt-2">
            Walk to any deal point with product to sell. Marked on your minimap.
          </div>
        </div>
      )}

      {/* Available locations toggle */}
      <button
        onClick={() => setShowAvailable(v => !v)}
        className="flex items-center gap-2 text-sm text-zinc-500 hover:text-zinc-300 transition-colors"
      >
        <span>{showAvailable ? '▾' : '▸'}</span>
        <span>{showAvailable ? 'Hide' : 'Show'} Available Locations ({labData.availableLocations.filter(l => l.available).length} free)</span>
      </button>

      {showAvailable && (
        <div className="grid grid-cols-2 gap-3">
          {labData.availableLocations.map(loc => (
            <AvailableLabCard key={loc.id} loc={loc} canPurchase={canPurchase} />
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Store Robbery Section ────────────────────────────────────

function RobberyCooldownBar({ data }: { data: RobberyData }) {
  if (data.cooldownLeft <= 0) return null
  const pct = Math.max(0, Math.min(100, (1 - data.cooldownLeft / data.cooldownSecs) * 100))
  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
      <div className="flex justify-between text-xs mb-1.5">
        <span className="text-zinc-400">Robbery cooldown</span>
        <span className="text-amber-400 font-medium">{formatTimeRemaining(data.cooldownLeft)} remaining</span>
      </div>
      <div className="h-2 rounded-full bg-surface-3 overflow-hidden">
        <div
          className="h-full rounded-full bg-amber-500 transition-all"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

function StoreRobberySection() {
  const data    = useOrgStore(s => s.data)
  const robbery = data?.robberyData

  if (!robbery) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-3 text-center">
        <div className="text-3xl opacity-30">🏪</div>
        <div className="text-zinc-500 text-sm">Store robberies unavailable for your org type.</div>
      </div>
    )
  }

  const ready = robbery.cooldownLeft <= 0

  return (
    <div className="flex flex-col gap-4">

      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-zinc-300 uppercase tracking-wider">Store Robberies</h3>
        <span className={`text-xs px-2.5 py-0.5 rounded-full font-semibold ${
          ready
            ? 'bg-green-500/15 text-green-400 border border-green-500/20'
            : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
        }`}>
          {ready ? '✓ READY' : '⏳ COOLING DOWN'}
        </span>
      </div>

      <RobberyCooldownBar data={robbery} />

      {/* Payout + How to */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs text-zinc-500 mb-1">Expected Payout</div>
          <div className="text-base font-bold text-white">
            {formatMoney(robbery.payoutMin)}–{formatMoney(robbery.payoutMax)}
          </div>
          <div className="text-xs text-zinc-600 mt-0.5">Deposited to org vault</div>
        </div>
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs text-zinc-500 mb-1">Heat Impact</div>
          <div className="text-base font-bold text-red-400">+15 heat</div>
          <div className="text-xs text-zinc-600 mt-0.5">Per successful job</div>
        </div>
      </div>

      {/* How to rob */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
        <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">How It Works</div>
        <div className="flex flex-col gap-1.5">
          {[
            '🗺️  Travel to any store marked on your map',
            '🎯 Use the [ROB] interaction — pass the skill check',
            '💰 Payout auto-deposits to org vault + contribution counted',
            '⏳ 1-hour per-org cooldown applies after each hit',
          ].map((step, i) => (
            <div key={i} className="flex items-start gap-2 text-xs text-zinc-400">
              <span className="flex-shrink-0 w-4 h-4 rounded-full bg-surface-3 flex items-center justify-center text-[10px] text-zinc-500 mt-px">{i + 1}</span>
              <span>{step}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Targets list */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
        <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">
          {robbery.stores.length} Available Targets
        </div>
        <div className="grid grid-cols-2 gap-1.5">
          {robbery.stores.map(store => (
            <div key={store.id} className="flex items-center gap-2 text-xs">
              <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${ready ? 'bg-green-400' : 'bg-zinc-600'}`} />
              <span className={ready ? 'text-zinc-300' : 'text-zinc-600'}>{store.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Recent history */}
      {robbery.recentRobberies.length > 0 && (
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">Recent Jobs</div>
          <div className="flex flex-col gap-1.5">
            {robbery.recentRobberies.slice(0, 5).map((r, i) => (
              <div key={i} className="flex items-center justify-between text-xs">
                <span className="text-zinc-500">
                  {robbery.stores.find(s => s.id === r.store_id)?.label ?? `Store #${r.store_id}`}
                </span>
                <span className="text-green-400 font-medium">{formatMoney(r.payout)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Main Tab ─────────────────────────────────────────────────

export function Operations() {
  const [section, setSection] = useState<'labs' | 'robbery'>('labs')
  const data = useOrgStore(s => s.data)

  return (
    <div className="flex flex-col gap-3">
      <HeatWarning heat={data?.org.heat ?? 0} />
      <WarWindowBadge warWindow={data?.warWindow} />

      {/* Sub-nav */}
      <div className="flex gap-1 p-1 bg-surface-2/60 rounded-xl w-fit border border-white/5">
        {([
          { id: 'labs',    label: '🧪 Drug Labs' },
          { id: 'robbery', label: '🏪 Robberies' },
        ] as const).map(({ id, label }) => (
          <button
            key={id}
            onClick={() => setSection(id)}
            className={`px-4 py-1.5 text-sm font-medium rounded-lg transition-all ${
              section === id
                ? 'bg-accent text-black shadow-sm'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {section === 'labs'    && <DrugLabsSection />}
      {section === 'robbery' && <StoreRobberySection />}
    </div>
  )
}
