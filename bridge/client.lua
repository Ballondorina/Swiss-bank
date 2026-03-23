Framework = nil
CurrentFramework = nil

if GetResourceState('qb-core') == 'started' then
    Framework = exports['qb-core']:GetCoreObject()
    CurrentFramework = 'qb'
elseif GetResourceState('es_extended') == 'started' then
    Framework = exports['es_extended']:getSharedObject()
    CurrentFramework = 'esx'
end

Bridge = {}

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

-- Returns gang name + isBoss for the local player
function Bridge.GetGangClient()
    local pd = Bridge.GetPlayerData()
    if not pd then return nil, false end
    if CurrentFramework == 'qb' then
        local gang = pd.gang
        if not gang or gang.name == 'none' then return nil, false end
        return gang.name, gang.isboss == true
    else
        local job = pd.job
        return job and job.name or nil, job and job.grade_level >= 3 or false
    end
end

-- Bridge is global, no return needed