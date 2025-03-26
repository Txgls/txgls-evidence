local QBCore = exports['qb-core']:GetCoreObject()
local casings = {}
local casingCount = 0
local weaponSerialMap = {} -- This will store generated serials for each weapon instance


local function GenerateSerialNumber(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local serial = ""
    for i = 1, length do
        local rand = math.random(#chars)
        serial = serial .. chars:sub(rand, rand)
    end
    return serial
end

-- Function to get or generate a consistent serial for a specific weapon
local function GetWeaponConsistentSerial(src, weaponName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    
    -- Generate a unique key for this weapon instance
    local weaponKey = Player.PlayerData.citizenid .. ":" .. weaponName
    
    -- If we already have a serial for this weapon, return it
    if weaponSerialMap[weaponKey] then
        return weaponSerialMap[weaponKey]
    end
    
    -- Otherwise generate a new serial and store it
    local serial = GenerateSerialNumber(Config.Evidence.SerialNumberLength)
    weaponSerialMap[weaponKey] = serial
    return serial
end

-- Function to generate random serial number

-- Create new casing with consistent serial for the same weapon
RegisterNetEvent('evidence:createCasing', function(coords, weapon)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    casingCount = casingCount + 1
    local casingId = casingCount
    
    -- Get consistent serial for this weapon instance
    local weaponSerial = nil
    if Config.Evidence.IncludeWeaponSerial then
        weaponSerial = GetWeaponConsistentSerial(src, weapon)
    end
    
    casings[casingId] = {
        id = casingId,
        coords = coords,
        weapon = weapon,
        weaponSerial = weaponSerial,
        collected = false,
        createdAt = os.time(),
        createdBy = Player.PlayerData.citizenid
    }
    
    TriggerClientEvent('evidence:addCasing', -1, casingId, casings[casingId])
    
    SetTimeout(Config.Evidence.EvidenceExpireTime * 60000, function()
        if casings[casingId] and not casings[casingId].collected then
            casings[casingId] = nil
            TriggerClientEvent('evidence:removeCasing', -1, casingId)
        end
    end)
end)

-- Rest of your existing code remains the same...
RegisterNetEvent('evidence:collectCasing', function(casingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not casings[casingId] or casings[casingId].collected then return end
    
    if not Player.Functions.GetItemByName(Config.Evidence.EvidenceBagItem) then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoEvidenceBag, 'error')
        return
    end
    
    local description = "A spent bullet casing"
    if casings[casingId].weaponSerial then
        local weaponName = "Unknown Weapon"
        if QBCore.Shared.Weapons[casings[casingId].weapon] then
            weaponName = QBCore.Shared.Weapons[casings[casingId].weapon].label or weaponName
        end
        description = string.format("Bullet casing from %s (Serial: %s)", weaponName, casings[casingId].weaponSerial)
    end
    
    casings[casingId].collected = true
    casings[casingId].collectedBy = Player.PlayerData.citizenid
    casings[casingId].collectedAt = os.time()
    
    local info = {
        serial = casings[casingId].weaponSerial,
        weapon = casings[casingId].weapon,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid
    }
    
    Player.Functions.AddItem(Config.Evidence.BulletCasingItem, 1, nil, info, description)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Evidence.BulletCasingItem], "add")
    
    TriggerClientEvent('QBCore:Notify', src, Config.Notifications.EvidenceCollected, 'success')
    TriggerClientEvent('evidence:removeCasing', -1, casingId)
end)

QBCore.Commands.Add("checkevidence", "Check for nearby evidence", {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('evidence:requestNearby', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You're not a police officer!", 'error')
    end
end)
