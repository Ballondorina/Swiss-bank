// ============================================================
// UNDERWORLD — Main Panel Container (v3)
// ============================================================

import { useOrgStore } from '../../store/orgStore'
import { Header } from './Header'
import { Nav } from './Nav'
import { Overview } from '../tabs/Overview'
import { Members } from '../tabs/Members'
import { Missions } from '../tabs/Missions'
import { Territory } from '../tabs/Territory'
import { Vault } from '../tabs/Vault'
import { Ledger } from '../tabs/Ledger'
import { Leaderboard } from '../tabs/Leaderboard'
import { Operations } from '../tabs/Operations'
import { Settings } from '../tabs/Settings'

const TAB_COMPONENTS = {
  overview:    Overview,
  members:     Members,
  missions:    Missions,
  territory:   Territory,
  operations:  Operations,
  vault:       Vault,
  ledger:      Ledger,
  leaderboard: Leaderboard,
  settings:    Settings,
}

export function Panel() {
  const isOpen   = useOrgStore(s => s.isOpen)
  const data     = useOrgStore(s => s.data)
  const activeTab = useOrgStore(s => s.activeTab)

  if (!isOpen || !data) return null

  const TabComponent = TAB_COMPONENTS[activeTab] ?? Overview

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 animate-fade-in">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />

      {/* Panel */}
      <div className="relative w-[960px] max-w-[95vw] h-[640px] max-h-[90vh] bg-surface-1 border border-white/8 rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-slide-up">
        <Header />
        <Nav />
        <div className="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-zinc-700 scrollbar-track-transparent p-5">
          <TabComponent />
        </div>
      </div>
    </div>
  )
}
