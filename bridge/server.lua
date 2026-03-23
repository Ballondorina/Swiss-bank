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

function Bridge.AdjustMoney(source, account, amount, adjType, reason)
    -- ox_inventory cash: use inventory item instead of framework money account
    if Config.UseOxInventory and account == 'cash' then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        local item = Config.CashItem or 'money'
        if adjType == 'add' then
            exports.ox_inventory:AddItem(source, item, amount)
            return true
        else
            local count = exports.ox_inventory:GetItemCount(source, item)
            if count >= amount then
                exports.ox_inventory:RemoveItem(source, item, amount)
                return true
            end
            return false
        end
    end

    local Player = Bridge.GetPlayer(source)
    if not Player then return false end

    if CurrentFramework == 'qb' then
        if adjType == 'add' then
            return Player.Functions.AddMoney(account, amount, reason)
        else
            return Player.Functions.RemoveMoney(account, amount, reason)
        end
    else
        local esxAccount = account == 'cash' and 'money' or 'bank'
        if adjType == 'add' then
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

-- Returns gang/org name + whether the player is the boss
function Bridge.GetGang(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return nil, false end
    if CurrentFramework == 'qb' then
        local gang = Player.PlayerData.gang
        if not gang or gang.name == 'none' then return nil, false end
        return gang.name, gang.isboss == true
    else
        local job = Player.getJob()
        -- In ESX servers that use jobs as gangs, grade 3+ is considered boss
        return job and job.name or nil, job and job.grade_level >= 3 or false
    end
end

-- Returns the player's current black money amount
function Bridge.GetBlackMoney(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return 0 end
    if CurrentFramework == 'qb' then
        return Player.PlayerData.money['black_money'] or 0
    else
        local acc = Player.getAccount('black_money')
        return acc and acc.money or 0
    end
end

-- Add or remove black money
function Bridge.AdjustBlackMoney(source, amount, adjType)
    local Player = Bridge.GetPlayer(source)
    if not Player then return false end
    if CurrentFramework == 'qb' then
        if adjType == 'add' then
            return Player.Functions.AddMoney('black_money', amount, 'Laundry')
        else
            return Player.Functions.RemoveMoney('black_money', amount, 'Laundry')
        end
    else
        if adjType == 'add' then
            Player.addAccountMoney('black_money', amount)
            return true
        else
            if Player.getAccount('black_money').money >= amount then
                Player.removeAccountMoney('black_money', amount)
                return true
            end
            return false
        end
    end
end

-- Look up a player's display name by citizenid (works offline via DB)
function Bridge.GetNameByCID(citizenid)
    if CurrentFramework == 'qb' then
        local row = exports.oxmysql:single_async('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if row and row.charinfo then
            local ok, info = pcall(json.decode, row.charinfo)
            if ok and info then
                return (info.firstname or '') .. ' ' .. (info.lastname or '')
            end
        end
    else
        local row = exports.oxmysql:single_async('SELECT firstname, lastname FROM users WHERE identifier = ?', { citizenid })
        if row then return (row.firstname or '') .. ' ' .. (row.lastname or '') end
    end
    return 'Unknown'
end

-- Bridge is global, no return needed