-- ============================================================
-- UNDERWORLD — Server: Main (v2)
-- New: stash registration, extended getOrgData, heat, leaderboard
-- ============================================================

-- ============================================================
-- HELPERS
-- ============================================================

-- Supports both QBCore (qb-core) and QBX (qbx_core)
local function GetQBCorePlayer(src)
    -- Try QBX first
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayer(src)
    end)
    if ok and player then return player end

    -- Fall back to standard QBCore
    ok, player = pcall(function()
        return exports['qb-core']:GetPlayer(src)
    end)
    if ok and player then return player end

    return nil
end

local function GetCitizenId(src)
    local Player = GetQBCorePlayer(src)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

local function GetQBPlayer(src)
    return GetQBCorePlayer(src)
end

local function GetPlayerByCitizenId(citizenId)
    for _, src in ipairs(GetPlayers()) do
        local cid = GetCitizenId(tonumber(src))
        if cid == citizenId then return tonumber(src) end
    end
    return nil
end

local function GetPlayerOrg(citizenId)
    return MySQL.single.await(
        'SELECT o.*, m.rank, m.loyalty, m.division, m.weekly_contribution, m.salary ' ..
        'FROM uw_organizations o ' ..
        'JOIN uw_members m ON o.id = m.org_id ' ..
        'WHERE m.citizen_id = ?',
        { citizenId }
    )
end

local function AddLedger(orgId, citizenId, txType, amount, description)
    MySQL.insert.await(
        'INSERT INTO uw_ledger (org_id, citizen_id, type, amount, description) VALUES (?, ?, ?, ?, ?)',
        { orgId, citizenId, txType, amount, description }
    )
end

local function NotifyOrg(orgId, notify)
    local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { orgId })
    for _, m in ipairs(members) do
        local src = GetPlayerByCitizenId(m.citizen_id)
        if src then TriggerClientEvent('ox_lib:notify', src, notify) end
    end
end

-- Export helpers for other server files
_ENV.GetCitizenId         = GetCitizenId
_ENV.GetQBPlayer          = GetQBPlayer
_ENV.GetPlayerOrg         = GetPlayerOrg
_ENV.GetPlayerByCitizenId = GetPlayerByCitizenId
_ENV.AddLedger            = AddLedger
_ENV.NotifyOrg            = NotifyOrg

