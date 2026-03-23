local dbReady = false
local Cooldowns = {}

-- Server-side locale helper (Locales is a shared_script, available here too)
local function LS(key, ...)
    local lang = Config.Language or 'en'
    local tbl  = (Locales and Locales[lang]) or (Locales and Locales['en']) or {}
    local str  = tbl[key] or key
    if select('#', ...) > 0 then return string.format(str, ...) end
    return str
end

local function GenerateAccountNumber(tableCheck)
    tableCheck = tableCheck or 'swisser_bank_pins'
    for _ = 1, 100 do
        local number = tostring(math.random(111111, 999999))
        local col = tableCheck == 'swisser_bank_org_accounts' and 'org_id' or 'citizenid'
        local check = exports.oxmysql:scalar_async('SELECT `' .. col .. '` FROM `' .. tableCheck .. '` WHERE account_no = ?', { number })
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

local function VerifyLaundryAccess(source)
    if not Config.LaundryEnabled then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    local npc = Config.LaundryNPC.coords
    return #(pCoords - vector3(npc.x, npc.y, npc.z)) < 8.0
end

-- Log suspicious access attempts for server admins to review
local function WarnCheat(source, eventName)
    local name = GetPlayerName(source) or 'unknown'
    print(string.format('[SwisserBank] ⚠️  BLOCKED: player %s (id:%d) tried "%s" without proper access.', name, source, eventName))
    Integrations.OnSuspicious(source, eventName)
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
    if not citizenid then return nil end
    -- Note: getData is safe to call from any location (ATMs, bank, etc.).
    -- All money-moving operations (deposit/withdraw/transfer) have their own
    -- VerifyBankAccess / VerifyLaundryAccess checks.

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
        TriggerClientEvent('swisser_bank:client:notify', src, 'success', LS('notify_deposited', amount, Config.Currency))
        Integrations.OnDeposit(src, citizenid, amount)
    else
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', LS('notify_no_cash'))
    end
end)

local function IsAccountLocked(citizenid)
    if not Config.LoanEnabled then return false end
    local locked = exports.oxmysql:scalar_async('SELECT account_locked FROM swisser_bank_loans WHERE citizenid = ?', { citizenid })
    return locked == 1
end

RegisterNetEvent('swisser_bank:withdraw', function(amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local citizenid = Bridge.GetIdentifier(src)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or amount <= 0 or amount > 10000000 then return end

    if IsAccountLocked(citizenid) then
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', LS('notify_frozen'))
        return
    end

    if Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Bank Withdraw') then
        Bridge.AdjustMoney(src, 'cash', amount, 'add', 'Bank Withdraw')
        CreateLog(citizenid, amount, 'outcome', 'Bank Withdraw', 'personal')
        TriggerClientEvent('swisser_bank:client:notify', src, 'success', LS('notify_withdrawn', amount, Config.Currency))
        Integrations.OnWithdraw(src, citizenid, amount)
    else
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', LS('notify_no_funds'))
    end
end)

RegisterNetEvent('swisser_bank:transfer', function(accountNo, amount, accountType)
    local src = source
    if not CheckCooldown(src) or not VerifyBankAccess(src) then return end
    local citizenid = Bridge.GetIdentifier(src)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or amount <= 0 or amount > 10000000 then return end
    if Bridge.GetBankBalance(src) < amount then return end

    if IsAccountLocked(citizenid) then
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', LS('notify_frozen'))
        return
    end

    local targetData = exports.oxmysql:single_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { accountNo })
    if not targetData then return end
    if targetData.citizenid == citizenid then return end -- Prevent self-transfer

    local myShortAccount = GetUserAccountNumber(citizenid)
    local senderName     = Bridge.GetName(src)
    local targetSrc      = Bridge.GetPlayerByCID(targetData.citizenid)

    if targetSrc then
        -- Online player transfer
        local targetName = Bridge.GetName(targetSrc)
        Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
        Bridge.AdjustMoney(targetSrc, 'bank', amount, 'add', 'Transfer Received')
        CreateLog(citizenid, amount, 'outcome', 'To: ' .. targetName .. ' (' .. accountNo .. ')', 'personal')
        CreateLog(targetData.citizenid, amount, 'income', 'From: ' .. senderName .. ' (' .. myShortAccount .. ')', 'personal')
        SendBankMail(
            targetData.citizenid,
            LS('mail_transfer_subject'),
            LS('mail_transfer_body', senderName, myShortAccount, amount, Config.Currency),
            "Wire Transfer"
        )
        TriggerClientEvent('swisser_bank:client:notify', src, 'success',
            LS('notify_sent', amount, Config.Currency, targetName, accountNo))
        TriggerClientEvent('swisser_bank:client:notify', targetSrc, 'success',
            LS('notify_received', amount, Config.Currency, senderName, myShortAccount))
        Integrations.OnTransfer(src, citizenid, targetSrc, targetData.citizenid, amount, senderName, targetName, myShortAccount, accountNo)
    else
        -- Offline player transfer — look up target name from DB
        local targetName = Bridge.GetNameByCID(targetData.citizenid)
        local transferred = false

        if CurrentFramework == 'qb' then
            local offlineTarget = exports.oxmysql:single_async('SELECT money FROM players WHERE citizenid = ?', { targetData.citizenid })
            if offlineTarget then
                local money = json.decode(offlineTarget.money)
                money.bank = money.bank + amount
                Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
                exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), targetData.citizenid })
                transferred = true
            end
        elseif CurrentFramework == 'esx' then
            local offlineBalance = exports.oxmysql:scalar_async('SELECT `bank` FROM `users` WHERE `identifier` = ?', { targetData.citizenid })
            if offlineBalance ~= nil then
                Bridge.AdjustMoney(src, 'bank', amount, 'remove', 'Transfer Sent')
                exports.oxmysql:execute('UPDATE `users` SET `bank` = `bank` + ? WHERE `identifier` = ?', { amount, targetData.citizenid })
                transferred = true
            end
        end

        if transferred then
            CreateLog(citizenid, amount, 'outcome', 'To: ' .. targetName .. ' (' .. accountNo .. ')', 'personal')
            CreateLog(targetData.citizenid, amount, 'income', 'From: ' .. senderName .. ' (' .. myShortAccount .. ')', 'personal')
            SendBankMail(
                targetData.citizenid,
                LS('mail_transfer_subject'),
                LS('mail_transfer_offline', senderName, myShortAccount, amount, Config.Currency),
                "Wire Transfer"
            )
            TriggerClientEvent('swisser_bank:client:notify', src, 'success',
                LS('notify_sent', amount, Config.Currency, targetName, accountNo))
            Integrations.OnTransfer(src, citizenid, nil, targetData.citizenid, amount, senderName, targetName, myShortAccount, accountNo)
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
    if not VerifyBankAccess(source) then WarnCheat(source, 'changePIN'); return false end
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
    if not VerifyBankAccess(source) then WarnCheat(source, 'updateCard'); return false end
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
    if not VerifyBankAccess(source) then WarnCheat(source, 'updateAvatar'); return false end
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

