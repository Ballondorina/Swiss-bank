// ============================================================
// UNDERWORLD — Vault Tab
// ============================================================

import { useState } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { formatMoney, formatMoneyFull, nuiPost } from '../../lib/utils'
import { RANK_NAMES } from '../../types/org'

export function Vault() {
  const data = useOrgStore(s => s.data)
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')

  if (!data) return null
  const { org, myRank } = data

  const rankData = {
    1: { canWithdraw: false, daily: 0 },
    2: { canWithdraw: true,  daily: 10000 },
    3: { canWithdraw: true,  daily: 50000 },
    4: { canWithdraw: true,  daily: 200000 },
    5: { canWithdraw: true,  daily: 999999999 },
  }[myRank] ?? { canWithdraw: false, daily: 0 }

  const isLocked = org.heat >= 91

  const handleDeposit = () => {
    const amt = Math.floor(Number(depositAmount))
    if (!amt || amt <= 0) return
    nuiPost('deposit', { amount: amt })
    setDepositAmount('')
  }

  const handleWithdraw = () => {
    const amt = Math.floor(Number(withdrawAmount))
    if (!amt || amt <= 0) return
    nuiPost('withdraw', { amount: amt })
    setWithdrawAmount('')
  }

  const handleStash = () => {
    nuiPost('openStash')
  }

  const handleLeave = () => {
    nuiPost('leaveOrg')
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Heat lock warning */}
      {isLocked && (
        <div className="bg-red-900/30 border border-red-700/50 rounded-xl px-4 py-3">
          <span className="text-red-300 text-sm font-medium">
            ⚠ Vault Locked — Heat is maxed out. Lay low until heat drops below 91.
          </span>
        </div>
      )}

      {/* Vault balance */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-5 text-center">
        <div className="text-xs text-zinc-500 uppercase tracking-wider mb-1">Org Vault Balance</div>
        <div className="text-3xl font-bold font-mono text-green-400">{formatMoneyFull(org.vault)}</div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {/* Deposit */}
        <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
          <h3 className="text-sm font-semibold text-white">Deposit Cash</h3>
          <Input
            label="Amount"
            type="number"
            min={1}
            value={depositAmount}
            onChange={e => setDepositAmount(e.target.value)}
            placeholder="Enter amount..."
          />
          <Button
            variant="success"
            disabled={!depositAmount || Number(depositAmount) <= 0}
            onClick={handleDeposit}
            className="w-full justify-center"
          >
            Deposit
          </Button>
        </div>

        {/* Withdraw */}
        <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
          <h3 className="text-sm font-semibold text-white">Withdraw Cash</h3>
          {rankData.canWithdraw ? (
            <>
              <div className="text-xs text-zinc-500">
                Daily limit: {rankData.daily >= 999999999 ? 'Unlimited' : formatMoney(rankData.daily)}
              </div>
              <Input
                label="Amount"
                type="number"
                min={1}
                value={withdrawAmount}
                onChange={e => setWithdrawAmount(e.target.value)}
                placeholder="Enter amount..."
                disabled={isLocked}
              />
              <Button
                variant="danger"
                disabled={isLocked || !withdrawAmount || Number(withdrawAmount) <= 0}
                onClick={handleWithdraw}
                className="w-full justify-center"
              >
                Withdraw
              </Button>
            </>
          ) : (
            <div className="text-sm text-zinc-500 italic mt-2">
              Your rank ({RANK_NAMES[myRank]}) cannot withdraw. Earn trust first.
            </div>
          )}
        </div>
      </div>

      {/* Stash */}
      <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex items-center justify-between">
        <div>
          <div className="text-sm font-semibold text-white">Organization Stash</div>
          <div className="text-xs text-zinc-500 mt-0.5">
            {myRank >= 2 ? 'Access the shared inventory locker at this office.' : 'Rank Soldat or higher required to access.'}
          </div>
        </div>
        <Button
          variant="outline"
          disabled={myRank < 2}
          onClick={handleStash}
        >
          Open Stash
        </Button>
      </div>

      {/* Leave org */}
      {myRank < 5 && (
        <div className="bg-surface-2 border border-red-500/10 rounded-xl p-4 flex items-center justify-between">
          <div>
            <div className="text-sm font-semibold text-red-400">Leave Organization</div>
            <div className="text-xs text-zinc-500 mt-0.5">You will lose all rank and access.</div>
          </div>
          <Button variant="danger" onClick={handleLeave}>Leave</Button>
        </div>
      )}
    </div>
  )
}
