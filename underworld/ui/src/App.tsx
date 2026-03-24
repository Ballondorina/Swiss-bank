// ============================================================
// UNDERWORLD — App Root
// ============================================================

import { useNUI } from './hooks/useNUI'
import { useOrgStore } from './store/orgStore'
import { Panel } from './components/layout/Panel'
import { CreateOrgModal } from './components/modals/CreateOrg'

export default function App() {
  useNUI()

  const isOpen = useOrgStore(s => s.isOpen)
  const isCreationOpen = useOrgStore(s => s.isCreationOpen)

  return (
    <>
      {isOpen && <Panel />}
      {isCreationOpen && <CreateOrgModal />}
    </>
  )
}
