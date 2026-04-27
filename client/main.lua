lib.locale()

local activeSentence = nil
local taskInProgress = false
local zonesActive    = false
local carriedProp    = nil
local dropZoneId     = nil

local useOxTarget = GetResourceState('ox_target') == 'started'

local function GetTaskById(taskId)
    for _, task in ipairs(Config.Tasks) do
        if task.id == taskId then return task end
    end
end

local function PlayPing()
    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function PlayAnim(animData)
    RequestAnimDict(animData.dict)
    local timeout = 0
    while not HasAnimDictLoaded(animData.dict) and timeout < 30 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasAnimDictLoaded(animData.dict) then return end
    TaskPlayAnim(PlayerPedId(), animData.dict, animData.anim,
        8.0, -8.0, -1, animData.flag, 0, false, false, false)
end

local function StopAnim(animData)
    StopAnimTask(PlayerPedId(), animData.dict, animData.anim, 1.0)
    ClearPedTasks(PlayerPedId())
    RemoveAnimDict(animData.dict)
end

local function HandleTaskInteract(taskId)
    if not activeSentence then return end
    if taskInProgress then
        lib.notify({ title = locale('title'), description = locale('task_active'), type = 'warning', duration = 3000 })
        return
    end
    TriggerServerEvent('kg_cs:server:requestTask', taskId)
end

local function HandleDrop(task)
    if not taskInProgress or not carriedProp then return end

    if dropZoneId then
        if useOxTarget then
            exports.ox_target:removeZone(dropZoneId)
        else
            exports['qb-target']:RemoveZone('kg_cs_drop')
        end
        dropZoneId = nil
    end

    DetachEntity(carriedProp, true, true)
    DeleteObject(carriedProp)
    carriedProp = nil

    ClearPedTasks(PlayerPedId())
    taskInProgress = false
    TriggerServerEvent('kg_cs:server:completeTask', task.id)
end

local function CleanupCarriedProp()
    if dropZoneId then
        if useOxTarget then
            exports.ox_target:removeZone(dropZoneId)
        else
            exports['qb-target']:RemoveZone('kg_cs_drop')
        end
        dropZoneId = nil
    end
    if carriedProp then
        DetachEntity(carriedProp, true, true)
        DeleteObject(carriedProp)
        carriedProp = nil
    end
end

local function RegisterDropZone(task)
    if useOxTarget then
        dropZoneId = exports.ox_target:addSphereZone({
            coords  = task.dropCoords,
            radius  = 2.5,
            options = {{
                name     = 'kg_cs_drop',
                icon     = task.icon,
                label    = locale('drop_trash'),
                onSelect = function() HandleDrop(task) end,
            }},
        })
    else
        exports['qb-target']:AddCircleZone('kg_cs_drop', task.dropCoords, 2.5,
            { name = 'kg_cs_drop', debugPoly = false },
            { options = {{ type = 'client', event = 'kg_cs:client:dropTask', icon = task.icon, label = locale('drop_trash'), taskId = task.id }}, distance = 2.5 }
        )
        dropZoneId = 'kg_cs_drop'
    end
end

AddEventHandler('kg_cs:client:dropTask', function(data)
    local task = GetTaskById(data.taskId)
    if task then HandleDrop(task) end
end)

local Target       = {}
local activeZoneId = nil

if useOxTarget then
    function Target.SetZone(task)
        if activeZoneId then
            exports.ox_target:removeZone(activeZoneId)
            activeZoneId = nil
        end
        local label = activeSentence
            and ('%s (%d/%d done)'):format(task.label, activeSentence.tasks_done, activeSentence.tasks_total)
            or task.label
        activeZoneId = exports.ox_target:addSphereZone({
            coords  = task.coords,
            radius  = 2.5,
            options = {{
                name     = 'kg_cs_task',
                icon     = task.icon,
                label    = label,
                onSelect = function() HandleTaskInteract(task.id) end,
            }},
        })
    end

    function Target.ClearZone()
        if activeZoneId then
            exports.ox_target:removeZone(activeZoneId)
            activeZoneId = nil
        end
    end
