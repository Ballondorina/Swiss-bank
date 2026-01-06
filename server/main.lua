local QBCore = exports['qb-core']:GetCoreObject()
local dbReady = false
local Cooldowns = {}

local function GenerateAccountNumber()
    local number = tostring(math.random(111111, 999999))
    local check = exports.oxmysql:scalar_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { number })
    if check then
        return GenerateAccountNumber()
    end
    return number
end

local function GetUserAccountNumber(citizenid)
    local success, result = pcall(function()
        return exports.oxmysql:single_async('SELECT account_no FROM swisser_bank_pins WHERE citizenid = ?', { citizenid })
    end)

    if success and result and result.account_no then
        return result.account_no
    else
        local newAcc = GenerateAccountNumber()
        exports.oxmysql:execute('INSERT INTO swisser_bank_pins (citizenid, pin, account_no) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE account_no = ?', {
            citizenid, Config.DefaultPIN, newAcc, newAcc
        })
        return newAcc
    end
end

local function VerifyBankAccess(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    for _, loc in ipairs(Config.BankLocations) do
        if #(pCoords - loc.coords) < (Config.MaxDistance + 10.0) then
            return true
        end
    end
    return true 
end

local function CheckCooldown(source)
    local now = GetGameTimer()
    if Cooldowns[source] and (now - Cooldowns[source]) < Config.EventCooldown then
        return false
    end
    Cooldowns[source] = now
    return true
end

local function CreateLog(citizenid, amount, type, label, accountType)
    if not dbReady then return end
    exports.oxmysql:insert('INSERT INTO swisser_bank_transactions (citizenid, amount, type, label, account) VALUES (?, ?, ?, ?, ?)', {
        citizenid, amount, type, label, accountType or 'personal'
    })
end

local function SendBankMail(citizenid, subject, message, sender)
    if not dbReady then return end
    exports.oxmysql:insert('INSERT INTO swisser_bank_mails (citizenid, subject, message, sender) VALUES (?, ?, ?, ?)', {
        citizenid, subject, message, sender or 'Bank System'
    })
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    dbReady = true
end)

-- Validation Callback for IBAN (Transfer Feedback)
lib.callback.register('swisser_bank:validateIBAN', function(source, iban)
    if not iban or iban == "" then return { valid = false } end
    
    local result = exports.oxmysql:single_async([[
        SELECT p.citizenid, JSON_VALUE(pl.charinfo, '$.firstname') as fname, JSON_VALUE(pl.charinfo, '$.lastname') as lname 
        FROM swisser_bank_pins p 
        LEFT JOIN players pl ON p.citizenid = pl.citizenid 
        WHERE p.account_no = ?
    ]], { iban })

    if result then
        return { 
            valid = true, 
            name = result.fname .. " " .. result.lname 
        }
    end
    return { valid = false }
end)

lib.callback.register('swisser_bank:checkPIN', function(source, inputPin)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local citizenid = Player.PlayerData.citizenid
    local result = exports.oxmysql:scalar_async('SELECT pin FROM swisser_bank_pins WHERE citizenid = ?', { citizenid })
    local actualPin = result or Config.DefaultPIN
    if not result then GetUserAccountNumber(citizenid) end
    return tostring(inputPin) == tostring(actualPin)
end)

