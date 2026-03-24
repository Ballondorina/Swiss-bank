-- ============================================================
-- UNDERWORLD — Server: Missions
-- ============================================================

-- Generate today's mission board for an org (idempotent)
local function GenerateDailyMissions(orgId)
    local org = MySQL.single.await('SELECT * FROM uw_organizations WHERE id = ?', { orgId })
    if not org then return end

    local tier     = Config.Tiers[org.tier]
    local orgType  = Config.OrgTypes[org.type]
    local today    = os.date('%Y-%m-%d')
    local required = tier.missionsRequired

    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM uw_daily_missions WHERE org_id = ? AND DATE(created_at) = ?',
        { orgId, today }
    ) or 0

    local toCreate = required - existing
    if toCreate <= 0 then return end

    local expiresAt = today .. ' 23:59:59'
    local mTypes    = orgType.missions

    for _ = 1, toCreate do
        local mType   = mTypes[math.random(1, #mTypes)]
        local mConfig = Config.Missions[mType]

        local pickupIdx   = math.random(1, #Config.MissionLocations.pickups)
        local deliveryIdx = math.random(1, #Config.MissionLocations.deliveries)
        -- Ensure pickup ≠ delivery index
        while deliveryIdx == pickupIdx do
            deliveryIdx = math.random(1, #Config.MissionLocations.deliveries)
        end

        local base   = math.random(tier.missionReward.min, tier.missionReward.max)
        local reward = math.floor(base * mConfig.rewardMult * orgType.incomeMult)

        local pickup   = Config.MissionLocations.pickups[pickupIdx]
        local delivery = Config.MissionLocations.deliveries[deliveryIdx]

        MySQL.insert.await(
            'INSERT INTO uw_daily_missions (org_id, mission_type, reward, pickup_coords, delivery_coords, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
            {
                orgId, mType, reward,
                json.encode({ x = pickup.x,   y = pickup.y,   z = pickup.z }),
                json.encode({ x = delivery.x, y = delivery.y, z = delivery.z }),
                expiresAt
            }
        )
    end
end

-- Internal event so main.lua can call it
AddEventHandler('underworld:internal:generateMissions', function(orgId)
    GenerateDailyMissions(orgId)
end)

-- ============================================================
-- START MISSION
-- ============================================================

RegisterNetEvent('underworld:server:startMission', function(missionId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local mConfig_ = nil -- will fetch after validating

    local mission = MySQL.single.await(
        'SELECT * FROM uw_daily_missions WHERE id = ? AND org_id = ? AND status = "pending"',
        { missionId, org.id }
    )
    if not mission then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Mission not available.' })
        return
    end

    local mConfig = Config.Missions[mission.mission_type]
    if not mConfig then return end

    if org.rank < (mConfig.minRank or 2) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('This mission requires rank %s or higher.'):format(Config.Ranks[mConfig.minRank].name)
        })
        return
    end

    -- Check expiry
    local expiresTs = MySQL.scalar.await(
        'SELECT UNIX_TIMESTAMP(expires_at) FROM uw_daily_missions WHERE id = ?',
        { missionId }
    ) or 0
    if os.time() > expiresTs then
        MySQL.update.await('UPDATE uw_daily_missions SET status = "expired" WHERE id = ?', { missionId })
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'This mission has expired.' })
        return
    end

    MySQL.update.await(
        'UPDATE uw_daily_missions SET status = "active", assigned_to = ?, started_at = NOW() WHERE id = ?',
        { citizenId, missionId }
    )

    local pickup   = json.decode(mission.pickup_coords)
    local delivery = json.decode(mission.delivery_coords)

    TriggerClientEvent('underworld:client:startMission', src, {
        missionId   = missionId,
        type        = mission.mission_type,
        label       = mConfig.label,
        description = mConfig.description,
        duration    = mConfig.duration,
        reward      = mission.reward,
        skillCheck  = mConfig.skillCheck,
        pickup      = pickup,
        delivery    = delivery
    })

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = ('[MISSION] %s — Head to the pickup point.'):format(mConfig.label)
    })
end)

-- ============================================================
-- PICKUP CONFIRMED (server validates proximity via client signal)
-- ============================================================

RegisterNetEvent('underworld:server:missionPickup', function(missionId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local mission = MySQL.single.await(
        'SELECT * FROM uw_daily_missions WHERE id = ? AND assigned_to = ? AND status = "active"',
        { missionId, citizenId }
    )
    if not mission then return end

    local delivery = json.decode(mission.delivery_coords)
    TriggerClientEvent('underworld:client:missionPickupDone', src, {
        missionId = missionId,
        delivery  = delivery
    })
    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Package secured. Get to the drop point.' })
end)

-- ============================================================
-- COMPLETE MISSION
-- ============================================================

RegisterNetEvent('underworld:server:completeMission', function(missionId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local mission = MySQL.single.await(
        'SELECT * FROM uw_daily_missions WHERE id = ? AND assigned_to = ? AND status = "active"',
        { missionId, citizenId }
    )
    if not mission then return end

    MySQL.update.await(
        'UPDATE uw_daily_missions SET status = "completed", completed_at = NOW() WHERE id = ?',
        { missionId }
    )

    -- Reward goes to vault, contribution logged
    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { mission.reward, org.id })
    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { mission.reward, mission.reward, citizenId, org.id }
    )

    local mLabel = Config.Missions[mission.mission_type] and Config.Missions[mission.mission_type].label or mission.mission_type
    AddLedger(org.id, citizenId, 'mission_reward', mission.reward, ('Mission: %s'):format(mLabel))

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[MISSION COMPLETE] +$%s added to the vault.'):format(mission.reward)
    })
    TriggerClientEvent('underworld:client:missionComplete', src, missionId)

    -- Notify other online org members
    local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { org.id })
    for _, m in ipairs(members) do
        if m.citizen_id ~= citizenId then
            local tSrc = GetPlayerByCitizenId(m.citizen_id)
            if tSrc then
                TriggerClientEvent('ox_lib:notify', tSrc, {
                    type = 'inform',
                    description = ('[ORG] %s completed a mission. +$%s to vault.'):format(GetPlayerName(src), mission.reward)
                })
            end
        end
    end

    -- Check if daily target just hit — celebrate
    local today     = os.date('%Y-%m-%d')
    local completed = MySQL.scalar.await(
        'SELECT COUNT(*) FROM uw_daily_missions WHERE org_id = ? AND status = "completed" AND DATE(completed_at) = ?',
        { org.id, today }
    ) or 0
    local required  = (Config.Tiers[org.tier] or {}).missionsRequired or 3

    if completed == required then
        NotifyOrg(org.id, {
            type = 'success',
            description = ('[ORG] Daily mission target reached! Passive income is now at full rate.')
        })
    end
end)

-- ============================================================
-- FAIL / ABANDON
-- ============================================================

RegisterNetEvent('underworld:server:failMission', function(missionId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local mission = MySQL.single.await(
        'SELECT * FROM uw_daily_missions WHERE id = ? AND assigned_to = ?',
        { missionId, citizenId }
    )
    if not mission then return end

    MySQL.update.await('UPDATE uw_daily_missions SET status = "failed" WHERE id = ?', { missionId })
    TriggerClientEvent('underworld:client:missionFailed', src, missionId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = '[MISSION FAILED]' })
end)
