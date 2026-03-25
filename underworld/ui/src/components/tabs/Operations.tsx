// ============================================================
// UNDERWORLD — Operations Tab: Drug Labs + Store Robberies
// ============================================================

import { useState } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { nuiPost, formatMoney, formatTimeRemaining } from '../../lib/utils'
import type { DrugLab, LabLocation, RobberyData, WarWindow } from '../../types/org'

// ─── Helpers ─────────────────────────────────────────────────

function HeatWarning({ heat }: { heat: number }) {
  if (heat < 60) return null
  return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-red-500/10 border border-red-500/30 text-sm text-red-400 mb-4">
      <span>⚠</span>
      <span>
        {heat >= 91
          ? 'Heat MAXED — labs may be raided any tick. Lower heat before operating.'
          : 'Heat ELEVATED — police scrutiny increased. Drug revenue reduced 30%.'}
      </span>
    </div>
  )
}

function WarWindowBadge({ warWindow }: { warWindow?: WarWindow }) {
  if (!warWindow?.enabled) return null
  return (
    <div className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm mb-4 ${
      warWindow.active
        ? 'bg-green-500/10 border border-green-500/30 text-green-400'
        : 'bg-zinc-800 border border-white/5 text-zinc-500'
    }`}>
      <span>{warWindow.active ? '⚔' : '🕐'}</span>
      <span>
        {warWindow.active
          ? `Territory War Window ACTIVE — closes at ${warWindow.endHour}:00`
          : `War Window closed — opens ${warWindow.nextStart != null ? `in ${warWindow.nextStart}h` : `at ${warWindow.startHour}:00`}`}
      </span>
    </div>
  )
}

// ─── Drug Labs Section ────────────────────────────────────────

function LabCard({ lab }: { lab: DrugLab }) {
  const [confirming, setConfirming] = useState(false)
  const stockPct = lab.max_stock > 0 ? (lab.stock / lab.max_stock) * 100 : 0

  const handleShutdown = async () => {
    if (!confirming) { setConfirming(true); return }
    await nuiPost('shutdownLab', { labId: lab.id })
    setConfirming(false)
  }

  const statusColor =
    lab.status === 'active'   ? 'text-green-400' :
    lab.status === 'raided'   ? 'text-red-400'   : 'text-zinc-500'

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold text-white">{lab.type_label}</div>
          <div className={`text-xs mt-0.5 uppercase tracking-wider ${statusColor}`}>
            {lab.status}
          </div>
        </div>
        <button
          onClick={handleShutdown}
          className={`text-xs px-2.5 py-1 rounded-lg transition-all ${
            confirming
              ? 'bg-red-500 text-white'
              : 'bg-surface-3 text-zinc-400 hover:text-red-400'
          }`}
        >
          {confirming ? 'Confirm?' : 'Shut Down'}
        </button>
      </div>

      {/* Stock bar */}
      <div>
        <div className="flex justify-between text-xs text-zinc-400 mb-1">
          <span>Stock</span>
          <span>{lab.stock} / {lab.max_stock} units</span>
        </div>
        <div className="h-1.5 rounded-full bg-surface-3 overflow-hidden">
          <div
            className="h-full rounded-full bg-accent transition-all"
            style={{ width: `${stockPct}%` }}
          />
        </div>
      </div>

      <div className="text-xs text-zinc-500">
        +{lab.production_rate} units/tick · Collect when stock &gt; 0 at lab location
      </div>
    </div>
  )
}

function AvailableLabCard({ loc, canPurchase }: { loc: LabLocation; canPurchase: boolean }) {
  const [confirming, setConfirming] = useState(false)
  const data = useOrgStore(s => s.data)
  const vaultEnough = (data?.org.vault ?? 0) >= loc.purchase_cost

  const handlePurchase = async () => {
    if (!confirming) { setConfirming(true); return }
    await nuiPost('purchaseLab', { locationId: loc.id })
    setConfirming(false)
  }

  const disabled = !canPurchase || !vaultEnough

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-2 opacity-80 hover:opacity-100 transition-opacity">
      <div className="flex items-center justify-between">
        <div>
          <div className="font-medium text-white">{loc.label}</div>
          <div className="text-xs text-zinc-400 mt-0.5">{loc.type_label}</div>
        </div>
        <div className="text-right">
          <div className="text-sm font-semibold text-accent">{formatMoney(loc.purchase_cost)}</div>
          <div className="text-xs text-zinc-500">setup cost</div>
        </div>
      </div>
      <div className="text-xs text-zinc-500">
        +{loc.production_rate} units/tick · Max {loc.max_stock} units
      </div>
      <button
        onClick={handlePurchase}
        disabled={disabled}
        className={`mt-1 text-sm px-3 py-1.5 rounded-lg transition-all font-medium ${
          confirming
            ? 'bg-accent text-black'
            : disabled
            ? 'bg-surface-3 text-zinc-600 cursor-not-allowed'
            : 'bg-surface-3 text-zinc-300 hover:bg-accent hover:text-black'
        }`}
      >
        {confirming ? 'Confirm Purchase?' : !vaultEnough ? 'Insufficient Vault' : !canPurchase ? 'Lab Limit Reached' : 'Purchase Lab'}
      </button>
    </div>
  )
}

function DrugLabsSection() {
  const data = useOrgStore(s => s.data)
  const labData = data?.labData
  if (!labData) {
    return (
      <div className="text-center text-zinc-600 py-8 text-sm">
        Drug lab data unavailable. Your org type may not support labs.
      </div>
    )
  }

  const canPurchase = labData.labs.length < labData.maxLabs
  const activeLabs  = labData.labs.filter(l => l.status === 'active')

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-zinc-300 uppercase tracking-wider">Drug Labs</h3>
        <span className="text-xs text-zinc-500">
          {labData.labs.length} / {labData.maxLabs} slots used
        </span>
      </div>

      {activeLabs.length > 0 && (
        <div className="grid grid-cols-2 gap-3">
          {activeLabs.map(lab => <LabCard key={lab.id} lab={lab} />)}
        </div>
      )}

      {/* Sell points info */}
      {labData.sellPoints.length > 0 && (
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">Deal Points</div>
          <div className="grid grid-cols-2 gap-1">
            {labData.sellPoints.map(sp => (
              <div key={sp.id} className="flex items-center gap-2 text-xs text-zinc-400">
                <span className="w-1.5 h-1.5 rounded-full bg-green-400 flex-shrink-0" />
                {sp.label}
              </div>
            ))}
          </div>
          <div className="text-xs text-zinc-600 mt-2">Walk to deal points with stock to sell.</div>
        </div>
      )}

      {/* Available locations */}
      {labData.availableLocations.length > 0 && (
        <div>
          <div className="text-xs font-semibold text-zinc-500 uppercase tracking-wider mb-2">Available Locations</div>
          <div className="grid grid-cols-2 gap-3">
            {labData.availableLocations.map(loc => (
              <AvailableLabCard key={loc.id} loc={loc} canPurchase={canPurchase} />
            ))}
          </div>
        </div>
      )}

      {labData.availableLocations.length === 0 && labData.labs.length === 0 && (
        <div className="text-center text-zinc-600 py-6 text-sm">
          No lab locations available. Check back later.
        </div>
      )}
    </div>
  )
}

// ─── Store Robberies Section ──────────────────────────────────

function RobberyCooldownBar({ data }: { data: RobberyData }) {
  if (data.cooldownLeft <= 0) return null
  const pct = Math.max(0, Math.min(100, (1 - data.cooldownLeft / data.cooldownSecs) * 100))
  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
      <div className="flex justify-between text-xs text-zinc-400 mb-2">
        <span>Robbery cooldown</span>
        <span className="text-amber-400">{formatTimeRemaining(data.cooldownLeft)}</span>
      </div>
      <div className="h-1.5 rounded-full bg-surface-3 overflow-hidden">
        <div
          className="h-full rounded-full bg-amber-500 transition-all"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

function StoreRobberySection() {
  const data = useOrgStore(s => s.data)
  const robbery = data?.robberyData

  if (!robbery) {
    return (
      <div className="text-center text-zinc-600 py-8 text-sm">
        Store robbery data unavailable. Your org type may not support robberies.
      </div>
    )
  }

  const ready = robbery.cooldownLeft <= 0

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-zinc-300 uppercase tracking-wider">Store Robberies</h3>
        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
          ready
            ? 'bg-green-500/15 text-green-400'
            : 'bg-amber-500/15 text-amber-400'
        }`}>
          {ready ? 'READY' : 'COOLDOWN'}
        </span>
      </div>

      <RobberyCooldownBar data={robbery} />

      <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
        <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">Payout Range</div>
        <div className="text-lg font-bold text-white">
          {formatMoney(robbery.payoutMin)} – {formatMoney(robbery.payoutMax)}
        </div>
        <div className="text-xs text-zinc-500 mt-1">Deposited directly to org vault. Adds +15 heat.</div>
      </div>

      <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
        <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">
          Available Targets — {robbery.stores.length} stores
        </div>
        <div className="flex flex-col gap-1.5">
          {robbery.stores.map(store => (
            <div key={store.id} className="flex items-center gap-2 text-sm">
              <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${ready ? 'bg-green-400' : 'bg-zinc-600'}`} />
              <span className={ready ? 'text-zinc-300' : 'text-zinc-600'}>{store.label}</span>
            </div>
          ))}
        </div>
        <div className="text-xs text-zinc-500 mt-2">
          {ready
            ? 'Walk to a store location. Use the target interaction to rob it.'
            : `Next robbery available in ${formatTimeRemaining(robbery.cooldownLeft)}.`}
        </div>
      </div>

      {robbery.recentRobberies.length > 0 && (
        <div className="bg-surface-2 border border-white/5 rounded-xl p-3">
          <div className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">Recent Robberies</div>
          <div className="flex flex-col gap-1.5">
            {robbery.recentRobberies.slice(0, 5).map((r, i) => (
              <div key={i} className="flex items-center justify-between text-sm">
                <span className="text-zinc-400">Store #{r.store_id}</span>
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
    <div className="flex flex-col gap-4">
      <HeatWarning heat={data?.org.heat ?? 0} />
      <WarWindowBadge warWindow={data?.warWindow} />

      {/* Sub-nav */}
      <div className="flex gap-1 p-1 bg-surface-2 rounded-xl w-fit">
        {(['labs', 'robbery'] as const).map(id => (
          <button
            key={id}
            onClick={() => setSection(id)}
            className={`px-4 py-1.5 text-sm font-medium rounded-lg transition-all ${
              section === id
                ? 'bg-accent text-black'
                : 'text-zinc-400 hover:text-zinc-200'
            }`}
          >
            {id === 'labs' ? '🧪 Drug Labs' : '🏪 Robberies'}
          </button>
        ))}
      </div>

      {section === 'labs'    && <DrugLabsSection />}
      {section === 'robbery' && <StoreRobberySection />}
    </div>
  )
}