-- ============================================================
-- STASH REGISTRATION ON STARTUP
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    CreateThread(function()
        -- Wait for MySQL to be ready (check every 500ms for up to 10 seconds)
        local waited = 0
        while not MySQL or not MySQL.query or waited > 20 do
            Wait(500)
            waited = waited + 1
        end
        if waited > 20 then
            print('[UNDERWORLD] [ERROR] MySQL not available after 10 seconds — stashes not registered')
            return
        end

        local orgs = MySQL.query.await('SELECT id, label, tier, level FROM uw_organizations')
        if not orgs then return end
        for _, org in ipairs(orgs) do
            local slots  = GetStashSlots(org.tier, org.level or 1)
            local weight = GetStashWeight(org.tier)
            exports.ox_inventory:RegisterStash(
                ('uw_stash_%d'):format(org.id),
                ('%s — Org Stash'):format(org.label),
                slots,
                weight
            )
        end
        print(('[UNDERWORLD] Registered %d org stashes.'):format(#orgs))

        -- Restore persistent cooldowns from DB
        local allMembers = MySQL.query.await(
            'SELECT citizen_id, mission_cooldown_expires FROM uw_members WHERE mission_cooldown_expires > ?',
            { os.time() }
        )
        if allMembers then
            for _, m in ipairs(allMembers) do
                if MissionCooldowns then
                    MissionCooldowns[m.citizen_id] = m.mission_cooldown_expires
                end
            end
            print(('[UNDERWORLD] Restored %d persistent cooldowns.'):format(#allMembers))
        end
    end)
end)

-- ============================================================
-- TIER UPGRADE — Direktör pays from vault
-- ============================================================

RegisterNetEvent('underworld:server:upgradeTier', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can upgrade the tier.' })
        return
    end

    local currentTier = org.tier
    local nextTier    = currentTier + 1
    local nextConfig  = Config.Tiers[nextTier]

    if not nextConfig then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Already at maximum tier.' })
        return
    end

    local cost = nextConfig.price
    -- Level 8+ gets 10% discount
    if (org.level or 1) >= 8 then
        cost = math.floor(cost * 0.9)
    end

    if org.vault < cost then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Insufficient vault funds. Need $%s, have $%s.'):format(cost, org.vault)
        })
        return
    end

    MySQL.update.await('UPDATE uw_organizations SET vault = vault - ?, tier = ? WHERE id = ?', { cost, nextTier, org.id })
    AddLedger(org.id, citizenId, 'tier_upgrade', -cost, ('Tier upgrade: %s → %s'):format(Config.Tiers[currentTier].label, nextConfig.label))

    -- Re-register stash with new tier limits
    if GetResourceState('ox_inventory') == 'started' then
        local slots  = GetStashSlots(nextTier, org.level or 1)
        local weight = GetStashWeight(nextTier)
        exports.ox_inventory:RegisterStash(
            ('uw_stash_%d'):format(org.id),
            ('%s — Org Stash'):format(org.label),
            slots,
            weight
        )
    end

    NotifyOrg(org.id, {
        type = 'success',
        description = ('[ORG] Tier upgraded to %s! New member cap: %s, new stash & mission unlocks.'):format(nextConfig.label, nextConfig.maxMembers)
    })
end)

-- ============================================================
-- TRANSFER LEADERSHIP
-- ============================================================

RegisterNetEvent('underworld:server:transferLeadership', function(targetCitizenId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can transfer leadership.' })
        return
    end

    local target = MySQL.single.await(
        'SELECT * FROM uw_members WHERE citizen_id = ? AND org_id = ?',
        { targetCitizenId, org.id }
    )
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Member not found in your organization.' })
        return
    end

    -- Demote current Direktör to Underdirektör, promote target to Direktör
    MySQL.update.await('UPDATE uw_members SET rank = 4 WHERE citizen_id = ? AND org_id = ?', { citizenId, org.id })
    MySQL.update.await('UPDATE uw_members SET rank = 5 WHERE citizen_id = ? AND org_id = ?', { targetCitizenId, org.id })

    AddLedger(org.id, citizenId, 'leadership_transfer', 0, ('Leadership transferred to %s'):format(target.name))

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('Leadership transferred to %s. You are now Underdirektör.'):format(target.name)
    })

    local targetSrc = GetPlayerByCitizenId(targetCitizenId)
    if targetSrc then
        TriggerClientEvent('ox_lib:notify', targetSrc, {
            type = 'success',
            description = ('[ORG] You are now the Direktör of %s!'):format(org.label)
        })
    end
end)

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================

RegisterNetEvent('underworld:server:postAnnouncement', function(content, pinned)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 4 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Rank Underdirektör or higher required.' })
        return
    end

    content = tostring(content or ''):sub(1, 500)
    if #content < 1 then return end

    pinned = pinned and true or false

    -- If pinning, unpin existing
    if pinned then
        MySQL.update.await('UPDATE uw_announcements SET pinned = 0 WHERE org_id = ? AND pinned = 1', { org.id })
    end

    MySQL.insert.await(
        'INSERT INTO uw_announcements (org_id, author_cid, author_name, content, pinned) VALUES (?, ?, ?, ?, ?)',
        { org.id, citizenId, GetPlayerName(src), content, pinned and 1 or 0 }
    )

    NotifyOrg(org.id, { type = 'inform', description = ('[ORG] New announcement posted.') })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Announcement posted.' })
end)