-- Per-player one-time admin tokens (cleared after use or 10 s expiry)
local adminTokens = {}

local function IsAdminSource(source)
    return source and source ~= 0 and IsPlayerAceAllowed(source, 'command.god')
end

lib.callback.register('swisser_bank:getAdminData', function(source)
    if not IsAdminSource(source) then return nil end
    local players = {}
    for _, pid in ipairs(GetPlayers()) do
        local cid = Bridge.GetIdentifier(tonumber(pid))
        if cid then
            players[#players + 1] = {
                source    = tonumber(pid),
                name      = GetPlayerName(pid) or 'unknown',
                citizenid = cid,
            }
        end
    end
    return { players = players }
end)

-- Admin: inspect a player (balance, loan status, freeze status)
lib.callback.register('swisser_bank:adminInspect', function(source, targetCid)
    if not IsAdminSource(source) then return nil end
    if type(targetCid) ~= 'string' or targetCid == '' then return nil end

    local targetSrc = Bridge.GetPlayerByCID(targetCid)
    local balance = 0
    if targetSrc then
        balance = Bridge.GetBankBalance(targetSrc)
    else
        -- Offline: read from DB
        if CurrentFramework == 'qb' then
            local row = exports.oxmysql:single_async('SELECT money FROM players WHERE citizenid = ?', { targetCid })
            if row then
                local ok, money = pcall(json.decode, row.money)
                if ok and money then balance = money.bank or 0 end
            end
        else
            balance = exports.oxmysql:scalar_async('SELECT `bank` FROM `users` WHERE `identifier` = ?', { targetCid }) or 0
        end
    end

    local loan = exports.oxmysql:single_async('SELECT amount, account_locked FROM swisser_bank_loans WHERE citizenid = ?', { targetCid })
    local accNo = exports.oxmysql:scalar_async('SELECT account_no FROM swisser_bank_pins WHERE citizenid = ?', { targetCid })

    return {
        citizenid = targetCid,
        balance   = balance,
        accNo     = accNo,
        loan      = loan and { amount = loan.amount, locked = loan.account_locked == 1 } or nil,
    }
end)