else
    local ZONE_NAME = 'kg_cs_active_task'

    function Target.SetZone(task)
        exports['qb-target']:RemoveZone(ZONE_NAME)
        local label = activeSentence
            and ('%s (%d/%d done)'):format(task.label, activeSentence.tasks_done, activeSentence.tasks_total)
            or task.label
        exports['qb-target']:AddCircleZone(ZONE_NAME, task.coords, 2.5,
            { name = ZONE_NAME, debugPoly = false },
            { options = {{ type = 'client', event = 'kg_cs:client:interactTask', icon = task.icon, label = label, taskId = task.id }}, distance = 2.5 }
        )
        activeZoneId = ZONE_NAME
    end

    function Target.ClearZone()
        if activeZoneId then
            exports['qb-target']:RemoveZone(activeZoneId)
            activeZoneId = nil
        end
    end

    AddEventHandler('kg_cs:client:interactTask', function(data)
        HandleTaskInteract(data.taskId)
    end)
end

local function ApplyCurrentZone()
    if not activeSentence or not activeSentence.current_task_id then return end
    local task = GetTaskById(activeSentence.current_task_id)
    if task then Target.SetZone(task) end
end

local function SetupZones()
    if zonesActive then return end
    zonesActive = true
    ApplyCurrentZone()

    Citizen.CreateThread(function()
        while zonesActive do
            if activeSentence and activeSentence.current_task_id then
                local task = GetTaskById(activeSentence.current_task_id)
                if task then
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    if #(playerCoords - task.coords) < 50.0 then
                        DrawMarker(
                            Config.MarkerType,
                            task.coords.x, task.coords.y, task.coords.z - 0.1,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
                            Config.MarkerColour.r, Config.MarkerColour.g,
                            Config.MarkerColour.b, Config.MarkerColour.a,
                            false, true, 2, false, nil, nil, false
                        )
                        Wait(0)
                    else
                        Wait(500)
                    end
                else
                    Wait(1000)
                end
            else
                Wait(1000)
            end
        end
    end)

    Citizen.CreateThread(function()
        while zonesActive do
            if carriedProp and activeSentence and activeSentence.current_task_id then
                local task = GetTaskById(activeSentence.current_task_id)
                if task and task.dropCoords then
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    if #(playerCoords - task.dropCoords) < 80.0 then
                        DrawMarker(
                            Config.MarkerType,
                            task.dropCoords.x, task.dropCoords.y, task.dropCoords.z - 0.1,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
                            100, 200, 100, Config.MarkerColour.a,
                            false, true, 2, false, nil, nil, false
                        )
                        Wait(0)
                    else
                        Wait(500)
                    end
                else
                    Wait(1000)
                end
            else
                Wait(500)
            end
        end
    end)

    Citizen.CreateThread(function()
        while zonesActive do
            Wait(2000)
            if activeSentence and not taskInProgress then
                local coords = GetEntityCoords(PlayerPedId())
                local dx     = coords.x - Config.ConfinementCoords.x
                local dy     = coords.y - Config.ConfinementCoords.y
                if math.sqrt(dx * dx + dy * dy) > Config.ConfinementRadius then
                    local rc = Config.ConfinementCoords
                    SetEntityCoords(PlayerPedId(), rc.x, rc.y, rc.z, false, false, false, false)
                    lib.notify({
                        title       = locale('title'),
                        description = locale('confinement_warning'),
                        type        = 'error',
                        duration    = 5000,
                    })
                end
            end
        end
    end)
end

local function ClearZones()
    if not zonesActive then return end
    zonesActive = false
    Target.ClearZone()
    CleanupCarriedProp()
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent('kg_cs:server:getSentence')
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(2000)
    TriggerServerEvent('kg_cs:server:getSentence')
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CleanupCarriedProp()
    Target.ClearZone()
end)

AddEventHandler('chat:init', function()
    TriggerEvent('chat:addSuggestion', '/sentence', locale('cmd_sentence_desc'), {
        { name = 'id',     help = locale('cmd_sentence_arg_id') },
        { name = 'tasks',  help = locale('cmd_sentence_arg_tasks', Config.MinTasks, Config.MaxTasks) },
        { name = 'reason', help = locale('cmd_sentence_arg_reason') },
    })
    TriggerEvent('chat:addSuggestion', '/clearsentence', locale('cmd_clearsentence_desc'), {
        { name = 'id', help = locale('cmd_clearsentence_arg_id') },
    })
    TriggerEvent('chat:addSuggestion', '/mysentence', locale('cmd_mysentence_desc'))
end)