RegisterNetEvent('underworld:server:deleteAnnouncement', function(announcementId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 4 then return end

    MySQL.update.await('DELETE FROM uw_announcements WHERE id = ? AND org_id = ?', { announcementId, org.id })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Announcement deleted.' })
end)

-- ============================================================
-- REFRESH PANEL — re-fetches all data without closing
-- ============================================================

RegisterNetEvent('underworld:server:refreshPanel', function()
    local src = source
    -- Just re-trigger the full getOrgData flow
    TriggerEvent('underworld:server:getOrgData_internal', src)
end)

-- ============================================================
-- LEADERBOARD QUERY (server callback)
-- ============================================================

local function BuildLeaderboard()
    -- Earnings leaderboard: sum of passive + mission rewards this week
    local earnings = MySQL.query.await(
        'SELECT org_id, SUM(amount) as total FROM uw_ledger ' ..
        'WHERE type IN ("mission_reward", "passive_income", "zone_bonus") ' ..
        'AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) ' ..
        'GROUP BY org_id ORDER BY total DESC LIMIT 5'
    ) or {}

    -- Mission completions this week
    local missions = MySQL.query.await(
        'SELECT org_id, COUNT(*) as total FROM uw_daily_missions ' ..
        'WHERE status = "completed" AND completed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) ' ..
        'GROUP BY org_id ORDER BY total DESC LIMIT 5'
    ) or {}

    -- Territory: sum of influence scores
    local territory = GetTerritoryLeaderboard()

    -- Enrich with org names
    local function enrich(rows, valueKey)
        local result = {}
        for _, r in ipairs(rows) do
            local org = MySQL.single.await('SELECT label, type FROM uw_organizations WHERE id = ?', { r.org_id })
            result[#result + 1] = {
                org_id = r.org_id,
                label  = org and org.label or 'Unknown',
                type   = org and org.type  or 'illegal',
                value  = r[valueKey] or r.total or 0
            }
        end
        return result
    end

    return {
        earnings  = enrich(earnings, 'total'),
        missions  = enrich(missions, 'total'),
        territory = territory
    }
end

-- ============================================================
-- ORG DATA — fetch full panel payload (extended)
-- ============================================================

local function BuildOrgPayload(src, citizenId, isRefresh)
    local org = GetPlayerOrg(citizenId)
    if not org then
        TriggerClientEvent('underworld:client:openPanel', src, nil)
        return
    end

    TriggerEvent('underworld:internal:generateMissions', org.id)

    local members = MySQL.query.await(
        'SELECT citizen_id, name, rank, division, loyalty, weekly_contribution, total_contribution, salary ' ..
        'FROM uw_members WHERE org_id = ? ORDER BY rank DESC',
        { org.id }
    )

    local ledger = MySQL.query.await(
        'SELECT * FROM uw_ledger WHERE org_id = ? ORDER BY created_at DESC LIMIT 50',
        { org.id }
    )

    local today    = os.date('%Y-%m-%d')
    local missions = MySQL.query.await(
        'SELECT * FROM uw_daily_missions WHERE org_id = ? AND DATE(created_at) = ? ORDER BY status ASC',
        { org.id, today }
    )

    -- Influence data for this org
    local influence = GetOrgInfluenceData(org.id)

    -- XP progress
    local nextLevelXp = XpForNextLevel(org.level or 1)

    -- Per-player cooldown (check persistent DB first, then in-memory)
    local myCooldownEnds = 0
    if MissionCooldowns and MissionCooldowns[citizenId] then
        myCooldownEnds = MissionCooldowns[citizenId]
    end
    -- Also check DB for persistent cooldown
    local dbCooldown = MySQL.scalar.await(
        'SELECT mission_cooldown_expires FROM uw_members WHERE citizen_id = ? AND org_id = ?',
        { citizenId, org.id }
    ) or 0
    if dbCooldown > myCooldownEnds then
        myCooldownEnds = dbCooldown
        MissionCooldowns[citizenId] = dbCooldown
    end

    -- Heat label
    local heat = org.heat or 0
    local heatLabel
    if heat >= 91 then     heatLabel = 'burned'
    elseif heat >= 61 then heatLabel = 'hot'
    elseif heat >= 31 then heatLabel = 'elevated'
    else                   heatLabel = 'normal' end

    -- Leaderboard
    local leaderboard = BuildLeaderboard()

    -- Announcements (latest 10)
    local announcements = MySQL.query.await(
        'SELECT * FROM uw_announcements WHERE org_id = ? ORDER BY pinned DESC, created_at DESC LIMIT 10',
        { org.id }
    ) or {}

    -- Diplomacy (wars, alliances)
    local diplomacy = GetDiplomacyData and GetDiplomacyData(org.id) or {}

    -- Votes
    local votes = GetVotesData and GetVotesData(org.id, citizenId) or {}

    -- Drug labs (for illegal/family orgs)
    local labData = nil
    if GetOrgLabData and (org.type == 'illegal' or org.type == 'family') then
        labData = GetOrgLabData(org.id, org.type)
    end

    -- Store robbery status
    local robberyData = GetRobberyData and GetRobberyData(org.id) or {}

    -- Territory war window
    local warWindow = GetWarWindowStatus and GetWarWindowStatus() or {}

    -- Tier upgrade info
    local nextTier = Config.Tiers[org.tier + 1]
    local tierUpgradeCost = nil
    if nextTier then
        tierUpgradeCost = nextTier.price
        if (org.level or 1) >= 8 then
            tierUpgradeCost = math.floor(tierUpgradeCost * 0.9)
        end
    end

    local action = isRefresh and 'underworld:client:refreshPanel' or 'underworld:client:openPanel'
    TriggerClientEvent(action, src, {
        org = {
            id          = org.id,
            name        = org.name,
            label       = org.label,
            type        = org.type,
            tier        = org.tier,
            vault       = org.vault,
            heat        = heat,
            heatLabel   = heatLabel,
            xp          = org.xp or 0,
            level       = org.level or 1,
            nextLevelXp = nextLevelXp
        },
        members          = members,
        ledger           = ledger,
        missions         = missions,
        influence        = influence,
        leaderboard      = leaderboard,
        announcements    = announcements,
        diplomacy        = diplomacy,
        votes            = votes,
        tierUpgradeCost  = tierUpgradeCost,
        labData          = labData,
        robberyData      = robberyData,
        warWindow        = warWindow,
        myRank           = org.rank,
        myCitizenId      = citizenId,
        myCooldownEnds   = myCooldownEnds
    })
end

RegisterNetEvent('underworld:server:getOrgData', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then
        print(('[UNDERWORLD] getOrgData: could not resolve citizenId for src=%d — is qb-core / qbx_core running?'):format(src))
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = '[Underworld] Character data not found. Make sure you are fully spawned in.' })
        return
    end
    BuildOrgPayload(src, citizenId, false)
