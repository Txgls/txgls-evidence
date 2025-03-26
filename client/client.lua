local casings = {}
local nearbyCasings = {}
local canCollect = false
local currentCasing = nil

-- Thread to handle casing collection
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        nearbyCasings = {}
        
        -- Check nearby casings
        for id, casing in pairs(casings) do
            local distance = #(playerCoords - casing.coords)
            
            if distance < 20.0 then
                nearbyCasings[id] = casing
                
                if distance < Config.Evidence.CollectDistance and not casing.collected then
                    canCollect = true
                    currentCasing = id
                end
            end
        end
        
        -- Draw markers if debug enabled
        if Config.Debug then
            for id, casing in pairs(nearbyCasings) do
                DrawMarker(28, casing.coords.x, casing.coords.y, casing.coords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 255, 0, 0, 100, false, true, 2, nil, nil, false)
            end
        end
        
        Citizen.Wait(500)
    end
end)

-- Handle key press to collect evidence
Citizen.CreateThread(function()
    while true do
        if canCollect and currentCasing then
            local text = "[E] Collect Evidence"
            if Config.Debug then
                text = text .. " (ID: "..currentCasing..")"
            end
            
            DrawText3D(casings[currentCasing].coords.x, casings[currentCasing].coords.y, casings[currentCasing].coords.z + 0.2, text)
            
            if IsControlJustReleased(0, 38) then -- E key
                TriggerServerEvent('evidence:collectCasing', currentCasing)
                canCollect = false
                currentCasing = nil
            end
        end
        Citizen.Wait(0)
    end
end)

-- Listen for weapon fired event
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        
        if IsPedShooting(playerPed) then
            local weapon = GetSelectedPedWeapon(playerPed)
            
            -- Check if weapon is blacklisted
            local isBlacklisted = false
            for _, blacklistedWeapon in ipairs(Config.Evidence.BlacklistedWeapons) do
                if weapon == blacklistedWeapon then
                    isBlacklisted = true
                    break
                end
            end
            
            if not isBlacklisted then
                -- Random chance to drop casing
                if math.random(1, 100) <= Config.Evidence.DropChance then
                    local coords = GetEntityCoords(playerPed)
                    local forward = GetEntityForwardVector(playerPed)
                    local casingCoords = vector3(
                        coords.x + forward.x * 0.5,
                        coords.y + forward.y * 0.5,
                        coords.z - 0.9
                    )
                    
                    -- Raycast to ground
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

-- Sync casings from server
RegisterNetEvent('evidence:syncCasings')
AddEventHandler('evidence:syncCasings', function(casingData)
    casings = casingData
end)

-- Add single casing
RegisterNetEvent('evidence:addCasing')
AddEventHandler('evidence:addCasing', function(id, casing)
    casings[id] = casing
end)

-- Remove casing
RegisterNetEvent('evidence:removeCasing')
AddEventHandler('evidence:removeCasing', function(id)
    casings[id] = nil
end)

-- Draw 3D text
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
