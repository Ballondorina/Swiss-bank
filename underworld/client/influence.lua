-- ============================================================
-- UNDERWORLD — Client: Influence Zone Presence Detection
-- ============================================================

local activeZone = nil  -- current zone player is standing in

-- ============================================================
-- ZONE CHECK THREAD
-- Runs every 15 seconds, reports presence to server every 60s
-- ============================================================

CreateThread(function()
    -- Wait for player to fully load
    Wait(5000)

    while true do
        Wait(15000)

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        local foundZone = nil
        for _, zone in ipairs(Config.InfluenceZones) do
            local dist = #(pos - vec3(zone.coords.x, zone.coords.y, zone.coords.z))
            if dist <= zone.radius then
                foundZone = zone.id
                break
            end
        end

        if foundZone ~= activeZone then
            activeZone = foundZone
            if activeZone then
                -- Show subtle zone entry notification
                local zoneName = nil
                for _, z in ipairs(Config.InfluenceZones) do
                    if z.id == activeZone then
                        zoneName = z.label
                        break
                    end
                end
                if zoneName then
                    lib.notify({
                        type        = 'inform',
                        description = ('Entering territory: %s'):format(zoneName),
                        duration    = 3000
                    })
                end
            end
        end

        -- Report presence to server if in a zone
        if activeZone then
            TriggerServerEvent('underworld:server:zonePresence', activeZone)
        end
    end
end)

-- ============================================================
-- MINIMAP ZONE BLIPS (subtle, not drawn on map)
-- Shown as radar blips for active zones
-- ============================================================

CreateThread(function()
    Wait(2000)
    for _, zone in ipairs(Config.InfluenceZones) do
        local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipColour(blip, 49)  -- subtle yellow
        SetBlipAlpha(blip, 40)
        SetBlipHighDetail(blip, true)

        local nameBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(nameBlip, 280)
        SetBlipColour(nameBlip, 49)
        SetBlipScale(nameBlip, 0.6)
        SetBlipAsShortRange(nameBlip, true)
        SetBlipCategory(nameBlip, 10)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('[Territory] %s'):format(zone.label))
        EndTextCommandSetBlipName(nameBlip)
    end
end)
