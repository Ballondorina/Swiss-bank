-- ============================================================
-- UNDERWORLD — Server: Store Robbery System (Grand RP-style)
-- Orgs can rob stores once per hour for ~$250K to vault.
-- Requires a skill check on the client side.
-- ============================================================

-- ============================================================
-- HELPERS
-- ============================================================

local function IsOrgAllowedRobberies(orgType)
    for _, t in ipairs(Config.StoreRobbery.allowedTypes) do
        if t == orgType then return true end
    end
    return false
end

local function GetStoreById(storeId)
    for _, s in ipairs(Config.StoreRobbery.stores) do
        if s.id == storeId then return s end
    end
    return nil
end

local function GetLastRobbery(orgId)
    return MySQL.single.await(
        'SELECT * FROM uw_robbery_log WHERE org_id = ? ORDER BY robbed_at DESC LIMIT 1',
        { orgId }
    )
end

-- ============================================================
-- REQUEST ROBBERY — client asks if the org can rob right now
-- Server sends back status + which stores are nearby
-- ============================================================

RegisterNetEvent('underworld:server:getRobberyStatus', function()
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local canRob   = false
    local cooldownLeft = 0
    local reason   = ''

    if not IsOrgAllowedRobberies(org.type) then
        reason = 'Your organization type cannot rob stores.'
    elseif org.rank < Config.StoreRobbery.minRank then
        reason = ('Requires rank %s or higher.'):format(
            Config.Ranks[Config.StoreRobbery.minRank] and Config.Ranks[Config.StoreRobbery.minRank].name or '?')
    elseif org.tier < Config.StoreRobbery.minTier then
        reason = 'Your org tier is too low.'
    else
        local last = GetLastRobbery(org.id)
        if last then
            local lastTs = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(robbed_at) FROM uw_robbery_log WHERE id = ?', { last.id }) or 0
            local elapsed = os.time() - lastTs
            if elapsed < Config.StoreRobbery.cooldownSecs then
                cooldownLeft = Config.StoreRobbery.cooldownSecs - elapsed
                reason = ('Org robbery on cooldown: %d minutes remaining.'):format(math.ceil(cooldownLeft / 60))
            else
                canRob = true
            end
        else
            canRob = true
        end
    end

    TriggerClientEvent('underworld:client:robberyStatus', src, {
        canRob       = canRob,
        cooldownLeft = cooldownLeft,
        reason       = reason,
        stores       = Config.StoreRobbery.stores,
        payoutMin    = Config.StoreRobbery.payoutMin,
        payoutMax    = Config.StoreRobbery.payoutMax,
    })
end)

-- ============================================================
-- EXECUTE ROBBERY — after client skill check passes
-- ============================================================

RegisterNetEvent('underworld:server:executeRobbery', function(storeId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    -- Re-validate everything server-side
    if not IsOrgAllowedRobberies(org.type) then return end
    if org.rank < Config.StoreRobbery.minRank then return end

    -- Cooldown check
    local last = GetLastRobbery(org.id)
    if last then
        local lastTs = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(robbed_at) FROM uw_robbery_log WHERE id = ?', { last.id }) or 0
        local elapsed = os.time() - lastTs
        if elapsed < Config.StoreRobbery.cooldownSecs then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Robbery still on cooldown.' })
            return
        end
    end

    -- Proximity check
    local store = GetStoreById(tonumber(storeId))
    if not store then return end
    if playerCoords then
        local dx = (playerCoords.x or 0) - store.coords.x
        local dy = (playerCoords.y or 0) - store.coords.y
        local dz = (playerCoords.z or 0) - store.coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > 20.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the store.' })
            print(('[UNDERWORLD] [ANTICHEAT] %s attempted store robbery from %.1f units away.'):format(citizenId, dist))
            return
        end
    end

    -- Calculate payout
    local payout = math.random(Config.StoreRobbery.payoutMin, Config.StoreRobbery.payoutMax)

    -- Apply heat multiplier (hot orgs get less payout, police are already watching)
    if (org.heat or 0) >= 61 then
        payout = math.floor(payout * 0.7)
    end

    -- Deposit to vault
    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { payout, org.id })

    -- Add heat
    MySQL.update.await(
        'UPDATE uw_organizations SET heat = LEAST(100, heat + ?) WHERE id = ?',
        { Config.StoreRobbery.heatGain, org.id }
    )

    -- Contribution
    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { payout, payout, citizenId, org.id }
    )

    -- Log
    MySQL.insert.await(
        'INSERT INTO uw_robbery_log (org_id, citizen_id, store_id, payout) VALUES (?, ?, ?, ?)',
        { org.id, citizenId, storeId, payout }
    )
    AddLedger(org.id, citizenId, 'store_robbery', payout, ('Store robbery: %s (+$%s)'):format(store.label, payout))

    -- XP
    GrantOrgXP(org.id, 30, 'store_robbery')

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[ROBBERY] %s hit. +$%s to vault. Next in 1hr.'):format(store.label, payout)
    })

    -- Notify org
    local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { org.id })
    for _, m in ipairs(members) do
        if m.citizen_id ~= citizenId then
            local tSrc = GetPlayerByCitizenId(m.citizen_id)
            if tSrc then
                TriggerClientEvent('ox_lib:notify', tSrc, {
                    type = 'inform',
                    description = ('[ORG] %s robbed %s. +$%s to vault.'):format(GetPlayerName(src), store.label, payout)
                })
            end
        end
    end
end)

-- ============================================================
-- GET ROBBERY STATUS DATA — for UI
-- ============================================================

function GetRobberyData(orgId)
    local last = GetLastRobbery(orgId)
    local lastTs = 0
    if last then
        lastTs = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(robbed_at) FROM uw_robbery_log WHERE id = ?', { last.id }) or 0
    end

    local cooldownLeft = 0
    if lastTs > 0 then
        local elapsed = os.time() - lastTs
        if elapsed < Config.StoreRobbery.cooldownSecs then
            cooldownLeft = Config.StoreRobbery.cooldownSecs - elapsed
        end
    end

    local recentRobberies = MySQL.query.await(
        'SELECT r.*, o.label as org_label FROM uw_robbery_log r ' ..
        'JOIN uw_organizations o ON o.id = r.org_id ' ..
        'WHERE r.org_id = ? ORDER BY r.robbed_at DESC LIMIT 5',
        { orgId }
    ) or {}

    return {
        cooldownLeft     = cooldownLeft,
        stores           = Config.StoreRobbery.stores,
        recentRobberies  = recentRobberies,
        payoutMin        = Config.StoreRobbery.payoutMin,
        payoutMax        = Config.StoreRobbery.payoutMax,
        cooldownSecs     = Config.StoreRobbery.cooldownSecs,
    }
end

_ENV.GetRobberyData = GetRobberyData
