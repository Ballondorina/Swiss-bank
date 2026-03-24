-- ============================================================
-- UNDERWORLD — Server: Org Level Progression
-- ============================================================

-- Returns the level for a given XP amount
local function XpToLevel(xp)
    local level = 1
    for lvl = 10, 1, -1 do
        if xp >= (Config.LevelThresholds[lvl] or 0) then
            level = lvl
            break
        end
    end
    return level
end

-- Returns XP needed for next level (nil if max)
local function XpForNextLevel(level)
    if level >= 10 then return nil end
    return Config.LevelThresholds[level + 1]
end

-- ============================================================
-- GRANT XP — called from missions.lua, passive.lua, main.lua
-- ============================================================

local function GrantOrgXP(orgId, amount, reason)
    if not orgId or amount <= 0 then return end

    local org = MySQL.single.await('SELECT id, xp, level FROM uw_organizations WHERE id = ?', { orgId })
    if not org then return end

    local newXp    = org.xp + amount
    local newLevel = XpToLevel(newXp)
    local leveled  = newLevel > org.level

    MySQL.update.await(
        'UPDATE uw_organizations SET xp = ?, level = ? WHERE id = ?',
        { newXp, newLevel, orgId }
    )

    if leveled then
        local unlock = Config.LevelUnlocks[newLevel] or ''
        local msg    = ('[ORG] LEVEL UP! Your organization reached Level %d.'):format(newLevel)
        if unlock ~= '' then
            msg = msg .. ' — ' .. unlock
        end
        NotifyOrg(orgId, { type = 'success', description = msg })
        print(('[UNDERWORLD] Org %d leveled up to %d (XP: %d)'):format(orgId, newLevel, newXp))
    end
end

-- ============================================================
-- STASH SLOT COUNT — tier + level bonus
-- ============================================================

local function GetStashSlots(tier, level)
    local base = Config.StashSlots[tier] or 10
    -- Level 3+ gives +5 bonus slots
    if level >= 3 then base = base + 5 end
    return base
end

local function GetStashWeight(tier)
    return Config.StashWeights[tier] or 5000
end

-- ============================================================
-- COOLDOWN DURATION — tier + level reduction
-- ============================================================

local function GetMissionCooldownSeconds(tier, level)
    local minutes = Config.MissionCooldowns[tier] or 30
    -- Level 6+ reduces cooldown
    if level >= 6 then
        minutes = math.max(5, minutes - Config.MissionCooldownReduction)
    end
    return minutes * 60
end

-- ============================================================
-- EXPORT TO _ENV
-- ============================================================

_ENV.GrantOrgXP              = GrantOrgXP
_ENV.XpToLevel               = XpToLevel
_ENV.XpForNextLevel          = XpForNextLevel
_ENV.GetStashSlots           = GetStashSlots
_ENV.GetStashWeight          = GetStashWeight
_ENV.GetMissionCooldownSeconds = GetMissionCooldownSeconds
