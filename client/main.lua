local PlayerData = {}
local isUIOpen = false
local lastGoalStatus = false

local function L(key)
    if not Locales or not Locales[Config.Language] then return key end
    return Locales[Config.Language][key] or key
end

local function OpenBankUI(isATM, isAdminDashboard)
    if isUIOpen then return end

    local data = nil
    local adminData = nil
    local lang = Config.Language or 'en'
    local uiLocale = Locales[lang] or Locales['en']

    if isAdminDashboard then
        adminData = lib.callback.await('swisser_bank:getAdminData', false)
        if not adminData then
            if SendNotification then SendNotification("Access Denied", "error") end
            return
        end
    else
        data = lib.callback.await('swisser_bank:getData', false, 'personal')
        if not data then
            if SendNotification then SendNotification("Error loading banking data", "error") end
            return
        end
    end

    isUIOpen = true
    SetNuiFocus(true, true)

    if isATM then
        lib.requestAnimDict('amb@prop_human_atm@male@enter')
        TaskPlayAnim(PlayerPedId(), 'amb@prop_human_atm@male@enter', 'enter', 8.0, 8.0, 2000, 0, 0, false, false, false)
    end

    if isAdminDashboard then
        SendNUIMessage({ action = 'open_admin', data = adminData, locale = uiLocale, currency = Config.Currency, audio = Config.Sounds })
    elseif Config.RequirePIN then
        SendNUIMessage({ action = 'open_pin', locale = uiLocale, audio = Config.Sounds })
    else
        SendNUIMessage({ action = 'open_bank', data = data, locale = uiLocale, currency = Config.Currency, logo = Config.BankLogo, audio = Config.Sounds })
    end
end

RegisterNetEvent('swisser_bank:client:openAdmin', function()
    OpenBankUI(false, true)
end)

-- Forward server notifications to the NUI as toast messages
RegisterNetEvent('swisser_bank:client:notify', function(notifType, message)
    if SendNotification then SendNotification(message, notifType) end
    if isUIOpen then
        SendNUIMessage({ action = 'NOTIFY', type = notifType, message = message })
    end
end)

