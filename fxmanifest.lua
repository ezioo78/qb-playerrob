fx_version 'cerulean'
game 'gta5'

description 'QB Player Robbery Script with Admin Integration - Stash Method'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'qb-core',
    'qb-inventory',
    'oxmysql'
}

lua54 'yes'