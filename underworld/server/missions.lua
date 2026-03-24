-- ============================================================
-- UNDERWORLD — Server: Missions (v2)
-- New: mission cooldowns, XP grants, zone assignment, influence
-- ============================================================

-- Per-member cooldown table (resets on server restart — by design)
local MissionCooldowns = {}  -- [citizenId] = unix timestamp when cooldown expires

-- ============================================================
-- HELPERS
-- ============================================================

local function GetCooldownRemaining(citizenId)
    local expires = MissionCooldowns[citizenId]
    if not expires then return 0 end
    local remaining = expires - os.time()
    return math.max(0, remaining)
end

-- Find which zone a coordinate falls in (returns zone_id or nil)
local function GetZoneForCoord(coordTable)
    if not coordTable then return nil end
    local pos = vec3(coordTable.x, coordTable.y, coordTable.z)
    for _, zone in ipairs(Config.InfluenceZones) do
        local dist = #(pos - vec3(zone.coords.x, zone.coords.y, zone.coords.z))
        if dist <= zone.radius then
            return zone.id
        end
    end
    return nil
end

-- ============================================================
-- GENERATE DAILY MISSIONS (idempotent)
-- ============================================================

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

    -- Level 2+ orgs can access higher-tier missions from the pool
    if (org.level or 1) >= 2 then
        local allMissions = {}
        for k, _ in pairs(Config.Missions) do allMissions[#allMissions + 1] = k end
        -- Mix: 50% org-type missions, 50% general pool
        if math.random() > 0.5 then mTypes = allMissions end
    end

    for _ = 1, toCreate do
        local mType   = mTypes[math.random(1, #mTypes)]
        local mConfig = Config.Missions[mType]
        if not mConfig then goto continue end

        local pickupIdx   = math.random(1, #Config.MissionLocations.pickups)
        local deliveryIdx = math.random(1, #Config.MissionLocations.deliveries)
        while deliveryIdx == pickupIdx do
            deliveryIdx = math.random(1, #Config.MissionLocations.deliveries)
        end

        local pickup   = Config.MissionLocations.pickups[pickupIdx]
        local delivery = Config.MissionLocations.deliveries[deliveryIdx]

        -- Determine zone from pickup location
        local zoneId = GetZoneForCoord({ x = pickup.x, y = pickup.y, z = pickup.z })

        local base   = math.random(tier.missionReward.min, tier.missionReward.max)
        local reward = math.floor(base * mConfig.rewardMult * orgType.incomeMult)

        MySQL.insert.await(
            'INSERT INTO uw_daily_missions (org_id, mission_type, reward, pickup_coords, delivery_coords, zone_id, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            {
                orgId, mType, reward,
                json.encode({ x = pickup.x,   y = pickup.y,   z = pickup.z }),
                json.encode({ x = delivery.x, y = delivery.y, z = delivery.z }),
                zoneId,
                expiresAt
            }
        )

        ::continue::
    end
end

AddEventHandler('underworld:internal:generateMissions', function(orgId)
    GenerateDailyMissions(orgId)
end)

-- ============================================================
-- GET COOLDOWN — called from getOrgData so UI can show timer
-- ============================================================

AddEventHandler('underworld:internal:getCooldown', function(citizenId, cb)
    cb(GetCooldownRemaining(citizenId))
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

    -- Check per-member cooldown
    local cooldownLeft = GetCooldownRemaining(citizenId)
    if cooldownLeft > 0 then
        local mins = math.ceil(cooldownLeft / 60)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('On cooldown. Next mission in %d min.'):format(mins)
        })
        return
    end

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
        delivery    = delivery,
        zoneId      = mission.zone_id
    })

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = ('[MISSION] %s — Head to the pickup point.'):format(mConfig.label)
    })
end)

-- ============================================================
-- PICKUP CONFIRMED
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
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = 'Package secured. Get to the drop point.'
    })
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

    -- Apply zone influence bonus to reward (if org owns the zone)
    local zoneMult = GetZoneRewardMult(org.id, mission.zone_id)
    local finalReward = math.floor(mission.reward * zoneMult)

    -- Apply heat penalty to org (illegal/family orgs only)
    local mConfig   = Config.Missions[mission.mission_type]
    local heatGain  = (mConfig and mConfig.heatGain or 0)
    local heatMult  = Config.OrgTypes[org.type] and Config.OrgTypes[org.type].heatMult or 0
    local heatDelta = math.floor(heatGain * heatMult)

    if heatDelta > 0 then
        MySQL.update.await(
            'UPDATE uw_organizations SET heat = LEAST(100, heat + ?) WHERE id = ?',
            { heatDelta, org.id }
        )
    end

    -- Reward vault + contributions
    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { finalReward, org.id })
    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { finalReward, finalReward, citizenId, org.id }
    )

    local mLabel = mConfig and mConfig.label or mission.mission_type
    local desc   = ('Mission: %s'):format(mLabel)
    if zoneMult > 1.0 then desc = desc .. ' [+Zone Bonus]' end
    AddLedger(org.id, citizenId, 'mission_reward', finalReward, desc)

    -- Grant XP to org
    GrantOrgXP(org.id, Config.XPGains.mission_complete, 'mission_complete')

    -- Update influence zone
    ApplyMissionInfluence(org.id, mission.zone_id)

    -- Set per-member cooldown
    local cooldownSecs = GetMissionCooldownSeconds(org.tier, org.level or 1)
    MissionCooldowns[citizenId] = os.time() + cooldownSecs

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[MISSION COMPLETE] +$%s to vault.'):format(finalReward)
    })
    TriggerClientEvent('underworld:client:missionComplete', src, missionId)

    -- Notify org members
    local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { org.id })
    for _, m in ipairs(members) do
        if m.citizen_id ~= citizenId then
            local tSrc = GetPlayerByCitizenId(m.citizen_id)
            if tSrc then
                TriggerClientEvent('ox_lib:notify', tSrc, {
                    type = 'inform',
                    description = ('[ORG] %s completed a mission. +$%s to vault.'):format(GetPlayerName(src), finalReward)
                })
            end
        end
    end

    -- Daily target reached?
    local today     = os.date('%Y-%m-%d')
    local completed = MySQL.scalar.await(
        'SELECT COUNT(*) FROM uw_daily_missions WHERE org_id = ? AND status = "completed" AND DATE(completed_at) = ?',
        { org.id, today }
    ) or 0
    local required  = (Config.Tiers[org.tier] or {}).missionsRequired or 3

    if completed == required then
        NotifyOrg(org.id, {
            type = 'success',
            description = '[ORG] Daily mission target reached! Passive income now at full rate.'
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

-- ============================================================
-- EXPOSE COOLDOWN TABLE for getOrgData
-- ============================================================
_ENV.MissionCooldowns = MissionCooldowns
