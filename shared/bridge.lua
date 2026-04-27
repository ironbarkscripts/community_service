local framework = nil

if GetResourceState('qbx_core') == 'started' then
    framework = 'qbx'
elseif GetResourceState('qb-core') == 'started' then
    framework = 'qb'
end

local function GetPlayer(source)
    if framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    elseif framework == 'qb' then
        return exports['qb-core']:GetPlayer(source)
    end
end

local function AddMoney(source, moneyType, amount)
    if framework == 'qbx' then
        exports.qbx_core:AddMoney(source, moneyType, amount)
    elseif framework == 'qb' then
        local Player = exports['qb-core']:GetPlayer(source)
        if Player then Player.Functions.AddMoney(moneyType, amount) end
    end
end

local function RemoveMoney(source, moneyType, amount)
    if framework == 'qbx' then
        exports.qbx_core:RemoveMoney(source, moneyType, amount)
    elseif framework == 'qb' then
        local Player = exports['qb-core']:GetPlayer(source)
        if Player then Player.Functions.RemoveMoney(moneyType, amount) end
    end
end

Bridge = {
    GetPlayer   = GetPlayer,
    AddMoney    = AddMoney,
    RemoveMoney = RemoveMoney,
    framework   = framework,
}
