fx_version 'cerulean'
game 'gta5'

description 'Swisser Bank - Universal Modern Banking System'
author 'Swisser Team'
version '1.1.0'

dependency 'ox_lib'
dependency 'oxmysql'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'locales/sv.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/utils.lua',
    'client/main.lua'
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

escrow_ignore {
    -- Allow customers to customize UI/behavior without touching protected logic
    'config.lua',
    'locales/*.lua',
    'client/*.lua',
    'bridge/client.lua',
    'web/**'
}

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/sounds/wrong.mp3',
    'web/sounds/correct.wav',
    'web/sounds/click.wav'
}

lua54 'yes'