-- ============================================================
-- UNDERWORLD — Server: Passive Income, Salaries & Weekly Reset
-- v2: XP grants, heat decay, influence decay, leaderboard reset
-- ============================================================

local lastSalaryDate     = ''
local lastLeaderboardDate = ''

-- ============================================================
-- HEAT MULTIPLIER
-- ============================================================

local function GetHeatMultiplier(heat)
    if heat >= 91 then
        return Config.HeatPassivePenalty.burned
    elseif heat >= 61 then
        return Config.HeatPassivePenalty.hot
    elseif heat >= 31 then
        return Config.HeatPassivePenalty.elevated
    else
        return Config.HeatPassivePenalty.normal
    end
end

-- ============================================================
-- PASSIVE INCOME TICK
-- ============================================================

local function ProcessPassiveIncome()
    local orgs = MySQL.query.await('SELECT * FROM uw_organizations')
    if not orgs or #orgs == 0 then return end

    for _, org in ipairs(orgs) do
        local tier = Config.Tiers[org.tier]
        if not tier then goto continue end

        -- Heat burns orgs out at max — skip passive entirely
        if (org.heat or 0) >= 91 then
            NotifyOrg(org.id, {
                type = 'error',
                description = '[ORG] Heat is maxed out — no passive income this tick.'
            })
            goto continue
        end

        local today = os.date('%Y-%m-%d')

        local completed = MySQL.scalar.await(
            'SELECT COUNT(*) FROM uw_daily_missions WHERE org_id = ? AND status = "completed" AND DATE(completed_at) = ?',
            { org.id, today }
        ) or 0

        if completed == 0 then goto continue end

        local required   = tier.missionsRequired
        local ratio      = math.min(completed / required, 1.0)
        local ticksPerDay = math.max(1, math.floor(24 * 60 / Config.PassiveTickMinutes))
        local base       = math.floor(tier.maxDailyPassive * ratio / ticksPerDay)

        -- Apply heat multiplier
        local heatMult = GetHeatMultiplier(org.heat or 0)
        local passive  = math.floor(base * heatMult)

        if passive > 0 then
            MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { passive, org.id })
            MySQL.insert.await(
                'INSERT INTO uw_passive_log (org_id, amount, missions_completed, missions_required) VALUES (?, ?, ?, ?)',
                { org.id, passive, completed, required }
            )
            AddLedger(org.id, nil, 'passive_income', passive,
                ('Passive income (%.0f%% missions)'):format(ratio * 100))

            -- Notify online members
            local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { org.id })
            for _, m in ipairs(members) do
                local src = GetPlayerByCitizenId(m.citizen_id)
                if src then
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'inform',
                        description = ('[ORG] Passive income: +$%s to vault.'):format(passive)
                    })
                end
            end

            -- Grant XP for passive tick
            GrantOrgXP(org.id, Config.XPGains.passive_tick, 'passive_tick')
        end

        -- Natural heat decay
        if (org.heat or 0) > 0 then
            MySQL.update.await(
                'UPDATE uw_organizations SET heat = GREATEST(0, heat - ?) WHERE id = ?',
                { Config.HeatDecayPerHour, org.id }
            )
        end

        ::continue::
    end

    -- Influence decay + zone passive bonuses
    ProcessInfluenceDecay()
end

-- ============================================================
-- WEEKLY SALARY PAYOUT
-- ============================================================

local function ProcessSalaries()
    local dayOfWeek = tonumber(os.date('%u')) -- 1 = Monday
    if dayOfWeek ~= Config.SalaryDayOfWeek then return end

    local today = os.date('%Y-%m-%d')
    if lastSalaryDate == today then return end
    lastSalaryDate = today

    local members = MySQL.query.await(
        'SELECT m.*, o.vault, o.label FROM uw_members m JOIN uw_organizations o ON o.id = m.org_id WHERE m.salary > 0'
    )
    if not members then return end

    for _, member in ipairs(members) do
        if member.vault >= member.salary then
            MySQL.update.await(
                'UPDATE uw_organizations SET vault = vault - ? WHERE id = ?',
                { member.salary, member.org_id }
            )
            AddLedger(member.org_id, member.citizen_id, 'salary', -member.salary,
                ('Weekly salary paid to %s'):format(member.name))

            local src = GetPlayerByCitizenId(member.citizen_id)
            if src then
                local Player = GetQBPlayer(src)
                if Player then
                    Player.Functions.AddMoney('bank', member.salary, 'underworld-salary')
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'success',
                        description = ('[ORG] Weekly salary of $%s paid.'):format(member.salary)
                    })
                end
            else
                MySQL.update.await(
                    "UPDATE players SET money = JSON_SET(money, '$.bank', JSON_EXTRACT(money, '$.bank') + ?) WHERE citizenid = ?",
                    { member.salary, member.citizen_id }
                )
            end
        else
            local director = MySQL.single.await(
                'SELECT citizen_id FROM uw_members WHERE org_id = ? AND rank = 5',
                { member.org_id }
            )
            if director then
                local dSrc = GetPlayerByCitizenId(director.citizen_id)
                if dSrc then
                    TriggerClientEvent('ox_lib:notify', dSrc, {
                        type = 'error',
                        description = '[ORG] Vault too low to cover weekly salaries.'
                    })
                end
            end
        end
    end

    MySQL.update.await('UPDATE uw_members SET weekly_contribution = 0', {})
    print('[UNDERWORLD] Weekly salaries processed and contributions reset.')
end

-- ============================================================
-- WEEKLY LEADERBOARD RESET + REWARDS
-- ============================================================

local function ProcessLeaderboardReset()
    local dayOfWeek = tonumber(os.date('%u'))
    if dayOfWeek ~= Config.SalaryDayOfWeek then return end

    local today = os.date('%Y-%m-%d')
    if lastLeaderboardDate == today then return end
    lastLeaderboardDate = today

    -- Rank by vault earnings (use passive_log sum this week as proxy)
    local topOrgs = MySQL.query.await(
        'SELECT org_id, SUM(amount) as earned FROM uw_passive_log ' ..
        'WHERE paid_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) ' ..
        'GROUP BY org_id ORDER BY earned DESC LIMIT 3'
    )
    if not topOrgs then return end

    for rank, row in ipairs(topOrgs) do
        local reward = Config.LeaderboardRewards[rank]
        if reward and reward > 0 then
            MySQL.update.await(
                'UPDATE uw_organizations SET vault = vault + ? WHERE id = ?',
                { reward, row.org_id }
            )
            AddLedger(row.org_id, nil, 'leaderboard_reward', reward,
                ('Weekly leaderboard reward — Rank #%d'):format(rank))
            NotifyOrg(row.org_id, {
                type = 'success',
                description = ('[ORG] Weekly leaderboard Rank #%d! +$%s to vault.'):format(rank, reward)
            })
        end
    end

    print('[UNDERWORLD] Weekly leaderboard processed.')
end

-- ============================================================
-- MAIN TICK LOOP
-- ============================================================

CreateThread(function()
    while true do
        Wait(Config.PassiveTickMinutes * 60 * 1000)
        ProcessPassiveIncome()
        ProcessSalaries()
        ProcessLeaderboardReset()
    end
end)
