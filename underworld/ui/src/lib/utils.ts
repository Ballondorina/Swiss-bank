// ============================================================
// UNDERWORLD — Utility Functions
// ============================================================

export function formatMoney(amount: number): string {
  if (Math.abs(amount) >= 1_000_000) {
    return `$${(amount / 1_000_000).toFixed(1)}M`
  }
  if (Math.abs(amount) >= 1_000) {
    return `$${(amount / 1_000).toFixed(1)}K`
  }
  return `$${amount.toLocaleString()}`
}

export function formatMoneyFull(amount: number): string {
  return `$${Math.abs(amount).toLocaleString()}`
}

export function formatDate(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  } catch {
    return dateStr
  }
}

export function formatDateTime(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    return d.toLocaleString('en-GB', {
      day: '2-digit', month: 'short',
      hour: '2-digit', minute: '2-digit'
    })
  } catch {
    return dateStr
  }
}

export function formatTimeRemaining(secondsLeft: number): string {
  if (secondsLeft <= 0) return ''
  const m = Math.floor(secondsLeft / 60)
  const s = secondsLeft % 60
  if (m > 0) return `${m}m ${s}s`
  return `${s}s`
}

export function formatCooldown(cooldownEnds: number): string {
  if (!cooldownEnds || cooldownEnds <= 0) return ''
  const now = Math.floor(Date.now() / 1000)
  const remaining = cooldownEnds - now
  if (remaining <= 0) return ''
  return formatTimeRemaining(remaining)
}

export function clamp(val: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, val))
}

export function xpPercent(xp: number, currentLevel: number, thresholds: Record<number, number>): number {
  const current = thresholds[currentLevel] ?? 0
  const next    = thresholds[currentLevel + 1]
  if (!next) return 100
  return clamp(((xp - current) / (next - current)) * 100, 0, 100)
}

// FiveM NUI fetch
export function nuiPost(endpoint: string, data?: Record<string, unknown>): Promise<unknown> {
  return fetch(`https://underworld/${endpoint}`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(data ?? {}),
  }).then(r => r.json()).catch(() => ({}))
}

// Dev mode mock
export const isDev = !('invokeNative' in window)