end)

AddEventHandler('underworld:server:getOrgData_internal', function(src)
    local citizenId = GetCitizenId(src)
    if not citizenId then return end
    BuildOrgPayload(src, citizenId, true)
end)

RegisterNetEvent('underworld:server:refreshPanel', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end
    BuildOrgPayload(src, citizenId, true)
end)

-- ============================================================
-- VAULT — deposit / withdraw
-- ============================================================

RegisterNetEvent('underworld:server:deposit', function(amount)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local Player = GetQBPlayer(src)
    if not Player then return end

    local cash = Player.PlayerData.money['cash']
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Not enough cash on you.' })
        return
    end

    Player.Functions.RemoveMoney('cash', amount, 'underworld-deposit')
    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { amount, org.id })
    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { amount, amount, citizenId, org.id }
    )
    AddLedger(org.id, citizenId, 'deposit', amount, 'Cash deposit')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Deposited $%s to the vault.'):format(amount) })
end)

RegisterNetEvent('underworld:server:withdraw', function(amount)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    -- Block withdrawals if org is burned (heat 91+)
    if (org.heat or 0) >= 91 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Vault locked — heat too high. Lay low until heat drops.'
        })
        return
    end

    local rankData = Config.Ranks[org.rank]
    if not rankData or not rankData.canWithdraw then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Your rank cannot withdraw from the vault.' })
        return
    end

    local todayWithdrawn = MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM uw_withdraw_log WHERE org_id = ? AND citizen_id = ? AND date = CURDATE()',
        { org.id, citizenId }
    ) or 0

    if (todayWithdrawn + amount) > rankData.dailyWithdraw then
        local remaining = math.max(0, rankData.dailyWithdraw - todayWithdrawn)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Daily limit: $%s. Remaining: $%s.'):format(rankData.dailyWithdraw, remaining)
        })
        return
    end

    if org.vault < amount then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vault does not have enough funds.' })
        return
    end

    local Player = GetQBPlayer(src)
    if not Player then return end

    MySQL.update.await('UPDATE uw_organizations SET vault = vault - ? WHERE id = ?', { amount, org.id })
    MySQL.insert.await(
        'INSERT INTO uw_withdraw_log (org_id, citizen_id, amount) VALUES (?, ?, ?)',
        { org.id, citizenId, amount }
    )
    Player.Functions.AddMoney('cash', amount, 'underworld-withdraw')
    AddLedger(org.id, citizenId, 'withdrawal', -amount, 'Vault withdrawal')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Withdrew $%s.'):format(amount) })
