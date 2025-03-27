local QBCore = exports['qb-core']:GetCoreObject()
local casings = {}
local bloods = {}
local nearbyEvidence = {}
local canCollect = false
local currentEvidence = nil
local evidenceType = nil
local flashlightEquipped = false
local flashlightActive = false

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local currentWeapon = GetSelectedPedWeapon(playerPed)

        flashlightEquipped = (currentWeapon == GetHashKey("WEAPON_FLASHLIGHT"))
        flashlightActive = flashlightEquipped and IsFlashLightOn(playerPed)
        
        Citizen.Wait(500)
    end
end)

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        nearbyEvidence = {}
        canCollect = false
        currentEvidence = nil
        evidenceType = nil
        
        if flashlightActive then
            for id, casing in pairs(casings) do
                local distance = #(playerCoords - casing.coords)
                if distance < 20.0 then
                    nearbyEvidence[id] = {type = 'casing', data = casing}
                    if distance < Config.Evidence.CollectDistance and not casing.collected then
                        canCollect = true
                        currentEvidence = id
                        evidenceType = 'casing'
                    end
                end
            end
            
            for id, blood in pairs(bloods) do
                local distance = #(playerCoords - blood.coords)
                if distance < 20.0 then
                    nearbyEvidence[id] = {type = 'blood', data = blood}
                    if distance < Config.Evidence.CollectDistance and not blood.collected then
                        canCollect = true
                        currentEvidence = id
                        evidenceType = 'blood'
                    end
                end
            end
            
            if Config.Debug then
                for id, evidence in pairs(nearbyEvidence) do
                    local color = evidence.type == 'casing' and {255, 255, 0} or {0, 0, 255}
                    DrawMarker(28, 
                        evidence.data.coords.x, 
                        evidence.data.coords.y, 
                        evidence.data.coords.z + 0.1, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                        0.1, 0.1, 0.1, 
                        color[1], color[2], color[3], 100, 
                        false, true, 2, nil, nil, false
                    )
                end
            end
        end
        
        Citizen.Wait(500)
    end
end)

Citizen.CreateThread(function()
    while true do
        if canCollect and currentEvidence and evidenceType and flashlightActive then
            local text = "[E] Collect " .. (evidenceType == 'casing' and "Casing" or "Blood Sample")
            local evidenceData = evidenceType == 'casing' and casings[currentEvidence] or bloods[currentEvidence]
            DrawText3D(
                evidenceData.coords.x, 
                evidenceData.coords.y, 
                evidenceData.coords.z + 0.2, 
                text
            )
            
            if IsControlJustReleased(0, 38) then
                if evidenceType == 'casing' then
                    TriggerServerEvent('evidence:collectCasing', currentEvidence)
                else
                    TriggerServerEvent('evidence:server:collectBlood', currentEvidence)
                end
                canCollect = false
                currentEvidence = nil
                evidenceType = nil
            end
        end
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        if IsPedShooting(playerPed) then
            local weapon = GetSelectedPedWeapon(playerPed)
            local isBlacklisted = false
            for _, blacklistedWeapon in ipairs(Config.Evidence.BlacklistedWeapons) do
                if weapon == blacklistedWeapon then
                    isBlacklisted = true
                    break
                end
            end
            
            if not isBlacklisted then
                if math.random(1, 100) <= Config.Evidence.DropChance then
                    local coords = GetEntityCoords(playerPed)
                    local forward = GetEntityForwardVector(playerPed)
                    local casingCoords = vector3(
                        coords.x + forward.x * 0.5,
                        coords.y + forward.y * 0.5,
                        coords.z - 0.9
                    )
                    
                    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
                        casingCoords.x, casingCoords.y, casingCoords.z + 1.0,
                        casingCoords.x, casingCoords.y, casingCoords.z - 1.0,
                        1, 0, 4
                    )
                    
                    local _, hit, hitCoords = GetShapeTestResult(rayHandle)
                    
                    if hit then
                        casingCoords = hitCoords
                    end
                    
                    TriggerServerEvent('evidence:createCasing', casingCoords, weapon)
                end
            end
        end
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local health = GetEntityHealth(playerPed)
        if health < 200 then
            local damage = 200 - health
            if damage >= Config.Evidence.MinBleedDamage then
                local coords = GetEntityCoords(playerPed)
                TriggerServerEvent('evidence:server:createBlood', coords, IsEntityDead(playerPed))
                Citizen.Wait(10000)
            end
        end
        Citizen.Wait(1000)
    end
end)

RegisterNetEvent('evidence:syncCasings')
AddEventHandler('evidence:syncCasings', function(casingData)
    casings = casingData
end)

RegisterNetEvent('evidence:addCasing')
AddEventHandler('evidence:addCasing', function(id, casing)
    casings[id] = casing
end)

RegisterNetEvent('evidence:removeCasing')
AddEventHandler('evidence:removeCasing', function(id)
    casings[id] = nil
end)

RegisterNetEvent('evidence:syncBlood')
AddEventHandler('evidence:syncBlood', function(bloodData)
    bloods = bloodData
end)

RegisterNetEvent('evidence:addBlood')
AddEventHandler('evidence:addBlood', function(id, blood)
    bloods[id] = blood
end)

RegisterNetEvent('evidence:removeBlood')
AddEventHandler('evidence:removeBlood', function(id)
    bloods[id] = nil
end)

RegisterNetEvent('evidence:client:checkBlood', function()
    QBCore.Functions.TriggerCallback('evidence:server:getNearbyBlood', function(results)
        if #results == 0 then
            QBCore.Functions.Notify("No blood evidence nearby", "error")
            return
        end
        
        local menu = {
            {
                header = "Nearby Blood Evidence",
                isMenuHeader = true
            }
        }
        
        for _, blood in ipairs(results) do
            table.insert(menu, {
                header = blood.name,
                txt = "Blood Type: "..blood.bloodType.." | "..(blood.isDead and "DECEASED" or "LIVING"),
                params = {
                    event = "evidence:client:viewBloodDetails",
                    args = blood
                }
            })
        end
        
        table.insert(menu, {
            header = "Close",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(menu)
    end, GetEntityCoords(PlayerPedId()), 5.0)
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('evidence:server:initBlood')
end)
