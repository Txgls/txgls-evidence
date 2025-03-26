fx_version 'cerulean'
game 'gta5'

author 'Txgls'
description 'Police Evidence System'
version '1.0.1'

dependencies {
    'oxmysql',
    'ox_inventory',
    'qb-core'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

lua54 'yes'
