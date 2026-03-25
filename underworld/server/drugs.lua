-- ============================================================
-- UNDERWORLD — Server: Drug Lab System (Grand RP-style)
-- Illegal/family orgs own labs → passive stock production →
-- members collect → members sell at deal points → vault $$$
-- ============================================================

-- ============================================================
-- HELPERS
-- ============================================================

local function IsOrgAllowedLabs(orgType)
    for _, t in ipairs(Config.DrugLabs.allowedTypes) do
        if t == orgType then return true end
    end
    return false
end

local function GetLabLocation(locationId)
    for _, loc in ipairs(Config.DrugLabs.locations) do
        if loc.id == locationId then return loc end
    end
    return nil
end

local function GetLabById(labId)
    return MySQL.single.await('SELECT * FROM uw_drug_labs WHERE id = ?', { labId })
end

local function GetOrgLabs(orgId)
    return MySQL.query.await('SELECT * FROM uw_drug_labs WHERE org_id = ? AND is_active = 1', { orgId }) or {}
end

-- ============================================================
-- PURCHASE / REGISTER LAB
-- ============================================================

RegisterNetEvent('underworld:server:purchaseLab', function(locationId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktor can purchase a lab.' })
        return
    end

    if not IsOrgAllowedLabs(org.type) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Your organization type cannot run drug labs.' })
        return
    end

    local labs = GetOrgLabs(org.id)
    if #labs >= Config.DrugLabs.maxLabsPerOrg then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Lab cap reached (%d/%d). Shut down an existing lab first.'):format(#labs, Config.DrugLabs.maxLabsPerOrg)
        })
        return
    end

    locationId = tonumber(locationId)
    local loc = GetLabLocation(locationId)
    if not loc then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid lab location.' })
        return
    end

    -- Check location not already taken by any org
    local taken = MySQL.scalar.await('SELECT org_id FROM uw_drug_labs WHERE location_id = ? AND is_active = 1', { locationId })
    if taken then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'That lab location is already controlled by another organization.' })
        return
    end

    local cost = Config.DrugLabs.labCost
    if org.vault < cost then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Insufficient vault funds. Need $%s.'):format(cost) })
        return
    end

    MySQL.update.await('UPDATE uw_organizations SET vault = vault - ? WHERE id = ?', { cost, org.id })
    MySQL.insert.await(
        'INSERT INTO uw_drug_labs (org_id, lab_type, location_id, stock, last_produced) VALUES (?, ?, ?, 0, NOW())',
        { org.id, loc.type, locationId }
    )
    AddLedger(org.id, citizenId, 'lab_purchase', -cost, ('Lab purchased: %s'):format(loc.label))

    NotifyOrg(org.id, { type = 'success', description = ('[OPS] %s lab is now online. Production begins immediately.'):format(loc.label) })
    TriggerClientEvent('underworld:client:labsUpdated', src)
end)

-- ============================================================
-- SHUT DOWN LAB
-- ============================================================

