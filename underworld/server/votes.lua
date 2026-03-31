-- ============================================================
-- UNDERWORLD — Server: Vote System
-- Activates the uw_votes table with full democratic governance
-- ============================================================

local VOTE_DURATION_HOURS = 24
local VOTE_TYPES = {
    kick_member      = { minRank = 3, label = 'Kick Member' },
    promote_member   = { minRank = 4, label = 'Promote Member' },
    declare_war      = { minRank = 4, label = 'Declare War' },
    form_alliance    = { minRank = 4, label = 'Form Alliance' },
    tier_upgrade     = { minRank = 4, label = 'Tier Upgrade' },
}

-- ============================================================
-- INITIATE VOTE
-- ============================================================

RegisterNetEvent('underworld:server:initiateVote', function(voteType, targetCitizen, description)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local vtConfig = VOTE_TYPES[voteType]
    if not vtConfig then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid vote type.' })
        return
    end

    if org.rank < vtConfig.minRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient rank to initiate this vote.' })
        return
    end

    -- Check no active vote of same type
    local existing = MySQL.scalar.await(
        'SELECT id FROM uw_votes WHERE org_id = ? AND type = ? AND status = "active"',
        { org.id, voteType }
    )
    if existing then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'A vote of this type is already active.' })
        return
    end

    local memberCount = MySQL.scalar.await('SELECT COUNT(*) FROM uw_members WHERE org_id = ?', { org.id }) or 0
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (VOTE_DURATION_HOURS * 3600))

    local voteId = MySQL.insert.await(
        'INSERT INTO uw_votes (org_id, type, target_citizen, initiated_by, total_eligible, description, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { org.id, voteType, targetCitizen, citizenId, memberCount, description or '', expiresAt }
    )

    -- Auto-vote "for" by the initiator
    MySQL.insert.await(
        'INSERT INTO uw_vote_records (vote_id, citizen_id, vote) VALUES (?, ?, "for")',
        { voteId, citizenId }
    )
    MySQL.update.await('UPDATE uw_votes SET votes_for = votes_for + 1 WHERE id = ?', { voteId })

    NotifyOrg(org.id, {
        type = 'inform',
        description = ('[VOTE] %s initiated: %s. Cast your vote in the Settings tab.'):format(vtConfig.label, description or '')
    })
end)

-- ============================================================
-- CAST VOTE
-- ============================================================

RegisterNetEvent('underworld:server:castVote', function(voteId, voteFor)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local vote = MySQL.single.await(
        'SELECT * FROM uw_votes WHERE id = ? AND org_id = ? AND status = "active"',
        { voteId, org.id }
    )
    if not vote then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vote not found or already ended.' })
        return
    end

    -- Check not already voted
    local already = MySQL.scalar.await(
        'SELECT id FROM uw_vote_records WHERE vote_id = ? AND citizen_id = ?',
        { voteId, citizenId }
    )
    if already then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You have already voted.' })
        return
    end

    local voteVal = voteFor and 'for' or 'against'
    MySQL.insert.await(
        'INSERT INTO uw_vote_records (vote_id, citizen_id, vote) VALUES (?, ?, ?)',
        { voteId, citizenId, voteVal }
    )

    local col = voteFor and 'votes_for' or 'votes_against'
    MySQL.update.await(
        ('UPDATE uw_votes SET %s = %s + 1 WHERE id = ?'):format(col, col),
        { voteId }
    )

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Vote cast.' })

    -- Check if vote can be resolved early (majority reached)
    local updated = MySQL.single.await('SELECT * FROM uw_votes WHERE id = ?', { voteId })
    if updated then
        local majority = math.ceil(updated.total_eligible / 2) + 1
        if updated.votes_for >= majority then
            ResolveVote(voteId, true)
        elseif updated.votes_against >= majority then
            ResolveVote(voteId, false)
        end
    end
end)

-- ============================================================
-- RESOLVE VOTE
-- ============================================================

function ResolveVote(voteId, passed)
    local vote = MySQL.single.await('SELECT * FROM uw_votes WHERE id = ? AND status = "active"', { voteId })
    if not vote then return end

    local newStatus = passed and 'passed' or 'failed'
    MySQL.update.await('UPDATE uw_votes SET status = ? WHERE id = ?', { newStatus, voteId })

    local label = (VOTE_TYPES[vote.type] or {}).label or vote.type

    if passed then
        NotifyOrg(vote.org_id, { type = 'success', description = ('[VOTE] "%s" has passed!'):format(label) })
        -- Execute vote action
        ExecuteVoteAction(vote)
    else
        NotifyOrg(vote.org_id, { type = 'error', description = ('[VOTE] "%s" has failed.'):format(label) })
    end
end

function ExecuteVoteAction(vote)
    if vote.type == 'kick_member' and vote.target_citizen then
        MySQL.update.await('DELETE FROM uw_members WHERE citizen_id = ? AND org_id = ?', { vote.target_citizen, vote.org_id })
        local targetSrc = GetPlayerByCitizenId(vote.target_citizen)
        if targetSrc then
            TriggerClientEvent('ox_lib:notify', targetSrc, { type = 'error', description = 'You have been voted out of the organization.' })
        end
    end
    -- Other vote types are informational and handled via the UI/settings tab
end

-- ============================================================
-- VOTE EXPIRY CHECK — runs every 5 minutes
-- ============================================================

CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        local expired = MySQL.query.await(
            'SELECT * FROM uw_votes WHERE status = "active" AND expires_at <= NOW()'
        )
        if expired then
            for _, vote in ipairs(expired) do
                local passed = vote.votes_for > vote.votes_against
                ResolveVote(vote.id, passed)
            end
        end
    end
end)

-- ============================================================
-- GET VOTES DATA — for UI
-- ============================================================

function GetVotesData(orgId, citizenId)
    local activeVotes = MySQL.query.await(
        'SELECT * FROM uw_votes WHERE org_id = ? AND status = "active" ORDER BY created_at DESC',
        { orgId }
    ) or {}

    local recentVotes = MySQL.query.await(
        'SELECT * FROM uw_votes WHERE org_id = ? AND status IN ("passed", "failed") ' ..
        'AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) ORDER BY created_at DESC LIMIT 10',
        { orgId }
    ) or {}

    -- Check which votes this player has already voted on
    local myVotes = {}
    for _, v in ipairs(activeVotes) do
        local record = MySQL.single.await(
            'SELECT vote FROM uw_vote_records WHERE vote_id = ? AND citizen_id = ?',
            { v.id, citizenId }
        )
        myVotes[tostring(v.id)] = record and record.vote or nil
    end

    return {
        active  = activeVotes,
        recent  = recentVotes,
        myVotes = myVotes
    }
end

_ENV.GetVotesData = GetVotesData
