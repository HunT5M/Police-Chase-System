-- ==========================================
-- CONFIGURATION
-- ==========================================
local CONFIG = {
    minSpeed = 50.0,
    maxDist = 30.0,
    fillRate = 0.05,
    keyTarget = 25,
    keySpike = 24,
    policeClass = 18,
    alpha = { targetText = 200, barBackground = 150, barProgress = 180, barText = 200 },
    colors = { bar = "#ff0000", ready = "#00ff00", text = "#ffffff" },
    allowedIds = {},
    dispatch = { enabled = false, sprite = 161, color = 1 }
}

-- SYSTEM STATES
local chaseProgress = 0.0   
local targetVeh = nil
local lockOnStartTime = 0 
local lastDispatchTime = 0 
local amIAllowed = true 

-- BLIP MANAGEMENT
local ActiveBlips = {} 

-- CACHE
local cachedTargetName = "VEHICLE"
local cachedTargetPlate = ""

-- MENU STATES
local isMenuOpen = false
local pendingRequest = false 
local tabletObj = nil

-- TABLET ASSETS 
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"
local tabletProp = "prop_cs_tablet" 
local tabletBone = 60309

-- INITIAL LOAD
Citizen.CreateThread(function()
    TriggerServerEvent('lspd:requestConfig')
end)

-- RECEIVE CONFIG
RegisterNetEvent('lspd:updateConfig')
AddEventHandler('lspd:updateConfig', function(serverConfig, allowedStatus)
    if serverConfig then
        if serverConfig.minSpeed then CONFIG.minSpeed = serverConfig.minSpeed + 0.0 end
        if serverConfig.maxDist then CONFIG.maxDist = serverConfig.maxDist + 0.0 end
        if serverConfig.fillRate then CONFIG.fillRate = serverConfig.fillRate + 0.0 end
        if serverConfig.alpha then CONFIG.alpha = serverConfig.alpha end
        if serverConfig.colors then CONFIG.colors = serverConfig.colors end
        if serverConfig.allowedIds then CONFIG.allowedIds = serverConfig.allowedIds end
        if serverConfig.dispatch then CONFIG.dispatch = serverConfig.dispatch end
    end
    if allowedStatus ~= nil then
        amIAllowed = allowedStatus
     
    end
end)

