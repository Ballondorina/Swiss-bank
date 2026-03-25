-- ============================================================
-- UNDERWORLD — Client: Drug Operations
--
-- Multi-step pipeline:
--   1. Gather raw materials at field locations (skill check)
--   2. Deposit at your lab (converts raw → product)
--   3. Collect finished product from lab
--   4. Sell at a deal point → vault $$$
-- ============================================================

-- ── State ────────────────────────────────────────────────────
local rawCarry      = nil   -- { drugType, rawAmount, rawLabel, labCoords }
local activeDelivery = nil  -- { labId, labType, units, labLabel }

-- ── Target / Blip registrations ──────────────────────────────
local labTargets    = {}
local sellTargets   = {}
local gatherTargets = {}
local storeTargets  = {}
local activeBlips   = {}

local function ClearList(list)
    for i = #list, 1, -1 do list[i] = nil end
end

local function RemoveTargets(list)
    for _, id in ipairs(list) do
        pcall(function() exports.ox_target:removeZone(id) end)
    end
    ClearList(list)
end

local function RemoveBlips(list)
    for _, blip in ipairs(list) do
        pcall(function() RemoveBlip(blip) end)
    end
    ClearList(list)
end

local function MakeBlip(x, y, z, sprite, colour, scale, label, shortRange)
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ============================================================
-- 1. GATHER TARGETS — raw material collection sites
-- ============================================================

