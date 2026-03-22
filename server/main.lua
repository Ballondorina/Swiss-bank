local dbReady = false
local Cooldowns = {}

local function GenerateAccountNumber()
    for _ = 1, 100 do
        local number = tostring(math.random(111111, 999999))
        local check = exports.oxmysql:scalar_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { number })
        if not check then return number end
    end
    -- Fallback: use time-based number if all random attempts collide
    return tostring((os.time() % 900000) + 100000)
end

local function GetUserAccountNumber(citizenid)
    local success, result = pcall(function()
        return exports.oxmysql:single_async('SELECT account_no FROM swisser_bank_pins WHERE citizenid = ?', { citizenid })
    end)

    if success and result and result.account_no then
        return result.account_no
    else
        local newAcc = GenerateAccountNumber()
        exports.oxmysql:execute('INSERT INTO swisser_bank_pins (citizenid, pin, account_no) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE account_no = COALESCE(account_no, ?)', {
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
    return false
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
        local name = ((result.fname or '') .. ' ' .. (result.lname or '')):match('^%s*(.-)%s*$')
        return { valid = true, name = name }
    end
    return { valid = false }
end)

lib.callback.register('swisser_bank:checkPIN', function(source, inputPin)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return false end
    local result = exports.oxmysql:scalar_async('SELECT pin FROM swisser_bank_pins WHERE citizenid = ?', { citizenid })
    local actualPin = result or Config.DefaultPIN
    if not result then GetUserAccountNumber(citizenid) end
    return tostring(inputPin) == tostring(actualPin)
end)

lib.callback.register('swisser_bank:getData', function(source, accountType)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not VerifyBankAccess(source) then return nil end

    local account = accountType or 'personal'

    local transactions = exports.oxmysql:query_async('SELECT * FROM swisser_bank_transactions WHERE citizenid = ? AND account = ? ORDER BY date DESC LIMIT 10', { citizenid, account })
    local mails = exports.oxmysql:query_async('SELECT * FROM swisser_bank_mails WHERE citizenid = ? ORDER BY date DESC LIMIT 20', { citizenid })
    local goal = exports.oxmysql:single_async('SELECT * FROM swisser_bank_goals WHERE citizenid = ?', { citizenid }) or { title = "Savings Goal", target = 0 }
    local cardUrl = exports.oxmysql:scalar_async('SELECT url FROM swisser_bank_cards WHERE citizenid = ?', { citizenid })
    local avatarUrl = exports.oxmysql:scalar_async('SELECT url FROM swisser_bank_avatars WHERE citizenid = ?', { citizenid })
    local shortAccount = GetUserAccountNumber(citizenid)

    return {
        balance = Bridge.GetBankBalance(source),
        name = Bridge.GetName(source),
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
    local citizenid = Bridge.GetIdentifier(src)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or amount <= 0 or amount > 10000000 then return end

    if Bridge.AdjustMoney(src, 'cash', amount, 'remove', 'Bank Deposit') then
        Bridge.AdjustMoney(src, 'bank', amount, 'add', 'Bank Deposit')
        CreateLog(citizenid, amount, 'income', 'Bank Deposit', 'personal')
        TriggerClientEvent('swisser_bank:client:notify', src, 'success', 'Deposited ' .. amount .. ' ' .. Config.Currency)
    else
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', 'Insufficient cash for deposit')
    end
end)

RegisterNetEvent('swisser_bank:withdraw', function(amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local citizenid = Bridge.GetIdentifier(src)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or amount <= 0 or amount > 10000000 then return end

    if Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Bank Withdraw') then
        Bridge.AdjustMoney(src, 'cash', amount, 'add', 'Bank Withdraw')
        CreateLog(citizenid, amount, 'outcome', 'Bank Withdraw', 'personal')
        TriggerClientEvent('swisser_bank:client:notify', src, 'success', 'Withdrew ' .. amount .. ' ' .. Config.Currency)
    else
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', 'Insufficient funds for withdrawal')
    end
end)

RegisterNetEvent('swisser_bank:transfer', function(accountNo, amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local citizenid = Bridge.GetIdentifier(src)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or amount <= 0 or amount > 10000000 then return end
    if Bridge.GetBankBalance(src) < amount then return end

    local targetData = exports.oxmysql:single_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { accountNo })
    if not targetData then return end
    if targetData.citizenid == citizenid then return end -- Prevent self-transfer

    local myShortAccount = GetUserAccountNumber(citizenid)
    local targetSrc = Bridge.GetPlayerByCID(targetData.citizenid)

    if targetSrc then
        -- Online player transfer
        Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
        Bridge.AdjustMoney(targetSrc, 'bank', amount, 'add', 'Transfer Received')
        CreateLog(citizenid, amount, 'outcome', 'To: ' .. accountNo, 'personal')
        CreateLog(targetData.citizenid, amount, 'income', 'From: ' .. myShortAccount, 'personal')
        SendBankMail(targetData.citizenid, "Incoming Transfer", "You received " .. amount .. " " .. Config.Currency, "Wire Transfer")
    else
        -- Offline player transfer
        if CurrentFramework == 'qb' then
            local offlineTarget = exports.oxmysql:single_async('SELECT money FROM players WHERE citizenid = ?', { targetData.citizenid })
            if offlineTarget then
                local money = json.decode(offlineTarget.money)
                money.bank = money.bank + amount
                Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
                exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), targetData.citizenid })
                CreateLog(citizenid, amount, 'outcome', 'To: ' .. accountNo, 'personal')
                CreateLog(targetData.citizenid, amount, 'income', 'From: ' .. myShortAccount, 'personal')
                SendBankMail(targetData.citizenid, "Incoming Transfer", "You received " .. amount .. " " .. Config.Currency .. " while you were away.", "Wire Transfer")
            end
        elseif CurrentFramework == 'esx' then
            local offlineBalance = exports.oxmysql:scalar_async('SELECT `bank` FROM `users` WHERE `identifier` = ?', { targetData.citizenid })
            if offlineBalance ~= nil then
                Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
                exports.oxmysql:execute('UPDATE `users` SET `bank` = `bank` + ? WHERE `identifier` = ?', { amount, targetData.citizenid })
                CreateLog(citizenid, amount, 'outcome', 'To: ' .. accountNo, 'personal')
                CreateLog(targetData.citizenid, amount, 'income', 'From: ' .. myShortAccount, 'personal')
                SendBankMail(targetData.citizenid, "Incoming Transfer", "You received " .. amount .. " " .. Config.Currency .. " while you were away.", "Wire Transfer")
            end
        end
    end
end)

