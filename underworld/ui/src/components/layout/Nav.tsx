// ============================================================
// UNDERWORLD — Tab Navigation (v3)
// ============================================================

import { useState } from 'react'
import { useOrgStore, type Tab } from '../../store/orgStore'
import { nuiPost } from '../../lib/utils'

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'overview',     label: 'Overview',    icon: '⬡' },
  { id: 'members',      label: 'Members',     icon: '◈' },
  { id: 'missions',     label: 'Missions',    icon: '◎' },
  { id: 'territory',    label: 'Territory',   icon: '⊕' },
  { id: 'operations',   label: 'Ops',         icon: '◆' },
  { id: 'vault',        label: 'Vault',       icon: '◇' },
  { id: 'ledger',       label: 'Ledger',      icon: '≡' },
  { id: 'leaderboard',  label: 'Rankings',    icon: '△' },
  { id: 'settings',     label: 'Settings',    icon: '⚙' },
]

export function Nav() {
  const activeTab  = useOrgStore(s => s.activeTab)
  const setActiveTab = useOrgStore(s => s.setActiveTab)
  const [refreshing, setRefreshing] = useState(false)

  const handleRefresh = () => {
    if (refreshing) return
    setRefreshing(true)
    nuiPost('refreshPanel')
    setTimeout(() => setRefreshing(false), 2000)
  }

  return (
    <div className="flex items-center gap-0.5 px-4 border-b border-white/5 bg-surface-1">
      <div className="flex gap-0.5 flex-1">
        {TABS.map(tab => {
          const active = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`
                flex items-center gap-1.5 px-3 py-3 text-sm font-medium transition-all duration-150
                border-b-2 -mb-px
                ${active
                  ? 'border-accent text-white'
                  : 'border-transparent text-zinc-500 hover:text-zinc-300 hover:border-zinc-600'
                }
              `}
            >
              <span className="text-base leading-none">{tab.icon}</span>
              <span>{tab.label}</span>
            </button>
          )
        })}
      </div>

      {/* Refresh button */}
      <button
        onClick={handleRefresh}
        disabled={refreshing}
        className={`
          w-8 h-8 flex items-center justify-center rounded-lg text-sm
          transition-all duration-150
          ${refreshing
            ? 'text-accent animate-spin'
            : 'text-zinc-500 hover:text-zinc-300 hover:bg-surface-3'
          }
        `}
        title="Refresh data"
      >
        ↻
      </button>
    </div>
  )
}