CreateThread(function()
    if Config.ShowBankBlips then
        for _, loc in ipairs(Config.BankLocations) do
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, Config.DefaultBlip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.DefaultBlip.scale)
            SetBlipColour(blip, Config.DefaultBlip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(loc.label or Config.DefaultBlip.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    if Config.UseOxTarget then
        exports.ox_target:addModel(Config.ATMModels, {
            {
                name = 'open_atm',
                icon = 'fa-solid fa-credit-card',
                label = L('open_atm'),
                distance = Config.ATMInteractionDistance or 1.5,
                onSelect = function() OpenBankUI(true) end
            }
        })
        for i, loc in ipairs(Config.BankLocations) do
            exports.ox_target:addSphereZone({
                coords = loc.coords,
                radius = Config.BankInteractionRadius or 0.9,
                options = {
                    {
                        name = 'open_bank_' .. i,
                        icon = 'fa-solid fa-building-columns',
                        label = L('open_bank'),
                        distance = Config.BankInteractionDistance or 1.5,
                        onSelect = function() OpenBankUI(false) end
                    }
                }
            })
        end
    end
end)

-- ============================================================
-- MONEY LAUNDERING NPC
-- ============================================================
local laundryPed = nil

local function ShowLaundryDialogue(line)
    lib.notify({ title = 'Shady Guy', description = line, type = 'inform', duration = 6000 })
end

local function HandleLaundryInteraction()
    -- Check if there's already a pending job
    local pending = lib.callback.await('swisser_bank:checkLaundry', false)

    if pending then
        local now = os.time()
        if pending.readyAt > now then
            local secsLeft = pending.readyAt - now
            ShowLaundryDialogue(Config.LaundryDialogue.not_ready:format(secsLeft))
        else
            -- Ready to collect
            ShowLaundryDialogue("Your money is ready. Let me get it...")
            Wait(1500)
            local result = lib.callback.await('swisser_bank:collectLaundry', false)
            if result and result.ok then
                ShowLaundryDialogue(result.msg)
                TriggerEvent('swisser_bank:client:notify', 'success', '💵 Received ' .. result.amount .. ' ' .. Config.Currency .. ' (clean)')
            else
                ShowLaundryDialogue(result and result.msg or "Something went wrong.")
            end
        end
        return
    end

    -- No pending job — ask for amount
    ShowLaundryDialogue(Config.LaundryDialogue.greeting)
    Wait(1000)

    local input = lib.inputDialog('Money Laundering', {
        { type = 'number', label = 'Amount of black money to launder', min = Config.LaundryMinAmount, max = Config.LaundryMaxAmount, required = true }
    })
    if not input or not input[1] then return end

    local amount = math.floor(tonumber(input[1]) or 0)
    local result = lib.callback.await('swisser_bank:submitLaundry', false, amount)
    if result and result.ok then
        ShowLaundryDialogue(result.msg)
        local fee = amount - result.cleanAmount
        lib.notify({
            title = 'Deal Made',
            description = string.format('Submitted: %d\nFee (%.0f%%): -%d\nYou will receive: %d',
                amount, Config.LaundryFee * 100, fee, result.cleanAmount),
            type = 'inform', duration = 8000
        })
    else
        ShowLaundryDialogue(result and result.msg or "Not interested.")
    end
end

CreateThread(function()
    if not Config.LaundryEnabled then return end

    -- Spawn NPC
    local coords = Config.LaundryNPC.coords
    RequestModel(Config.LaundryNPC.model)
    while not HasModelLoaded(Config.LaundryNPC.model) do Wait(100) end

    laundryPed = CreatePed(4, Config.LaundryNPC.model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityInvincible(laundryPed, true)
    SetBlockingOfNonTemporaryEvents(laundryPed, true)
    FreezeEntityPosition(laundryPed, true)
    SetPedFleeAttributes(laundryPed, 0, false)
    TaskStartScenarioInPlace(laundryPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    -- Blip
    if Config.LaundryNPC.blip and Config.LaundryNPC.blip.enabled then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, Config.LaundryNPC.blip.sprite)
        SetBlipScale(blip, Config.LaundryNPC.blip.scale)
        SetBlipColour(blip, Config.LaundryNPC.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.LaundryNPC.blip.label)
        EndTextCommandSetBlipName(blip)
    end

    -- ox_target interaction
    if Config.UseOxTarget then
        exports.ox_target:addLocalEntity(laundryPed, {
            {
                name = 'swisser_laundry',
                icon = 'fa-solid fa-money-bill-wave',
                label = 'Talk to him...',
                distance = 2.0,
                onSelect = HandleLaundryInteraction,
            }
        })
    end
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    if IsEntityPlayingAnim(PlayerPedId(), 'amb@prop_human_atm@male@enter', 'enter', 3) then
        lib.requestAnimDict('amb@prop_human_atm@male@exit')
        TaskPlayAnim(PlayerPedId(), 'amb@prop_human_atm@male@exit', 'exit', 8.0, 8.0, 2000, 0, 0, false, false, false)
    end
    cb('ok')
end)

RegisterNUICallback('checkPIN', function(data, cb)
    local isCorrect = lib.callback.await('swisser_bank:checkPIN', false, data.pin)
    cb(isCorrect)
end)

RegisterNUICallback('refresh', function(data, cb)
    local result = lib.callback.await('swisser_bank:getData', false, data.accountType)
    if result and result.goal and result.goal.target > 0 then
        local isAchieved = result.balance >= result.goal.target
        if isAchieved and not lastGoalStatus then
            if SendNotification then SendNotification("Goal Achieved! You reached your savings target!", "success") end
        end
        lastGoalStatus = isAchieved
    end
    cb(result)
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('swisser_bank:deposit', data.amount, data.accountType)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('swisser_bank:withdraw', data.amount, data.accountType)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('swisser_bank:transfer', data.iban, data.amount, data.accountType)
    cb('ok')
end)

RegisterNUICallback('validateIBAN', function(data, cb)
    local result = lib.callback.await('swisser_bank:validateIBAN', false, data.iban)
    cb(result)
end)

RegisterNUICallback('updateGoal', function(data, cb)
    local success = lib.callback.await('swisser_bank:updateGoal', false, data)
    lastGoalStatus = false
    cb(success)
end)

RegisterNUICallback('changePIN', function(data, cb)
    local success = lib.callback.await('swisser_bank:changePIN', false, data)
    cb(success)
end)

RegisterNUICallback('updateCard', function(data, cb)
    local success = lib.callback.await('swisser_bank:updateCard', false, data.url)
    cb(success)
end)

RegisterNUICallback('updateAvatar', function(data, cb)
    local success = lib.callback.await('swisser_bank:updateAvatar', false, data.url)
    cb(success)
end)

RegisterNUICallback('loadBankData', function(_, cb)
    local data = lib.callback.await('swisser_bank:getData', false, 'personal')
    cb(data)
end)

RegisterNUICallback('markMailsRead', function(_, cb)
    TriggerServerEvent('swisser_bank:markMailsRead')
    cb('ok')
end)

-- Org NUI callbacks
RegisterNUICallback('getOrgData', function(_, cb)
    local result = lib.callback.await('swisser_bank:getOrgData', false)
    cb(result)
end)

RegisterNUICallback('orgDeposit', function(data, cb)
    local ok = lib.callback.await('swisser_bank:orgDeposit', false, data.amount)
    cb(ok)
end)

RegisterNUICallback('orgWithdraw', function(data, cb)
    local ok = lib.callback.await('swisser_bank:orgWithdraw', false, data.amount)
    cb(ok)
end)

RegisterNUICallback('orgTransfer', function(data, cb)
    local ok = lib.callback.await('swisser_bank:orgTransfer', false, data.iban, data.amount)
    cb(ok)
end)

RegisterNUICallback('orgAddMember', function(data, cb)
    local result = lib.callback.await('swisser_bank:orgAddMember', false, data.accountNo)
    cb(result)
end)

RegisterNUICallback('orgRemoveMember', function(data, cb)
    local ok = lib.callback.await('swisser_bank:orgRemoveMember', false, data.citizenid)
    cb(ok)
end)

RegisterNUICallback('orgSetRole', function(data, cb)
    local ok = lib.callback.await('swisser_bank:orgSetRole', false, data.citizenid, data.role)
    cb(ok)
end)

-- Loan NUI callbacks
RegisterNUICallback('getLoanData', function(_, cb)
    local result = lib.callback.await('swisser_bank:getLoanData', false)
    cb(result)
end)

RegisterNUICallback('takeLoan', function(data, cb)
    local result = lib.callback.await('swisser_bank:takeLoan', false, data.amount)
    cb(result)
end)

RegisterNUICallback('repayLoan', function(_, cb)
    local result = lib.callback.await('swisser_bank:repayLoan', false)
    cb(result)
end)