RegisterNetEvent('kg_cs:client:receiveSentence', function(data)
    activeSentence = data
    if data then
        local remaining = data.tasks_total - data.tasks_done
        lib.notify({
            title       = locale('title'),
            description = locale('tasks_remaining', remaining),
            type        = 'inform',
            duration    = 7000,
        })
        SetupZones()
    else
        ClearZones()
    end
end)

RegisterNetEvent('kg_cs:client:sentenced', function(data)
    activeSentence = data
    PlayPing()
    lib.notify({
        title       = locale('title'),
        description = locale('sentenced_player', data.tasks_total),
        type        = 'error',
        duration    = 8000,
    })
    SetupZones()
end)

RegisterNetEvent('kg_cs:client:sentenceUpdate', function(data)
    activeSentence = data
    local remaining = data.tasks_total - data.tasks_done
    Target.ClearZone()
    Wait(200)
    PlayPing()
    lib.notify({
        title       = locale('title'),
        description = locale('task_complete', remaining),
        type        = 'success',
        duration    = 5000,
    })
    ApplyCurrentZone()
end)

RegisterNetEvent('kg_cs:client:tasksAdded', function(data)
    activeSentence = data
    local remaining = data.tasks_total - data.tasks_done
    lib.notify({
        title       = locale('title'),
        description = locale('tasks_added_player', remaining),
        type        = 'error',
        duration    = 7000,
    })
end)

RegisterNetEvent('kg_cs:client:sentenceComplete', function()
    activeSentence = nil
    lib.notify({
        title       = locale('title'),
        description = locale('service_complete'),
        type        = 'success',
        duration    = 8000,
    })
    ClearZones()
end)

RegisterNetEvent('kg_cs:client:taskGranted', function(taskData)
    if taskInProgress then return end

    local task = GetTaskById(taskData.taskId)
    if not task then
        TriggerServerEvent('kg_cs:server:cancelTask')
        return
    end

    taskInProgress = true

    if task.prop then
        PlayAnim(task.animation)

        local picked = lib.progressBar({
            duration     = task.duration,
            label        = locale('picking_up'),
            useWhileDead = false,
            canCancel    = true,
            disable      = { move = true, car = true, combat = true },
        })

        StopAnim(task.animation)

        if not picked then
            taskInProgress = false
            TriggerServerEvent('kg_cs:server:cancelTask')
            lib.notify({ title = locale('title'), description = locale('task_cancelled'), type = 'warning', duration = 3000 })
            return
        end

        local model = task.prop.model

        if not IsModelValid(model) then
            taskInProgress = false
            TriggerServerEvent('kg_cs:server:cancelTask')
            lib.notify({ title = locale('title'), description = locale('prop_error'), type = 'error', duration = 4000 })
            return
        end

        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end

        local playerPos = GetEntityCoords(PlayerPedId())
        carriedProp     = CreateObject(model, playerPos.x, playerPos.y, playerPos.z, true, true, false)
        local boneIdx   = GetPedBoneIndex(PlayerPedId(), task.prop.bone)
        AttachEntityToEntity(
            carriedProp, PlayerPedId(), boneIdx,
            task.prop.offset.x, task.prop.offset.y, task.prop.offset.z,
            task.prop.rotation.x, task.prop.rotation.y, task.prop.rotation.z,
            true, true, false, true, 1, true
        )
        SetModelAsNoLongerNeeded(model)

        RegisterDropZone(task)
        return
    end

    PlayPing()
    PlayAnim(task.animation)

    if task.sound then
        Citizen.CreateThread(function()
            while taskInProgress do
                PlaySoundFrontend(-1, task.sound.name, task.sound.set, true)
                Wait(task.sound.interval or 3000)
            end
        end)
    end

    local success = lib.progressBar({
        duration     = task.duration,
        label        = task.label,
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })

    StopAnim(task.animation)
    taskInProgress = false

    if success then
        TriggerServerEvent('kg_cs:server:completeTask', taskData.taskId)
    else
        TriggerServerEvent('kg_cs:server:cancelTask')
        lib.notify({ title = locale('title'), description = locale('task_cancelled'), type = 'warning', duration = 3000 })
    end
end)

RegisterNetEvent('kg_cs:client:taskDenied', function(reason)
    lib.notify({
        title       = locale('title'),
        description = reason or locale('cannot_start'),
        type        = 'warning',
        duration    = 4000,
    })
end)
