-- ============================================================
-- UNDERWORLD — Server: War & Alliance System
-- ============================================================

local WAR_DURATION_HOURS = 72  -- wars last 3 days
local WAR_SCORE_PER_KILL = 1
local WAR_VAULT_PENALTY  = 0.05 -- loser loses 5% of vault
local MIN_WAR_TIER       = 2    -- must be at least Established to declare war

-- ============================================================
-- HELPERS
-- ============================================================

local function GetOrgById(orgId)
    return MySQL.single.await('SELECT * FROM uw_organizations WHERE id = ?', { orgId })
end

local function GetActiveWar(orgId)
    return MySQL.single.await(
        'SELECT * FROM uw_wars WHERE status = "active" AND (attacker_org_id = ? OR defender_org_id = ?)',
        { orgId, orgId }
    )
end

local function GetPendingWar(orgId)
    return MySQL.single.await(
        'SELECT * FROM uw_wars WHERE status = "pending" AND (attacker_org_id = ? OR defender_org_id = ?)',
        { orgId, orgId }
    )
end

local function AreAllied(orgId1, orgId2)
    local a = math.min(orgId1, orgId2)
    local b = math.max(orgId1, orgId2)
    return MySQL.scalar.await(
        'SELECT id FROM uw_alliances WHERE org_id_1 = ? AND org_id_2 = ? AND status = "active"',
        { a, b }
    ) ~= nil
end

-- ============================================================
-- DECLARE WAR
-- ============================================================

RegisterNetEvent('underworld:server:declareWar', function(targetOrgId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can declare war.' })
        return
    end

    if org.tier < MIN_WAR_TIER then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Your org must be at least Established (Tier 2) to declare war.' })
        return
    end

    local targetOrg = GetOrgById(targetOrgId)
    if not targetOrg then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target organization not found.' })
        return
    end

    if targetOrg.id == org.id then return end

    -- Check not already at war
    if GetActiveWar(org.id) or GetPendingWar(org.id) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You already have an active or pending war.' })
        return
    end
    if GetActiveWar(targetOrgId) or GetPendingWar(targetOrgId) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target org is already at war.' })
        return
    end

    -- Check not allied
    if AreAllied(org.id, targetOrgId) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You cannot declare war on an ally. Dissolve the alliance first.' })
        return
    end

    local endsAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (WAR_DURATION_HOURS * 3600))

    MySQL.insert.await(
        'INSERT INTO uw_wars (attacker_org_id, defender_org_id, ends_at) VALUES (?, ?, ?)',
        { org.id, targetOrgId, endsAt }
    )

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('War declared on %s. Awaiting their response.'):format(targetOrg.label) })

    -- Notify defender Direktör
    local defender = MySQL.single.await('SELECT citizen_id FROM uw_members WHERE org_id = ? AND rank = 5', { targetOrgId })
    if defender then
        local defSrc = GetPlayerByCitizenId(defender.citizen_id)
        if defSrc then
            TriggerClientEvent('ox_lib:notify', defSrc, {
                type = 'error',
                description = ('[WAR] %s has declared war on your organization! Accept or reject in the Settings tab.'):format(org.label)
            })
        end
    end

    AddLedger(org.id, citizenId, 'war_declared', 0, ('War declared on %s'):format(targetOrg.label))
end)

-- ============================================================
-- ACCEPT / REJECT WAR
-- ============================================================

RegisterNetEvent('underworld:server:respondWar', function(warId, accept)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can respond to war declarations.' })
        return
    end

    local war = MySQL.single.await('SELECT * FROM uw_wars WHERE id = ? AND defender_org_id = ? AND status = "pending"', { warId, org.id })
    if not war then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'War declaration not found.' })
        return
    end

    if accept then
        MySQL.update.await('UPDATE uw_wars SET status = "active", started_at = NOW() WHERE id = ?', { warId })
        NotifyOrg(war.attacker_org_id, { type = 'error', description = '[WAR] War has begun! The enemy has accepted your declaration.' })
        NotifyOrg(org.id, { type = 'error', description = '[WAR] War has begun! Fight for your organization.' })
        AddLedger(org.id, citizenId, 'war_accepted', 0, 'War declaration accepted')
    else
        MySQL.update.await('UPDATE uw_wars SET status = "rejected" WHERE id = ?', { warId })
        NotifyOrg(war.attacker_org_id, { type = 'inform', description = '[WAR] Your war declaration was rejected.' })
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'War declaration rejected.' })
    end
