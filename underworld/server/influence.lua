-- ============================================================
-- UNDERWORLD — Server: Influence Zones (Territory System)
-- ============================================================

-- ============================================================
-- HELPERS
-- ============================================================

-- Get or upsert an influence row
local function GetInfluence(orgId, zoneId)
    local row = MySQL.single.await(
        'SELECT score FROM uw_influence WHERE org_id = ? AND zone_id = ?',
        { orgId, zoneId }
    )
    if row then return row.score end
    MySQL.insert.await(
        'INSERT INTO uw_influence (org_id, zone_id, score) VALUES (?, ?, 0)',
        { orgId, zoneId }
    )
    return 0
end

local function SetInfluence(orgId, zoneId, score)
    score = math.max(0, math.min(100, score))
    MySQL.update.await(
        'INSERT INTO uw_influence (org_id, zone_id, score) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE score = ?, last_activity = NOW()',
        { orgId, zoneId, score, score }
    )
end

-- ============================================================
-- ZONE OWNER — org with highest score
-- Returns: { orgId, score, isContested } or nil
-- ============================================================

local function GetZoneOwner(zoneId)
    local rows = MySQL.query.await(
        'SELECT org_id, score FROM uw_influence WHERE zone_id = ? AND score > 0 ORDER BY score DESC LIMIT 2',
        { zoneId }
    )
    if not rows or #rows == 0 then return nil end

    local top    = rows[1]
    local second = rows[2]
    local contested = second and (top.score - second.score) <= Config.InfluenceContestThresh

    return {
        orgId      = top.org_id,
        score      = top.score,
        contested  = contested
    }
end

-- Returns all zone ownership data for a given org
local function GetOrgInfluenceData(orgId)
    local result = {}
    for _, zone in ipairs(Config.InfluenceZones) do
        local myScore = MySQL.scalar.await(
            'SELECT COALESCE(score, 0) FROM uw_influence WHERE org_id = ? AND zone_id = ?',
            { orgId, zone.id }
        ) or 0

        local owner = GetZoneOwner(zone.id)
        local isOwner     = owner and owner.orgId == orgId and not owner.contested
        local isContested = owner and owner.orgId == orgId and owner.contested

        result[#result + 1] = {
            zone_id       = zone.id,
            label         = zone.label,
            my_score      = myScore,
            is_owner      = isOwner,
            is_contested  = isContested,
            passive_bonus = isOwner and zone.passiveBonus or 0
        }
    end
    return result
end

-- ============================================================
-- APPLY INFLUENCE GAIN — mission completed in a zone
-- ============================================================

local function ApplyMissionInfluence(orgId, zoneId)
    if not zoneId then return end
    local current = GetInfluence(orgId, zoneId)
    SetInfluence(orgId, zoneId, current + Config.InfluenceMissionGain)
end

-- ============================================================
-- TERRITORY WAR WINDOW CHECK
-- ============================================================

local function IsWarWindowActive()
    if not Config.TerritoryWarWindows or not Config.TerritoryWarWindows.enabled then
        return true  -- if not configured, always active
    end
    local dayOfWeek = tonumber(os.date('%u'))  -- 1=Monday
    local hour      = tonumber(os.date('%H'))  -- 0-23

    local dayAllowed = false
    for _, d in ipairs(Config.TerritoryWarWindows.activeDays) do
        if d == dayOfWeek then dayAllowed = true; break end
    end
    if not dayAllowed then return false end

    return hour >= Config.TerritoryWarWindows.startHour and hour < Config.TerritoryWarWindows.endHour
end

local warWindowWasActive = false
local warWindowThread = CreateThread(function()
    while true do
        Wait(60 * 1000)  -- check every minute
        local isActive = IsWarWindowActive()
        if isActive and not warWindowWasActive and Config.TerritoryWarWindows.notifyOnOpen then
            -- Window just opened — notify all online org members
            local orgs = MySQL.query.await('SELECT id FROM uw_organizations') or {}
            for _, o in ipairs(orgs) do
                NotifyOrg(o.id, {
                    type = 'success',
                    description = '[TERRITORY] War window is now open! Capture zones until ' ..
                        Config.TerritoryWarWindows.endHour .. ':00.'
                })
            end
        end
        warWindowWasActive = isActive
    end
end)

