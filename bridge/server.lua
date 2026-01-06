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

function Bridge.GetPlayer(source)
    if CurrentFramework == 'qb' then
        return Framework.Functions.GetPlayer(source)
    else
        return Framework.GetPlayerFromId(source)
    end
end

function Bridge.GetIdentifier(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return nil end
    if CurrentFramework == 'qb' then
        return Player.PlayerData.citizenid
    else
        return Player.identifier
    end
end

function Bridge.GetName(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return "Unknown" end
    if CurrentFramework == 'qb' then
        return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    else
        return Player.getName()
    end
end

function Bridge.GetBankBalance(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return 0 end
    if CurrentFramework == 'qb' then
        return Player.PlayerData.money.bank
    else
        return Player.getAccount('bank').money
    end
end

function Bridge.AdjustMoney(source, account, amount, type, reason)
    local Player = Bridge.GetPlayer(source)
    if not Player then return false end
    
    if CurrentFramework == 'qb' then
        if type == 'add' then
            return Player.Functions.AddMoney(account, amount, reason)
        else
            return Player.Functions.RemoveMoney(account, amount, reason)
        end
    else
        local esxAccount = account == 'cash' and 'money' or 'bank'
        if type == 'add' then
            Player.addAccountMoney(esxAccount, amount)
            return true
        else
            if Player.getAccount(esxAccount).money >= amount then
                Player.removeAccountMoney(esxAccount, amount)
                return true
            end
        end
    end
    return false
end

function Bridge.GetPlayerByCID(citizenid)
    if CurrentFramework == 'qb' then
        local p = Framework.Functions.GetPlayerByCitizenId(citizenid)
        return p and p.PlayerData.source or nil
    else
        local p = Framework.GetPlayerFromIdentifier(citizenid)
        return p and p.source or nil
    end
end

return Bridge