end)

-- ============================================================
-- SURRENDER
-- ============================================================

RegisterNetEvent('underworld:server:surrender', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can surrender.' })
        return
    end

    local war = GetActiveWar(org.id)
    if not war then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at war.' })
        return
    end

    local winnerId = war.attacker_org_id == org.id and war.defender_org_id or war.attacker_org_id
    EndWar(war.id, winnerId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You have surrendered. The war is lost.' })
end)

-- ============================================================
-- END WAR — applies consequences
-- ============================================================

function EndWar(warId, winnerOrgId)
    local war = MySQL.single.await('SELECT * FROM uw_wars WHERE id = ?', { warId })
    if not war or war.status ~= 'active' then return end

    local loserId = war.attacker_org_id == winnerOrgId and war.defender_org_id or war.attacker_org_id

    MySQL.update.await(
        'UPDATE uw_wars SET status = "ended", winner_org_id = ?, ended_at = NOW() WHERE id = ?',
        { winnerOrgId, warId }
    )

    -- Vault penalty: loser loses 5%, winner gains it
    local loserOrg = GetOrgById(loserId)
    if loserOrg then
        local penalty = math.floor(loserOrg.vault * WAR_VAULT_PENALTY)
        if penalty > 0 then
            MySQL.update.await('UPDATE uw_organizations SET vault = vault - ? WHERE id = ?', { penalty, loserId })
            MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { penalty, winnerOrgId })
            AddLedger(loserId, nil, 'war_penalty', -penalty, 'War defeat — vault penalty')
            AddLedger(winnerOrgId, nil, 'war_spoils', penalty, 'War victory — spoils of war')
        end
    end

    -- Transfer some influence from loser to winner
    local loserInfluence = MySQL.query.await(
        'SELECT zone_id, score FROM uw_influence WHERE org_id = ? AND score > 0',
        { loserId }
    )
    if loserInfluence then
        for _, row in ipairs(loserInfluence) do
            local transfer = math.floor(row.score * 0.2) -- 20% influence transfer
            if transfer > 0 then
                MySQL.update.await('UPDATE uw_influence SET score = GREATEST(0, score - ?) WHERE org_id = ? AND zone_id = ?', { transfer, loserId, row.zone_id })
                -- Upsert winner influence
                MySQL.update.await(
                    'INSERT INTO uw_influence (org_id, zone_id, score) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE score = LEAST(100, score + ?)',
                    { winnerOrgId, row.zone_id, transfer, transfer }
                )
            end
        end
    end

    -- XP bonus to winner
    GrantOrgXP(winnerOrgId, 200, 'war_victory')

    NotifyOrg(winnerOrgId, { type = 'success', description = '[WAR] Victory! Your organization has won the war. Spoils have been claimed.' })
    NotifyOrg(loserId, { type = 'error', description = '[WAR] Defeat. Your organization has lost the war. Vault penalized and influence transferred.' })
end

-- ============================================================
-- WAR KILL TRACKING — called when a PvP kill happens
-- ============================================================

RegisterNetEvent('underworld:server:reportWarKill', function(victimSrc)
    local killerSrc = source
    local killerCid = GetCitizenId(killerSrc)
    if not killerCid then return end

    local victimCid = GetCitizenId(tonumber(victimSrc))
    if not victimCid then return end

    local killerOrg = GetPlayerOrg(killerCid)
    local victimOrg = GetPlayerOrg(victimCid)
    if not killerOrg or not victimOrg then return end
    if killerOrg.id == victimOrg.id then return end

    -- Check if these orgs are at war
    local war = MySQL.single.await(
        'SELECT * FROM uw_wars WHERE status = "active" AND ' ..
        '((attacker_org_id = ? AND defender_org_id = ?) OR (attacker_org_id = ? AND defender_org_id = ?))',
        { killerOrg.id, victimOrg.id, victimOrg.id, killerOrg.id }
    )
    if not war then return end

    -- Record kill
    MySQL.insert.await(
        'INSERT INTO uw_war_kills (war_id, killer_cid, killer_org, victim_cid, victim_org) VALUES (?, ?, ?, ?, ?)',
        { war.id, killerCid, killerOrg.id, victimCid, victimOrg.id }
    )

    -- Update war score
    local scoreCol = killerOrg.id == war.attacker_org_id and 'score_attacker' or 'score_defender'
    MySQL.update.await(
        ('UPDATE uw_wars SET %s = %s + ? WHERE id = ?'):format(scoreCol, scoreCol),
        { WAR_SCORE_PER_KILL, war.id }
    )

    TriggerClientEvent('ox_lib:notify', killerSrc, { type = 'success', description = '[WAR] Enemy eliminated. +1 war point.' })
end)