-- Admin: toggle account freeze (loan must exist)
lib.callback.register('swisser_bank:adminToggleFreeze', function(source, targetCid)
    if not IsAdminSource(source) then return false end
    if type(targetCid) ~= 'string' or targetCid == '' then return false end

    local loan = exports.oxmysql:single_async('SELECT account_locked FROM swisser_bank_loans WHERE citizenid = ?', { targetCid })
    if not loan then
        -- No loan — create a freeze-only record so we can block the account
        exports.oxmysql:execute([[
            INSERT INTO swisser_bank_loans (citizenid, amount, original_amount, interest_rate, due_date, account_locked)
            VALUES (?, 0, 0, 0, NOW(), 1)
            ON DUPLICATE KEY UPDATE account_locked = 1
        ]], { targetCid })
        local tSrc = Bridge.GetPlayerByCID(targetCid)
        if tSrc then TriggerClientEvent('swisser_bank:client:notify', tSrc, 'error', '🔒 Your account has been frozen by an administrator.') end
        Integrations.OnAdminAction(source, 'freeze', targetCid)
        return { frozen = true }
    end

    local newLocked = loan.account_locked == 1 and 0 or 1
    exports.oxmysql:execute('UPDATE swisser_bank_loans SET account_locked = ? WHERE citizenid = ?', { newLocked, targetCid })
    local tSrc = Bridge.GetPlayerByCID(targetCid)
    if tSrc then
        if newLocked == 1 then
            TriggerClientEvent('swisser_bank:client:notify', tSrc, 'error', '🔒 Your account has been frozen by an administrator.')
        else
            TriggerClientEvent('swisser_bank:client:notify', tSrc, 'success', '✅ Your account has been unfrozen by an administrator.')
        end
    end
    Integrations.OnAdminAction(source, newLocked == 1 and 'freeze' or 'unfreeze', targetCid)
    return { frozen = newLocked == 1 }
end)

-- Admin: reset PIN to server default
lib.callback.register('swisser_bank:adminResetPIN', function(source, targetCid)
    if not IsAdminSource(source) then return false end
    if type(targetCid) ~= 'string' or targetCid == '' then return false end
    exports.oxmysql:execute('UPDATE swisser_bank_pins SET pin = ? WHERE citizenid = ?', { Config.DefaultPIN, targetCid })
    local tSrc = Bridge.GetPlayerByCID(targetCid)
    if tSrc then TriggerClientEvent('swisser_bank:client:notify', tSrc, 'inform', 'ℹ️ Your bank PIN has been reset by an administrator.') end
    Integrations.OnAdminAction(source, 'resetPIN', targetCid)
    return true
end)

-- Admin: broadcast a message to all online players
lib.callback.register('swisser_bank:adminBroadcast', function(source, message)
    if not IsAdminSource(source) then return false end
    if type(message) ~= 'string' or #message == 0 or #message > 200 then return false end
    local adminName = Bridge.GetName(source)
    local fullMsg   = '📢 [Bank] ' .. message
    for _, pid in ipairs(GetPlayers()) do
        TriggerClientEvent('swisser_bank:client:notify', tonumber(pid), 'info', fullMsg)
    end
    print(string.format('[SwisserBank] Admin broadcast by %s: %s', adminName, message))
    Integrations.OnAdminAction(source, 'broadcast: ' .. message, 'ALL')
    return true
end)

-- Admin: force-clear an active loan
lib.callback.register('swisser_bank:adminClearLoan', function(source, targetCid)
    if not IsAdminSource(source) then return false end
    if type(targetCid) ~= 'string' or targetCid == '' then return false end
    exports.oxmysql:execute('DELETE FROM swisser_bank_loans WHERE citizenid = ?', { targetCid })
    local tSrc = Bridge.GetPlayerByCID(targetCid)
    if tSrc then TriggerClientEvent('swisser_bank:client:notify', tSrc, 'success', '✅ Your loan has been cleared by an administrator.') end
    Integrations.OnAdminAction(source, 'clearLoan', targetCid)
    return true
end)

-- /bankadmin — opens the in-game admin dashboard for authorised staff
RegisterCommand('bankadmin', function(source, _args)
    if source == 0 then return end -- console only via rcon, not useful here
    if not IsPlayerAceAllowed(source, 'command.god') then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'No permission.')
        return
    end
    -- Generate a one-time random token so a Lua executor cannot replay the event
    local token = tostring(math.random(1e8, 9e8)) .. tostring(GetGameTimer())
    adminTokens[source] = { token = token, expires = GetGameTimer() + 8000 }
    -- Send token first so the client guard is primed, then fire the open event
    TriggerClientEvent('swisser_bank:client:setAdminToken', source, token)
    TriggerClientEvent('swisser_bank:client:openAdmin', source, token)
end, false)

-- ============================================================
-- LOAN SYSTEM
-- ============================================================

lib.callback.register('swisser_bank:getLoanData', function(source)
    if not Config.LoanEnabled then return nil end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return nil end
    local loan = exports.oxmysql:single_async('SELECT * FROM swisser_bank_loans WHERE citizenid = ?', { citizenid })
    if loan then
        local daysOverdue = 0
        if os.time() > loan.due_date then
            daysOverdue = math.floor((os.time() - loan.due_date) / 86400)
        end
        return {
            hasLoan = true,
            loan = {
                amount    = loan.amount,
                remaining = loan.amount,
                due_date  = tostring(loan.due_date),
            },
            interestRate  = loan.interest_rate * 100,
            accountLocked = loan.account_locked == 1,
            daysOverdue   = daysOverdue,
            penaltyApplied = loan.penalty_applied == 1,
        }
    end
    return {
        hasLoan       = false,
        interestRate  = Config.LoanInterestRate * 100,
        maxLoanAmount = Config.MaxLoanAmount,
        minLoanAmount = Config.MinLoanAmount,
    }
end)

