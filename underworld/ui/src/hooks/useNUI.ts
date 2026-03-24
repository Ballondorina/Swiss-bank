// ============================================================
// UNDERWORLD — NUI Message Listener Hook
// ============================================================

import { useEffect } from 'react'
import { useOrgStore } from '../store/orgStore'
import type { OrgData, CreationFees } from '../types/org'

interface NUIMessage {
  action: string
  data?: unknown
}

export function useNUI() {
  const {
    setIsOpen, setData, setActiveTab,
    setCreationOpen, setCreationFees,
    setCreationLoading, setCreationError,
  } = useOrgStore()

  useEffect(() => {
    const handler = (event: MessageEvent<NUIMessage>) => {
      const { action, data } = event.data

      switch (action) {
        case 'openPanel':
          if (data) {
            setData(data as OrgData)
            setActiveTab('overview')
            setIsOpen(true)
          }
          break

        case 'closePanel':
          setIsOpen(false)
          setData(null)
          break

        case 'openCreation':
          setCreationFees(data as CreationFees)
          setCreationLoading(false)
          setCreationError(null)
          setCreationOpen(true)
          break

        case 'creationSuccess':
          setCreationLoading(false)
          setCreationOpen(false)
          break

        case 'creationFailed':
          setCreationLoading(false)
          setCreationError('Creation failed. Check your details and try again.')
          break
      }
    }

    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [setIsOpen, setData, setActiveTab, setCreationOpen, setCreationFees, setCreationLoading, setCreationError])
}