-- Expose for UI
function GetWarWindowStatus()
    if not Config.TerritoryWarWindows or not Config.TerritoryWarWindows.enabled then
        return { enabled = false, active = true }
    end
    local active = IsWarWindowActive()
    local hour   = tonumber(os.date('%H'))
    local nextStart = nil
    if not active then
        -- Calculate hours until next window
        local hoursUntil = (Config.TerritoryWarWindows.startHour - hour + 24) % 24
        nextStart = hoursUntil
    end
    return {
        enabled    = true,
        active     = active,
        startHour  = Config.TerritoryWarWindows.startHour,
        endHour    = Config.TerritoryWarWindows.endHour,
        activeDays = Config.TerritoryWarWindows.activeDays,
        nextStart  = nextStart,
    }
end

-- ============================================================
-- APPLY PRESENCE GAIN — player is in zone (called from client)
-- Rate-limited via server-side cooldown table
-- ============================================================

local PresenceCooldowns = {}  -- [citizenId .. zoneId] = os.time() last granted

RegisterNetEvent('underworld:server:zonePresence', function(zoneId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    -- Require level 4+ for influence zones to be active
    if (org.level or 1) < 4 then return end

    -- Territory war window check — presence gains only during war window
    if not IsWarWindowActive() then return end

    local key     = citizenId .. zoneId
    local now     = os.time()
    local lastTs  = PresenceCooldowns[key] or 0

    -- Allow presence gain at most once per 60 seconds per player per zone
    if (now - lastTs) < 60 then return end
    PresenceCooldowns[key] = now

    -- War window bonus multiplier
    local gain = Config.InfluencePresenceGain
    if Config.TerritoryWarWindows and Config.TerritoryWarWindows.warWindowBonus then
        gain = gain * Config.TerritoryWarWindows.warWindowBonus
    end

    local current = GetInfluence(org.id, zoneId)
    SetInfluence(org.id, zoneId, current + gain)
end)

-- ============================================================
-- GET MISSION REWARD MULTIPLIER for a zone
-- ============================================================

local function GetZoneRewardMult(orgId, zoneId)
    if not zoneId then return 1.0 end
    local owner = GetZoneOwner(zoneId)
    if owner and owner.orgId == orgId and not owner.contested then
        return Config.InfluenceMissionBonus
    end
    return 1.0
end

-- ============================================================
-- DECAY TICK — called from passive.lua every hour
-- Reduces all scores by Config.InfluenceDecayPerHour
-- ============================================================

local function ProcessInfluenceDecay()
    -- Decay all scores > 0
    MySQL.update.await(
        'UPDATE uw_influence SET score = GREATEST(0, score - ?) WHERE score > 0',
        { Config.InfluenceDecayPerHour }
    )

    -- Add zone passive bonuses to owners
    for _, zone in ipairs(Config.InfluenceZones) do
        local owner = GetZoneOwner(zone.id)
        if owner and not owner.contested and zone.passiveBonus > 0 then
            MySQL.update.await(
                'UPDATE uw_organizations SET vault = vault + ? WHERE id = ?',
                { zone.passiveBonus, owner.orgId }
            )
            AddLedger(owner.orgId, nil, 'zone_bonus', zone.passiveBonus,
                ('Territory bonus: %s'):format(zone.label))
        end
    end
end

-- ============================================================
-- FULL INFLUENCE TABLE — for leaderboard/territory scoring
-- ============================================================

local function GetTerritoryLeaderboard()
    local rows = MySQL.query.await(
        'SELECT org_id, SUM(score) as total_score FROM uw_influence GROUP BY org_id ORDER BY total_score DESC LIMIT 5'
    )
    if not rows then return {} end
    local result = {}
    for _, r in ipairs(rows) do
        local orgRow = MySQL.single.await('SELECT label, type FROM uw_organizations WHERE id = ?', { r.org_id })
        result[#result + 1] = {
            org_id      = r.org_id,
            label       = orgRow and orgRow.label or 'Unknown',
            type        = orgRow and orgRow.type or 'illegal',
            total_score = r.total_score
        }
    end
    return result
end

-- ============================================================
-- EXPORTS
-- ============================================================

_ENV.ApplyMissionInfluence    = ApplyMissionInfluence
_ENV.GetZoneRewardMult        = GetZoneRewardMult
_ENV.GetOrgInfluenceData      = GetOrgInfluenceData
_ENV.ProcessInfluenceDecay    = ProcessInfluenceDecay
_ENV.GetTerritoryLeaderboard  = GetTerritoryLeaderboard
