// ============================================================
// UNDERWORLD — Settings Tab (v3)
// Tier Upgrade, Announcements, Diplomacy, Votes
// ============================================================

import { useState } from 'react'
import { useOrgStore } from '../../store/orgStore'
import { Button } from '../ui/Button'
import { formatMoney, formatDateTime, nuiPost } from '../../lib/utils'
import { TIER_NAMES, RANK_NAMES, VOTE_TYPE_LABELS, TYPE_COLORS } from '../../types/org'
import type { OrgType } from '../../types/org'

export function Settings() {
  const data = useOrgStore(s => s.data)
  if (!data) return null

  const { org, myRank, announcements, diplomacy, votes, tierUpgradeCost } = data
  const isDirektor = myRank === 5
  const isOfficer  = myRank >= 4

  return (
    <div className="flex flex-col gap-5">
      {/* Tier Upgrade */}
      <TierUpgradeSection org={org} isDirektor={isDirektor} tierUpgradeCost={tierUpgradeCost} />

      {/* Announcements */}
      <AnnouncementsSection announcements={announcements ?? []} isOfficer={isOfficer} />

      {/* Diplomacy */}
      <DiplomacySection diplomacy={diplomacy} isDirektor={isDirektor} orgId={org.id} />

      {/* Votes */}
      <VotesSection votes={votes} myRank={myRank} orgId={org.id} />
    </div>
  )
}

// ============================================================
// TIER UPGRADE
// ============================================================

function TierUpgradeSection({ org, isDirektor, tierUpgradeCost }: {
  org: { tier: number; vault: number; level: number }
  isDirektor: boolean
  tierUpgradeCost: number | null
}) {
  const [confirming, setConfirming] = useState(false)

  const handleUpgrade = () => {
    if (!confirming) { setConfirming(true); return }
    nuiPost('upgradeTier')
    setConfirming(false)
  }

  const nextTierName = TIER_NAMES[org.tier + 1]
  const currentName  = TIER_NAMES[org.tier] ?? `Tier ${org.tier}`
  const canAfford    = tierUpgradeCost !== null && org.vault >= tierUpgradeCost
  const hasDiscount  = org.level >= 8

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
      <h3 className="text-sm font-semibold text-white">Tier Upgrade</h3>

      {tierUpgradeCost !== null && nextTierName ? (
        <>
          <div className="flex items-center justify-between text-sm">
            <span className="text-zinc-400">
              {currentName} → <span className="text-white font-medium">{nextTierName}</span>
            </span>
            <div className="text-right">
              <span className="font-mono font-bold text-amber-400">{formatMoney(tierUpgradeCost)}</span>
              {hasDiscount && <span className="text-xs text-green-400 ml-1">(10% discount)</span>}
            </div>
          </div>
          <div className="text-xs text-zinc-500">
            Upgrading increases member cap, stash size, mission availability, and passive income ceiling.
          </div>
          {isDirektor ? (
            <div className="flex items-center gap-2">
              <Button
                variant={confirming ? 'danger' : 'primary'}
                size="sm"
                disabled={!canAfford}
                onClick={handleUpgrade}
              >
                {confirming ? 'Confirm Upgrade' : 'Upgrade Tier'}
              </Button>
              {confirming && (
                <Button size="sm" variant="ghost" onClick={() => setConfirming(false)}>Cancel</Button>
              )}
              {!canAfford && (
                <span className="text-xs text-red-400">Insufficient vault funds</span>
              )}
            </div>
          ) : (
            <span className="text-xs text-zinc-500 italic">Only the Direktor can upgrade the tier.</span>
          )}
        </>
      ) : (
        <span className="text-sm text-green-400 font-medium">Maximum tier reached.</span>
      )}
    </div>
  )
}

// ============================================================
// ANNOUNCEMENTS
// ============================================================

