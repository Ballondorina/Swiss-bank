local Framework = nil
local CurrentFramework = nil

if GetResourceState('qb-core') == 'started' then
    Framework = exports['qb-core']:GetCoreObject()
    CurrentFramework = 'qb'
elseif GetResourceState('es_extended') == 'started' then
    Framework = exports['es_extended']:getSharedObject()
    CurrentFramework = 'esx'
end

local Bridge = {}

function Bridge.GetPlayerData()
    if CurrentFramework == 'qb' then
        return Framework.Functions.GetPlayerData()
    else
        return Framework.GetPlayerData()
    end
end

-- Events for updating local PlayerData
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = Bridge.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
end)

return Bridge