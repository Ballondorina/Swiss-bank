local QBCore = nil
if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

function SendNotification(text, type)
    local t = type or 'info'
    if Config.NotifySystem == 'qb' and QBCore then
        QBCore.Functions.Notify(text, t)
    elseif Config.NotifySystem == 'esx' then
        -- ESX default notification
        if GetResourceState('es_extended') == 'started' then
            exports['es_extended']:ShowNotification(text)
        end
    elseif Config.NotifySystem == 'ox' then
        lib.notify({ title = 'Bank', description = text, type = t == 'primary' and 'info' or t })
    elseif Config.NotifySystem == 'qs' then
        exports['qs-notify']:Alert("Bank", text, 5000, t)
    elseif Config.NotifySystem == 'jg' then
        exports['jg-notify']:SendAlert("Bank", text, 5000, t)
    elseif Config.NotifySystem == 'okok' then
        exports['okokNotify']:Alert("Bank", text, 5000, t)
    elseif Config.NotifySystem == 'mythic' then
        exports['mythic_notify']:DoHudText(t, text)
    elseif Config.NotifySystem == 'pnotify' then
        -- pNotify (standalone or QB-wrapped)
        exports['pNotify']:SendNotification({ text = text, type = t, duration = 5000 })
    elseif Config.NotifySystem == 'brutal' then
        local brutalType = (t == 'success' or t == 'error') and t or 'info'
        exports['brutal_notifications']:Notification("BANK", text, 5000, brutalType)
    elseif Config.NotifySystem == 'ps' then
        -- ps-ui notify (Project Sloth)
        exports['ps-ui']:Notify(text, t, 5000)
    else
        print(string.format("[Bank Notification] %s: %s", t, text))
    end
end

function DrawTextUI(text)
    if Config.TextUISystem == 'ox' then
        lib.showTextUI(text, { position = 'left-center' })
    elseif Config.TextUISystem == 'qb' then
        exports['qb-core']:DrawText(text, 'left')
    elseif Config.TextUISystem == 'qs' then
        exports['qs-textui']:ShowTextUI(text)
    elseif Config.TextUISystem == 'jg' then
        exports['jg-textui']:ShowText(text)
    elseif Config.TextUISystem == 'brutal' then
        exports['brutal_textui']:Open(text, "info", "left")
    end
end

function HideTextUI()
    if Config.TextUISystem == 'ox' then
        lib.hideTextUI()
    elseif Config.TextUISystem == 'qb' then
        exports['qb-core']:HideText()
    elseif Config.TextUISystem == 'qs' then
        exports['qs-textui']:HideTextUI()
    elseif Config.TextUISystem == 'jg' then
        exports['jg-textui']:HideText()
    elseif Config.TextUISystem == 'brutal' then
        exports['brutal_textui']:Close()
    end
end

exports('SendNotification', SendNotification)
exports('DrawTextUI', DrawTextUI)
exports('HideTextUI', HideTextUI)