lib.callback.register('swisser_bank:getData', function(source, accountType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not VerifyBankAccess(source) then return nil end

    local citizenid = Player.PlayerData.citizenid
    local account = accountType or 'personal'
    
    local transactions = exports.oxmysql:query_async('SELECT * FROM swisser_bank_transactions WHERE citizenid = ? AND account = ? ORDER BY date DESC LIMIT 10', { citizenid, account })
    local mails = exports.oxmysql:query_async('SELECT * FROM swisser_bank_mails WHERE citizenid = ? ORDER BY date DESC LIMIT 20', { citizenid })
    local goal = exports.oxmysql:single_async('SELECT * FROM swisser_bank_goals WHERE citizenid = ?', { citizenid }) or { title = "Savings Goal", target = 0 }
    local cardUrl = exports.oxmysql:scalar_async('SELECT url FROM swisser_bank_cards WHERE citizenid = ?', { citizenid })
    local avatarUrl = exports.oxmysql:scalar_async('SELECT url FROM swisser_bank_avatars WHERE citizenid = ?', { citizenid })
    local shortAccount = GetUserAccountNumber(citizenid)

    return {
        balance = Player.PlayerData.money.bank,
        name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        iban = shortAccount, 
        transactions = transactions or {},
        mails = mails or {},
        currentAccount = account,
        tiers = Config.CardTiers,
        pinCost = Config.PINChangeCost,
        cardCost = Config.CustomCardCost,
        avatarCost = Config.AvatarChangeCost,
        cardUrl = cardUrl,
        avatarUrl = avatarUrl,
        goal = goal,
        branding = Config.ScriptBranding,
        currency = Config.Currency,
        enableCurrencyChanger = Config.EnableCurrencyChanger,
        availableCurrencies = Config.AvailableCurrencies
    }
end)

RegisterNetEvent('swisser_bank:deposit', function(amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not Player or amount <= 0 then return end

    if Player.Functions.RemoveMoney('cash', amount, 'Bank Deposit') then
        Player.Functions.AddMoney('bank', amount, 'Bank Deposit')
        CreateLog(Player.PlayerData.citizenid, amount, 'income', 'Bank Deposit', 'personal')
    end
end)

RegisterNetEvent('swisser_bank:withdraw', function(amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not Player or amount <= 0 then return end

    if Player.Functions.RemoveMoney('bank', amount, 'Bank Withdraw') then
        Player.Functions.AddMoney('cash', amount, 'Bank Withdraw')
        CreateLog(Player.PlayerData.citizenid, amount, 'outcome', 'Bank Withdraw', 'personal')
    end
end)

RegisterNetEvent('swisser_bank:transfer', function(accountNo, amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not Player or amount <= 0 then return end
    if Player.PlayerData.money.bank < amount then return end

    local targetData = exports.oxmysql:single_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { accountNo })
    if not targetData then return end 

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetData.citizenid)
    local myShortAccount = GetUserAccountNumber(Player.PlayerData.citizenid)

    if targetPlayer then
        if targetPlayer.PlayerData.citizenid == Player.PlayerData.citizenid then return end
        Player.Functions.RemoveMoney('bank', amount, 'Transfer Sent')
        targetPlayer.Functions.AddMoney('bank', amount, 'Transfer Received')
        CreateLog(Player.PlayerData.citizenid, amount, 'outcome', 'To: '..accountNo, 'personal')
        CreateLog(targetPlayer.PlayerData.citizenid, amount, 'income', 'From: '..myShortAccount, 'personal')
        SendBankMail(targetPlayer.PlayerData.citizenid, "Incoming Transfer", "You received " .. amount .. " " .. Config.Currency, "Wire Transfer")
    else
        local offlineTarget = exports.oxmysql:single_async('SELECT money FROM players WHERE citizenid = ?', { targetData.citizenid })
        if offlineTarget then
            local money = json.decode(offlineTarget.money)
            money.bank = money.bank + amount
            Player.Functions.RemoveMoney('bank', amount, 'Transfer Sent')
            exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), targetData.citizenid })
            CreateLog(Player.PlayerData.citizenid, amount, 'outcome', 'To: '..accountNo, 'personal')
            CreateLog(targetData.citizenid, amount, 'income', 'From: '..myShortAccount, 'personal')
            SendBankMail(targetData.citizenid, "Incoming Transfer", "You received " .. amount .. " " .. Config.Currency .. " while you were away.", "Wire Transfer")
        end
    end
end)

lib.callback.register('swisser_bank:updateGoal', function(source, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    exports.oxmysql:execute('INSERT INTO swisser_bank_goals (citizenid, title, target) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE title = ?, target = ?', {
        Player.PlayerData.citizenid, data.title, data.target, data.title, data.target
    })
    return true
end)

lib.callback.register('swisser_bank:changePIN', function(source, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not CheckCooldown(source) then return false end
    if Player.Functions.RemoveMoney('bank', Config.PINChangeCost, 'Bank PIN Change') then
        exports.oxmysql:execute('UPDATE swisser_bank_pins SET pin = ? WHERE citizenid = ?', {
            data.newPin, Player.PlayerData.citizenid
        })
        return true
    end
    return false
end)

lib.callback.register('swisser_bank:updateCard', function(source, url)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not CheckCooldown(source) then return false end
    if url == "REMOVE" then
        exports.oxmysql:execute('DELETE FROM swisser_bank_cards WHERE citizenid = ?', { Player.PlayerData.citizenid })
        return true
    end
    if Player.Functions.RemoveMoney('bank', Config.CustomCardCost, 'Custom Card Design') then
        exports.oxmysql:execute('INSERT INTO swisser_bank_cards (citizenid, url) VALUES (?, ?) ON DUPLICATE KEY UPDATE url = ?', {
            Player.PlayerData.citizenid, url, url
        })
        return true
    end
    return false
end)

lib.callback.register('swisser_bank:updateAvatar', function(source, url)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not CheckCooldown(source) then return false end
    if url == "REMOVE" then
        exports.oxmysql:execute('DELETE FROM swisser_bank_avatars WHERE citizenid = ?', { Player.PlayerData.citizenid })
        return true
    end
    if Player.Functions.RemoveMoney('bank', Config.AvatarChangeCost, 'Custom Bank Avatar') then
        exports.oxmysql:execute('INSERT INTO swisser_bank_avatars (citizenid, url) VALUES (?, ?) ON DUPLICATE KEY UPDATE url = ?', {
            Player.PlayerData.citizenid, url, url
        })
        return true
    end
    return false
end)

RegisterNetEvent('swisser_bank:markMailsRead', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    exports.oxmysql:execute('UPDATE swisser_bank_mails SET is_read = 1 WHERE citizenid = ?', { Player.PlayerData.citizenid })
end)