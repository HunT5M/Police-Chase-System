-- ==========================================
-- GESTIONE OGGETTI (SPIKES)
-- ==========================================
RegisterNetEvent('police:spawnSpikes')
AddEventHandler('police:spawnSpikes', function(coords, heading)
    local spikeObj = CreateObject(GetHashKey("p_ld_stinger_s"), coords.x, coords.y, coords.z, true, true, true)
    SetEntityHeading(spikeObj, heading)
    Citizen.SetTimeout(60000, function()
        if DoesEntityExist(spikeObj) then DeleteEntity(spikeObj) end
    end)
end)

RegisterNetEvent('police:removeSpikes')
AddEventHandler('police:removeSpikes', function(netId)
    TriggerClientEvent('police:forceDeleteClient', -1, netId)
    local obj = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(obj) then DeleteEntity(obj) end
end)

-- ==========================================
-- CONFIGURAZIONE & WHITELIST
-- ==========================================
local currentConfig = {}

Citizen.CreateThread(function()
    local loadFile = LoadResourceFile(GetCurrentResourceName(), "config.json")
    if loadFile then 
        currentConfig = json.decode(loadFile)
        print("^2[LSPD] Config loaded.^7")
    end
end)

function IsAllowed(src)
    if not currentConfig.restrictMode then return true end
    if not currentConfig.allowedIds or #currentConfig.allowedIds == 0 then return false end 

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        local cleanId = string.gsub(string.lower(id), "%s+", "")
        for _, allowed in ipairs(currentConfig.allowedIds) do
            if cleanId == string.gsub(string.lower(allowed), "%s+", "") then
                return true
            end
        end
    end
    return false
end

RegisterNetEvent('lspd:requestConfig')
AddEventHandler('lspd:requestConfig', function()
    local src = source
    local playerAllowed = IsAllowed(src)
    TriggerClientEvent('lspd:updateConfig', src, currentConfig, playerAllowed)
end)

RegisterNetEvent('lspd_config:checkPerms')
AddEventHandler('lspd_config:checkPerms', function()
    local src = source
    if IsPlayerAceAllowed(src, "command.pcem") then
        TriggerClientEvent('lspd_config:openMenu', src, currentConfig)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { "^1SYSTEM", "Access Denied." } })
    end
end)

RegisterNetEvent('lspd_config:saveData')
AddEventHandler('lspd_config:saveData', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, "command.pcem") then return end

    currentConfig.minSpeed = tonumber(data.minSpeed)
    currentConfig.maxDist = tonumber(data.maxDist)
    currentConfig.fillRate = tonumber(data.fillRate)
    if data.colors then currentConfig.colors = data.colors end
    if data.globalAlpha then 
        local a = tonumber(data.globalAlpha)
        currentConfig.alpha = { targetText=a, barBackground=math.floor(a*0.7), barProgress=math.floor(a*0.8), barText=a }
    end
    currentConfig.restrictMode = data.restrictMode
    currentConfig.allowedIds = data.allowedIds
    if data.dispatch then currentConfig.dispatch = data.dispatch end

    SaveResourceFile(GetCurrentResourceName(), "config.json", json.encode(currentConfig, { indent = true }), -1)
    
    local players = GetPlayers()
    for _, pId in ipairs(players) do
        local isAuth = IsAllowed(tonumber(pId))
        TriggerClientEvent('lspd:updateConfig', pId, currentConfig, isAuth)
    end
end)

RegisterNetEvent('lspd:triggerDispatch')
AddEventHandler('lspd:triggerDispatch', function(targetNetId, coords)
    TriggerClientEvent('lspd:clientDispatch', -1, targetNetId, coords, currentConfig.dispatch)
end)