-- ==========================================
-- CHASE LOGIC
-- ==========================================
Citizen.CreateThread(function()
    while true do
        local wait = 1000 
        local ped = PlayerPedId()
        
        if IsPedInAnyVehicle(ped, false) and not isMenuOpen then
            local myVeh = GetVehiclePedIsIn(ped, false)
            
            if GetPedInVehicleSeat(myVeh, -1) == ped and GetVehicleClass(myVeh) == CONFIG.policeClass then
                wait = 0 
                
                DisableControlAction(0, 24, true) 
                DisableControlAction(0, 25, true) 
                DisableControlAction(0, 68, true) 

                -- LOCK ON
                if IsDisabledControlJustPressed(0, CONFIG.keyTarget) then
                    if targetVeh then
                        targetVeh = nil
                        chaseProgress = 0.0
                        ShowNotification("~b~Target disengaged.")
                        PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    else
                        AttemptLockOn(myVeh)
                    end
                end

                if targetVeh and DoesEntityExist(targetVeh) then
                    local timeElapsed = GetGameTimer() - lockOnStartTime
                    local textToShow = nil
                    
                    if timeElapsed < 2000 then 
                        textToShow = "~r~[ TARGET ]"
                    elseif timeElapsed < 4000 then
                        textToShow = "[ " .. string.upper(cachedTargetName) .. " ]"
                    elseif timeElapsed < 6000 then
                        local plateText = (cachedTargetPlate ~= "") and cachedTargetPlate or "NO PLATE"
                        textToShow = "[ " .. plateText .. " ]"
                    else
                        textToShow = nil 
                    end

                    if textToShow then
                        local tCoords = GetEntityCoords(targetVeh)
                        DrawText3D(tCoords.x, tCoords.y, tCoords.z + 1.35, textToShow)
                    end
                    
                    local speedKmh = GetEntitySpeed(myVeh) * 3.6
                    if speedKmh >= CONFIG.minSpeed then
                        local offset = GetOffsetFromEntityInWorldCoords(myVeh, 0.0, CONFIG.maxDist, 0.0)
                        local rayHandle = StartShapeTestCapsule(GetEntityCoords(myVeh), offset, 2.0, 10, myVeh, 7)
                        local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
                        
                        if hit == 1 and entityHit == targetVeh then
                            if chaseProgress < 100.0 then 
                                chaseProgress = chaseProgress + CONFIG.fillRate 
                            end
                        end
                    end
                    
                    if chaseProgress > 100.0 then chaseProgress = 100.0 end
                    
                    if chaseProgress > 0.0 then 
                        drawChaseUI(chaseProgress) 
                    end
                    
              
                    if chaseProgress >= 100.0 then
                        
                       
                        if CONFIG.dispatch.enabled and (GetGameTimer() - lastDispatchTime > 1000) then
                            lastDispatchTime = GetGameTimer()
                            local tNet = NetworkGetNetworkIdFromEntity(targetVeh)
                            local tCoords = GetEntityCoords(targetVeh)
                            TriggerServerEvent('lspd:triggerDispatch', tNet, tCoords)
                        end

                      
                        if IsDisabledControlJustPressed(0, CONFIG.keySpike) then
                            if amIAllowed then
                               
                                if deploySpikes(myVeh, targetVeh) then
                                    chaseProgress = 0.0
                                    targetVeh = nil 
                                else
                                    PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                    ShowHelpNotification("~r~DANGER: Too close! Keep distance.")
                                end
                            else
                              
                                PlaySoundFrontend(-1, "Place_Sentry_Turret_Fail", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                                ShowNotification("~r~ACCESS DENIED: Not authorized.")
                            end
                        end
                    end
                elseif targetVeh and not DoesEntityExist(targetVeh) then
                    targetVeh = nil
                    chaseProgress = 0.0
                    ShowNotification("~r~Target lost.")
                end
            else
                targetVeh = nil
                chaseProgress = 0.0
            end
        else
            wait = 1000
        end
        Citizen.Wait(wait)
    end
end)

-- ==========================================
-- DISPATCH RECEIVER
-- ==========================================
RegisterNetEvent('lspd:clientDispatch')
AddEventHandler('lspd:clientDispatch', function(targetNetId, coords, dispatchConfig)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetVehicleClass(veh) == CONFIG.policeClass then
            
            if not ActiveBlips[targetNetId] then
                local newBlip = nil
                if NetworkDoesNetworkIdExist(targetNetId) then
                    local targetEnt = NetworkGetEntityFromNetworkId(targetNetId)
                    if DoesEntityExist(targetEnt) then newBlip = AddBlipForEntity(targetEnt) end
                end
                if not newBlip then newBlip = AddBlipForCoord(coords.x, coords.y, coords.z) end

                SetBlipSprite(newBlip, tonumber(dispatchConfig.sprite) or 161)
                SetBlipScale(newBlip, 1.0)
                SetBlipColour(newBlip, tonumber(dispatchConfig.color) or 1)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("PURSUIT IN PROGRESS")
                EndTextCommandSetBlipName(newBlip)
                
                PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", true)

                ActiveBlips[targetNetId] = { blip = newBlip, lastUpdate = GetGameTimer() }
            else
                local data = ActiveBlips[targetNetId]
                data.lastUpdate = GetGameTimer() 
                if GetBlipInfoIdType(data.blip) == 4 then SetBlipCoords(data.blip, coords.x, coords.y, coords.z) end
                SetBlipSprite(data.blip, tonumber(dispatchConfig.sprite) or 161)
                SetBlipColour(data.blip, tonumber(dispatchConfig.color) or 1)
            end
        end
    end
end)

-- CLEANUP BLIPS
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local currentTime = GetGameTimer()
        for netId, data in pairs(ActiveBlips) do
            if (currentTime - data.lastUpdate) > 3000 then
                if DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
                ActiveBlips[netId] = nil
            end
        end
    end
end)

