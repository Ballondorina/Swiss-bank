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
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', '🔒 Account frozen due to overdue loan. Repay your loan to unlock.')
        return
    end

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

    if IsAccountLocked(citizenid) then
        TriggerClientEvent('swisser_bank:client:notify', src, 'error', '🔒 Account frozen due to overdue loan. Repay your loan to unlock.')
        return
    end

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

    return { success = true, amount = amount, totalOwed = totalOwed }
end)

lib.callback.register('swisser_bank:repayLoan', function(source)
    if not Config.LoanEnabled then return { success = false } end
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
                end
            end
        end

        ::continue::
    end
end)
