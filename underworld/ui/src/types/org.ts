// ============================================================
// UNDERWORLD — TypeScript Types
// ============================================================

export type OrgType = 'legal' | 'illegal' | 'family'
export type HeatLabel = 'normal' | 'elevated' | 'hot' | 'burned'
export type MissionStatus = 'pending' | 'active' | 'completed' | 'failed' | 'expired'

export interface Org {
  id: number
  name: string
  label: string
  type: OrgType
  tier: number
  vault: number
  heat: number
  heatLabel: HeatLabel
  xp: number
  level: number
  nextLevelXp: number | null
}

export interface Member {
  citizen_id: string
  name: string
  rank: number
  division: string | null
  loyalty: number
  weekly_contribution: number
  total_contribution: number
  salary: number
}

export interface LedgerEntry {
  id: number
  citizen_id: string | null
  type: string
  amount: number
  description: string | null
  created_at: string
}

export interface Mission {
  id: number
  mission_type: string
  status: MissionStatus
  assigned_to: string | null
  reward: number
  zone_id: string | null
  expires_at: string
  completed_at: string | null
}

export interface InfluenceZone {
  zone_id: string
  label: string
  my_score: number
  is_owner: boolean
  is_contested: boolean
  passive_bonus: number
}

export interface LeaderboardEntry {
  org_id: number
  label: string
  type: OrgType
  value: number
}

export interface Leaderboard {
  earnings: LeaderboardEntry[]
  missions: LeaderboardEntry[]
  territory: LeaderboardEntry[]
}

export interface OrgData {
  org: Org
  members: Member[]
  ledger: LedgerEntry[]
  missions: Mission[]
  influence: InfluenceZone[]
  leaderboard: Leaderboard
  myRank: number
  myCitizenId: string
  myCooldownEnds: number  // unix timestamp
}

export interface CreationFees {
  fees: Record<OrgType, number>
  requiresApproval: boolean
  orgTypes: Record<OrgType, string>
}

export const RANK_NAMES: Record<number, string> = {
  1: 'Associé',
  2: 'Soldat',
  3: 'Kapten',
  4: 'Underdirektör',
  5: 'Direktör',
}

export const TIER_NAMES: Record<number, string> = {
  1: 'Street',
  2: 'Established',
  3: 'Syndicate',
  4: 'Empire',
}

export const TYPE_COLORS: Record<OrgType, string> = {
  legal:   '#2196F3',
  illegal: '#F44336',
  family:  '#9C27B0',
}

export const HEAT_COLORS: Record<HeatLabel, string> = {
  normal:   '#4caf50',
  elevated: '#ff9800',
  hot:      '#f44336',
  burned:   '#7f0000',
}
