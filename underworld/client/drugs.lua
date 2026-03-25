-- ============================================================
-- UNDERWORLD — Client: Drug Labs & Store Robberies
-- ============================================================

local activeDelivery = nil  -- { labId, labType, units, orgId, labLabel }
local orgLabIds      = {}   -- list of lab IDs this org owns (synced from server)

-- ============================================================
-- SPAWN LAB MARKERS & TARGETS — called when panel data loads
-- ============================================================

local labTargets    = {}
local sellTargets   = {}
local storeTargets  = {}

local function ClearTargets(list)
    for _, id in ipairs(list) do
        pcall(function() exports.ox_target:removeZone(id) end)
    end
    table.wipe and table.wipe(list) or (#list == 0 or (function() for i = #list, 1, -1 do list[i] = nil end end)())
end

local function SetupLabTargets(labs)
    ClearTargets(labTargets)
    for _, lab in ipairs(labs or {}) do
        local loc = nil
        for _, l in ipairs(Config.DrugLabs.locations) do
            if l.id == lab.location_id then loc = l break end
        end
        if not loc then goto continue end

        local zoneId = 'uw_lab_' .. lab.id
        exports.ox_target:addSphereZone({
            coords  = vec3(loc.coords.x, loc.coords.y, loc.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                {
                    name     = zoneId .. '_collect',
                    label    = ('[OPS] Collect Stock — %s (%d/%d units)'):format(lab.type_label, lab.stock, lab.max_stock),
                    icon     = 'fa-solid fa-box',
                    distance = 3.0,
                    canInteract = function()
                        return lab.stock > 0 and not activeDelivery
                    end,
                    onSelect = function()
                        local myPos = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent('underworld:server:collectLabStock', lab.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                    end
                }
            }
        })
        table.insert(labTargets, zoneId .. '_collect')

        -- Map blip for this lab
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, 612)
        SetBlipColour(blip, 1)  -- red
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('[OPS] %s'):format(lab.type_label))
        EndTextCommandSetBlipName(blip)

        ::continue::
    end
end

local function SetupSellTargets()
    ClearTargets(sellTargets)
    for _, sp in ipairs(Config.DrugLabs.sellPoints or {}) do
        local zoneId = 'uw_sell_' .. sp.id
        exports.ox_target:addSphereZone({
            coords  = vec3(sp.coords.x, sp.coords.y, sp.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                {
                    name     = zoneId,
                    label    = ('[OPS] Sell at %s'):format(sp.label),
                    icon     = 'fa-solid fa-money-bill',
                    distance = 3.0,
                    canInteract = function()
                        return activeDelivery ~= nil
                    end,
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

        -- Subtle sell point blip
        local blip = AddBlipForCoord(sp.coords.x, sp.coords.y, sp.coords.z)
        SetBlipSprite(blip, 67)
        SetBlipColour(blip, 2)  -- green
        SetBlipScale(blip, 0.6)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('[OPS] Deal: %s'):format(sp.label))
        EndTextCommandSetBlipName(blip)
    end
end

local function SetupStoreTargets(stores)
    ClearTargets(storeTargets)
    for _, store in ipairs(stores or {}) do
        local zoneId = 'uw_store_' .. store.id
        exports.ox_target:addSphereZone({
            coords  = vec3(store.coords.x, store.coords.y, store.coords.z),
            radius  = 5.0,
            debug   = false,
            options = {
                {
                    name     = zoneId,
                    label    = ('[ROB] Rob %s'):format(store.label),
                    icon     = 'fa-solid fa-mask',
                    distance = 3.0,
                    onSelect = function()
                        -- Skill check before telling server
                        local success = lib.skillCheck({ 'easy', 'medium', 'easy' }, { 'w', 'a', 's', 'd' })
                        if success then
                            local myPos = GetEntityCoords(PlayerPedId())
                            TriggerServerEvent('underworld:server:executeRobbery', store.id, { x = myPos.x, y = myPos.y, z = myPos.z })
                        else
                            lib.notify({ type = 'error', description = '[ROBBERY FAILED] You panicked and fled.' })
                        end
                    end
                }
            }
        })
        table.insert(storeTargets, zoneId)
    end
end

-- ============================================================
-- DELIVERY THREAD — shows HUD while carrying product
-- ============================================================

RegisterNetEvent('underworld:client:startLabDelivery', function(data)
    activeDelivery = data

    -- Set waypoint to nearest sell point
    local nearest, nearestDist = nil, math.huge
    local myPos = GetEntityCoords(PlayerPedId())
    for _, sp in ipairs(Config.DrugLabs.sellPoints or {}) do
        local dist = #(myPos - vec3(sp.coords.x, sp.coords.y, sp.coords.z))
        if dist < nearestDist then
            nearest = sp
            nearestDist = dist
        end
    end
    if nearest then
        SetNewWaypoint(nearest.coords.x, nearest.coords.y)
    end

    -- Notification thread
    CreateThread(function()
        while activeDelivery do
            Wait(0)
            local str = ('[OPS] Carrying %d units of %s — reach a deal point to sell'):format(
                activeDelivery.units, activeDelivery.labLabel)
            lib.showTextUI(str, { position = 'top-center', icon = 'fa-solid fa-box' })
            Wait(2000)
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
-- LABS UPDATED — re-sync from panel refresh
-- ============================================================

RegisterNetEvent('underworld:client:labsUpdated', function()
    -- Request fresh panel data
    TriggerServerEvent('underworld:server:refreshPanel')
end)

-- ============================================================
-- INITIALISE FROM PANEL DATA
-- ============================================================

AddEventHandler('underworld:client:initOps', function(labData, robberyData)
    if labData then
        SetupLabTargets(labData.labs or {})
        SetupSellTargets()
    end
    if robberyData then
        SetupStoreTargets(robberyData.stores or {})
    end
end)
