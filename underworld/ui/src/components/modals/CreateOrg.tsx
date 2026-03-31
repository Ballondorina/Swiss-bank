// ============================================================
// UNDERWORLD — Create Organization Modal
// ============================================================

import { useState } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { Button } from '../ui/Button'
import { Input, Select } from '../ui/Input'
import { formatMoney, nuiPost } from '../../lib/utils'
import type { OrgType } from '../../types/org'

const TYPE_DESCS: Record<OrgType, string> = {
  legal:   'Corporations operate legitimate businesses. Lower heat, steady income, legal missions.',
  illegal: 'Criminal organizations run high-risk, high-reward operations. Max income multiplier.',
  family:  'Crime families balance legitimacy and shadow work. Moderate risk, balanced income.',
}

export function CreateOrgModal() {
  const { isCreationOpen, creationFees, creationLoading, creationError, setCreationOpen, setCreationLoading } = useOrgStore()

  const [name, setName]       = useState('')
  const [label, setLabel]     = useState('')
  const [orgType, setOrgType] = useState<OrgType>('illegal')

  if (!isCreationOpen || !creationFees) return null

  const fee = creationFees.fees[orgType] ?? 0

  const handleClose = () => {
    nuiPost('closeCreation')
    setCreationOpen(false)
  }

  const handleSubmit = () => {
    if (!name.trim() || !label.trim()) return
    setCreationLoading(true)
    nuiPost('createOrg', { name: name.trim(), label: label.trim(), orgType })
  }

  const nameValid  = name.trim().length >= 3 && name.trim().length <= 24 && /^[A-Za-z][A-Za-z0-9 ]*$/.test(name.trim())
  const labelValid = label.trim().length >= 3 && label.trim().length <= 48
  const canSubmit  = nameValid && labelValid && !creationLoading

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 animate-fade-in">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={handleClose} />
      <div className="relative w-[480px] bg-surface-1 border border-white/8 rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-slide-up">

        {/* Header */}
        <div className="px-6 pt-5 pb-4 border-b border-white/5 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-white">Found an Organization</h2>
            <p className="text-xs text-zinc-500 mt-0.5">Register your org at the Notary Office</p>
          </div>
          <button
            onClick={handleClose}
            className="w-8 h-8 flex items-center justify-center rounded-lg bg-surface-3 hover:bg-red-500/20 hover:text-red-400 text-zinc-400 transition-all text-lg"
          >
            ×
          </button>
        </div>

        {/* Body */}
        <div className="p-6 flex flex-col gap-4">

          {/* Org type picker */}
          <div className="flex flex-col gap-2">
            <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider">Organization Type</span>
            <div className="grid grid-cols-3 gap-2">
              {(['legal', 'illegal', 'family'] as OrgType[]).map(t => {
                const colors: Record<OrgType, string> = { legal: '#2196F3', illegal: '#F44336', family: '#9C27B0' }
                const labels: Record<OrgType, string> = { legal: 'Corporation', illegal: 'Organization', family: 'Family' }
                const selected = orgType === t
                return (
                  <button
                    key={t}
                    onClick={() => setOrgType(t)}
                    className={`rounded-lg py-2 px-3 text-sm font-medium border transition-all ${
                      selected
                        ? `border-current text-white`
                        : 'border-white/10 text-zinc-500 hover:text-zinc-300 hover:border-zinc-500'
                    }`}
                    style={selected ? { borderColor: colors[t], backgroundColor: `${colors[t]}18`, color: colors[t] } : undefined}
                  >
                    {labels[t]}
                  </button>
                )
              })}
            </div>
            <p className="text-xs text-zinc-500 italic">{TYPE_DESCS[orgType]}</p>
          </div>

          <Input
            label="Org Name (internal ID)"
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="e.g. los_santos_cartel"
            error={name && !nameValid ? '3–24 chars, letters/numbers/spaces, start with letter' : undefined}
          />

          <Input
            label="Display Label"
            value={label}
            onChange={e => setLabel(e.target.value)}
            placeholder="e.g. Los Santos Cartel"
            error={label && !labelValid ? '3–48 characters required' : undefined}
          />

          {/* Fee display */}
          <div className="bg-surface-3 border border-white/5 rounded-lg px-4 py-3 flex items-center justify-between">
            <span className="text-sm text-zinc-400">Registration Fee</span>
            <span className="text-lg font-bold font-mono text-red-400">{formatMoney(fee)}</span>
          </div>

          {creationError && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2 text-sm text-red-400">
              {creationError}
            </div>
          )}

          <Button
            variant="primary"
            className="w-full justify-center py-2.5"
            disabled={!canSubmit}
            onClick={handleSubmit}
          >
            {creationLoading ? 'Processing...' : `Pay ${formatMoney(fee)} & Found Organization`}
          </Button>
        </div>
      </div>
    </div>
  )
}
