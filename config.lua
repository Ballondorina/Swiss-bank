--[[
    Swisser Bank Configuration
    This file contains all configurable settings for the Swisser Bank resource.
    Adjust these values to customize the banking system for your server.
]]

Config = {}

-- [CORE SETTINGS] -------------------------------------------------------------------------
Config.Language = 'en'             -- Default language: 'en' (English) or 'sv' (Swedish)
Config.BankLogo = 'logo.svg'       -- Path to the bank logo file in the web folder
Config.ScriptBranding = "AI.SWISSER.DEV"  -- Branding text shown in the UI
Config.DefaultPIN = "1234"         -- Default PIN for new bank accounts (users should change this)

-- [CURRENCY SETTINGS] --------------------------------------------------------------------
Config.Currency = '$'              -- Default currency symbol
Config.EnableCurrencyChanger = true  -- Allow users to change currency in the UI

-- Available currencies for players to choose from
-- id: Internal identifier (lowercase)
-- label: Display name shown in the UI
-- symbol: Currency symbol (e.g., $, €, £)
Config.AvailableCurrencies = {
    { id = 'usd', label = 'US Dollar ($)', symbol = '$' },
    { id = 'eur', label = 'Euro (€)', symbol = '€' },
    { id = 'gbp', label = 'Pound (£)', symbol = '£' },
    { id = 'sek', label = 'Swedish Krona (kr)', symbol = 'kr' },
    { id = 'jpy', label = 'Yen (¥)', symbol = '¥' }
}

-- [NOTIFICATION & UI SETTINGS] ----------------------------------------------------------
Config.NotifySystem = 'qb'         -- Notification system: 'qb' (QBCore) or 'esx' (ESX)
Config.TextUISystem = 'ox'         -- Text UI system (for 3D text and interactions)

-- [SECURITY SETTINGS] -------------------------------------------------------------------
Config.MaxDistance = 5.0           -- Maximum interaction distance for bank NPCs/ATMs
Config.EventCooldown = 1500        -- Cooldown between actions in milliseconds (anti-spam)
Config.RequirePIN = true           -- Whether PIN is required for transactions
Config.ATMInteractionDistance = 1.25  -- How close player needs to be to interact with ATMs
Config.BankInteractionRadius = 1.0 -- Radius for bank teller interactions
Config.BankInteractionDistance = 1.8 -- Distance for bank teller interactions

-- [SOUND SETTINGS] ----------------------------------------------------------------------
-- Sound effects for different UI actions
-- Files should be placed in web/sounds/ directory
Config.Sounds = {
    Success = 'correct.wav',  -- Played on successful transactions
    Error = 'wrong.mp3',      -- Played on errors/declined transactions
    Click = 'click.wav',      -- Played on button clicks
    Volume = 0.5             -- Volume level (0.0 to 1.0)
}

-- [PRICING] ----------------------------------------------------------------------------
Config.PINChangeCost = 1000       -- Cost to change PIN
Config.CustomCardCost = 5000      -- Cost for custom card design
Config.AvatarChangeCost = 2500    -- Cost to change profile avatar

-- [INTERACTION SETTINGS] --------------------------------------------------------------
Config.UseOxTarget = true  -- Use ox_target for interactions (requires ox_target resource)

-- List of ATM models that will work with the banking system
-- Add or remove models as needed for your server
Config.ATMModels = {
    `prop_atm_01`,  -- Standard blue ATM
    `prop_atm_02`,  -- Standard red ATM
    `prop_atm_03`,
    `prop_vinewood_atm_01`
}

-- Visual Tiers
Config.CardTiers = {
    { amount = 2000000, label = "DIAMOND", style = "diamond" },
    { amount = 1000000, label = "EMERALD", style = "emerald" },
    { amount = 500000,  label = "GOLD ELITE", style = "gold" },
    { amount = 100000,  label = "SILVER PLUS", style = "silver" },
    { amount = 0,       label = "STANDARD", style = "standard" }
}

Config.ShowBankBlips = true
Config.DefaultBlip = { sprite = 108, color = 2, scale = 0.7, label = "Bank" }

Config.BankLocations = {
    { coords = vector3(149.95, -1040.83, 29.37), label = "Bank" },
    { coords = vector3(-1212.98, -330.84, 37.78), label = "Bank" },
    { coords = vector3(-2962.58, 482.62, 15.70), label = "Bank" },
    { coords = vector3(-112.20, 6469.29, 31.62), label = "Bank" },
    { coords = vector3(1175.06, 2706.64, 38.09), label = "Bank" },
    { coords = vector3(-351.53, -49.52, 49.04), label = "Bank" },
    { coords = vector3(314.18, -278.62, 54.17), label = "Bank" },
    { coords = vector3(252.33, 218.11, 106.29), label = "Bank" }
}