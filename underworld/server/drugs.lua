-- ============================================================
-- UNDERWORLD — Server: Drug Lab System (Multi-Step Pipeline)
--
-- Pipeline: Gather raw → Deposit at lab → Collect product → Sell
-- Passive production = small trickle only (1–3 units/hr bonus)
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

local function Dist3D(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Find a gather location and its drug type from a gather ID
local function FindGatherLocation(gatherId)
    for drugType, locs in pairs(Config.DrugLabs.gatherLocations or {}) do
        for _, loc in ipairs(locs) do
            if loc.id == gatherId then
                return drugType, loc
            end
        end
    end
    return nil, nil
end

-- ============================================================
-- IN-MEMORY PLAYER STATE
-- Raw carry:  PlayerRawCarry[src]  = { drugType, rawAmount, orgId }
-- Gather CDs: GatherCooldowns[cid..'_'..gatherId] = timestamp
-- Collect CDs: CollectCooldowns[cid] = timestamp
-- ============================================================

local PlayerRawCarry    = {}
local GatherCooldowns   = {}
local CollectCooldowns  = {}

-- Clean up when player drops
AddEventHandler('playerDropped', function()
    local src = source
    PlayerRawCarry[src] = nil
end)

-- ============================================================
-- PURCHASE / REGISTER LAB
-- ============================================================

RegisterNetEvent('underworld:server:purchaseLab', function(locationId)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can purchase a lab.' })
        return
    end

    if not IsOrgAllowedLabs(org.type) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Your org type cannot run drug labs.' })
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

    local taken = MySQL.scalar.await('SELECT org_id FROM uw_drug_labs WHERE location_id = ? AND is_active = 1', { locationId })
    if taken then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'That location is already controlled by another organization.' })
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

    local typeCfg = Config.DrugLabs.types[loc.type] or {}
    NotifyOrg(org.id, {
        type = 'success',
        description = ('[OPS] %s is online. Start by gathering %s.'):format(loc.label, typeCfg.rawLabel or 'raw materials')
    })
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
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Only the Direktör can shut down labs.' })
        return
    end

    local lab = GetLabById(labId)
    if not lab or lab.org_id ~= org.id then return end

    MySQL.update.await('UPDATE uw_drug_labs SET is_active = 0 WHERE id = ?', { labId })
    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Lab shut down. Remaining stock is forfeited.' })
    AddLedger(org.id, citizenId, 'lab_shutdown', 0, 'Drug lab shut down')
    TriggerClientEvent('underworld:client:labsUpdated', src)
end)

-- ============================================================
-- STEP 1: GATHER RAW MATERIALS
-- Player goes to a field/supplier, skill check passes on client,
-- then calls this to receive their carry state.
-- ============================================================

RegisterNetEvent('underworld:server:gatherRawMaterial', function(gatherId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Rank Soldat or higher required.' })
        return
    end

    if not IsOrgAllowedLabs(org.type) then return end

    -- Find gather location
    local drugType, loc = FindGatherLocation(tostring(gatherId))
    if not drugType or not loc then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid gather location.' })
        return
    end

    -- Org must own a lab of this drug type
    local matchingLabs = MySQL.query.await(
        'SELECT id, location_id FROM uw_drug_labs WHERE org_id = ? AND lab_type = ? AND is_active = 1',
        { org.id, drugType }
    )
    if not matchingLabs or #matchingLabs == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Your org needs a %s lab to gather %s. Purchase one from the Operations panel.'):format(
                drugType, (Config.DrugLabs.types[drugType] or {}).rawLabel or drugType)
        })
        return
    end

    -- Proximity check
    if playerCoords then
        local dist = Dist3D(playerCoords, loc.coords)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the gather location.' })
            return
        end
    end

    -- Per-player per-location cooldown
    local cdKey = citizenId .. '_' .. tostring(gatherId)
    local now   = os.time()
    local cd    = Config.DrugLabs.gatherCooldownSecs or 180
    if GatherCooldowns[cdKey] and (now - GatherCooldowns[cdKey]) < cd then
        local wait = cd - (now - GatherCooldowns[cdKey])
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Gather cooldown: %ds remaining.'):format(wait) })
        return
    end

    -- Already carrying something?
    if PlayerRawCarry[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You are already carrying materials. Deposit them at your lab first.'
        })
        return
    end

    local typeCfg = Config.DrugLabs.types[drugType] or {}
    local amount  = typeCfg.rawPerGather or 5

    GatherCooldowns[cdKey] = now
    PlayerRawCarry[src]    = { drugType = drugType, rawAmount = amount, orgId = org.id }

    -- Build lab coords list for waypoint
    local labCoords = {}
    for _, ml in ipairs(matchingLabs) do
        local labLoc = GetLabLocation(ml.location_id)
        if labLoc then
            labCoords[#labCoords + 1] = { x = labLoc.coords.x, y = labLoc.coords.y, z = labLoc.coords.z, labId = ml.id }
        end
    end

    TriggerClientEvent('underworld:client:startRawCarry', src, {
        drugType    = drugType,
        rawAmount   = amount,
        rawLabel    = typeCfg.rawLabel or drugType,
        gatherLabel = loc.label,
        labCoords   = labCoords,
    })

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[OPS] Gathered %dx %s. Head to your lab to deposit.'):format(amount, typeCfg.rawLabel or drugType)
    })