lib.callback.register('swisser_bank:takeLoan', function(source, amount)
    if not Config.LoanEnabled then return { success = false, reason = 'loan_disabled' } end
    if not VerifyBankAccess(source) then WarnCheat(source, 'takeLoan'); return { success = false } end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return { success = false } end

    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.MinLoanAmount then return { success = false, reason = 'min' } end
    if amount > Config.MaxLoanAmount then return { success = false, reason = 'max' } end

    -- Check for existing active loan
    local existing = exports.oxmysql:scalar_async('SELECT citizenid FROM swisser_bank_loans WHERE citizenid = ?', { citizenid })
    if existing then return { success = false, reason = 'already_active' } end

    local totalOwed = math.floor(amount * (1 + Config.LoanInterestRate))
    local dueDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.LoanDurationDays * 86400))

    Bridge.AdjustMoney(source, 'bank', amount, 'add', 'Bank Loan')
    exports.oxmysql:insert('INSERT INTO swisser_bank_loans (citizenid, amount, original_amount, interest_rate, due_date) VALUES (?, ?, ?, ?, ?)', {
        citizenid, totalOwed, amount, Config.LoanInterestRate, dueDate
    })
    CreateLog(citizenid, amount, 'income', 'Bank Loan', 'personal')
    SendBankMail(citizenid, "Loan Approved", "Your loan of " .. amount .. " " .. Config.Currency .. " has been deposited. Total to repay: " .. totalOwed .. " " .. Config.Currency .. ". Due: " .. dueDate, "Loan Department")
    Integrations.OnLoanTaken(source, citizenid, amount, totalOwed)

    return { success = true, amount = amount, totalOwed = totalOwed }
end)

lib.callback.register('swisser_bank:repayLoan', function(source)
    if not Config.LoanEnabled then return { success = false } end
    if not VerifyBankAccess(source) then WarnCheat(source, 'repayLoan'); return { success = false } end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return { success = false } end

    local loan = exports.oxmysql:single_async('SELECT * FROM swisser_bank_loans WHERE citizenid = ?', { citizenid })
    if not loan then return { success = false, reason = 'no_loan' } end

    if Bridge.GetBankBalance(source) < loan.amount then
        return { success = false, reason = 'insufficient' }
    end

    Bridge.AdjustMoney(source, 'bank', loan.amount, 'remove', 'Loan Repayment')
    exports.oxmysql:execute('DELETE FROM swisser_bank_loans WHERE citizenid = ?', { citizenid })
    CreateLog(citizenid, loan.amount, 'outcome', 'Loan Repayment', 'personal')
    SendBankMail(citizenid, "Loan Repaid", "Your loan of " .. loan.amount .. " " .. Config.Currency .. " has been fully repaid. Your account is now clear.", "Loan Department")
    Integrations.OnLoanRepaid(source, citizenid, loan.amount)

    return { success = true, amount = loan.amount }
end)

