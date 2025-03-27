local QBCore = exports['qb-core']:GetCoreObject()

-- Evidence storage
local casings = {}
local bloods = {}

-- Local state
local nearbyEvidence = {}
local canCollect = false
local currentEvidence = nil
local evidenceType = nil
local flashlightState = {
    equipped = false,
    active = false
}

-- Configuration shortcuts
local Config = Config or {}
local EvidenceConfig = Config.Evidence or {}

-- ========================
--  Flashlight Management
-- ========================

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local currentWeapon = GetSelectedPedWeapon(playerPed)
        
        flashlightState.equipped = (currentWeapon == GetHashKey("WEAPON_FLASHLIGHT"))
        flashlightState.active = flashlightState.equipped and IsFlashLightOn(playerPed)
        
        Citizen.Wait(500)
    end
end)

-- ========================
--  Evidence Detection
-- ========================

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        nearbyEvidence = {}
        canCollect = false
        currentEvidence = nil
        evidenceType = nil
        
        if flashlightState.active then
            CheckNearbyEvidence(playerCoords)
            
            if EvidenceConfig.Debug then
                DrawDebugMarkers()
            end
        end
        
        Citizen.Wait(500)
    end
end)

function CheckNearbyEvidence(coords)
    -- Check casings
    for id, casing in pairs(casings) do
        local distance = #(coords - casing.coords)
        if distance < 20.0 then
            nearbyEvidence[id] = {type = 'casing', data = casing}
            if distance < EvidenceConfig.CollectDistance and not casing.collected then
                canCollect = true
                currentEvidence = id
                evidenceType = 'casing'
            end
        end
    end
    
    -- Check blood
    for id, blood in pairs(bloods) do
        local distance = #(coords - blood.coords)
        if distance < 20.0 then
            nearbyEvidence[id] = {type = 'blood', data = blood}
            if distance < EvidenceConfig.CollectDistance and not blood.collected then
                canCollect = true
                currentEvidence = id
                evidenceType = 'blood'
            end
        end
    end
end

function DrawDebugMarkers()
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

-- ========================
--  Evidence Collection
-- ========================

Citizen.CreateThread(function()
    while true do
        if canCollect and currentEvidence and evidenceType and flashlightState.active then
            HandleEvidenceCollection()
        end
        Citizen.Wait(0)
    end
end)

function HandleEvidenceCollection()
    local evidenceData = evidenceType == 'casing' and casings[currentEvidence] or bloods[currentEvidence]
    local text = "[E] Collect " .. (evidenceType == 'casing' and "Casing" or "Blood Sample")
    
    DrawText3D(
        evidenceData.coords.x, 
        evidenceData.coords.y, 
        evidenceData.coords.z + 0.2, 
        text
    )
    
    if IsControlJustReleased(0, 38) then
        CollectEvidence()
    end
end

function CollectEvidence()
    if evidenceType == 'casing' then
        TriggerServerEvent('evidence:collectCasing', currentEvidence)
    else
        TriggerServerEvent('evidence:server:collectBlood', currentEvidence)
    end
    
    -- Reset collection state
    canCollect = false
    currentEvidence = nil
    evidenceType = nil
end

-- ========================
--  Evidence Creation
-- ========================

-- Casing creation from shooting
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        if IsPedShooting(playerPed) then
            HandleBulletCasing(playerPed)
        end
        Citizen.Wait(0)
    end
end)

function HandleBulletCasing(playerPed)
    local weapon = GetSelectedPedWeapon(playerPed)
    
    if IsWeaponBlacklisted(weapon) then return end
    
    if math.random(1, 100) <= EvidenceConfig.DropChance then
        local coords = GetEntityCoords(playerPed)
        local forward = GetEntityForwardVector(playerPed)
        local casingCoords = vector3(
            coords.x + forward.x * 0.5,
            coords.y + forward.y * 0.5,
            coords.z - 0.9
        )
        
        -- Raycast to find ground position
        local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
            casingCoords.x, casingCoords.y, casingCoords.z + 1.0,
            casingCoords.x, casingCoords.y, casingCoords.z - 1.0,
            1, 0, 4
        )
        
        local _, hit, hitCoords = GetShapeTestResult(rayHandle)
        
        TriggerServerEvent('evidence:createCasing', hit and hitCoords or casingCoords, weapon)
    end
end

function IsWeaponBlacklisted(weapon)
    for _, blacklistedWeapon in ipairs(EvidenceConfig.BlacklistedWeapons) do
        if weapon == blacklistedWeapon then
            return true
        end
    end
    return false
end

-- Blood creation from damage
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local health = GetEntityHealth(playerPed)
        
        if health < 200 then
            local damage = 200 - health
            if damage >= EvidenceConfig.MinBleedDamage then
                TriggerServerEvent('evidence:server:createBlood', GetEntityCoords(playerPed), IsEntityDead(playerPed))
                Citizen.Wait(10000) -- Prevent rapid blood creation
            end
        end
        Citizen.Wait(1000)
    end
end)

-- ========================
--  Evidence Sync Handlers
-- ========================

RegisterNetEvent('evidence:syncCasings', function(casingData)
    casings = casingData
end)

RegisterNetEvent('evidence:addCasing', function(id, casing)
    casings[id] = casing
end)

RegisterNetEvent('evidence:removeCasing', function(id)
    casings[id] = nil
end)

RegisterNetEvent('evidence:syncBlood', function(bloodData)
    bloods = bloodData
end)

RegisterNetEvent('evidence:addBlood', function(id, blood)
    bloods[id] = blood
end)

RegisterNetEvent('evidence:removeBlood', function(id)
    bloods[id] = nil
end)

-- ========================
--  Blood Evidence Menu
-- ========================

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

-- ========================
--  Utility Functions
-- ========================

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

-- ========================
--  Player Load Handler
-- ========================

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('evidence:server:initBlood')
end)

-- ========================
--  Draw Blood Command
-- ========================

RegisterCommand('drawblood', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    QBCore.Functions.TriggerCallback('evidence:server:canDrawBlood', function(canDraw)
        if not canDraw then
            QBCore.Functions.Notify(Config.DrawBlood.Notifications.NoPermission, 'error')
            return
        end
        
        if not HasBloodKit() then
            QBCore.Functions.Notify(Config.DrawBlood.Notifications.NoItem, 'error')
            return
        end
        
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player == -1 or distance > 2.5 then
            QBCore.Functions.Notify(Config.DrawBlood.Notifications.NoTarget, 'error')
            return
        end
        
        local targetPed = GetPlayerPed(player)
        
        RequestAnimDict(Config.DrawBlood.Animation.dict)
        while not HasAnimDictLoaded(Config.DrawBlood.Animation.dict) do
            Citizen.Wait(0)
        end
        
        TaskPlayAnim(playerPed, Config.DrawBlood.Animation.dict, Config.DrawBlood.Animation.anim, 
                    8.0, -8.0, Config.DrawBlood.Animation.duration, 33, 0, false, false, false)
        
        QBCore.Functions.Progressbar("drawing_blood", "Drawing blood sample...", 
            Config.DrawBlood.Animation.duration, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function()
                ClearPedTasks(playerPed)
                TriggerServerEvent('evidence:server:drawBlood', GetPlayerServerId(player))
            end, function()
                ClearPedTasks(playerPed)
                QBCore.Functions.Notify("Cancelled", "error")
            end)
    end)
end, false)

function HasBloodKit()
    return exports['ox_inventory']:Search('count', Config.DrawBlood.RequiredItem) > 0
end
