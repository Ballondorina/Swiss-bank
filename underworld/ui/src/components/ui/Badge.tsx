// ============================================================
// UNDERWORLD — Badge Component
// ============================================================

import type { OrgType, MissionStatus, HeatLabel } from '../../types/org'

interface BadgeProps {
  children: React.ReactNode
  color?: string
  className?: string
}

export function Badge({ children, color, className = '' }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${className}`}
      style={color ? { backgroundColor: `${color}22`, color, border: `1px solid ${color}44` } : undefined}
    >
      {children}
    </span>
  )
}

const TYPE_COLOR: Record<OrgType, string> = {
  legal:   '#2196F3',
  illegal: '#F44336',
  family:  '#9C27B0',
}

const TYPE_LABEL: Record<OrgType, string> = {
  legal:   'Corporation',
  illegal: 'Organization',
  family:  'Family',
}

export function OrgTypeBadge({ type }: { type: OrgType }) {
  return <Badge color={TYPE_COLOR[type]}>{TYPE_LABEL[type]}</Badge>
}

const STATUS_STYLES: Record<MissionStatus, string> = {
  pending:   'bg-zinc-700/50 text-zinc-300 border border-zinc-600/40',
  active:    'bg-amber-500/20 text-amber-300 border border-amber-500/40',
  completed: 'bg-green-500/20 text-green-300 border border-green-500/40',
  failed:    'bg-red-500/20 text-red-400 border border-red-500/40',
  expired:   'bg-zinc-800/50 text-zinc-500 border border-zinc-700/30',
}

const STATUS_LABELS: Record<MissionStatus, string> = {
  pending:   'Available',
  active:    'Active',
  completed: 'Done',
  failed:    'Failed',
  expired:   'Expired',
}

export function MissionStatusBadge({ status }: { status: MissionStatus }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${STATUS_STYLES[status]}`}>
      {STATUS_LABELS[status]}
    </span>
  )
}

const HEAT_STYLES: Record<HeatLabel, string> = {
  normal:   'bg-green-500/20 text-green-300 border border-green-500/40',
  elevated: 'bg-amber-500/20 text-amber-300 border border-amber-500/40',
  hot:      'bg-red-500/20 text-red-400 border border-red-500/40',
  burned:   'bg-red-900/40 text-red-300 border border-red-800/60',
}

const HEAT_LABELS: Record<HeatLabel, string> = {
  normal:   'Normal',
  elevated: 'Elevated',
  hot:      'HOT',
  burned:   'BURNED',
}

export function HeatBadge({ label }: { label: HeatLabel }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${HEAT_STYLES[label]}`}>
      {HEAT_LABELS[label]}
    </span>
  )
}

const RANK_COLORS = ['', '#9e9e9e', '#4caf50', '#2196F3', '#9C27B0', '#f7c948']

export function RankBadge({ rank, name }: { rank: number; name: string }) {
  const color = RANK_COLORS[rank] ?? '#9e9e9e'
  return <Badge color={color}>{name}</Badge>
}