RegisterNetEvent('underworld:server:shutdownLab', function(labId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktor can shut down labs.' })
        return
    end

    local lab = GetLabById(labId)
    if not lab or lab.org_id ~= org.id then return end

    MySQL.update.await('UPDATE uw_drug_labs SET is_active = 0 WHERE id = ?', { labId })
    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Lab shut down. You forfeit remaining stock.' })
    AddLedger(org.id, citizenId, 'lab_shutdown', 0, 'Drug lab shut down')
    TriggerClientEvent('underworld:client:labsUpdated', src)
end)

-- ============================================================
-- COLLECT STOCK — member goes to lab, picks up units
-- ============================================================

local CollectCooldowns = {}  -- [citizenId] = timestamp

RegisterNetEvent('underworld:server:collectLabStock', function(labId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Rank Soldat or higher required.' })
        return
    end

    -- Per-member collect cooldown (5 min)
    local now = os.time()
    if CollectCooldowns[citizenId] and (now - CollectCooldowns[citizenId]) < 300 then
        local wait = 300 - (now - CollectCooldowns[citizenId])
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Collect cooldown: %d seconds remaining.'):format(wait) })
        return
    end

    local lab = GetLabById(labId)
    if not lab or lab.org_id ~= org.id or lab.is_active == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lab not found or not yours.' })
        return
    end

    -- Proximity check
    local loc = GetLabLocation(lab.location_id)
    if loc and playerCoords then
        local dx = (playerCoords.x or 0) - loc.coords.x
        local dy = (playerCoords.y or 0) - loc.coords.y
        local dz = (playerCoords.z or 0) - loc.coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the lab.' })
            return
        end
    end

    if lab.stock <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lab has no stock ready. Come back later.' })
        return
    end

    -- Collect up to 20 units at a time
    local units = math.min(lab.stock, 20)
    MySQL.update.await('UPDATE uw_drug_labs SET stock = stock - ? WHERE id = ?', { units, labId })
    CollectCooldowns[citizenId] = now

    -- Give the player a "carry" payload for delivery
    local labConfig = Config.DrugLabs.types[lab.lab_type] or Config.DrugLabs.types.cocaine
    TriggerClientEvent('underworld:client:startLabDelivery', src, {
        labId      = labId,
        labType    = lab.lab_type,
        units      = units,
        orgId      = org.id,
        labLabel   = labConfig.label,
    })

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = ('[OPS] Collected %d units of %s. Head to a deal point to sell.'):format(units, labConfig.label)
    })
end)

-- ============================================================
-- SELL STOCK — member reaches deal point, converts to vault $
-- ============================================================

RegisterNetEvent('underworld:server:sellLabStock', function(labId, units, sellPointId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    units     = math.max(1, math.floor(tonumber(units) or 0))
    labId     = tonumber(labId)
    sellPointId = tonumber(sellPointId)

    local lab = GetLabById(labId)
    if not lab or lab.org_id ~= org.id then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid lab.' })
        return
    end

    -- Proximity check vs sell point
    local sellPoint = nil
    for _, sp in ipairs(Config.DrugLabs.sellPoints) do
        if sp.id == sellPointId then sellPoint = sp break end
    end
    if not sellPoint then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid deal point.' })
        return
    end
    if playerCoords then
        local dx = (playerCoords.x or 0) - sellPoint.coords.x
        local dy = (playerCoords.y or 0) - sellPoint.coords.y
        local dz = (playerCoords.z or 0) - sellPoint.coords.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the deal point.' })
            return
        end
    end

    local labCfg = Config.DrugLabs.types[lab.lab_type] or Config.DrugLabs.types.cocaine
    local revenue = units * labCfg.sellPricePerUnit
    local heatGain = labCfg.heatGainOnSell

    -- Deposit revenue to vault
    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { revenue, org.id })

    -- Add heat
    if heatGain > 0 then
        MySQL.update.await(
            'UPDATE uw_organizations SET heat = LEAST(100, heat + ?) WHERE id = ?',
            { heatGain, org.id }
        )
    end

    -- Contribution tracking
    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { revenue, revenue, citizenId, org.id }
    )

    AddLedger(org.id, citizenId, 'drug_sale', revenue,
        ('%d units of %s sold at %s'):format(units, labCfg.label, sellPoint.label))

    -- Log the sale
    MySQL.insert.await(
        'INSERT INTO uw_lab_sell_log (org_id, lab_id, citizen_id, units_sold, revenue) VALUES (?, ?, ?, ?, ?)',
        { org.id, labId, citizenId, units, revenue }
    )

    -- Grant XP
    GrantOrgXP(org.id, math.floor(units / 5) + 1, 'drug_sale')

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[OPS] Sold %d units — +$%s to vault.'):format(units, revenue)
    })
    TriggerClientEvent('underworld:client:deliveryComplete', src)