-- ============================================================
-- WAR EXPIRY CHECK — runs every 5 minutes
-- ============================================================

CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        local expired = MySQL.query.await(
            'SELECT * FROM uw_wars WHERE status = "active" AND ends_at <= NOW()'
        )
        if expired then
            for _, war in ipairs(expired) do
                local winnerId
                if war.score_attacker > war.score_defender then
                    winnerId = war.attacker_org_id
                elseif war.score_defender > war.score_attacker then
                    winnerId = war.defender_org_id
                else
                    -- Draw — no winner, just end
                    MySQL.update.await('UPDATE uw_wars SET status = "ended", ended_at = NOW() WHERE id = ?', { war.id })
                    NotifyOrg(war.attacker_org_id, { type = 'inform', description = '[WAR] The war has ended in a draw. No penalties.' })
                    NotifyOrg(war.defender_org_id, { type = 'inform', description = '[WAR] The war has ended in a draw. No penalties.' })
                    goto continue
                end
                EndWar(war.id, winnerId)
                ::continue::
            end
        end

        -- Also expire pending wars after 24h
        MySQL.update.await(
            'UPDATE uw_wars SET status = "rejected" WHERE status = "pending" AND created_at <= DATE_SUB(NOW(), INTERVAL 24 HOUR)'
        )
    end
end)

-- ============================================================
-- ALLIANCE — PROPOSE
-- ============================================================

RegisterNetEvent('underworld:server:proposeAlliance', function(targetOrgId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can propose alliances.' })
        return
    end

    targetOrgId = tonumber(targetOrgId)
    if not targetOrgId or targetOrgId == org.id then return end

    local targetOrg = GetOrgById(targetOrgId)
    if not targetOrg then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target organization not found.' })
        return
    end

    -- Ensure canonical order for unique constraint
    local a, b = math.min(org.id, targetOrgId), math.max(org.id, targetOrgId)

    local existing = MySQL.single.await(
        'SELECT * FROM uw_alliances WHERE org_id_1 = ? AND org_id_2 = ? AND status IN ("active", "pending")',
        { a, b }
    )
    if existing then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'An alliance already exists or is pending.' })
        return
    end

    -- Check not at war
    local atWar = MySQL.scalar.await(
        'SELECT id FROM uw_wars WHERE status = "active" AND ' ..
        '((attacker_org_id = ? AND defender_org_id = ?) OR (attacker_org_id = ? AND defender_org_id = ?))',
        { org.id, targetOrgId, targetOrgId, org.id }
    )
    if atWar then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot ally with an org you are at war with.' })
        return
    end

    MySQL.insert.await(
        'INSERT INTO uw_alliances (org_id_1, org_id_2, status, initiated_by) VALUES (?, ?, "pending", ?)',
        { a, b, org.id }
    )

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Alliance proposed to %s.'):format(targetOrg.label) })

    -- Notify target Direktör
    local defender = MySQL.single.await('SELECT citizen_id FROM uw_members WHERE org_id = ? AND rank = 5', { targetOrgId })
    if defender then
        local defSrc = GetPlayerByCitizenId(defender.citizen_id)
        if defSrc then
            TriggerClientEvent('ox_lib:notify', defSrc, {
                type = 'inform',
                description = ('[ALLIANCE] %s has proposed an alliance! Check the Settings tab.'):format(org.label)
            })
        end
    end
end)

-- ============================================================
-- ALLIANCE — ACCEPT / REJECT
-- ============================================================