-- ============================================================
-- LOAN ENFORCEMENT THREAD
-- Runs every hour. Checks all overdue loans and applies:
--   Day 1-3 overdue  → daily warning mail
--   Day 4  overdue   → 15% penalty added once to amount
--   Day 7+ overdue   → account frozen (no withdraw/transfer)
-- ============================================================
CreateThread(function()
    while true do
        Wait(3600 * 1000) -- check every hour

        if not dbReady or not Config.LoanEnabled then goto continue end

        local now = os.time()
        local overdueLoans = exports.oxmysql:query_async([[
            SELECT citizenid, amount, original_amount, interest_rate,
                   UNIX_TIMESTAMP(due_date) AS due_ts,
                   overdue_notified, penalty_applied, account_locked
            FROM swisser_bank_loans
            WHERE due_date < NOW()
        ]])

        if not overdueLoans then goto continue end

        for _, loan in ipairs(overdueLoans) do
            local cid        = loan.citizenid
            local daysLate   = math.floor((now - loan.due_ts) / 86400)
            local notified   = loan.overdue_notified or 0
            local penaltyDone = loan.penalty_applied == 1
            local locked     = loan.account_locked == 1

            -- Days 1-3: send one warning mail per day (only new days)
            if daysLate >= 1 and daysLate <= 3 and daysLate > notified then
                local daysLeft = math.max(0, 7 - daysLate)
                SendBankMail(
                    cid,
                    "⚠️ Loan Overdue — Day " .. daysLate,
                    "⚠️ Att Låna pengar är inte gratis!\n\n" ..
                    "Your loan repayment was due " .. daysLate .. " day(s) ago.\n" ..
                    "Outstanding balance: " .. loan.amount .. " " .. Config.Currency .. "\n\n" ..
                    "You have approximately " .. daysLeft .. " day(s) before your account is FROZEN.\n" ..
                    "Repay immediately to avoid penalties and account restrictions.",
                    "⚠️ Debt Collection"
                )
                exports.oxmysql:execute('UPDATE swisser_bank_loans SET overdue_notified = ? WHERE citizenid = ?', { daysLate, cid })

                -- Notify if player is online
                local src = Bridge.GetPlayerByCID(cid)
                if src then
                    TriggerClientEvent('swisser_bank:client:notify', src, 'error',
                        '⚠️ Att Låna pengar är inte gratis! Loan overdue by ' .. daysLate .. ' day(s). Repay NOW to avoid penalties!')
                    Integrations.OnLoanOverdue(src, cid, daysLate, loan.amount)
                end
            end

            -- Day 4: apply 15% penalty once
            if daysLate >= 4 and not penaltyDone then
                local penalty = math.floor(loan.amount * 0.15)
                local newAmount = loan.amount + penalty
                exports.oxmysql:execute([[
                    UPDATE swisser_bank_loans
                    SET amount = ?, penalty_applied = 1
                    WHERE citizenid = ?
                ]], { newAmount, cid })
                SendBankMail(
                    cid,
                    "💸 15% Late Penalty Applied",
                    "⚠️ Att Låna pengar är inte gratis!\n\n" ..
                    "Your loan is 4+ days overdue. A 15% late penalty has been added.\n" ..
                    "Previous balance: " .. loan.amount .. " " .. Config.Currency .. "\n" ..
                    "Penalty added:   +" .. penalty .. " " .. Config.Currency .. "\n" ..
                    "New total owed:  " .. newAmount .. " " .. Config.Currency .. "\n\n" ..
                    "Repay now — your account will be FROZEN in 3 days if unpaid.",
                    "💸 Penalty Department"
                )
                local src = Bridge.GetPlayerByCID(cid)
                if src then
                    TriggerClientEvent('swisser_bank:client:notify', src, 'error',
                        '💸 15% late penalty added! New debt: ' .. newAmount .. ' ' .. Config.Currency)
                end
            end

            -- Day 7+: freeze account
            if daysLate >= 7 and not locked then
                exports.oxmysql:execute('UPDATE swisser_bank_loans SET account_locked = 1 WHERE citizenid = ?', { cid })
                SendBankMail(
                    cid,
                    "🔒 Account Frozen — Overdue Loan",
                    "⚠️ Att Låna pengar är inte gratis!\n\n" ..
                    "Your account has been FROZEN due to an unpaid loan that is 7+ days overdue.\n\n" ..
                    "🔒 All withdrawals and transfers are BLOCKED.\n" ..
                    "Outstanding balance: " .. loan.amount .. " " .. Config.Currency .. "\n\n" ..
                    "Visit the bank and repay your loan in full to unfreeze your account.",
                    "🔒 Account Security"
                )
                local src = Bridge.GetPlayerByCID(cid)
                if src then
                    TriggerClientEvent('swisser_bank:client:notify', src, 'error',
                        '🔒 Your account has been FROZEN. Repay your overdue loan immediately!')
                    Integrations.OnAccountFrozen(src, cid)
                end
            end
        end

        ::continue::
    end
end)

-- ============================================================
-- GANG / ORGANIZATION ACCOUNTS
-- ============================================================

local function IsGangAllowed(gangName)
    for _, entry in ipairs(Config.AllowedGangAccounts) do
        if entry.gang == gangName then return true, entry.label end
    end
    return false, nil
end

local function GetOrgRole(orgId, citizenid)
    local row = exports.oxmysql:scalar_async(
        'SELECT role FROM swisser_bank_org_members WHERE org_id = ? AND citizenid = ?',
        { orgId, citizenid }
    )
    return row -- 'owner', 'admin', 'member', or nil
end

