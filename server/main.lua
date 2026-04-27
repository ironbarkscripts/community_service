lib.locale()

local sentences     = {}
local taskLocks     = {}
local taskCooldowns = {}
local taskCycles    = {}

local function GetTask(taskId)
    for _, t in ipairs(Config.Tasks) do
        if t.id == taskId then return t end
    end
end

local function PickNextTask(source, excludeId)
    if not taskCycles[source] then taskCycles[source] = {} end
    local done = taskCycles[source]

    local available = {}
    for _, t in ipairs(Config.Tasks) do
        if not done[t.id] and t.id ~= excludeId then
            available[#available + 1] = t
        end
    end

    if #available == 0 then
        taskCycles[source] = {}
        for _, t in ipairs(Config.Tasks) do
            if t.id ~= excludeId then
                available[#available + 1] = t
            end
        end
        if #available == 0 then return Config.Tasks[1] end
    end

    return available[math.random(#available)]
end

local function Dist2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function GetCitizenId(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end
    return player.PlayerData.citizenid
end

local function IsAuthorisedJob(source)
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    local job = player.PlayerData.job.name
    for _, j in ipairs(Config.AuthorisedJobs) do
        if j == job then return true end
    end
    return false
end

local function Notify(source, msg, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title       = locale('title'),
        description = msg,
        type        = ntype or 'inform',
        duration    = 6000,
    })
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `kg_cs_sentences` (
            `citizenid`       varchar(50)  PRIMARY KEY,
            `tasks_total`     int          DEFAULT 0,
            `tasks_done`      int          DEFAULT 0,
            `reason`          varchar(255),
            `sentenced_by`    varchar(50),
            `current_task_id` varchar(50),
            `sentenced_at`    timestamp    DEFAULT CURRENT_TIMESTAMP,
            `updated_at`      timestamp    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query([[ALTER TABLE `kg_cs_sentences` ADD COLUMN IF NOT EXISTS `current_task_id` varchar(50) DEFAULT NULL]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `kg_cs_log` (
            `id`           int          AUTO_INCREMENT PRIMARY KEY,
            `citizenid`    varchar(50),
            `task_id`      varchar(50),
            `sentenced_by` varchar(50),
            `completed_at` timestamp    DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end)

RegisterNetEvent('kg_cs:server:getSentence', function()
    local source = source
    local cid    = GetCitizenId(source)
    if not cid then return end

    MySQL.single('SELECT * FROM `kg_cs_sentences` WHERE `citizenid` = ?', { cid }, function(row)
        if row then
            local currentTaskId = row.current_task_id
            if not currentTaskId then
                local t = PickNextTask(source, nil)
                currentTaskId = t.id
                MySQL.update('UPDATE `kg_cs_sentences` SET `current_task_id` = ? WHERE `citizenid` = ?',
                    { currentTaskId, cid })
            end
            sentences[cid] = {
                tasks_total     = row.tasks_total,
                tasks_done      = row.tasks_done,
                reason          = row.reason,
                sentenced_by    = row.sentenced_by,
                current_task_id = currentTaskId,
            }
            TriggerClientEvent('kg_cs:client:receiveSentence', source, sentences[cid])
        else
            sentences[cid] = nil
            TriggerClientEvent('kg_cs:client:receiveSentence', source, nil)
        end
    end)
end)

RegisterNetEvent('kg_cs:server:requestTask', function(taskId)
    local source = source
    local ped    = GetPlayerPed(source)
    if ped == 0 then return end

    local cid = GetCitizenId(source)
    if not cid then return end

    local sentence = sentences[cid]
    if not sentence then
        TriggerClientEvent('kg_cs:client:taskDenied', source, locale('no_sentence'))
        return
    end

    if taskLocks[source] then
        TriggerClientEvent('kg_cs:client:taskDenied', source, locale('task_active'))
        return
    end

    local now = os.time()
    if taskCooldowns[source] and (now - taskCooldowns[source]) < Config.TaskCooldown then
        local remaining = Config.TaskCooldown - (now - taskCooldowns[source])
        TriggerClientEvent('kg_cs:client:taskDenied', source, locale('cooldown', remaining))
        return
    end

    if sentence.current_task_id ~= taskId then
        TriggerClientEvent('kg_cs:client:taskDenied', source, locale('wrong_task'))
        return
    end

    local task = GetTask(taskId)
    if not task then return end

    local playerCoords = GetEntityCoords(ped)
    if Dist2D(playerCoords, task.coords) > Config.TaskRadius then
        TriggerClientEvent('kg_cs:client:taskDenied', source, locale('not_close_enough'))
        return
    end

    taskLocks[source] = taskId
    TriggerClientEvent('kg_cs:client:taskGranted', source, { taskId = taskId })
end)

RegisterNetEvent('kg_cs:server:cancelTask', function()
    local source = source
    taskLocks[source] = nil
end)

RegisterNetEvent('kg_cs:server:completeTask', function(taskId)
    local source = source
    local ped    = GetPlayerPed(source)
    if ped == 0 then return end

    if taskLocks[source] ~= taskId then return end

    local cid = GetCitizenId(source)
    if not cid then return end

    local sentence = sentences[cid]
    if not sentence then taskLocks[source] = nil; return end

    local task = GetTask(taskId)
    if not task then taskLocks[source] = nil; return end

    local checkCoords  = task.dropCoords or task.coords
    local playerCoords = GetEntityCoords(ped)
    if Dist2D(playerCoords, checkCoords) > Config.TaskRadius then
        taskLocks[source] = nil
        Notify(source, locale('task_failed'), 'error')
        return
    end

    if not taskCycles[source] then taskCycles[source] = {} end
    taskCycles[source][taskId] = true

    sentence.tasks_done   = sentence.tasks_done + 1
    taskLocks[source]     = nil
    taskCooldowns[source] = os.time()

    MySQL.insert(
        'INSERT INTO `kg_cs_log` (`citizenid`, `task_id`, `sentenced_by`) VALUES (?, ?, ?)',
        { cid, taskId, sentence.sentenced_by }
    )

    if sentence.tasks_done >= sentence.tasks_total then
        sentences[cid]     = nil
        taskCycles[source] = nil
        MySQL.query('DELETE FROM `kg_cs_sentences` WHERE `citizenid` = ?', { cid })
        TriggerClientEvent('kg_cs:client:sentenceComplete', source)
        print(('[kg_cs] %s completed community service'):format(cid))
    else
        local nextTask = PickNextTask(source, taskId)
        sentence.current_task_id = nextTask.id
        MySQL.update(
            'UPDATE `kg_cs_sentences` SET `tasks_done` = ?, `current_task_id` = ? WHERE `citizenid` = ?',
            { sentence.tasks_done, nextTask.id, cid }
        )
        TriggerClientEvent('kg_cs:client:sentenceUpdate', source, sentence)
    end
end)

AddEventHandler('playerDropped', function()
    local source          = source
    taskLocks[source]     = nil
    taskCooldowns[source] = nil
    taskCycles[source]    = nil
end)

RegisterCommand('sentence', function(source, args)
    if source ~= 0 and not IsAuthorisedJob(source) then
        Notify(source, locale('no_permission'), 'error')
        return
    end

    local targetId = tonumber(args[1])
    local tasks    = tonumber(args[2])
    local reason   = args[3] and table.concat(args, ' ', 3) or nil

    if not targetId or not tasks or not reason or reason == '' then
        if source ~= 0 then
            Notify(source, locale('usage_sentence'), 'error')
        end
        return
    end

    if tasks < Config.MinTasks or tasks > Config.MaxTasks then
        if source ~= 0 then
            Notify(source, locale('tasks_range', Config.MinTasks, Config.MaxTasks), 'error')
        end
        return
    end

    local targetPlayer = Bridge.GetPlayer(targetId)
    if not targetPlayer then
        if source ~= 0 then Notify(source, locale('player_not_found'), 'error') end
        return
    end

    local targetCid  = targetPlayer.PlayerData.citizenid
    local officerCid = source ~= 0 and GetCitizenId(source) or 'console'
    local existing   = sentences[targetCid]

    if existing then
        local newTotal = math.min(existing.tasks_total + tasks, Config.MaxTasks)
        sentences[targetCid].tasks_total = newTotal
        MySQL.update(
            'UPDATE `kg_cs_sentences` SET `tasks_total` = ? WHERE `citizenid` = ?',
            { newTotal, targetCid }
        )
        if source ~= 0 then
            Notify(source, locale('tasks_added_officer', tasks, targetCid), 'success')
        end
        TriggerClientEvent('kg_cs:client:tasksAdded', targetId, sentences[targetCid])
    else
        local firstTask = PickNextTask(targetId, nil)
        sentences[targetCid] = {
            tasks_total     = tasks,
            tasks_done      = 0,
            reason          = reason,
            sentenced_by    = officerCid,
            current_task_id = firstTask.id,
        }
        MySQL.insert(
            'INSERT INTO `kg_cs_sentences` (`citizenid`, `tasks_total`, `tasks_done`, `reason`, `sentenced_by`, `current_task_id`) VALUES (?, ?, 0, ?, ?, ?)',
            { targetCid, tasks, reason, officerCid, firstTask.id }
        )
        if source ~= 0 then
            Notify(source, locale('sentenced_officer', targetCid, tasks), 'success')
        end
        TriggerClientEvent('kg_cs:client:sentenced', targetId, sentences[targetCid])
    end

    print(('[kg_cs] %s sentenced %s to %d tasks. Reason: %s'):format(officerCid, targetCid, tasks, reason))
end, false)

RegisterCommand('mysentence', function(source)
    if source == 0 then return end
    local cid = GetCitizenId(source)
    if not cid then return end
    local sentence = sentences[cid]
    if not sentence then
        Notify(source, locale('no_active_sentence'), 'inform')
        return
    end
    local remaining = sentence.tasks_total - sentence.tasks_done
    Notify(source, locale('my_sentence', remaining, sentence.tasks_done, sentence.tasks_total), 'inform')
end, false)

RegisterCommand('clearsentence', function(source, args)
    if source ~= 0 and not IsAuthorisedJob(source) then
        Notify(source, locale('no_permission'), 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if source ~= 0 then Notify(source, locale('usage_clearsentence'), 'error') end
        return
    end

    local targetPlayer = Bridge.GetPlayer(targetId)
    if not targetPlayer then
        if source ~= 0 then Notify(source, locale('player_not_found'), 'error') end
        return
    end

    local targetCid  = targetPlayer.PlayerData.citizenid
    local officerCid = source ~= 0 and GetCitizenId(source) or 'console'

    if not sentences[targetCid] then
        if source ~= 0 then Notify(source, locale('no_target_sentence'), 'inform') end
        return
    end

    sentences[targetCid]  = nil
    taskLocks[targetId]   = nil
    taskCycles[targetId]  = nil

    MySQL.query('DELETE FROM `kg_cs_sentences` WHERE `citizenid` = ?', { targetCid })
    MySQL.insert(
        'INSERT INTO `kg_cs_log` (`citizenid`, `task_id`, `sentenced_by`) VALUES (?, ?, ?)',
        { targetCid, 'cleared', officerCid }
    )

    TriggerClientEvent('kg_cs:client:sentenceComplete', targetId)
    Notify(targetId, locale('sentence_cleared'), 'success')
    if source ~= 0 then
        Notify(source, locale('cleared_officer', targetCid), 'success')
    end

    print(('[kg_cs] %s cleared sentence for %s'):format(officerCid, targetCid))
end, false)
