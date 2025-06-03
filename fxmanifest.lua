fx_version 'cerulean'
game 'gta5'

author 'Nadun Nissanka'
description 'Nu-Blackmarket - Standalone black market script for FiveM'
version '1.0.0'

dependencies {
    'ox_target',
    'ox_inventory',
    'qbx_core'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'test_config.lua' -- Testing utilities (remove for production)
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes' 