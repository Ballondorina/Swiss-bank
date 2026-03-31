-- ============================================================
-- UNDERWORLD — Client: Main (v2)
-- New: stash access, creation NUI callbacks, extended panel
-- ============================================================

-- ============================================================
-- PANEL OPEN
-- ============================================================

RegisterNetEvent('underworld:client:openPanel', function(data)
    if not data then
        lib.notify({ type = 'error', description = 'You are not part of any organization.' })
        return
    end
    SendNUIMessage({ action = 'openPanel', data = data })
    SetNuiFocus(true, true)

    -- Initialise drug lab + robbery targets from panel data
    TriggerEvent('underworld:client:initOps', data.labData, data.robberyData)
end)

-- ============================================================
-- STASH OPEN
-- ============================================================

RegisterNetEvent('underworld:client:openStash', function(data)
    if GetResourceState('ox_inventory') ~= 'started' then
        lib.notify({ type = 'error', description = 'Inventory system not available.' })
        return
    end
    exports.ox_inventory:openInventory('stash', data.stashId)
end)

-- ============================================================
-- INVITE
-- ============================================================

RegisterNetEvent('underworld:client:orgInvite', function(data)
    CreateThread(function()
        local alert = lib.alertDialog({
            header   = 'Organization Invite',
            content  = ('**%s** has invited you to join **%s**.\n\nAccept?'):format(data.inviterName, data.orgName),
            centered = true,
            cancel   = true
        })
        if alert == 'confirm' then
            TriggerServerEvent('underworld:server:acceptInvite', data.orgId)
        end
    end)
end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('closePanel', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('underworld:server:deposit', data.amount)
    cb({})
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('underworld:server:withdraw', data.amount)
    cb({})
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('underworld:server:kickMember', data.citizenId)
    cb({})
end)

RegisterNUICallback('setRank', function(data, cb)
    TriggerServerEvent('underworld:server:setRank', data.citizenId, data.rank)
    cb({})
end)

RegisterNUICallback('setSalary', function(data, cb)
    TriggerServerEvent('underworld:server:setSalary', data.citizenId, data.salary)
    cb({})
end)

RegisterNUICallback('startMission', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('underworld:server:startMission', data.missionId)
    cb({})
end)

RegisterNUICallback('openStash', function(_, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('underworld:server:openStash')
    cb({})
end)

RegisterNUICallback('leaveOrg', function(_, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('underworld:server:leaveOrg')
    cb({})
end)

-- ============================================================
-- v3 NUI CALLBACKS — Tier Upgrade, Transfer, Announcements,
--   Wars, Alliances, Votes, Refresh
-- ============================================================

RegisterNUICallback('upgradeTier', function(_, cb)
    TriggerServerEvent('underworld:server:upgradeTier')
    cb({})
end)

RegisterNUICallback('transferLeadership', function(data, cb)
    TriggerServerEvent('underworld:server:transferLeadership', data.citizenId)
    cb({})
end)

RegisterNUICallback('postAnnouncement', function(data, cb)
    TriggerServerEvent('underworld:server:postAnnouncement', data.content, data.pinned)
    cb({})
end)

RegisterNUICallback('deleteAnnouncement', function(data, cb)
    TriggerServerEvent('underworld:server:deleteAnnouncement', data.id)
    cb({})
end)

RegisterNUICallback('declareWar', function(data, cb)
    TriggerServerEvent('underworld:server:declareWar', data.targetOrgId)
    cb({})
end)

RegisterNUICallback('respondWar', function(data, cb)
    TriggerServerEvent('underworld:server:respondWar', data.warId, data.accept)
    cb({})
end)

RegisterNUICallback('surrender', function(_, cb)
    TriggerServerEvent('underworld:server:surrender')
    cb({})
end)

RegisterNUICallback('proposeAlliance', function(data, cb)
    TriggerServerEvent('underworld:server:proposeAlliance', data.targetOrgId)
    cb({})
end)

RegisterNUICallback('respondAlliance', function(data, cb)
    TriggerServerEvent('underworld:server:respondAlliance', data.allianceId, data.accept)
    cb({})
end)

RegisterNUICallback('dissolveAlliance', function(data, cb)
    TriggerServerEvent('underworld:server:dissolveAlliance', data.allianceId)
    cb({})
end)

RegisterNUICallback('initiateVote', function(data, cb)
    TriggerServerEvent('underworld:server:initiateVote', data.voteType, data.targetCitizen, data.description)
    cb({})
end)

RegisterNUICallback('castVote', function(data, cb)
    TriggerServerEvent('underworld:server:castVote', data.voteId, data.voteFor)
    cb({})
end)

RegisterNUICallback('refreshPanel', function(_, cb)
    TriggerServerEvent('underworld:server:refreshPanel')
    cb({})
end)

-- ============================================================
-- DRUG LAB NUI CALLBACKS
-- ============================================================

RegisterNUICallback('purchaseLab', function(data, cb)
    TriggerServerEvent('underworld:server:purchaseLab', data.locationId)
    cb({})
end)

RegisterNUICallback('shutdownLab', function(data, cb)
    TriggerServerEvent('underworld:server:shutdownLab', data.labId)
    cb({})
end)

-- ============================================================
-- PANEL REFRESH — re-opens panel with new data (no close/open)
-- ============================================================

RegisterNetEvent('underworld:client:refreshPanel', function(data)
    if not data then return end
    SendNUIMessage({ action = 'refreshPanel', data = data })
end)

-- ============================================================
-- COMMAND
-- ============================================================

RegisterCommand('orgpanel', function()
    TriggerServerEvent('underworld:server:getOrgData')
end, false)

-- ============================================================
-- OFFICE TERMINAL ZONES (ox_target)
-- ============================================================

CreateThread(function()
    Wait(1000)
    for i, loc in ipairs(Config.OfficeLocations) do
        exports.ox_target:addSphereZone({
            coords  = vec3(loc.coords.x, loc.coords.y, loc.coords.z),
            radius  = 2.0,
            debug   = false,
            options = {
                {
                    name     = 'uw_office_panel_' .. i,
                    label    = loc.label .. ' — Terminal',
                    icon     = 'fa-solid fa-building',
                    onSelect = function()
                        TriggerServerEvent('underworld:server:getOrgData')
                    end
                },
                {
                    name     = 'uw_office_stash_' .. i,
                    label    = loc.label .. ' — Org Stash',
                    icon     = 'fa-solid fa-box-archive',
                    onSelect = function()
                        TriggerServerEvent('underworld:server:openStash')
                    end
                }
            }
        })

        -- Blip
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, 475)
        SetBlipColour(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.label)
        EndTextCommandSetBlipName(blip)
    end
end)