RegisterNetEvent('underworld:server:respondAlliance', function(allianceId, accept)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can respond to alliances.' })
        return
    end

    local alliance = MySQL.single.await('SELECT * FROM uw_alliances WHERE id = ? AND status = "pending"', { allianceId })
    if not alliance then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Alliance proposal not found.' })
        return
    end

    -- Verify this org is a party and NOT the initiator
    local isParty = (alliance.org_id_1 == org.id or alliance.org_id_2 == org.id)
    if not isParty or alliance.initiated_by == org.id then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You cannot respond to your own proposal.' })
        return
    end

    if accept then
        MySQL.update.await('UPDATE uw_alliances SET status = "active" WHERE id = ?', { allianceId })
        local otherOrgId = alliance.org_id_1 == org.id and alliance.org_id_2 or alliance.org_id_1
        NotifyOrg(otherOrgId, { type = 'success', description = ('[ALLIANCE] Your alliance with %s has been accepted!'):format(org.label) })
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Alliance formed!' })
        AddLedger(org.id, citizenId, 'alliance_formed', 0, 'Alliance formed')
        AddLedger(otherOrgId, nil, 'alliance_formed', 0, ('Alliance formed with %s'):format(org.label))
    else
        MySQL.update.await('UPDATE uw_alliances SET status = "dissolved" WHERE id = ?', { allianceId })
        TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Alliance proposal rejected.' })
    end
end)

-- ============================================================
-- ALLIANCE — DISSOLVE
-- ============================================================

RegisterNetEvent('underworld:server:dissolveAlliance', function(allianceId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can dissolve alliances.' })
        return
    end

    local alliance = MySQL.single.await('SELECT * FROM uw_alliances WHERE id = ? AND status = "active"', { allianceId })
    if not alliance then return end

    local isParty = (alliance.org_id_1 == org.id or alliance.org_id_2 == org.id)
    if not isParty then return end

    MySQL.update.await('UPDATE uw_alliances SET status = "dissolved" WHERE id = ?', { allianceId })

    local otherOrgId = alliance.org_id_1 == org.id and alliance.org_id_2 or alliance.org_id_1
    NotifyOrg(otherOrgId, { type = 'error', description = ('[ALLIANCE] %s has dissolved the alliance.'):format(org.label) })
    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Alliance dissolved.' })
end)

-- ============================================================
-- GET DIPLOMACY DATA — for UI
-- ============================================================

function GetDiplomacyData(orgId)
    -- Active/pending wars
    local wars = MySQL.query.await(
        'SELECT w.*, ' ..
        '  a_org.label as attacker_label, a_org.type as attacker_type, ' ..
        '  d_org.label as defender_label, d_org.type as defender_type ' ..
        'FROM uw_wars w ' ..
        'JOIN uw_organizations a_org ON a_org.id = w.attacker_org_id ' ..
        'JOIN uw_organizations d_org ON d_org.id = w.defender_org_id ' ..
        'WHERE w.status IN ("active", "pending") AND (w.attacker_org_id = ? OR w.defender_org_id = ?)',
        { orgId, orgId }
    ) or {}

    -- Recent ended wars (last 7 days)
    local recentWars = MySQL.query.await(
        'SELECT w.*, ' ..
        '  a_org.label as attacker_label, ' ..
        '  d_org.label as defender_label ' ..
        'FROM uw_wars w ' ..
        'JOIN uw_organizations a_org ON a_org.id = w.attacker_org_id ' ..
        'JOIN uw_organizations d_org ON d_org.id = w.defender_org_id ' ..
        'WHERE w.status = "ended" AND w.ended_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) ' ..
        'AND (w.attacker_org_id = ? OR w.defender_org_id = ?) ORDER BY w.ended_at DESC LIMIT 5',
        { orgId, orgId }
    ) or {}

    -- Active/pending alliances
    local alliances = MySQL.query.await(
        'SELECT al.*, ' ..
        '  o1.label as org1_label, o1.type as org1_type, ' ..
        '  o2.label as org2_label, o2.type as org2_type ' ..
        'FROM uw_alliances al ' ..
        'JOIN uw_organizations o1 ON o1.id = al.org_id_1 ' ..
        'JOIN uw_organizations o2 ON o2.id = al.org_id_2 ' ..
        'WHERE al.status IN ("active", "pending") AND (al.org_id_1 = ? OR al.org_id_2 = ?)',
        { orgId, orgId }
    ) or {}

    -- All orgs for war/alliance target selection
    local allOrgs = MySQL.query.await(
        'SELECT id, label, type, tier, level FROM uw_organizations WHERE id != ? ORDER BY label',
        { orgId }
    ) or {}

    return {
        wars        = wars,
        recentWars  = recentWars,
        alliances   = alliances,
        allOrgs     = allOrgs
    }
end

_ENV.GetDiplomacyData = GetDiplomacyData
_ENV.AreAllied        = AreAllied
_ENV.GetActiveWar     = GetActiveWar