-- ==========================================
-- PHYSICS & SPIKES (CON ROTTURA RUOTA)
-- ==========================================
Citizen.CreateThread(function()
    local spikeModel = GetHashKey("p_ld_stinger_s")
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        if DoesObjectOfTypeExistAtCoords(myCoords, 100.0, spikeModel, true) then
            Citizen.Wait(50) 
            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if not IsVehicleTyreBurst(veh, 0, false) then
                    local vehPos = GetEntityCoords(veh)
                    local closestSpike = GetClosestObjectOfType(vehPos.x, vehPos.y, vehPos.z, 3.0, spikeModel, false, false, false)
                    if closestSpike ~= 0 and DoesEntityExist(closestSpike) then
                        local spikePos = GetEntityCoords(closestSpike)
                        local dist = #(vector2(vehPos.x, vehPos.y) - vector2(spikePos.x, spikePos.y))
                        if dist < 3.0 then
                            popTyres(veh)
                            local targetToBreak = veh
                            Citizen.SetTimeout(5000, function()
                                if DoesEntityExist(targetToBreak) then
                                    local wheelIndex = math.random(0, 1)
                                    BreakOffVehicleWheel(targetToBreak, wheelIndex, true, false, true, false)
                                end
                            end)
                            local netId = NetworkGetNetworkIdFromEntity(closestSpike)
                            NetworkRequestControlOfEntity(closestSpike)
                            SetEntityAsMissionEntity(closestSpike, false, true)
                            DeleteEntity(closestSpike)
                            if netId and netId ~= 0 then TriggerServerEvent('police:removeSpikes', netId) end
                            PlaySoundFromEntity(-1, "Barricade_Smash", veh, "DLC_HEIST_FLEECA_SOUNDSET", 0, 0)
                        end
                    end
                end
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

RegisterNetEvent('police:forceDeleteClient')
AddEventHandler('police:forceDeleteClient', function(netId)
    if NetworkDoesNetworkIdExist(netId) then
        local obj = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)

-- ==========================================
-- TABLET & MENU ANIMATION
-- ==========================================
function ToggleTablet(bool)
    local ped = PlayerPedId()
    if bool then
        SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        RequestAnimDict(tabletDict)
        RequestModel(tabletProp)
        
        Citizen.CreateThread(function()
            while not HasAnimDictLoaded(tabletDict) or not HasModelLoaded(tabletProp) do Wait(100) end
            
            if tabletObj then DeleteEntity(tabletObj) end
            tabletObj = CreateObject(GetHashKey(tabletProp), 0, 0, 0, true, true, true)
            AttachEntityToEntity(tabletObj, ped, GetPedBoneIndex(ped, tabletBone), 
                0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
            
            TaskPlayAnim(ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
        end)
        
        SetNightvision(false)
        SetSeethrough(false)
        SetTimecycleModifier("hud_def_desat_neutral")
        SetTimecycleModifierStrength(1.0)
    else
        StopAnimTask(ped, tabletDict, tabletAnim, 1.0)
        if tabletObj then DeleteEntity(tabletObj) tabletObj = nil end
        
        ClearTimecycleModifier()
        SetNightvision(false)
        SetSeethrough(false)
    end
end

-- MENU OPEN
RegisterNetEvent('lspd_config:openMenu')
AddEventHandler('lspd_config:openMenu', function(currentServerConfig)
    if isMenuOpen then pendingRequest = false return end
    
    if currentServerConfig then 
        if currentServerConfig.minSpeed then CONFIG.minSpeed = currentServerConfig.minSpeed end
        if currentServerConfig.maxDist then CONFIG.maxDist = currentServerConfig.maxDist end
        if currentServerConfig.fillRate then CONFIG.fillRate = currentServerConfig.fillRate end
        if currentServerConfig.alpha then CONFIG.alpha = currentServerConfig.alpha end
        if currentServerConfig.colors then CONFIG.colors = currentServerConfig.colors end
        if currentServerConfig.allowedIds then CONFIG.allowedIds = currentServerConfig.allowedIds end
        if currentServerConfig.dispatch then CONFIG.dispatch = currentServerConfig.dispatch end
    end

    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            minSpeed = CONFIG.minSpeed,
            maxDist = CONFIG.maxDist,
            fillRate = CONFIG.fillRate,
            alpha = CONFIG.alpha.targetText,
            colors = CONFIG.colors,
            allowedIds = CONFIG.allowedIds,
            dispatch = CONFIG.dispatch 
        }
    })
    ToggleTablet(true)
    pendingRequest = false
end)

RegisterNUICallback('closeUI', function(data, cb)
    isMenuOpen = false
    pendingRequest = false
    SetNuiFocus(false, false)
    ToggleTablet(false)
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    if data.minSpeed then CONFIG.minSpeed = tonumber(data.minSpeed) end
    if data.maxDist then CONFIG.maxDist = tonumber(data.maxDist) end
    if data.fillRate then CONFIG.fillRate = tonumber(data.fillRate) end
    if data.globalAlpha then
        local alphaVal = tonumber(data.globalAlpha)
        CONFIG.alpha.targetText = alphaVal
        CONFIG.alpha.barText = alphaVal
        CONFIG.alpha.barBackground = math.floor(alphaVal * 0.7)
    end
    if data.colors then 
        if not CONFIG.colors then CONFIG.colors = {} end
        CONFIG.colors.bar = data.colors.bar; CONFIG.colors.ready = data.colors.ready; CONFIG.colors.text = data.colors.text
    end
    if data.dispatch then CONFIG.dispatch = data.dispatch end

    TriggerServerEvent('lspd_config:saveData', data)
    ShowNotification("~g~Police Chase System Updated.")
    cb('ok')
end)

RegisterKeyMapping('pcem', 'Apri Config LSPD', 'keyboard', '3')
RegisterCommand('pcem', function()
    if isMenuOpen or pendingRequest then return end
    pendingRequest = true
    TriggerServerEvent('lspd_config:checkPerms')
    SetTimeout(1000, function() if not isMenuOpen then pendingRequest = false end end)
end)

