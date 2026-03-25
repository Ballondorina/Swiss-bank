-- ============================================================
-- UNDERWORLD — Client: Missions
-- ============================================================

local activeMission = nil

-- ============================================================
-- START MISSION — set up blip, waypoint, timer thread
-- ============================================================

RegisterNetEvent('underworld:client:startMission', function(mData)
    if activeMission then
        lib.notify({ type = 'error', description = 'You already have an active mission.' })
        return
    end

    activeMission = {
        missionId  = mData.missionId,
        type       = mData.type,
        label      = mData.label,
        reward     = mData.reward,
        skillCheck = mData.skillCheck or {},
        duration   = mData.duration,
        pickup     = mData.pickup,
        delivery   = mData.delivery,
        stage      = 'pickup',
        expiresAt  = GetGameTimer() + (mData.duration * 60 * 1000)
    }

    -- Blip
    activeMission.blip = AddBlipForCoord(mData.pickup.x, mData.pickup.y, mData.pickup.z)
    SetBlipSprite(activeMission.blip, 1)
    SetBlipColour(activeMission.blip, 1)
    SetBlipScale(activeMission.blip, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('[MISSION] Pickup')
    EndTextCommandSetBlipName(activeMission.blip)
    SetNewWaypoint(mData.pickup.x, mData.pickup.y)

    StartMissionThread()
end)

-- ============================================================
-- MISSION LOOP
-- ============================================================

function StartMissionThread()
    CreateThread(function()
        while activeMission do
            Wait(500)

            local ped    = PlayerPedId()
            local pos    = GetEntityCoords(ped)
            local target = activeMission.stage == 'pickup' and activeMission.pickup or activeMission.delivery

            -- Timer expired
            if GetGameTimer() > activeMission.expiresAt then
                lib.notify({ type = 'error', description = '[MISSION FAILED] Ran out of time.' })
                TriggerServerEvent('underworld:server:failMission', activeMission.missionId)
                ClearActiveMission()
                break
            end

            local dist = #(pos - vec3(target.x, target.y, target.z))

            -- Draw marker
            local r, g = 255, 100
            if activeMission.stage == 'delivery' then r, g = 0, 200 end
            DrawMarker(1, target.x, target.y, target.z - 1.0,
                0, 0, 0, 0, 0, 0,
                1.5, 1.5, 1.0,
                r, g, 50, 150,
                false, true, 2, false, nil, nil, false)

            if dist < 3.0 then
                -- PICKUP STAGE
                if activeMission.stage == 'pickup' then
                    lib.showTextUI('[E] Collect Package', { position = 'right-center', icon = 'fa-solid fa-box' })

                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()

                        local success = true
                        if #activeMission.skillCheck > 0 then
                            success = lib.skillCheck(activeMission.skillCheck, { 'w', 'a', 's', 'd' })
                        end

                        if success then
                            local myPos = GetEntityCoords(ped)
                            TriggerServerEvent('underworld:server:missionPickup', activeMission.missionId, { x = myPos.x, y = myPos.y, z = myPos.z })
                        else
                            lib.notify({ type = 'error', description = '[MISSION FAILED] You fumbled the pickup.' })
                            TriggerServerEvent('underworld:server:failMission', activeMission.missionId)
                            ClearActiveMission()
                            break
                        end
                    end

                -- DELIVERY STAGE
                elseif activeMission.stage == 'delivery' then
                    lib.showTextUI('[E] Deliver Package', { position = 'right-center', icon = 'fa-solid fa-check' })

                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()
                        local myPos = GetEntityCoords(ped)
                        TriggerServerEvent('underworld:server:completeMission', activeMission.missionId, { x = myPos.x, y = myPos.y, z = myPos.z })
                        break
                    end
                end
            else
                lib.hideTextUI()
            end
        end
    end)
end

-- ============================================================
-- SERVER CALLBACKS
-- ============================================================

RegisterNetEvent('underworld:client:missionPickupDone', function(data)
    if not activeMission then return end

    activeMission.stage    = 'delivery'
    activeMission.delivery = data.delivery

    if activeMission.blip then RemoveBlip(activeMission.blip) end
    activeMission.blip = AddBlipForCoord(data.delivery.x, data.delivery.y, data.delivery.z)
    SetBlipSprite(activeMission.blip, 1)
    SetBlipColour(activeMission.blip, 2)
    SetBlipScale(activeMission.blip, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('[MISSION] Drop Point')
    EndTextCommandSetBlipName(activeMission.blip)
    SetNewWaypoint(data.delivery.x, data.delivery.y)
end)

RegisterNetEvent('underworld:client:missionComplete', function()
    ClearActiveMission()
end)

RegisterNetEvent('underworld:client:missionFailed', function()
    ClearActiveMission()
end)

-- ============================================================
-- CLEANUP
-- ============================================================

function ClearActiveMission()
    if not activeMission then return end
    if activeMission.blip then RemoveBlip(activeMission.blip) end
    lib.hideTextUI()
    ClearGpsPlayerWaypoint()
    activeMission = nil
end