function AnnouncementsSection({ announcements, isOfficer }: {
  announcements: { id: number; content: string; author_name: string; pinned: boolean | number; created_at: string }[]
  isOfficer: boolean
}) {
  const [newContent, setNewContent] = useState('')
  const [pinNew, setPinNew] = useState(false)

  const handlePost = () => {
    if (!newContent.trim()) return
    nuiPost('postAnnouncement', { content: newContent.trim(), pinned: pinNew })
    setNewContent('')
    setPinNew(false)
  }

  const handleDelete = (id: number) => {
    nuiPost('deleteAnnouncement', { id })
  }

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
      <h3 className="text-sm font-semibold text-white">Announcements</h3>

      {/* Post new */}
      {isOfficer && (
        <div className="flex flex-col gap-2 border-b border-white/5 pb-3">
          <textarea
            value={newContent}
            onChange={e => setNewContent(e.target.value)}
            placeholder="Write an announcement..."
            maxLength={500}
            rows={2}
            className="w-full bg-surface-3 border border-white/8 rounded-lg px-3 py-2 text-sm text-white placeholder-zinc-600 outline-none focus:border-accent/60 resize-none"
          />
          <div className="flex items-center gap-3">
            <label className="flex items-center gap-1.5 text-xs text-zinc-400 cursor-pointer">
              <input
                type="checkbox"
                checked={pinNew}
                onChange={e => setPinNew(e.target.checked)}
                className="rounded bg-surface-3 border-white/20"
              />
              Pin this announcement
            </label>
            <div className="flex-1" />
            <span className="text-xs text-zinc-600">{newContent.length}/500</span>
            <Button size="sm" variant="primary" disabled={!newContent.trim()} onClick={handlePost}>
              Post
            </Button>
          </div>
        </div>
      )}

      {/* List */}
      {announcements.length === 0 ? (
        <span className="text-sm text-zinc-500 italic">No announcements yet.</span>
      ) : (
        <div className="flex flex-col gap-2 max-h-48 overflow-y-auto scrollbar-thin">
          {announcements.map(a => (
            <div
              key={a.id}
              className={`flex items-start gap-2 p-2 rounded-lg ${
                a.pinned ? 'bg-accent/5 border border-accent/20' : 'bg-surface-3/50'
              }`}
            >
              {a.pinned ? <span className="text-accent text-xs mt-0.5 flex-shrink-0">PIN</span> : null}
              <div className="flex-1 min-w-0">
                <p className="text-sm text-zinc-200">{a.content}</p>
                <p className="text-xs text-zinc-600 mt-0.5">— {a.author_name}, {formatDateTime(a.created_at)}</p>
              </div>
              {isOfficer && (
                <button
                  onClick={() => handleDelete(a.id)}
                  className="text-xs text-zinc-600 hover:text-red-400 flex-shrink-0"
                >
                  x
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ============================================================
// DIPLOMACY — Wars + Alliances
// ============================================================

function DiplomacySection({ diplomacy, isDirektor, orgId }: {
  diplomacy: {
    wars: any[]
    recentWars: any[]
    alliances: any[]
    allOrgs: { id: number; label: string; type: OrgType; tier: number; level: number }[]
  }
  isDirektor: boolean
  orgId: number
}) {
  const [showWarPicker, setShowWarPicker] = useState(false)
  const [showAlliancePicker, setShowAlliancePicker] = useState(false)

  if (!diplomacy) return null

  const { wars, recentWars, alliances, allOrgs } = diplomacy
  const activeWars = wars?.filter(w => w.status === 'active') ?? []
  const pendingWars = wars?.filter(w => w.status === 'pending') ?? []
  const activeAlliances = alliances?.filter(a => a.status === 'active') ?? []
  const pendingAlliances = alliances?.filter(a => a.status === 'pending') ?? []

  // Pending wars where we are the defender
  const incomingWars = pendingWars.filter(w => w.defender_org_id === orgId)
  // Pending alliances where we are NOT the initiator
  const incomingAlliances = pendingAlliances.filter(a => a.initiated_by !== orgId)

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-4">
      <h3 className="text-sm font-semibold text-white">Diplomacy</h3>

      {/* Active Wars */}
      {activeWars.length > 0 && (
        <div className="flex flex-col gap-2">
          <span className="text-xs text-red-400 uppercase tracking-wider font-semibold">Active Wars</span>
          {activeWars.map(w => {
            const isAttacker = w.attacker_org_id === orgId
            const enemyLabel = isAttacker ? w.defender_label : w.attacker_label
            const myScore = isAttacker ? w.score_attacker : w.score_defender
            const theirScore = isAttacker ? w.score_defender : w.score_attacker

            return (
              <div key={w.id} className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 flex items-center justify-between">
                <div>
                  <span className="text-sm text-white font-medium">vs {enemyLabel}</span>
                  <div className="text-xs text-zinc-500 mt-0.5">
                    Score: <span className="text-green-400">{myScore}</span> - <span className="text-red-400">{theirScore}</span>
                    {w.ends_at && ` | Ends: ${formatDateTime(w.ends_at)}`}
                  </div>
                </div>
                {isDirektor && (
                  <Button size="sm" variant="danger" onClick={() => nuiPost('surrender')}>
                    Surrender
                  </Button>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* Incoming war declarations */}
      {incomingWars.length > 0 && (
        <div className="flex flex-col gap-2">
          <span className="text-xs text-amber-400 uppercase tracking-wider font-semibold">Incoming War Declarations</span>
          {incomingWars.map(w => (
            <div key={w.id} className="bg-amber-500/10 border border-amber-500/20 rounded-lg px-3 py-2 flex items-center justify-between">
              <span className="text-sm text-white">{w.attacker_label} declares war</span>
              {isDirektor && (
                <div className="flex gap-2">
                  <Button size="sm" variant="danger" onClick={() => nuiPost('respondWar', { warId: w.id, accept: true })}>
                    Accept
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => nuiPost('respondWar', { warId: w.id, accept: false })}>
                    Reject
                  </Button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Active Alliances */}
      {activeAlliances.length > 0 && (
        <div className="flex flex-col gap-2">
          <span className="text-xs text-blue-400 uppercase tracking-wider font-semibold">Active Alliances</span>
          {activeAlliances.map(a => {
            const allyLabel = a.org_id_1 === orgId ? a.org2_label : a.org1_label
            return (
              <div key={a.id} className="bg-blue-500/10 border border-blue-500/20 rounded-lg px-3 py-2 flex items-center justify-between">
                <span className="text-sm text-white">Allied with {allyLabel}</span>
                {isDirektor && (
                  <Button size="sm" variant="ghost" onClick={() => nuiPost('dissolveAlliance', { allianceId: a.id })}>
                    Dissolve
                  </Button>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* Incoming alliance proposals */}
      {incomingAlliances.length > 0 && (
        <div className="flex flex-col gap-2">
          <span className="text-xs text-blue-400 uppercase tracking-wider font-semibold">Alliance Proposals</span>
          {incomingAlliances.map(a => {
            const fromLabel = a.initiated_by === a.org_id_1 ? a.org1_label : a.org2_label
            return (
              <div key={a.id} className="bg-blue-500/10 border border-blue-500/20 rounded-lg px-3 py-2 flex items-center justify-between">
                <span className="text-sm text-white">{fromLabel} proposes alliance</span>
                {isDirektor && (
                  <div className="flex gap-2">
                    <Button size="sm" variant="primary" onClick={() => nuiPost('respondAlliance', { allianceId: a.id, accept: true })}>
                      Accept
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => nuiPost('respondAlliance', { allianceId: a.id, accept: false })}>
                      Reject
                    </Button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* Recent wars */}
      {recentWars && recentWars.length > 0 && (
        <div className="flex flex-col gap-1">
          <span className="text-xs text-zinc-600 uppercase tracking-wider font-semibold">Recent Wars</span>
          {recentWars.map(w => {
            const won = w.winner_org_id === orgId
            return (
              <div key={w.id} className="flex items-center gap-2 text-xs text-zinc-500">
                <span className={won ? 'text-green-400' : 'text-red-400'}>{won ? 'W' : 'L'}</span>
                <span>vs {w.attacker_org_id === orgId ? w.defender_label : w.attacker_label}</span>
                <span>({w.score_attacker}-{w.score_defender})</span>
              </div>
            )
          })}
        </div>
      )}

      {/* Action buttons */}
      {isDirektor && (
        <div className="flex gap-2 border-t border-white/5 pt-3">
          {!showWarPicker && !showAlliancePicker && (
            <>
              <Button size="sm" variant="danger" onClick={() => setShowWarPicker(true)} disabled={activeWars.length > 0}>
                Declare War
              </Button>
              <Button size="sm" variant="outline" onClick={() => setShowAlliancePicker(true)}>
                Propose Alliance
              </Button>
            </>
          )}

          {showWarPicker && (
            <OrgPicker
              orgs={allOrgs}
              label="Declare war on:"
              onSelect={(id) => { nuiPost('declareWar', { targetOrgId: id }); setShowWarPicker(false) }}
              onCancel={() => setShowWarPicker(false)}
              variant="danger"
            />
          )}

          {showAlliancePicker && (
            <OrgPicker
              orgs={allOrgs}
              label="Propose alliance to:"
              onSelect={(id) => { nuiPost('proposeAlliance', { targetOrgId: id }); setShowAlliancePicker(false) }}
              onCancel={() => setShowAlliancePicker(false)}
              variant="primary"
            />
          )}
        </div>
      )}

      {activeWars.length === 0 && activeAlliances.length === 0 && incomingWars.length === 0 && incomingAlliances.length === 0 && (!recentWars || recentWars.length === 0) && (
        <span className="text-sm text-zinc-500 italic">No active diplomatic relations.</span>
      )}
    </div>
  )
}

function OrgPicker({ orgs, label, onSelect, onCancel, variant }: {
  orgs: { id: number; label: string; type: OrgType; tier: number }[]
  label: string
  onSelect: (id: number) => void
  onCancel: () => void
  variant: 'primary' | 'danger'
}) {
  const [selected, setSelected] = useState<number | null>(null)

  return (
    <div className="flex items-center gap-2 flex-wrap">
      <span className="text-xs text-zinc-400">{label}</span>
      <select
        value={selected ?? ''}
        onChange={e => setSelected(Number(e.target.value))}
        className="bg-surface-3 border border-white/10 rounded px-2 py-1 text-xs text-white max-w-[200px]"
      >
        <option value="">Select org...</option>
        {orgs.map(o => (
          <option key={o.id} value={o.id}>{o.label} ({TIER_NAMES[o.tier] ?? `T${o.tier}`})</option>
        ))}
      </select>
      <Button size="sm" variant={variant} disabled={!selected} onClick={() => selected && onSelect(selected)}>
        Confirm
      </Button>
      <Button size="sm" variant="ghost" onClick={onCancel}>Cancel</Button>
    </div>
  )
}

// ============================================================
// VOTES
// ============================================================

function VotesSection({ votes, myRank, orgId }: {
  votes: {
    active: any[]
    recent: any[]
    myVotes: Record<string, string | null>
  }
  myRank: number
  orgId: number
}) {
  const [showInitiate, setShowInitiate] = useState(false)
  const [voteType, setVoteType] = useState('kick_member')
  const [voteDesc, setVoteDesc] = useState('')

  if (!votes) return null

  const handleInitiate = () => {
    if (!voteDesc.trim()) return
    nuiPost('initiateVote', { voteType, description: voteDesc.trim() })
    setShowInitiate(false)
    setVoteDesc('')
  }

  const handleCastVote = (voteId: number, voteFor: boolean) => {
    nuiPost('castVote', { voteId, voteFor })
  }

  return (
    <div className="bg-surface-2 border border-white/5 rounded-xl p-4 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-white">Org Votes</h3>
        {myRank >= 3 && !showInitiate && (
          <Button size="sm" variant="outline" onClick={() => setShowInitiate(true)}>
            New Vote
          </Button>
        )}
      </div>

      {/* Initiate vote form */}
      {showInitiate && (
        <div className="flex flex-col gap-2 border-b border-white/5 pb-3">
          <div className="flex gap-2">
            <select
              value={voteType}
              onChange={e => setVoteType(e.target.value)}
              className="bg-surface-3 border border-white/10 rounded px-2 py-1 text-xs text-white"
            >
              {Object.entries(VOTE_TYPE_LABELS).map(([key, label]) => (
                <option key={key} value={key}>{label}</option>
              ))}
            </select>
            <input
              type="text"
              value={voteDesc}
              onChange={e => setVoteDesc(e.target.value)}
              placeholder="Description..."
              className="flex-1 bg-surface-3 border border-white/8 rounded px-2 py-1 text-xs text-white placeholder-zinc-600 outline-none"
            />
          </div>
          <div className="flex gap-2">
            <Button size="sm" variant="primary" disabled={!voteDesc.trim()} onClick={handleInitiate}>
              Start Vote
            </Button>
            <Button size="sm" variant="ghost" onClick={() => setShowInitiate(false)}>Cancel</Button>
          </div>
        </div>
      )}

      {/* Active votes */}
      {votes.active && votes.active.length > 0 ? (
        <div className="flex flex-col gap-2">
          {votes.active.map(v => {
            const label = VOTE_TYPE_LABELS[v.type] ?? v.type
            const myVote = votes.myVotes[String(v.id)]
            const total = v.votes_for + v.votes_against
            const pct = v.total_eligible > 0 ? Math.round((v.votes_for / v.total_eligible) * 100) : 0

            return (
              <div key={v.id} className="bg-surface-3/50 rounded-lg px-3 py-2 flex flex-col gap-2">
                <div className="flex items-center justify-between">
                  <div>
                    <span className="text-sm text-white font-medium">{label}</span>
                    {v.description && <span className="text-xs text-zinc-500 ml-2">{v.description}</span>}
                  </div>
                  <span className="text-xs text-zinc-500">{total}/{v.total_eligible} voted</span>
                </div>

                {/* Vote bar */}
                <div className="w-full bg-surface-4 rounded-full h-1.5">
                  <div
                    className="h-full rounded-full bg-green-500 transition-all"
                    style={{ width: `${pct}%` }}
                  />
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-xs text-zinc-500">
                    For: {v.votes_for} | Against: {v.votes_against}
                  </span>
                  {myVote ? (
                    <span className="text-xs text-zinc-400">You voted: {myVote}</span>
                  ) : (
                    <div className="flex gap-1.5">
                      <Button size="sm" variant="success" onClick={() => handleCastVote(v.id, true)}>For</Button>
                      <Button size="sm" variant="danger" onClick={() => handleCastVote(v.id, false)}>Against</Button>
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      ) : (
        <span className="text-sm text-zinc-500 italic">No active votes.</span>
      )}

      {/* Recent votes */}
      {votes.recent && votes.recent.length > 0 && (
        <div className="flex flex-col gap-1 mt-1">
          <span className="text-xs text-zinc-600 uppercase tracking-wider">Recent</span>
          {votes.recent.map(v => (
            <div key={v.id} className="flex items-center gap-2 text-xs text-zinc-500">
              <span className={v.status === 'passed' ? 'text-green-400' : 'text-red-400'}>
                {v.status === 'passed' ? 'PASSED' : 'FAILED'}
              </span>
              <span>{VOTE_TYPE_LABELS[v.type] ?? v.type}</span>
              <span>({v.votes_for}-{v.votes_against})</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
