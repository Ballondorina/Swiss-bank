fx_version 'cerulean'
game 'gta5'

name 'underworld'
description 'Underworld — Organization System v2'
version '2.0.0'
author 'Custom'

dependency 'ox_lib'
dependency 'oxmysql'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/main.lua',    -- helpers + getOrgData + vault + membership + stash + admin cmds
    'server/levels.lua',  -- XP/level progression (must load after main for _ENV exports)
    'server/influence.lua', -- territory zones (must load after main)
    'server/creation.lua',  -- player-paid org creation (after main + levels)
    'server/missions.lua',  -- daily missions + cooldowns (after main + levels + influence)
    'server/passive.lua',   -- passive income + salaries + leaderboard (after all others)
}

client_scripts {
    'client/main.lua',      -- panel open/close + stash + office zones
    'client/missions.lua',  -- mission thread + markers
    'client/influence.lua', -- zone presence detection + blips
    'client/creation.lua',  -- notary NPC + org creation flow
}

-- Point to compiled React/TSX app
-- Run `cd ui && npm install && npm run build` to generate web/dist/
ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*'
}

lua54 'yes'
