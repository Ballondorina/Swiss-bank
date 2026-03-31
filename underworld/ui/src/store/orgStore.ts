// ============================================================
// UNDERWORLD — Zustand Store (v3)
// ============================================================

import { create } from 'zustand'
import type { OrgData, CreationFees } from '../types/org'

export type Tab = 'overview' | 'members' | 'missions' | 'territory' | 'vault' | 'ledger' | 'leaderboard' | 'operations' | 'settings'

interface OrgStore {
  // Panel state
  isOpen: boolean
  data: OrgData | null
  activeTab: Tab
  setIsOpen: (open: boolean) => void
  setData: (data: OrgData | null) => void
  setActiveTab: (tab: Tab) => void

  // Creation modal state
  isCreationOpen: boolean
  creationFees: CreationFees | null
  creationLoading: boolean
  creationError: string | null
  setCreationOpen: (open: boolean) => void
  setCreationFees: (fees: CreationFees) => void
  setCreationLoading: (loading: boolean) => void
  setCreationError: (error: string | null) => void
}

export const useOrgStore = create<OrgStore>((set) => ({
  isOpen:    false,
  data:      null,
  activeTab: 'overview',
  setIsOpen:    (open) => set({ isOpen: open }),
  setData:      (data) => set({ data }),
  setActiveTab: (tab)  => set({ activeTab: tab }),

  isCreationOpen:  false,
  creationFees:    null,
  creationLoading: false,
  creationError:   null,
  setCreationOpen:    (open)    => set({ isCreationOpen: open }),
  setCreationFees:    (fees)    => set({ creationFees: fees }),
  setCreationLoading: (loading) => set({ creationLoading: loading }),
  setCreationError:   (error)   => set({ creationError: error }),
}))
