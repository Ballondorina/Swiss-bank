-- ============================================================
-- UNDERWORLD — Server: Passive Income & Salaries
-- ============================================================

-- ============================================================
-- PASSIVE INCOME TICK
-- ============================================================

local function ProcessPassiveIncome()
    local orgs = MySQL.query.await('SELECT * FROM uw_organizations')
    if not orgs or #orgs == 0 then return end

    for _, org in ipairs(orgs) do
        local tier = Config.Tiers[org.tier]
        if not tier then goto continue end

        local today = os.date('%Y-%m-%d')

        local completed = MySQL.scalar.await(
            'SELECT COUNT(*) FROM uw_daily_missions WHERE org_id = ? AND status = "completed" AND DATE(completed_at) = ?',
            { org.id, today }
        ) or 0

        if completed == 0 then goto continue end

        local required = tier.missionsRequired
        local ratio    = math.min(completed / required, 1.0)

        -- Divide max daily passive by number of ticks per day
        local ticksPerDay = math.max(1, math.floor(24 * 60 / Config.PassiveTickMinutes))
        local passive     = math.floor(tier.maxDailyPassive * ratio / ticksPerDay)

        if passive > 0 then
            MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { passive, org.id })
            MySQL.insert.await(
                'INSERT INTO uw_passive_log (org_id, amount, missions_completed, missions_required) VALUES (?, ?, ?, ?)',
                { org.id, passive, completed, required }
            )
            AddLedger(org.id, nil, 'passive_income', passive,
                ('Passive income (%.0f%% mission completion)'):format(ratio * 100))

            -- Notify online members
            local members = MySQL.query.await('SELECT citizen_id FROM uw_members WHERE org_id = ?', { org.id })
            for _, m in ipairs(members) do
                local src = GetPlayerByCitizenId(m.citizen_id)
                if src then
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'inform',
                        description = ('[ORG] Passive income: +$%s added to vault.'):format(passive)
                    })
                end
            end
        end

        ::continue::
    end
end

-- ============================================================
-- WEEKLY SALARY PAYOUT
-- ============================================================

local lastSalaryDate = ''

local function ProcessSalaries()
    local dayOfWeek = tonumber(os.date('%u')) -- 1 = Monday
    if dayOfWeek ~= Config.SalaryDayOfWeek then return end

    local today = os.date('%Y-%m-%d')
    if lastSalaryDate == today then return end -- already ran today
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
                        description = ('[ORG] Weekly salary of $%s paid to your bank.'):format(member.salary)
                    })
                end
            else
                -- Offline: write directly to player money
                MySQL.update.await(
                    "UPDATE players SET money = JSON_SET(money, '$.bank', JSON_EXTRACT(money, '$.bank') + ?) WHERE citizenid = ?",
                    { member.salary, member.citizen_id }
                )
            end
        else
            -- Vault insufficient — warn director
            local director = MySQL.single.await(
                'SELECT citizen_id FROM uw_members WHERE org_id = ? AND rank = 5',
                { member.org_id }
            )
            if director then
                local src = GetPlayerByCitizenId(director.citizen_id)
                if src then
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'error',
                        description = '[ORG] Vault too low to cover weekly salaries.'
                    })
                end
            end
        end
    end

    -- Reset weekly contributions after salary day
    MySQL.update.await('UPDATE uw_members SET weekly_contribution = 0', {})
    print('[UNDERWORLD] Weekly salaries processed and contributions reset.')
end

-- ============================================================
-- TICK LOOP
-- ============================================================

CreateThread(function()
    while true do
        Wait(Config.PassiveTickMinutes * 60 * 1000)
        ProcessPassiveIncome()
        ProcessSalaries()
    end
end)
