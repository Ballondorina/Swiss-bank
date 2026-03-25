// ============================================================
// UNDERWORLD — TypeScript Types (v3)
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

// v3: Announcements
export interface Announcement {
  id: number
  org_id: number
  author_cid: string
  author_name: string
  content: string
  pinned: boolean | number
  created_at: string
}

// v3: War System
export interface War {
  id: number
  attacker_org_id: number
  defender_org_id: number
  status: 'pending' | 'active' | 'ended' | 'rejected'
  score_attacker: number
  score_defender: number
  winner_org_id: number | null
  attacker_label?: string
  attacker_type?: string
  defender_label?: string
  defender_type?: string
  started_at: string | null
  ends_at: string | null
  ended_at: string | null
}

// v3: Alliance System
export interface Alliance {
  id: number
  org_id_1: number
  org_id_2: number
  status: 'pending' | 'active' | 'dissolved'
  initiated_by: number
  org1_label?: string
  org1_type?: string
  org2_label?: string
  org2_type?: string
  created_at: string
}

export interface DiplomacyData {
  wars: War[]
  recentWars: War[]
  alliances: Alliance[]
  allOrgs: { id: number; label: string; type: OrgType; tier: number; level: number }[]
}

// v3: Vote System
export interface Vote {
  id: number
  org_id: number
  type: string
  target_citizen: string | null
  initiated_by: string
  votes_for: number
  votes_against: number
  total_eligible: number
  status: 'active' | 'passed' | 'failed'
  description: string | null
  created_at: string
  expires_at: string
}

export interface VotesData {
  active: Vote[]
  recent: Vote[]
  myVotes: Record<string, string | null>  // voteId -> 'for'|'against'|null
}

// Operations: Drug Labs
export interface DrugLab {
  id: number
  org_id: number
  location_id: number
  type: string
  type_label: string
  stock: number
  max_stock: number
  status: 'active' | 'shutdown' | 'raided'
  production_rate: number  // units/tick
}

export interface LabLocation {
  id: number
  label: string
  type: string
  type_label: string
  coords: { x: number; y: number; z: number }
  purchase_cost: number
  production_rate: number
  max_stock: number
  available: boolean
}

export interface SellPoint {
  id: string
  label: string
  coords: { x: number; y: number; z: number }
}

export interface LabData {
  labs: DrugLab[]
  availableLocations: LabLocation[]
  sellPoints: SellPoint[]
  maxLabs: number
}

// Operations: Store Robbery
export interface RobberyStore {
  id: number
  label: string
  coords: { x: number; y: number; z: number }
}

export interface RobberyLog {
  id: number
  store_id: number
  payout: number
  robbed_at: string
}

export interface RobberyData {
  cooldownLeft: number
  stores: RobberyStore[]
  recentRobberies: RobberyLog[]
  payoutMin: number
  payoutMax: number
  cooldownSecs: number
}

// Operations: War Window
export interface WarWindow {
  enabled: boolean
  active: boolean
  startHour?: number
  endHour?: number
  activeDays?: number[]
  nextStart?: number
}

export interface OrgData {
  org: Org
  members: Member[]
  ledger: LedgerEntry[]
  missions: Mission[]
  influence: InfluenceZone[]
  leaderboard: Leaderboard
  announcements: Announcement[]
  diplomacy: DiplomacyData
  votes: VotesData
  tierUpgradeCost: number | null
  myRank: number
  myCitizenId: string
  myCooldownEnds: number  // unix timestamp
  labData?: LabData
  robberyData?: RobberyData
  warWindow?: WarWindow
}

export interface CreationFees {
  fees: Record<OrgType, number>
  requiresApproval: boolean
  orgTypes: Record<OrgType, string>
}

export const RANK_NAMES: Record<number, string> = {
  1: 'Associe',
  2: 'Soldat',
  3: 'Kapten',
  4: 'Underdirektor',
  5: 'Direktor',
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

export const VOTE_TYPE_LABELS: Record<string, string> = {
  kick_member:    'Kick Member',
  promote_member: 'Promote Member',
  declare_war:    'Declare War',
  form_alliance:  'Form Alliance',
  tier_upgrade:   'Tier Upgrade',
}