end)

-- ============================================================
-- MEMBERSHIP — invite / accept / kick / rank / salary / leave
-- ============================================================

RegisterNetEvent('underworld:server:invitePlayer', function(targetSrc)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    if org.rank < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only Kaptens and above can invite.' })
        return
    end

    local memberCount = MySQL.scalar.await('SELECT COUNT(*) FROM uw_members WHERE org_id = ?', { org.id }) or 0
    local tier = Config.Tiers[org.tier]
    if memberCount >= tier.maxMembers then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Member cap reached (%s/%s).'):format(memberCount, tier.maxMembers)
        })
        return
    end

    local targetCitizenId = GetCitizenId(tonumber(targetSrc))
    if not targetCitizenId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player not found.' })
        return
    end

    local existing = MySQL.scalar.await('SELECT id FROM uw_members WHERE citizen_id = ?', { targetCitizenId })
    if existing then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'That player is already in an organization.' })
        return
    end

    TriggerClientEvent('underworld:client:orgInvite', tonumber(targetSrc), {
        orgId       = org.id,
        orgName     = org.label,
        inviterName = GetPlayerName(src)
    })
end)

RegisterNetEvent('underworld:server:acceptInvite', function(orgId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local existing = MySQL.scalar.await('SELECT id FROM uw_members WHERE citizen_id = ?', { citizenId })
    if existing then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are already in an organization.' })
        return
    end

    local org = MySQL.single.await('SELECT * FROM uw_organizations WHERE id = ?', { orgId })
    if not org then return end

    local memberCount = MySQL.scalar.await('SELECT COUNT(*) FROM uw_members WHERE org_id = ?', { org.id }) or 0
    local tier = Config.Tiers[org.tier]
    if memberCount >= tier.maxMembers then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'That organization is full.' })
        return
    end

    MySQL.insert.await(
        'INSERT INTO uw_members (org_id, citizen_id, name, rank) VALUES (?, ?, ?, 1)',
        { org.id, citizenId, GetPlayerName(src) }
    )

    -- Grant XP for new member
    GrantOrgXP(org.id, Config.XPGains.new_member, 'new_member')

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('Welcome to %s. You start as Associé.'):format(org.label)
    })
    NotifyOrg(org.id, {
        type = 'inform',
        description = ('[ORG] %s has joined as Associé.'):format(GetPlayerName(src))
    })
end)

RegisterNetEvent('underworld:server:kickMember', function(targetCitizenId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 4 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient rank to kick members.' })
        return
    end

    local target = MySQL.single.await(
        'SELECT * FROM uw_members WHERE citizen_id = ? AND org_id = ?',
        { targetCitizenId, org.id }
    )
    if not target then return end

    if target.rank >= org.rank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Cannot kick equal or higher rank.' })
        return
    end

    MySQL.update.await('DELETE FROM uw_members WHERE citizen_id = ? AND org_id = ?', { targetCitizenId, org.id })

    local targetSrc = GetPlayerByCitizenId(targetCitizenId)
    if targetSrc then
        TriggerClientEvent('ox_lib:notify', targetSrc, {
            type = 'error',
            description = ('You have been removed from %s.'):format(org.label)
        })
    end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Member removed.' })
end)

RegisterNetEvent('underworld:server:setRank', function(targetCitizenId, newRank)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can change ranks.' })
        return
    end

    newRank = math.max(1, math.min(4, math.floor(tonumber(newRank) or 1)))
    MySQL.update.await(
        'UPDATE uw_members SET rank = ? WHERE citizen_id = ? AND org_id = ?',
        { newRank, targetCitizenId, org.id }
    )

    local rankName = Config.Ranks[newRank].name
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Rank updated to %s.'):format(rankName) })

    local targetSrc = GetPlayerByCitizenId(targetCitizenId)
    if targetSrc then
        TriggerClientEvent('ox_lib:notify', targetSrc, {
            type = 'inform',
            description = ('[ORG] Your rank has been updated to %s.'):format(rankName)
        })
    end
end)

RegisterNetEvent('underworld:server:setSalary', function(targetCitizenId, salary)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can set salaries.' })
        return
    end

    salary = math.max(0, math.floor(tonumber(salary) or 0))
    MySQL.update.await(
        'UPDATE uw_members SET salary = ? WHERE citizen_id = ? AND org_id = ?',
        { salary, targetCitizenId, org.id }
    )
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Salary set to $%s/week.'):format(salary) })
end)

RegisterNetEvent('underworld:server:leaveOrg', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    if org.rank == 5 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'The Direktör cannot leave. Transfer leadership first.'
        })
        return
    end

    MySQL.update.await('DELETE FROM uw_members WHERE citizen_id = ? AND org_id = ?', { citizenId, org.id })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('You have left %s.'):format(org.label) })