end)

-- ============================================================
-- STEP 2: DEPOSIT RAW MATERIALS AT LAB
-- Player walks to their lab entrance, deposits what they carry.
-- Raw materials convert: rawAmount / rawToProduct = product units
-- ============================================================

RegisterNetEvent('underworld:server:depositRawMaterial', function(labId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local carry = PlayerRawCarry[src]
    if not carry then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not carrying any materials.' })
        return
    end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    local lab = GetLabById(tonumber(labId))
    if not lab or lab.org_id ~= org.id or lab.is_active == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lab not found or not yours.' })
        return
    end

    if lab.lab_type ~= carry.drugType then
        local labCfg  = Config.DrugLabs.types[lab.lab_type]  or {}
        local carryCfg = Config.DrugLabs.types[carry.drugType] or {}
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Wrong lab — this is a %s lab, you are carrying %s.'):format(
                labCfg.label or lab.lab_type, carryCfg.rawLabel or carry.drugType)
        })
        return
    end

    -- Proximity check
    local loc = GetLabLocation(lab.location_id)
    if loc and playerCoords then
        local dist = Dist3D(playerCoords, loc.coords)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the lab.' })
            return
        end
    end

    local typeCfg  = Config.DrugLabs.types[carry.drugType] or {}
    local ratio    = typeCfg.rawToProduct or 3
    local units    = math.floor(carry.rawAmount / ratio)

    if units <= 0 then
        PlayerRawCarry[src] = nil
        TriggerClientEvent('underworld:client:rawCarryComplete', src)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Not enough raw material to produce any units.' })
        return
    end

    local maxStock = typeCfg.maxStock or 50
    MySQL.update.await(
        'UPDATE uw_drug_labs SET stock = LEAST(?, stock + ?), last_produced = NOW() WHERE id = ?',
        { maxStock, units, lab.id }
    )

    PlayerRawCarry[src] = nil
    TriggerClientEvent('underworld:client:rawCarryComplete', src)

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[OPS] Materials deposited → +%d units added to lab. Collect when ready.'):format(units)
    })
end)

-- ============================================================
-- STEP 3: COLLECT PRODUCT FROM LAB
-- ============================================================

RegisterNetEvent('underworld:server:collectLabStock', function(labId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org or org.rank < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Rank Soldat or higher required.' })
        return
    end

    -- Can't collect while already carrying product or raw
    if PlayerRawCarry[src] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Deposit your raw materials first.' })
        return
    end

    local now = os.time()
    local cd  = Config.DrugLabs.collectCooldownSecs or 300
    if CollectCooldowns[citizenId] and (now - CollectCooldowns[citizenId]) < cd then
        local wait = cd - (now - CollectCooldowns[citizenId])
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Collect cooldown: %ds remaining.'):format(wait) })
        return
    end

    local lab = GetLabById(tonumber(labId))
    if not lab or lab.org_id ~= org.id or lab.is_active == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lab not found or not yours.' })
        return
    end

    -- Proximity check
    local loc = GetLabLocation(lab.location_id)
    if loc and playerCoords then
        local dist = Dist3D(playerCoords, loc.coords)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the lab.' })
            return
        end
    end

    if lab.stock <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lab has no stock ready. Deposit raw materials first.' })
        return
    end

    local units = math.min(lab.stock, 20)
    MySQL.update.await('UPDATE uw_drug_labs SET stock = stock - ? WHERE id = ?', { units, labId })
    CollectCooldowns[citizenId] = now

    local labConfig = Config.DrugLabs.types[lab.lab_type] or {}
    TriggerClientEvent('underworld:client:startLabDelivery', src, {
        labId      = labId,
        labType    = lab.lab_type,
        units      = units,
        orgId      = org.id,
        labLabel   = labConfig.label or lab.lab_type,
    })

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'inform',
        description = ('[OPS] Collected %d units. Head to a deal point to sell.'):format(units)
    })
