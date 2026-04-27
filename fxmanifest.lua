fx_version 'cerulean'
game 'gta5'

author      'Ironbark Scripts'
version     '1.0.0'
description 'Community Service'

-- Framework: qbx_core (primary) or qb-core — detected at runtime via shared/bridge.lua
-- Target:    ox_target (primary) or qb-target — detected at runtime
-- Ensure your framework and ox_lib start before this resource in server.cfg

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/bridge.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
