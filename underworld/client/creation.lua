-- ============================================================
-- UNDERWORLD — Client: Org Creation (Notary NPC)
-- ============================================================

local creationNPC = nil

-- ============================================================
-- NPC SPAWN
-- ============================================================

CreateThread(function()
    Wait(2000)

    local cfg   = Config.CreationNPC
    local model = GetHashKey(cfg.model)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    creationNPC = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
    SetEntityInvincible(creationNPC, true)
    SetBlockingOfNonTemporaryEvents(creationNPC, true)
    FreezeEntityPosition(creationNPC, true)
    SetPedCanRagdoll(creationNPC, false)
    TaskStartScenarioInPlace(creationNPC, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    -- Blip
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.label or 'Notary Office')
    EndTextCommandSetBlipName(blip)

    -- ox_target interaction
    exports.ox_target:addLocalEntity(creationNPC, {
        {
            name     = 'uw_found_org',
            label    = 'Found an Organization',
            icon     = 'fa-solid fa-landmark',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('underworld:server:getCreationFees')
            end
        }
    })

    SetModelAsNoLongerNeeded(model)
end)

-- ============================================================
-- NUI OPEN — server sends fees, client opens creation modal
-- ============================================================

RegisterNetEvent('underworld:client:creationFees', function(data)
    SendNUIMessage({ action = 'openCreation', data = data })
    SetNuiFocus(true, true)
end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('createOrg', function(data, cb)
    TriggerServerEvent('underworld:server:createOrg', data)
    cb({})
end)

RegisterNUICallback('closeCreation', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- ============================================================
-- CREATION RESULT — server confirms success
-- ============================================================

RegisterNetEvent('underworld:client:creationResult', function(data)
    if data.success then
        SendNUIMessage({ action = 'creationSuccess' })
        -- Short delay, then close and open the panel
        CreateThread(function()
            Wait(2000)
            SetNuiFocus(false, false)
            TriggerServerEvent('underworld:server:getOrgData')
        end)
    else
        SendNUIMessage({ action = 'creationFailed' })
    end
end)