local function LogOrgTransaction(orgId, citizenid, playerName, amount, txType, label)
    exports.oxmysql:insert([[
        INSERT INTO swisser_bank_org_transactions (org_id, citizenid, player_name, amount, type, label)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { orgId, citizenid, playerName, amount, txType, label })
end

-- Admin command: /bankcreateorg [gangname]
RegisterCommand(Config.GangAccountCommand, function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.god') then
        if source ~= 0 then
            TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'No permission.')
        end
        return
    end
    local gangName = args[1] and args[1]:lower()
    if not gangName then
        print('[SwisserBank] Usage: /' .. Config.GangAccountCommand .. ' [gangname]')
        return
    end
    local allowed, label = IsGangAllowed(gangName)
    if not allowed then
        local msg = '[SwisserBank] Gang "' .. gangName .. '" is not in Config.AllowedGangAccounts.'
        print(msg)
        if source ~= 0 then TriggerClientEvent('swisser_bank:client:notify', source, 'error', msg) end
        return
    end
    local existing = exports.oxmysql:scalar_async('SELECT org_id FROM swisser_bank_org_accounts WHERE org_id = ?', { gangName })
    if existing then
        local msg = '[SwisserBank] Org account for "' .. gangName .. '" already exists.'
        print(msg)
        if source ~= 0 then TriggerClientEvent('swisser_bank:client:notify', source, 'error', msg) end
        return
    end
    local accNo = GenerateAccountNumber('swisser_bank_org_accounts')
    exports.oxmysql:insert('INSERT INTO swisser_bank_org_accounts (org_id, label, balance, account_no) VALUES (?, ?, 0, ?)',
        { gangName, label, accNo })
    local msg = '[SwisserBank] Org account created for "' .. gangName .. '" (acc: ' .. accNo .. ')'
    print(msg)
    if source ~= 0 then TriggerClientEvent('swisser_bank:client:notify', source, 'success', msg) end
end, true)

-- Get org data for the player's gang
lib.callback.register('swisser_bank:getOrgData', function(source)
    if not Config.GangAccountEnabled then return nil end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return nil end
    local gangName, isBoss = Bridge.GetGang(source)
    if not gangName then return nil end

    local org = exports.oxmysql:single_async('SELECT * FROM swisser_bank_org_accounts WHERE org_id = ?', { gangName })
    if not org then return { noAccount = true, gangName = gangName, isBoss = isBoss } end

    local role = GetOrgRole(gangName, citizenid)

    -- Auto-add boss on first open if they're in the gang
    if isBoss and not role then
        exports.oxmysql:insert('INSERT IGNORE INTO swisser_bank_org_members (org_id, citizenid, role, added_by) VALUES (?, ?, ?, ?)',
            { gangName, citizenid, 'owner', citizenid })
        role = 'owner'
    end

    if not role then return nil end -- not a member

    local members = exports.oxmysql:query_async([[
        SELECT m.citizenid, m.role, m.added_at,
               JSON_VALUE(p.charinfo, '$.firstname') AS fname,
               JSON_VALUE(p.charinfo, '$.lastname')  AS lname
        FROM swisser_bank_org_members m
        LEFT JOIN players p ON m.citizenid = p.citizenid
        WHERE m.org_id = ?
        ORDER BY FIELD(m.role,'owner','admin','member'), m.added_at ASC
    ]], { gangName })

    local txs = exports.oxmysql:query_async([[
        SELECT * FROM swisser_bank_org_transactions
        WHERE org_id = ? ORDER BY date DESC LIMIT 20
    ]], { gangName })

    return {
        orgId      = gangName,
        label      = org.label,
        balance    = org.balance,
        accountNo  = org.account_no,
        myRole     = role,
        isBoss     = isBoss,
        members    = members or {},
        transactions = txs or {},
    }
end)

-- Deposit cash → org account (all roles)
lib.callback.register('swisser_bank:orgDeposit', function(source, amount)
    if not Config.GangAccountEnabled then return false end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgDeposit'); return false end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end
    local gangName = Bridge.GetGang(source)
    if not gangName then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if not GetOrgRole(gangName, citizenid) then return false end

    if Bridge.AdjustMoney(source, 'cash', amount, 'remove', 'Org Deposit') then
        exports.oxmysql:execute('UPDATE swisser_bank_org_accounts SET balance = balance + ? WHERE org_id = ?', { amount, gangName })
        LogOrgTransaction(gangName, citizenid, Bridge.GetName(source), amount, 'income', 'Deposit by ' .. Bridge.GetName(source))
        TriggerClientEvent('swisser_bank:client:notify', source, 'success', 'Deposited ' .. amount .. ' to org account.')
        return true
    end
    TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'Not enough cash.')
    return false
end)

-- Withdraw from org account (admin/owner only)
lib.callback.register('swisser_bank:orgWithdraw', function(source, amount)
    if not Config.GangAccountEnabled then return false end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgWithdraw'); return false end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end
    local gangName = Bridge.GetGang(source)
    if not gangName then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local role = GetOrgRole(gangName, citizenid)
    if role == 'member' or not role then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'No permission to withdraw.')
        return false
    end
    local org = exports.oxmysql:single_async('SELECT balance FROM swisser_bank_org_accounts WHERE org_id = ?', { gangName })
    if not org or org.balance < amount then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'Insufficient org funds.')
        return false
    end
    exports.oxmysql:execute('UPDATE swisser_bank_org_accounts SET balance = balance - ? WHERE org_id = ?', { amount, gangName })
    Bridge.AdjustMoney(source, 'cash', amount, 'add', 'Org Withdrawal')
    LogOrgTransaction(gangName, citizenid, Bridge.GetName(source), amount, 'outcome', 'Withdrawal by ' .. Bridge.GetName(source))
    TriggerClientEvent('swisser_bank:client:notify', source, 'success', 'Withdrew ' .. amount .. ' from org account.')
    return true