lib.callback.register('swisser_bank:updateGoal', function(source, data)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return false end
    exports.oxmysql:execute('INSERT INTO swisser_bank_goals (citizenid, title, target) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE title = ?, target = ?', {
        citizenid, data.title, data.target, data.title, data.target
    })
    return true
end)

lib.callback.register('swisser_bank:changePIN', function(source, data)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end

    -- Validate new PIN format: must be exactly 4 digits
    local newPin = tostring(data.newPin or '')
    if #newPin ~= 4 or not newPin:match('^%d+$') then return false end

    -- Verify the current PIN before allowing the change
    local storedPin = exports.oxmysql:scalar_async('SELECT pin FROM swisser_bank_pins WHERE citizenid = ?', { citizenid })
    local actualPin = storedPin or Config.DefaultPIN
    if tostring(data.currentPin) ~= tostring(actualPin) then return false end

    if Bridge.AdjustMoney(source, 'bank', Config.PINChangeCost, 'remove', 'Bank PIN Change') then
        exports.oxmysql:execute('UPDATE swisser_bank_pins SET pin = ? WHERE citizenid = ?', {
            newPin, citizenid
        })
        return true
    end
    return false
end)

lib.callback.register('swisser_bank:updateCard', function(source, url)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end
    if url == "REMOVE" then
        exports.oxmysql:execute('DELETE FROM swisser_bank_cards WHERE citizenid = ?', { citizenid })
        return true
    end
    if Bridge.AdjustMoney(source, 'bank', Config.CustomCardCost, 'remove', 'Custom Card Design') then
        exports.oxmysql:execute('INSERT INTO swisser_bank_cards (citizenid, url) VALUES (?, ?) ON DUPLICATE KEY UPDATE url = ?', {
            citizenid, url, url
        })
        return true
    end
    return false
end)

lib.callback.register('swisser_bank:updateAvatar', function(source, url)
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end
    if url == "REMOVE" then
        exports.oxmysql:execute('DELETE FROM swisser_bank_avatars WHERE citizenid = ?', { citizenid })
        return true
    end
    if Bridge.AdjustMoney(source, 'bank', Config.AvatarChangeCost, 'remove', 'Custom Bank Avatar') then
        exports.oxmysql:execute('INSERT INTO swisser_bank_avatars (citizenid, url) VALUES (?, ?) ON DUPLICATE KEY UPDATE url = ?', {
            citizenid, url, url
        })
        return true
    end
    return false
end)

RegisterNetEvent('swisser_bank:markMailsRead', function()
    local src = source
    local citizenid = Bridge.GetIdentifier(src)
    if not citizenid then return end
    exports.oxmysql:execute('UPDATE swisser_bank_mails SET is_read = 1 WHERE citizenid = ?', { citizenid })
end)

lib.callback.register('swisser_bank:getAdminData', function(source)
    -- Admin access is not yet implemented; deny all by default
    return nil
end)
