// ============================================================
// UNDERWORLD — NUI POST Hook
// ============================================================

import { useCallback } from 'react'
import { nuiPost } from '../lib/utils'

export function usePost() {
  return useCallback(
    (endpoint: string, data?: Record<string, unknown>) => nuiPost(endpoint, data),
    []
  )
}