end)

-- ============================================================
-- STEP 4: SELL PRODUCT AT DEAL POINT
-- ============================================================

RegisterNetEvent('underworld:server:sellLabStock', function(labId, units, sellPointId, playerCoords)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local org = GetPlayerOrg(citizenId)
    if not org then return end

    units       = math.max(1, math.floor(tonumber(units) or 0))
    labId       = tonumber(labId)
    sellPointId = tonumber(sellPointId)

    local lab = GetLabById(labId)
    if not lab or lab.org_id ~= org.id then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid lab.' })
        return
    end

    -- Find sell point
    local sellPoint = nil
    for _, sp in ipairs(Config.DrugLabs.sellPoints) do
        if sp.id == sellPointId then sellPoint = sp break end
    end
    if not sellPoint then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid deal point.' })
        return
    end

    -- Proximity check
    if playerCoords then
        local dist = Dist3D(playerCoords, sellPoint.coords)
        if dist > 15.0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not at the deal point.' })
            return
        end
    end

    local labCfg  = Config.DrugLabs.types[lab.lab_type] or {}
    local revenue = units * (labCfg.sellPricePerUnit or 8000)
    local heat    = labCfg.heatGainOnSell or 5

    -- Hot org discount
    if (org.heat or 0) >= 61 then
        revenue = math.floor(revenue * 0.7)
    end

    MySQL.update.await('UPDATE uw_organizations SET vault = vault + ? WHERE id = ?', { revenue, org.id })

    if heat > 0 then
        MySQL.update.await(
            'UPDATE uw_organizations SET heat = LEAST(100, heat + ?) WHERE id = ?',
            { heat, org.id }
        )
    end

    MySQL.update.await(
        'UPDATE uw_members SET weekly_contribution = weekly_contribution + ?, total_contribution = total_contribution + ? WHERE citizen_id = ? AND org_id = ?',
        { revenue, revenue, citizenId, org.id }
    )

    AddLedger(org.id, citizenId, 'drug_sale', revenue,
        ('%d units of %s sold at %s'):format(units, labCfg.label or lab.lab_type, sellPoint.label))

    MySQL.insert.await(
        'INSERT INTO uw_lab_sell_log (org_id, lab_id, citizen_id, units_sold, revenue) VALUES (?, ?, ?, ?, ?)',
        { org.id, labId, citizenId, units, revenue }
    )

    GrantOrgXP(org.id, math.floor(units / 5) + 1, 'drug_sale')

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('[OPS] Sold %d units — +$%s to vault.'):format(units, revenue)
    })
    TriggerClientEvent('underworld:client:deliveryComplete', src)
end)

-- ============================================================
-- LAB PRODUCTION TICK — passive trickle, called from passive.lua
-- ============================================================

function ProcessLabProduction()
    local labs = MySQL.query.await('SELECT * FROM uw_drug_labs WHERE is_active = 1') or {}

    for _, lab in ipairs(labs) do
        local labCfg = Config.DrugLabs.types[lab.lab_type]
        if not labCfg then goto continue end

        local org = MySQL.single.await('SELECT * FROM uw_organizations WHERE id = ?', { lab.org_id })
        if not org then goto continue end

        if (org.heat or 0) >= 91 then goto continue end

        -- Raid check
        if (org.heat or 0) >= Config.DrugLabs.raidHeatThreshold then
            if math.random() < Config.DrugLabs.raidChancePerTick then
                MySQL.update.await('UPDATE uw_drug_labs SET is_active = 0, stock = 0 WHERE id = ?', { lab.id })
                local loc = GetLabLocation(lab.location_id)
                AddLedger(lab.org_id, nil, 'lab_raided', 0,
                    ('Lab raided by police: %s'):format(loc and loc.label or 'Unknown'))
                NotifyOrg(lab.org_id, {
                    type = 'error',
                    description = '[OPS] POLICE RAID — Your lab was hit and shut down. Reduce heat to reopen it.'
                })
                goto continue
            end
        end

        -- Passive trickle (active gathering is the main income driver)
        local currentStock = lab.stock or 0
        if currentStock < labCfg.maxStock then
            local produced = math.min(labCfg.unitsPerHour or 1, labCfg.maxStock - currentStock)
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