end)

-- ============================================================
-- LAB PRODUCTION TICK — called from passive.lua every hour
-- ============================================================

function ProcessLabProduction()
    local labs = MySQL.query.await('SELECT * FROM uw_drug_labs WHERE is_active = 1') or {}

    for _, lab in ipairs(labs) do
        local labCfg = Config.DrugLabs.types[lab.lab_type]
        if not labCfg then goto continue end

        local org = MySQL.single.await('SELECT * FROM uw_organizations WHERE id = ?', { lab.org_id })
        if not org then goto continue end

        -- Don't produce if org is burned out
        if (org.heat or 0) >= 91 then goto continue end

        -- Raid check if org is hot
        if (org.heat or 0) >= Config.DrugLabs.raidHeatThreshold then
            if math.random() < Config.DrugLabs.raidChancePerTick then
                -- Lab raided! Shut it down and notify org
                MySQL.update.await('UPDATE uw_drug_labs SET is_active = 0, stock = 0 WHERE id = ?', { lab.id })
                AddLedger(lab.org_id, nil, 'lab_raided', 0, ('Lab raided by police: %s'):format(
                    GetLabLocation(lab.location_id) and GetLabLocation(lab.location_id).label or 'Unknown'
                ))
                NotifyOrg(lab.org_id, {
                    type = 'error',
                    description = '[OPS] POLICE RAID — Your drug lab has been raided and shut down! Reduce your heat to reopen.'
                })
                goto continue
            end
        end

        -- Produce stock up to cap
        local currentStock = lab.stock or 0
        if currentStock < labCfg.maxStock then
            local produced = math.min(labCfg.unitsPerHour, labCfg.maxStock - currentStock)
            MySQL.update.await(
                'UPDATE uw_drug_labs SET stock = stock + ?, last_produced = NOW() WHERE id = ?',
                { produced, lab.id }
            )
        end

        ::continue::
    end
end

-- ============================================================
-- GET LAB DATA — for panel payload
-- ============================================================

function GetOrgLabData(orgId)
    local labs = GetOrgLabs(orgId)
    local result = {}
    for _, lab in ipairs(labs) do
        local loc    = GetLabLocation(lab.location_id) or {}
        local labCfg = Config.DrugLabs.types[lab.lab_type] or {}
        result[#result + 1] = {
            id           = lab.id,
            lab_type     = lab.lab_type,
            type_label   = labCfg.label or lab.lab_type,
            location_id  = lab.location_id,
            location_label = loc.label or 'Unknown',
            stock        = lab.stock or 0,
            max_stock    = labCfg.maxStock or 0,
            units_per_hr = labCfg.unitsPerHour or 0,
            sell_price   = labCfg.sellPricePerUnit or 0,
            is_active    = lab.is_active == 1 or lab.is_active == true,
            last_produced = lab.last_produced,
        }
    end

    -- Also return all available locations (for purchasing UI)
    local takenLocations = {}
    local allLabs = MySQL.query.await('SELECT location_id FROM uw_drug_labs WHERE is_active = 1') or {}
    for _, l in ipairs(allLabs) do takenLocations[l.location_id] = true end

    local availableLocations = {}
    for _, loc in ipairs(Config.DrugLabs.locations) do
        availableLocations[#availableLocations + 1] = {
            id      = loc.id,
            label   = loc.label,
            type    = loc.type,
            taken   = takenLocations[loc.id] or false,
        }
    end

    return {
        labs               = result,
        availableLocations = availableLocations,
        sellPoints         = Config.DrugLabs.sellPoints,
        labCost            = Config.DrugLabs.labCost,
        maxLabs            = Config.DrugLabs.maxLabsPerOrg,
        canOwnLabs         = true,  -- already filtered by org type at server level
    }
end

_ENV.ProcessLabProduction = ProcessLabProduction
_ENV.GetOrgLabData        = GetOrgLabData
