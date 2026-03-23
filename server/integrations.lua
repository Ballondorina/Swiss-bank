--[[
    Swiss Bank — Integrations Layer
    Handles: Discord webhook logging, lb-phone push notifications
    All functions are no-ops when the relevant Config flag is false.
]]

-- ============================================================
-- DISCORD WEBHOOK
-- ============================================================

local EMBED_COLORS = {
    deposit   = 3066993,   -- green
    withdraw  = 15158332,  -- red
    transfer  = 3447003,   -- blue
    loan      = 16776960,  -- yellow
    laundry   = 10181046,  -- purple
    admin     = 16744272,  -- orange
    suspicious = 15158332, -- red
}

local function DiscordLog(eventType, title, description, fields, playerName)
    if not Config.DiscordEnabled then return end
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end
    if not (Config.DiscordLogs and Config.DiscordLogs[eventType]) then return end

    local embedFields = {}
    if fields then
        for _, f in ipairs(fields) do
            embedFields[#embedFields + 1] = {
                name   = f.name,
                value  = tostring(f.value),
                inline = f.inline ~= false,
            }
        end
    end

    local embed = {
        title       = title,
        description = description,
        color       = EMBED_COLORS[eventType] or 0,
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = Config.DiscordBotName or 'Swiss Bank' },
        fields      = embedFields,
    }

    local payload = json.encode({
        username   = Config.DiscordBotName or 'Swiss Bank',
        avatar_url = Config.DiscordAvatar or nil,
        embeds     = { embed },
    })

    PerformHttpRequest(Config.DiscordWebhook, function(status, _, _headers)
        if status ~= 204 and status ~= 200 then
            print('[SwisserBank] Discord webhook returned status ' .. tostring(status))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

-- ============================================================
-- LB-PHONE PUSH NOTIFICATIONS
-- ============================================================

local function PhoneNotify(target, eventType, title, message)
    if not Config.LBPhoneEnabled then return end
    if not (Config.LBPhoneEvents and Config.LBPhoneEvents[eventType]) then return end
    if not target or target == 0 then return end
    if GetResourceState('lb-phone') ~= 'started' then return end

    exports['lb-phone']:SendNotification(target, {
        app    = Config.DiscordBotName or 'Swiss Bank',
        title  = title,
        body   = message,
        icon   = 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png',
    })
end

-- ============================================================
-- PUBLIC API (called from server/main.lua)
-- ============================================================

Integrations = {}

--- Log a deposit
function Integrations.OnDeposit(src, citizenid, amount)
    local name = GetPlayerName(src) or 'Unknown'
    local minAmt = Config.DiscordMinAmount or 0
    if amount < minAmt then return end
    DiscordLog('deposit',
        '💰 Deposit',
        string.format('**%s** deposited **%s %s** into their account.', name, amount, Config.Currency),
        {
            { name = 'Player',    value = name },
            { name = 'CitizenID', value = citizenid },
            { name = 'Amount',    value = amount .. ' ' .. Config.Currency },
        }
    )
end

--- Log a withdrawal
function Integrations.OnWithdraw(src, citizenid, amount)
    local name = GetPlayerName(src) or 'Unknown'
    local minAmt = Config.DiscordMinAmount or 0
    if amount < minAmt then return end
    DiscordLog('withdraw',
        '🏧 Withdrawal',
        string.format('**%s** withdrew **%s %s** from their account.', name, amount, Config.Currency),
        {
            { name = 'Player',    value = name },
            { name = 'CitizenID', value = citizenid },
            { name = 'Amount',    value = amount .. ' ' .. Config.Currency },
        }
    )
end

--- Log a transfer (sender side); notify receiver via phone
function Integrations.OnTransfer(src, senderCid, targetSrc, targetCid, amount, senderName, targetName, senderAccNo, targetAccNo)
    local minAmt = Config.DiscordMinAmount or 0
    if amount >= minAmt then
        DiscordLog('transfer',
            '💸 Transfer',
            string.format('**%s** sent **%s %s** to **%s**.', senderName, amount, Config.Currency, targetName),
            {
                { name = 'From',       value = senderName .. ' (' .. senderAccNo .. ')' },
                { name = 'To',         value = targetName .. ' (' .. targetAccNo .. ')' },
                { name = 'Amount',     value = amount .. ' ' .. Config.Currency },
                { name = 'Sender ID',  value = senderCid },
                { name = 'Target ID',  value = targetCid },
            }
        )
    end
    -- Phone notification to recipient (online only)
    if targetSrc then
        PhoneNotify(targetSrc, 'transfer_received',
            '💸 Transfer Received',
            string.format('You received %s %s from %s (%s)', amount, Config.Currency, senderName, senderAccNo)
        )
    end
end

--- Log a loan taken
function Integrations.OnLoanTaken(src, citizenid, amount, totalOwed)
    local name = GetPlayerName(src) or 'Unknown'
    DiscordLog('loan',
        '🏦 Loan Taken',
        string.format('**%s** took a loan of **%s %s** (total owed: %s %s).', name, amount, Config.Currency, totalOwed, Config.Currency),
        {
            { name = 'Player',     value = name },
            { name = 'CitizenID',  value = citizenid },
            { name = 'Principal',  value = amount .. ' ' .. Config.Currency },
            { name = 'Total Owed', value = totalOwed .. ' ' .. Config.Currency },
        }
    )
end

--- Log a loan repaid
function Integrations.OnLoanRepaid(src, citizenid, amount)
    local name = GetPlayerName(src) or 'Unknown'
    DiscordLog('loan',
        '✅ Loan Repaid',
        string.format('**%s** fully repaid their loan of **%s %s**.', name, amount, Config.Currency),
        {
            { name = 'Player',    value = name },
            { name = 'CitizenID', value = citizenid },
            { name = 'Amount',    value = amount .. ' ' .. Config.Currency },
        }
    )
end

--- Notify player of overdue loan via phone
function Integrations.OnLoanOverdue(targetSrc, citizenid, daysLate, amount)
    if not targetSrc then return end
    PhoneNotify(targetSrc, 'loan_overdue',
        '⚠️ Loan Overdue',
        string.format('Your loan is %d day(s) overdue! Outstanding: %s %s. Repay now.', daysLate, amount, Config.Currency)
    )
end

--- Notify player of account freeze via phone
function Integrations.OnAccountFrozen(targetSrc, citizenid)
    if not targetSrc then return end
    PhoneNotify(targetSrc, 'account_frozen',
        '🔒 Account Frozen',
        'Your bank account has been frozen due to an unpaid overdue loan.'
    )
end

--- Log completed laundry transaction
function Integrations.OnLaundry(src, citizenid, dirtyAmount, cleanAmount)
    local name = GetPlayerName(src) or 'Unknown'
    local fee   = dirtyAmount - cleanAmount
    DiscordLog('laundry',
        '🧺 Money Laundered',
        string.format('**%s** laundered **%s %s** (received %s, fee %s).', name, dirtyAmount, Config.Currency, cleanAmount, fee),
        {
            { name = 'Player',       value = name },
            { name = 'CitizenID',    value = citizenid },
            { name = 'Dirty Amount', value = dirtyAmount .. ' ' .. Config.Currency },
            { name = 'Clean Amount', value = cleanAmount .. ' ' .. Config.Currency },
            { name = 'Fee',          value = fee .. ' ' .. Config.Currency },
        }
    )
end

--- Log admin action (freeze, clear loan, reset PIN, broadcast)
function Integrations.OnAdminAction(adminSrc, action, targetCid)
    local adminName = GetPlayerName(adminSrc) or 'Console'
    DiscordLog('admin',
        '🛡️ Admin Action',
        string.format('Admin **%s** performed: **%s** on target `%s`.', adminName, action, tostring(targetCid)),
        {
            { name = 'Admin',     value = adminName },
            { name = 'Action',    value = action },
            { name = 'Target ID', value = tostring(targetCid) },
        }
    )
end

--- Log a blocked cheat attempt
function Integrations.OnSuspicious(src, eventName)
    local name = GetPlayerName(src) or 'Unknown'
    DiscordLog('suspicious',
        '🚨 Suspicious Activity Blocked',
        string.format('**%s** (id: %d) attempted unauthorized action: `%s`.', name, src, eventName),
        {
            { name = 'Player',     value = name },
            { name = 'Server ID',  value = tostring(src) },
            { name = 'Event',      value = eventName },
        }
    )
end