local function SetupGatherTargets(gatherLocations)
    RemoveTargets(gatherTargets)

    for _, loc in ipairs(gatherLocations or {}) do
        local typeCfg = Config.DrugLabs.types[loc.drugType] or {}
        local zoneId  = 'uw_gather_' .. tostring(loc.id)

        exports.ox_target:addSphereZone({
            coords  = vec3(loc.coords.x, loc.coords.y, loc.coords.z),
            radius  = 6.0,
            debug   = false,
            options = {
                {
                    name  = zoneId,
                    label = ('[OPS] %s'):format(typeCfg.gatherLabel or 'Gather Raw Materials'),
                    icon  = 'fa-solid fa-seedling',
                    distance = 3.5,
                    canInteract = function()
                        return rawCarry == nil and activeDelivery == nil
                    end,
                    onSelect = function()
                        -- Skill check on client before telling server
                        local skills = typeCfg.gatherSkill or { 'easy', 'easy' }
                        local success = lib.skillCheck(skills, { 'w', 'a', 's', 'd' })
                        if success then
                            local myPos = GetEntityCoords(PlayerPedId())
                            TriggerServerEvent('underworld:server:gatherRawMaterial',
                                loc.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                        else
                            lib.notify({ type = 'error', description = '[OPS] You fumbled the job. Try again.' })
                        end
                    end
                }
            }
        })
        table.insert(gatherTargets, zoneId)

        -- Blip: herb/plant (green)
        local blip = MakeBlip(loc.coords.x, loc.coords.y, loc.coords.z, 469, 2, 0.65,
            ('[OPS] %s — %s'):format(typeCfg.rawLabel or loc.drugType, loc.label))
        table.insert(activeBlips, blip)
    end
end

-- ============================================================
-- 2. LAB TARGETS — deposit raw materials + collect product
-- ============================================================

local function SetupLabTargets(labs)
    RemoveTargets(labTargets)

    for _, lab in ipairs(labs or {}) do
        -- Find world coords
        local loc = nil
        for _, l in ipairs(Config.DrugLabs.locations) do
            if l.id == lab.location_id then loc = l break end
        end
        if not loc then goto continue end

        local labTypeCfg = Config.DrugLabs.types[lab.lab_type] or {}
        local zoneId     = 'uw_lab_' .. tostring(lab.id)

        exports.ox_target:addSphereZone({
            coords  = vec3(loc.coords.x, loc.coords.y, loc.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                -- Deposit raw materials (visible when carrying matching raw)
                {
                    name  = zoneId .. '_deposit',
                    label = ('[OPS] Deposit %s to lab'):format(labTypeCfg.rawLabel or 'materials'),
                    icon  = 'fa-solid fa-flask',
                    distance = 3.0,
                    canInteract = function()
                        return rawCarry ~= nil and rawCarry.drugType == lab.lab_type
                    end,
                    onSelect = function()
                        if not rawCarry then return end
                        local myPos = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent('underworld:server:depositRawMaterial',
                            lab.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                    end
                },
                -- Collect finished product (visible when stock > 0 and not carrying)
                {
                    name  = zoneId .. '_collect',
                    label = ('[OPS] Collect Product — %d/%d units'):format(lab.stock, lab.max_stock),
                    icon  = 'fa-solid fa-box',
                    distance = 3.0,
                    canInteract = function()
                        return lab.stock > 0 and rawCarry == nil and activeDelivery == nil
                    end,
                    onSelect = function()
                        local myPos = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent('underworld:server:collectLabStock',
                            lab.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                    end
                }
            }
        })
        table.insert(labTargets, zoneId .. '_deposit')
        table.insert(labTargets, zoneId .. '_collect')

        -- Lab blip (red, factory icon)
        local blip = MakeBlip(loc.coords.x, loc.coords.y, loc.coords.z, 612, 1, 0.75,
            ('[OPS] %s — %s'):format(labTypeCfg.label or lab.lab_type, loc.label))
        table.insert(activeBlips, blip)

        ::continue::
    end
end

-- ============================================================
-- 3. SELL TARGETS — deal points
-- ============================================================

local function SetupSellTargets()
    RemoveTargets(sellTargets)

    for _, sp in ipairs(Config.DrugLabs.sellPoints or {}) do
        local zoneId = 'uw_sell_' .. tostring(sp.id)

        exports.ox_target:addSphereZone({
            coords  = vec3(sp.coords.x, sp.coords.y, sp.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                {
                    name  = zoneId,
                    label = ('[OPS] Sell at %s'):format(sp.label),
                    icon  = 'fa-solid fa-money-bill',
                    distance = 3.0,
                    canInteract = function() return activeDelivery ~= nil end,
                    onSelect = function()
                        if not activeDelivery then return end
                        local myPos = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent('underworld:server:sellLabStock',
                            activeDelivery.labId,
                            activeDelivery.units,
                            sp.id,
                            { x = myPos.x, y = myPos.y, z = myPos.z }
                        )
                    end
                }
            }
        })
        table.insert(sellTargets, zoneId)

        -- Blip: dollar/money (green, short range only)
        local blip = MakeBlip(sp.coords.x, sp.coords.y, sp.coords.z, 67, 2, 0.6,
            ('[OPS] Deal Point — %s'):format(sp.label), true)
        table.insert(activeBlips, blip)
    end
end

-- ============================================================
-- 4. STORE ROBBERY TARGETS
-- ============================================================

local function SetupStoreTargets(stores)
    RemoveTargets(storeTargets)

    for _, store in ipairs(stores or {}) do
        local zoneId = 'uw_store_' .. tostring(store.id)

        exports.ox_target:addSphereZone({
            coords  = vec3(store.coords.x, store.coords.y, store.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                {
                    name  = zoneId,
                    label = ('[ROB] Rob %s'):format(store.label),
                    icon  = 'fa-solid fa-mask',
                    distance = 3.0,
                    onSelect = function()
                        local success = lib.skillCheck(
                            { 'easy', 'medium', 'easy' },
                            { 'w', 'a', 's', 'd' }
                        )
                        if success then
                            local myPos = GetEntityCoords(PlayerPedId())
                            TriggerServerEvent('underworld:server:executeRobbery',
                                store.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                        else
                            lib.notify({ type = 'error', description = '[ROBBERY] You panicked and fled.' })
                        end
                    end
                }
            }
        })
        table.insert(storeTargets, zoneId)
    end
end

-- ============================================================
-- RAW CARRY HUD — show while player has raw materials
-- ============================================================

RegisterNetEvent('underworld:client:startRawCarry', function(data)
    rawCarry = data

    -- Waypoint to nearest lab
    if data.labCoords and #data.labCoords > 0 then
        local myPos = GetEntityCoords(PlayerPedId())
        local nearest, nearestDist = data.labCoords[1], math.huge
        for _, lc in ipairs(data.labCoords) do
            local dist = #(myPos - vec3(lc.x, lc.y, lc.z))
            if dist < nearestDist then
                nearest     = lc
                nearestDist = dist
            end
        end
        SetNewWaypoint(nearest.x, nearest.y)
    end

    CreateThread(function()
        while rawCarry do
            lib.showTextUI(
                ('[OPS] Carrying %dx %s — go to your lab to deposit'):format(
                    rawCarry.rawAmount, rawCarry.rawLabel),
                { position = 'top-center', icon = 'fa-solid fa-seedling' }
            )
            Wait(2500)
        end
        lib.hideTextUI()
    end)
end)

RegisterNetEvent('underworld:client:rawCarryComplete', function()
    rawCarry = nil
    lib.hideTextUI()
    ClearGpsPlayerWaypoint()
end)

-- ============================================================
-- PRODUCT DELIVERY HUD — show while carrying finished product
-- ============================================================

RegisterNetEvent('underworld:client:startLabDelivery', function(data)
    activeDelivery = data

    -- Waypoint to nearest sell point
    local myPos = GetEntityCoords(PlayerPedId())
    local nearest, nearestDist = nil, math.huge
    for _, sp in ipairs(Config.DrugLabs.sellPoints or {}) do
        local dist = #(myPos - vec3(sp.coords.x, sp.coords.y, sp.coords.z))
        if dist < nearestDist then
            nearest     = sp
            nearestDist = dist
        end
    end
    if nearest then SetNewWaypoint(nearest.coords.x, nearest.coords.y) end

    CreateThread(function()
        while activeDelivery do
            lib.showTextUI(
                ('[OPS] Carrying %dx %s — reach a deal point to sell'):format(
                    activeDelivery.units, activeDelivery.labLabel),
                { position = 'top-center', icon = 'fa-solid fa-box' }
            )
            Wait(2500)
        end
        lib.hideTextUI()
    end)
end)

RegisterNetEvent('underworld:client:deliveryComplete', function()
    activeDelivery = nil
    lib.hideTextUI()
    ClearGpsPlayerWaypoint()
end)

-- ============================================================
-- LABS UPDATED — re-sync world targets
-- ============================================================

RegisterNetEvent('underworld:client:labsUpdated', function()
    TriggerServerEvent('underworld:server:refreshPanel')
end)

-- ============================================================
-- INIT — called from client/main.lua when panel data arrives
-- ============================================================

AddEventHandler('underworld:client:initOps', function(labData, robberyData)
    -- Clear old blips
    RemoveBlips(activeBlips)

    if labData then
        SetupLabTargets(labData.labs or {})
        SetupSellTargets()
        SetupGatherTargets(labData.gatherLocations or {})
    end

    if robberyData then
        SetupStoreTargets(robberyData.stores or {})
    end
end)
