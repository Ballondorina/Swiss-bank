// ============================================================
// UNDERWORLD — Tab Navigation
// ============================================================

import { useOrgStore } from '../../store/orgStore'

type Tab = 'overview' | 'members' | 'missions' | 'territory' | 'vault' | 'ledger' | 'leaderboard'

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'overview',     label: 'Overview',    icon: '⬡' },
  { id: 'members',      label: 'Members',     icon: '◈' },
  { id: 'missions',     label: 'Missions',    icon: '◎' },
  { id: 'territory',    label: 'Territory',   icon: '⊕' },
  { id: 'vault',        label: 'Vault',       icon: '◇' },
  { id: 'ledger',       label: 'Ledger',      icon: '≡' },
  { id: 'leaderboard',  label: 'Rankings',    icon: '△' },
]

export function Nav() {
  const activeTab  = useOrgStore(s => s.activeTab)
  const setActiveTab = useOrgStore(s => s.setActiveTab)

  return (
    <div className="flex gap-0.5 px-4 border-b border-white/5 bg-surface-1">
      {TABS.map(tab => {
        const active = activeTab === tab.id
        return (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as Tab)}
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
  )
}