end)

-- Transfer from org account to a player (admin/owner only)
lib.callback.register('swisser_bank:orgTransfer', function(source, targetAccNo, amount)
    if not Config.GangAccountEnabled then return false end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgTransfer'); return false end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return false end
    local gangName = Bridge.GetGang(source)
    if not gangName then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local role = GetOrgRole(gangName, citizenid)
    if role == 'member' or not role then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'No permission to transfer.')
        return false
    end
    local org = exports.oxmysql:single_async('SELECT balance FROM swisser_bank_org_accounts WHERE org_id = ?', { gangName })
    if not org or org.balance < amount then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'Insufficient org funds.')
        return false
    end
    local target = exports.oxmysql:single_async('SELECT citizenid FROM swisser_bank_pins WHERE account_no = ?', { targetAccNo })
    if not target then
        TriggerClientEvent('swisser_bank:client:notify', source, 'error', 'Account not found.')
        return false
    end
    exports.oxmysql:execute('UPDATE swisser_bank_org_accounts SET balance = balance - ? WHERE org_id = ?', { amount, gangName })
    local targetSrc = Bridge.GetPlayerByCID(target.citizenid)
    if targetSrc then
        Bridge.AdjustMoney(targetSrc, 'bank', amount, 'add', 'Org Transfer')
    else
        -- Offline: update DB directly (QBCore)
        if CurrentFramework == 'qb' then
            local row = exports.oxmysql:single_async('SELECT money FROM players WHERE citizenid = ?', { target.citizenid })
            if row then
                local money = json.decode(row.money)
                money.bank = money.bank + amount
                exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), target.citizenid })
            end
        end
    end
    LogOrgTransaction(gangName, citizenid, Bridge.GetName(source), amount, 'outcome', 'Transfer to ' .. targetAccNo)
    CreateLog(target.citizenid, amount, 'income', 'From org: ' .. gangName, 'personal')
    SendBankMail(target.citizenid, 'Org Transfer Received', 'You received ' .. amount .. ' ' .. Config.Currency .. ' from ' .. gangName .. ' organization account.', gangName)
    TriggerClientEvent('swisser_bank:client:notify', source, 'success', 'Transferred ' .. amount .. ' to ' .. targetAccNo)
    return true
end)

-- Add a member by account number (owner only)
lib.callback.register('swisser_bank:orgAddMember', function(source, targetAccNo)
    if not Config.GangAccountEnabled then return { ok = false } end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgAddMember'); return { ok = false } end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return { ok = false } end
    local gangName = Bridge.GetGang(source)
    if not gangName then return { ok = false } end
    if GetOrgRole(gangName, citizenid) ~= 'owner' then
        return { ok = false, reason = 'No permission.' }
    end
    local targetPin = exports.oxmysql:single_async([[
        SELECT p.citizenid, JSON_VALUE(pl.charinfo,'$.firstname') AS fname,
               JSON_VALUE(pl.charinfo,'$.lastname') AS lname
        FROM swisser_bank_pins p LEFT JOIN players pl ON p.citizenid = pl.citizenid
        WHERE p.account_no = ?
    ]], { targetAccNo })
    if not targetPin then return { ok = false, reason = 'Account not found.' } end
    if targetPin.citizenid == citizenid then return { ok = false, reason = 'Cannot add yourself.' } end
    local exists = exports.oxmysql:scalar_async('SELECT role FROM swisser_bank_org_members WHERE org_id = ? AND citizenid = ?',
        { gangName, targetPin.citizenid })
    if exists then return { ok = false, reason = 'Already a member.' } end
    exports.oxmysql:insert('INSERT INTO swisser_bank_org_members (org_id, citizenid, role, added_by) VALUES (?, ?, ?, ?)',
        { gangName, targetPin.citizenid, 'member', citizenid })
    local name = (targetPin.fname or '') .. ' ' .. (targetPin.lname or '')
    return { ok = true, name = name:match('^%s*(.-)%s*$') }
end)

-- Remove a member (owner only)
lib.callback.register('swisser_bank:orgRemoveMember', function(source, targetCid)
    if not Config.GangAccountEnabled then return false end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgRemoveMember'); return false end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return false end
    local gangName = Bridge.GetGang(source)
    if not gangName or GetOrgRole(gangName, citizenid) ~= 'owner' then return false end
    if targetCid == citizenid then return false end -- can't remove self
    exports.oxmysql:execute('DELETE FROM swisser_bank_org_members WHERE org_id = ? AND citizenid = ?', { gangName, targetCid })
    return true
end)

