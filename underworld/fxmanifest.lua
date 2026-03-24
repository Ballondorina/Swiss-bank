fx_version 'cerulean'
game 'gta5'

name 'underworld'
description 'Underworld — Organization System'
version '1.0.0'
author 'Custom'

dependency 'ox_lib'
dependency 'oxmysql'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/main.lua',
    'server/missions.lua',
    'server/passive.lua'
}

client_scripts {
    'client/main.lua',
    'client/missions.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

lua54 'yes'