-- PREVIEW MODE
Citizen.CreateThread(function()
    while true do
        local wait = 1000
        if isMenuOpen then
            wait = 0
            drawChaseUI(50.0) 
        end
        Citizen.Wait(wait)
    end
end)

-- HELPERS
function HexToRGB(hex)
    if not hex then return 255, 255, 255 end
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.0, 0.35)
    local r, g, b = HexToRGB(CONFIG.colors.text)
    local a = CONFIG.alpha and CONFIG.alpha.targetText or 200
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, a)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function drawChaseUI(percent)
    local barX, barY = 0.5, 0.975
    local barW, barH = 0.20, 0.026
    local aBg = CONFIG.alpha and CONFIG.alpha.barBackground or 150
    DrawRect(barX, barY, barW, barH, 0, 0, 0, aBg)
    local r,g,b = 200, 0, 0
    local text = ""
    if not CONFIG.colors then CONFIG.colors = { bar = "#ff0000", ready = "#00ff00", text = "#ffffff" } end
    if percent >= 100.0 then
        if amIAllowed then r, g, b = HexToRGB(CONFIG.colors.ready); text = "SPIKES READY"
        else r, g, b = 150, 0, 0; text = "DEPLOYMENT DENIED" end
    else
        r, g, b = HexToRGB(CONFIG.colors.bar)
        if isMenuOpen then text = "CHASE: PREVIEW MODE"
        else text = (cachedTargetPlate ~= "") and ("CHASE: [" .. cachedTargetPlate .. "] " .. string.upper(cachedTargetName)) or ("CHASE: " .. string.upper(cachedTargetName)) end
    end
    local currentW = (percent / 100) * barW
    local aProg = CONFIG.alpha and CONFIG.alpha.barProgress or 180
    DrawRect(barX, barY, currentW, barH, r, g, b, aProg)
    local tr, tg, tb = HexToRGB(CONFIG.colors.text)
    local aTxt = CONFIG.alpha and CONFIG.alpha.barText or 200
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.32, 0.32)
    SetTextColour(tr, tg, tb, aTxt)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(barX, barY - 0.012)
end

function AttemptLockOn(myVeh)
    local offset = GetOffsetFromEntityInWorldCoords(myVeh, 0.0, 40.0, 0.0)
    local rayHandle = StartShapeTestCapsule(GetEntityCoords(myVeh), offset, 3.0, 10, myVeh, 7)
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
    if hit == 1 and IsEntityAVehicle(entityHit) then
        if GetVehicleClass(entityHit) == CONFIG.policeClass then ShowNotification("~r~Cannot lock on Police.") return end
        targetVeh = entityHit
        chaseProgress = 0.0
        lockOnStartTime = GetGameTimer() 
        local model = GetEntityModel(targetVeh)
        local rawName = GetLabelText(GetDisplayNameFromVehicleModel(model))
        cachedTargetName = (rawName == "NULL") and "VEHICLE" or rawName
        local rawPlate = GetVehicleNumberPlateText(targetVeh)
        cachedTargetPlate = rawPlate and rawPlate:gsub("^%s*(.-)%s*$", "%1") or ""
        ShowNotification("~r~TARGET LOCKED")
        PlaySoundFrontend(-1, "Hack_Success", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", true)
    else ShowNotification("~y~No target found.") end
end

function deploySpikes(veh, target)
    if target and DoesEntityExist(target) then
        if #(GetEntityCoords(veh) - GetEntityCoords(target)) < 8.0 then return false end
    end
    local spawnCoords = GetOffsetFromEntityInWorldCoords(veh, 0.0, -5.0, -0.2)
    local offS, offE = GetOffsetFromEntityInWorldCoords(veh, 0.0, -5.0, 0.5), GetOffsetFromEntityInWorldCoords(veh, 0.0, -5.0, -10.0)
    local rayHandle = StartShapeTestRay(offS.x, offS.y, offS.z, offE.x, offE.y, offE.z, 1, veh, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    local finalCoords = (hit == 1) and hitCoords or GetOffsetFromEntityInWorldCoords(veh, 0.0, -5.0, -0.5)
    if IsAnyVehicleNearPoint(finalCoords.x, finalCoords.y, finalCoords.z, 5.0) then return false end
    TriggerServerEvent('police:spawnSpikes', finalCoords, GetEntityHeading(veh) + 90.0)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    return true
end

function popTyres(veh)
    local tyres = {0, 1, 4, 5}
    for _, tyreId in ipairs(tyres) do SetVehicleTyreBurst(veh, tyreId, true, 1000.0) end
end
function ShowHelpNotification(msg) BeginTextCommandDisplayHelp("STRING") AddTextComponentSubstringPlayerName(msg) EndTextCommandDisplayHelp(0, false, true, -1) end
function ShowNotification(msg) SetNotificationTextEntry("STRING") AddTextComponentString(msg) DrawNotification(false, false) end