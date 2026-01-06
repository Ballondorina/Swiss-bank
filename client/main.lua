local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isUIOpen = false
local lastGoalStatus = false 

local function L(key)
    if not Locales or not Locales[Config.Language] then return key end
    return Locales[Config.Language][key] or key
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

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
                        name = 'open_bank_'..i,
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

-- Added for Transfer Validation Feedback
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

RegisterNetEvent('swisser_bank:markMailsRead', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    exports.oxmysql:execute('UPDATE swisser_bank_mails SET is_read = 1 WHERE citizenid = ?', { Player.PlayerData.citizenid })
end)