function GetOrgLabData(orgId, orgType)
    if not IsOrgAllowedLabs(orgType or '') then
        return nil
    end

    local labs = GetOrgLabs(orgId)
    local result = {}
    local ownedTypes = {}

    for _, lab in ipairs(labs) do
        local loc    = GetLabLocation(lab.location_id) or {}
        local labCfg = Config.DrugLabs.types[lab.lab_type] or {}
        ownedTypes[lab.lab_type] = true
        result[#result + 1] = {
            id             = lab.id,
            lab_type       = lab.lab_type,
            type_label     = labCfg.label or lab.lab_type,
            location_id    = lab.location_id,
            location_label = loc.label or 'Unknown',
            stock          = lab.stock or 0,
            max_stock      = labCfg.maxStock or 50,
            units_per_hr   = labCfg.unitsPerHour or 1,
            sell_price     = labCfg.sellPricePerUnit or 0,
            raw_label      = labCfg.rawLabel or '',
            gather_label   = labCfg.gatherLabel or '',
            steps          = labCfg.steps or {},
            is_active      = lab.is_active == 1 or lab.is_active == true,
            last_produced  = lab.last_produced,
        }
    end

    -- Available locations (not currently controlled)
    local takenLocations = {}
    local allActiveLabs  = MySQL.query.await('SELECT location_id FROM uw_drug_labs WHERE is_active = 1') or {}
    for _, l in ipairs(allActiveLabs) do takenLocations[l.location_id] = true end

    local available = {}
    for _, loc in ipairs(Config.DrugLabs.locations) do
        local labCfg = Config.DrugLabs.types[loc.type] or {}
        available[#available + 1] = {
            id             = loc.id,
            label          = loc.label,
            type           = loc.type,
            type_label     = labCfg.label or loc.type,
            purchase_cost  = Config.DrugLabs.labCost,
            production_rate = labCfg.unitsPerHour or 1,
            max_stock      = labCfg.maxStock or 50,
            available      = not takenLocations[loc.id],
            coords         = { x = loc.coords.x, y = loc.coords.y, z = loc.coords.z },
        }
    end

    -- Gather locations for drug types the org currently works with
    local gatherLocs = {}
    for drugType, locs in pairs(Config.DrugLabs.gatherLocations or {}) do
        if ownedTypes[drugType] then
            for _, loc in ipairs(locs) do
                gatherLocs[#gatherLocs + 1] = {
                    id       = loc.id,
                    label    = loc.label,
                    drugType = drugType,
                    coords   = { x = loc.coords.x, y = loc.coords.y, z = loc.coords.z },
                }
            end
        end
    end

    -- Type config for UI pipeline display
    local typeConfig = {}
    for k, v in pairs(Config.DrugLabs.types) do
        typeConfig[k] = {
            label            = v.label,
            rawLabel         = v.rawLabel,
            gatherLabel      = v.gatherLabel,
            steps            = v.steps,
            rawPerGather     = v.rawPerGather,
            rawToProduct     = v.rawToProduct,
            sellPricePerUnit = v.sellPricePerUnit,
        }
    end

    return {
        labs               = result,
        availableLocations = available,
        sellPoints         = Config.DrugLabs.sellPoints,
        labCost            = Config.DrugLabs.labCost,
        maxLabs            = Config.DrugLabs.maxLabsPerOrg,
        canOwnLabs         = true,
        gatherLocations    = gatherLocs,
        typeConfig         = typeConfig,
    }
end

_ENV.ProcessLabProduction = ProcessLabProduction
_ENV.GetOrgLabData        = GetOrgLabData