end)

-- ============================================================
-- STASH ACCESS — opens ox_inventory stash for org member
-- ============================================================

RegisterNetEvent('underworld:server:openStash', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not in an organization.' })
        return
    end

    if org.rank < 2 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You need to be at least Soldat to access the stash.'
        })
        return
    end

    -- Check stash is registered (might need registration if ox_inventory was restarted)
    if GetResourceState('ox_inventory') == 'started' then
        local slots  = GetStashSlots(org.tier, org.level or 1)
        local weight = GetStashWeight(org.tier)
        exports.ox_inventory:RegisterStash(
            ('uw_stash_%d'):format(org.id),
            ('%s — Org Stash'):format(org.label),
            slots,
            weight
        )
    end

    TriggerClientEvent('underworld:client:openStash', src, {
        stashId = ('uw_stash_%d'):format(org.id)
    })
end)

-- ============================================================
-- ADMIN COMMANDS
-- ============================================================

RegisterCommand('uwadmincreateorg', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.uwcreateorg') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'No permission.' })
        end
        return
    end

    local name    = args[1]
    local orgType = args[2]
    local tier    = tonumber(args[3]) or 1
    local label   = table.concat(args, ' ', 4)

    if not name or not orgType or label == '' then
        print('[UNDERWORLD] Usage: /uwcreateorg <name> <type: legal/illegal/family> <tier: 1-4> <label>')
        return
    end

    if not Config.OrgTypes[orgType] then
        print('[UNDERWORLD] Invalid type. Valid: legal, illegal, family')
        return
    end

    local orgId = MySQL.insert.await(
        'INSERT INTO uw_organizations (name, label, type, tier, xp, level) VALUES (?, ?, ?, ?, 0, 1)',
        { name, label, orgType, tier }
    )

    if orgId and GetResourceState('ox_inventory') == 'started' then
        local slots  = GetStashSlots(tier, 1)
        local weight = GetStashWeight(tier)
        exports.ox_inventory:RegisterStash(
            ('uw_stash_%d'):format(orgId),
            ('%s — Org Stash'):format(label),
            slots, weight
        )
    end

    print(('[UNDERWORLD] Created org "%s" (type: %s, tier: %s, id: %s)'):format(label, orgType, tier, orgId))
end, true)

RegisterCommand('uwsetdirektor', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.uwcreateorg') then return end

    local targetSrc = tonumber(args[1])
    local orgName   = args[2]
    if not targetSrc or not orgName then
        print('[UNDERWORLD] Usage: /uwsetdirektor <playerid> <orgname>')
        return
    end

    local citizenId = GetCitizenId(targetSrc)
    if not citizenId then print('[UNDERWORLD] Player not found.') return end

    local org = MySQL.single.await('SELECT * FROM uw_organizations WHERE name = ?', { orgName })
    if not org then print('[UNDERWORLD] Org not found.') return end

    local existing = MySQL.scalar.await('SELECT id FROM uw_members WHERE citizen_id = ?', { citizenId })
    if existing then
        MySQL.update.await('UPDATE uw_members SET rank = 5, org_id = ? WHERE citizen_id = ?', { org.id, citizenId })
    else
        MySQL.insert.await(
            'INSERT INTO uw_members (org_id, citizen_id, name, rank) VALUES (?, ?, ?, 5)',
            { org.id, citizenId, GetPlayerName(targetSrc) }
        )
    end

    TriggerClientEvent('ox_lib:notify', targetSrc, {
        type = 'success',
        description = ('You are now the Direktör of %s.'):format(org.label)
    })
    print(('[UNDERWORLD] %s set as Direktör of %s.'):format(GetPlayerName(targetSrc), org.label))
end, true)
