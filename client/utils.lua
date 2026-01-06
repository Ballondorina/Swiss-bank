local QBCore = exports['qb-core']:GetCoreObject()

function SendNotification(text, type)
    if Config.NotifySystem == 'qb' then
        QBCore.Functions.Notify(text, type)
    elseif Config.NotifySystem == 'ox' then
        lib.notify({ title = 'Bank', description = text, type = type == 'primary' and 'info' or type })
    elseif Config.NotifySystem == 'qs' then
        exports['qs-notify']:Alert("Bank", text, 5000, type)
    elseif Config.NotifySystem == 'jg' then
        exports['jg-notify']:SendAlert("Bank", text, 5000, type)
    elseif Config.NotifySystem == 'okok' then
        -- Corrected Export Name
        exports['okokNotify']:Alert("Bank", text, 5000, type)
    elseif Config.NotifySystem == 'mythic' then
        exports['mythic_notify']:DoHudText(type, text)
    elseif Config.NotifySystem == 'brutal' then
        local brutalType = type
        if type == 'success' then brutalType = 'success' 
        elseif type == 'error' then brutalType = 'error'
        else brutalType = 'info' end
        exports['brutal_notifications']:Notification("BANK", text, 5000, brutalType)
    else
        print(string.format("[Bank Notification] %s: %s", type, text))
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