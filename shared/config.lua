Config = {}

Config.AuthorisedJobs = { 'police', 'sheriff', 'state' }

Config.MinTasks     = 3
Config.MaxTasks     = 50
Config.TaskCooldown = 10
Config.TaskRadius   = 5.0

Config.ConfinementCoords = vector3(2206.0, 5555.0, 53.04)
Config.ConfinementRadius = 120.0

Config.MarkerType   = 1
Config.MarkerColour = { r = 255, g = 165, b = 0, a = 180 }
Config.MarkerSize   = { x = 1.5, y = 1.5, z = 0.5 }

Config.Tasks = {
    {
        id        = 'sweep_road',
        label     = 'Sweep the road',
        coords    = vector3(2207.01, 5607.71, 52.98),
        animation = {
            dict = 'amb@world_human_janitor@male@base',
            anim = 'base',
            flag = 49,
        },
        duration  = 15000,
        icon      = 'fas fa-broom',
    },
    {
        id        = 'prune_bush',
        label     = 'Prune the bushes',
        coords    = vector3(2185.05, 5554.55, 52.3),
        animation = {
            dict = 'amb@world_human_gardener_plant@male@base',
            anim = 'base',
            flag = 49,
        },
        duration  = 13000,
        icon      = 'fas fa-scissors',
    },
    {
        id        = 'tidy_pallet',
        label     = 'Stack the pallets',
        coords    = vector3(2215.98, 5590.09, 53.16),
        animation = {
            dict = 'amb@world_human_maid_clean@male@base',
            anim = 'base',
            flag = 49,
        },
        duration  = 16000,
        icon      = 'fas fa-pallet',
    },
    {
        id        = 'wash_house',
        label     = 'Scrub the walls',
        coords    = vector3(2232.46, 5608.97, 53.85),
        animation = {
            dict = 'amb@world_human_maid_clean@male@base',
            anim = 'base',
            flag = 49,
        },
        duration  = 18000,
        icon      = 'fas fa-soap',
    },
    {
        id        = 'weed_garden',
        label     = 'Weed the garden',
        coords    = vector3(2222.82, 5564.38, 52.95),
        animation = {
            dict = 'amb@world_human_gardener_plant@male@base',
            anim = 'base',
            flag = 49,
        },
        duration  = 14000,
        icon      = 'fas fa-seedling',
    },
    {
        id         = 'take_trash_out',
        label      = 'Take the trash out',
        coords     = vector3(2224.06, 5603.31, 54.02),
        dropCoords = vector3(2211.64, 5588.73, 53.18),
        prop = {
            model    = 'prop_rub_binbag_01',
            bone     = 57005,
            offset   = vector3(0.12, 0.0, -0.05),
            rotation = vector3(0.0, 0.0, 0.0),
        },
        animation = {
            dict = 'amb@world_human_janitor@male@base',
            anim = 'base',
            flag = 49,
        },
        duration   = 2500,
        icon       = 'fas fa-trash',
    },
}
