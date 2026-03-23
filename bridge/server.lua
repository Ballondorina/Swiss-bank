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

-- ============================================================
-- INVENTORY CASH BRIDGE
-- Handles cash (hand money) via whichever inventory your server runs.
-- Set Config.InventorySystem in config.lua to match your resource.
--
-- Supported values for Config.InventorySystem:
--   'ox'      → ox_inventory
--   'qs'      → qs-inventory
--   'ak47'    → ak47_inventory
--   'ps'      → ps-inventory (Project Sloth)
--   'codem'   → codem-inventory
--   'none'    → use framework money (QBCore / ESX) — default
--
-- Adding your own inventory:
--   1. Add a new elseif block below following the same pattern.
--   2. Your block needs two operations:
--        add:    give the player `amount` of Config.CashItem
--        remove: check the player has enough, then take it away
--   3. Return true on success, false on failure.
--   4. Set Config.InventorySystem = 'yourkey' in config.lua.
-- ============================================================
local function AdjustInventoryCash(source, amount, adjType)
    local item = Config.CashItem or 'money'
    local inv   = Config.InventorySystem or 'none'

    -- ox_inventory
    if inv == 'ox' then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        if adjType == 'add' then
            exports.ox_inventory:AddItem(source, item, amount)
            return true
        else
            if exports.ox_inventory:GetItemCount(source, item) >= amount then
                exports.ox_inventory:RemoveItem(source, item, amount)
                return true
            end
            return false
        end

    -- qs-inventory
    elseif inv == 'qs' then
        if GetResourceState('qs-inventory') ~= 'started' then return false end
        if adjType == 'add' then
            exports['qs-inventory']:AddItem(source, item, amount)
            return true
        else
            if exports['qs-inventory']:GetItemCount(source, item) >= amount then
                exports['qs-inventory']:RemoveItem(source, item, amount)
                return true
            end
            return false
        end

    -- ak47_inventory
    elseif inv == 'ak47' then
        if GetResourceState('ak47_inventory') ~= 'started' then return false end
        if adjType == 'add' then
            exports['ak47_inventory']:AddItem(source, item, amount)
            return true
        else
            if exports['ak47_inventory']:GetItemCount(source, item) >= amount then
                exports['ak47_inventory']:RemoveItem(source, item, amount)
                return true
            end
            return false
        end

    -- ps-inventory (Project Sloth)
    elseif inv == 'ps' then
        if GetResourceState('ps-inventory') ~= 'started' then return false end
        if adjType == 'add' then
            exports['ps-inventory']:AddItem(source, item, amount)
            return true
        else
            if exports['ps-inventory']:GetItemCount(source, item) >= amount then
                exports['ps-inventory']:RemoveItem(source, item, amount)
                return true
            end
            return false
        end

    -- codem-inventory
    elseif inv == 'codem' then
        if GetResourceState('codem-inventory') ~= 'started' then return false end
        if adjType == 'add' then
            exports['codem-inventory']:AddItem(source, item, amount)
            return true
        else
            if exports['codem-inventory']:GetItemCount(source, item) >= amount then
                exports['codem-inventory']:RemoveItem(source, item, amount)
                return true
            end
            return false
        end

    -- -------------------------------------------------------
    -- CUSTOM INVENTORY — copy this block and fill in your resource name:
    --
    -- elseif inv == 'myinv' then
    --     if GetResourceState('my-inventory') ~= 'started' then return false end
    --     if adjType == 'add' then
    --         exports['my-inventory']:AddItem(source, item, amount)
    --         return true
    --     else
    --         if exports['my-inventory']:GetItemCount(source, item) >= amount then
    --             exports['my-inventory']:RemoveItem(source, item, amount)
    --             return true
    --         end
    --         return false
    --     end
    -- -------------------------------------------------------
    end

    return nil -- 'none' or unknown: fall through to framework money
end

function Bridge.AdjustMoney(source, account, amount, adjType, reason)
    -- Route cash through the configured inventory system (if not 'none')
    if account == 'cash' and Config.InventorySystem and Config.InventorySystem ~= 'none' then
        local result = AdjustInventoryCash(source, amount, adjType)
        if result ~= nil then return result end
        -- nil means inventory key not recognised — fall through to framework
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