-- Set member role (owner only)
lib.callback.register('swisser_bank:orgSetRole', function(source, targetCid, newRole)
    if not Config.GangAccountEnabled then return false end
    if not VerifyBankAccess(source) then WarnCheat(source, 'orgSetRole'); return false end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return false end
    local gangName = Bridge.GetGang(source)
    if not gangName or GetOrgRole(gangName, citizenid) ~= 'owner' then return false end
    if targetCid == citizenid then return false end
    if newRole ~= 'admin' and newRole ~= 'member' then return false end
    exports.oxmysql:execute('UPDATE swisser_bank_org_members SET role = ? WHERE org_id = ? AND citizenid = ?',
        { newRole, gangName, targetCid })
    return true
end)

-- ============================================================
-- MONEY LAUNDERING
-- ============================================================

lib.callback.register('swisser_bank:submitLaundry', function(source, amount)
    if not Config.LaundryEnabled then return { ok = false, msg = 'Service unavailable.' } end
    if not VerifyLaundryAccess(source) then WarnCheat(source, 'submitLaundry'); return { ok = false, msg = 'You are not near the NPC.' } end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid or not CheckCooldown(source) then return { ok = false, msg = 'Too fast.' } end
    amount = math.floor(tonumber(amount) or 0)

    local minFmt = tostring(Config.LaundryMinAmount)
    local maxFmt = tostring(Config.LaundryMaxAmount)

    if amount < Config.LaundryMinAmount then
        return { ok = false, msg = Config.LaundryDialogue.too_little:format(minFmt) }
    end
    if amount > Config.LaundryMaxAmount then
        return { ok = false, msg = Config.LaundryDialogue.too_much:format(maxFmt) }
    end

    -- Check for existing pending job
    local existing = exports.oxmysql:single_async('SELECT ready_at, collected FROM swisser_bank_laundry WHERE citizenid = ?', { citizenid })
    if existing and existing.collected == 0 then
        local now = os.time()
        if existing.ready_at > now then
            local secsLeft = existing.ready_at - now
            return { ok = false, msg = Config.LaundryDialogue.not_ready:format(secsLeft) }
        else
            return { ok = false, msg = Config.LaundryDialogue.already_has }
        end
    end

    -- Check black money
    local dirty = Bridge.GetBlackMoney(source)
    if dirty < amount then
        return { ok = false, msg = Config.LaundryDialogue.no_dirty }
    end

    local cleanAmount = math.floor(amount * (1 - Config.LaundryFee))
    local readyAt = os.time() + Config.LaundryTime

    Bridge.AdjustBlackMoney(source, amount, 'remove')
    exports.oxmysql:execute([[
        INSERT INTO swisser_bank_laundry (citizenid, amount_dirty, amount_clean, ready_at, collected)
        VALUES (?, ?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE amount_dirty = ?, amount_clean = ?, ready_at = ?, collected = 0
    ]], { citizenid, amount, cleanAmount, readyAt, amount, cleanAmount, readyAt })

    return { ok = true, msg = Config.LaundryDialogue.submit, readyAt = readyAt, cleanAmount = cleanAmount }
end)

lib.callback.register('swisser_bank:collectLaundry', function(source)
    if not Config.LaundryEnabled then return { ok = false, msg = 'Service unavailable.' } end
    if not VerifyLaundryAccess(source) then WarnCheat(source, 'collectLaundry'); return { ok = false, msg = 'You are not near the NPC.' } end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return { ok = false } end

    local job = exports.oxmysql:single_async('SELECT * FROM swisser_bank_laundry WHERE citizenid = ? AND collected = 0', { citizenid })
    if not job then
        return { ok = false, msg = Config.LaundryDialogue.collected }
    end

    local now = os.time()
    if job.ready_at > now then
        local secsLeft = job.ready_at - now
        return { ok = false, msg = Config.LaundryDialogue.not_ready:format(secsLeft) }
    end

    -- Pay out clean money
    Bridge.AdjustMoney(source, 'bank', job.amount_clean, 'add', 'Laundered Funds')
    exports.oxmysql:execute('UPDATE swisser_bank_laundry SET collected = 1 WHERE citizenid = ?', { citizenid })
    CreateLog(citizenid, job.amount_clean, 'income', 'Deposit', 'personal') -- generic label on purpose
    Integrations.OnLaundry(source, citizenid, job.amount_dirty, job.amount_clean)

    return { ok = true, msg = Config.LaundryDialogue.ready, amount = job.amount_clean }
end)

lib.callback.register('swisser_bank:checkLaundry', function(source)
    if not Config.LaundryEnabled then return nil end
    local citizenid = Bridge.GetIdentifier(source)
    if not citizenid then return nil end
    local job = exports.oxmysql:single_async('SELECT * FROM swisser_bank_laundry WHERE citizenid = ? AND collected = 0', { citizenid })
    if not job then return nil end
    return { readyAt = job.ready_at, cleanAmount = job.amount_clean, amountDirty = job.amount_dirty }
end)
