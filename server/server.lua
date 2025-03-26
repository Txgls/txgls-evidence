local QBCore = exports['qb-core']:GetCoreObject()
local casings = {}
local bloods = {}
local evidenceCount = 0
local weaponSerialMap = {}

local function GetRandomBloodType()
    return Config.Evidence.BloodTypes[math.random(#Config.Evidence.BloodTypes)]
end

local function GenerateSerialNumber(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local serial = ""
    for i = 1, length do
        local rand = math.random(#chars)
        serial = serial .. chars:sub(rand, rand)
    end
    return serial
end

local function GetWeaponConsistentSerial(src, weaponName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local weaponKey = Player.PlayerData.citizenid .. ":" .. weaponName
    if weaponSerialMap[weaponKey] then
        return weaponSerialMap[weaponKey]
    end
    local serial = GenerateSerialNumber(Config.Evidence.SerialNumberLength)
    weaponSerialMap[weaponKey] = serial
    return serial
end

RegisterNetEvent('evidence:createCasing', function(coords, weapon)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    evidenceCount = evidenceCount + 1
    local casingId = "casing_"..evidenceCount
    local weaponSerial = Config.Evidence.IncludeWeaponSerial and GetWeaponConsistentSerial(src, weapon) or nil
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

RegisterNetEvent('evidence:server:createBlood', function(coords, isDead)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or math.random(100) > Config.Evidence.BloodDropChance then return end
    evidenceCount = evidenceCount + 1
    local bloodId = "blood_"..evidenceCount
    local bloodType = GetRandomBloodType()
    bloods[bloodId] = {
        id = bloodId,
        coords = coords,
        citizenid = Player.PlayerData.citizenid,
        name = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname,
        bloodType = bloodType,
        isDead = isDead or false,
        collected = false,
        createdAt = os.time()
    }
    TriggerClientEvent('evidence:addBlood', -1, bloodId, bloods[bloodId])
    SetTimeout(Config.Evidence.EvidenceExpireTime * 60000, function()
        if bloods[bloodId] and not bloods[bloodId].collected then
            bloods[bloodId] = nil
            TriggerClientEvent('evidence:removeBlood', -1, bloodId)
        end
    end)
end)

RegisterNetEvent('evidence:collectCasing', function(casingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not casings[casingId] or casings[casingId].collected then return end
    if not Player.Functions.GetItemByName(Config.Evidence.EvidenceBagItem) then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoEvidenceBag, 'error')
        return
    end
    local weaponName = "Unknown Weapon"
    if QBCore.Shared.Weapons[casings[casingId].weapon] then
        weaponName = QBCore.Shared.Weapons[casings[casingId].weapon].label or weaponName
    end
    local info = {
        serial = casings[casingId].weaponSerial,
        weapon = casings[casingId].weapon,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid
    }
    local description = casings[casingId].weaponSerial and 
        string.format("Bullet casing from %s (Serial: %s)", weaponName, casings[casingId].weaponSerial) or
        "A spent bullet casing"
    casings[casingId].collected = true
    casings[casingId].collectedBy = Player.PlayerData.citizenid
    casings[casingId].collectedAt = os.time()
    if Player.Functions.AddItem(Config.Evidence.BulletCasingItem, 1, nil, info, description) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Evidence.BulletCasingItem], "add")
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.EvidenceCollected, 'success')
        TriggerClientEvent('evidence:removeCasing', -1, casingId)
    end
end)

RegisterNetEvent('evidence:server:collectBlood', function(bloodId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not bloods[bloodId] or bloods[bloodId].collected then return end
    if not exports.ox_inventory:GetItem(src, Config.Evidence.EvidenceBagItem, nil, false) then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoEvidenceBag, 'error')
        return
    end
    local charinfo = Player.PlayerData.charinfo or {}
    local bloodData = bloods[bloodId]
    local metadata = {
        donorCitizenid = bloodData.citizenid or "UNKNOWN",
        donorName = bloodData.name or "Unknown Subject",
        bloodType = bloodData.bloodType or "UNK",
        isDead = bloodData.isDead == true,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid,
        collectedByName = charinfo.firstname and (charinfo.firstname.." "..(charinfo.lastname or "")) or "Unknown Officer",
        description = ("Blood sample from %s (ID: %s) | Type: %s | Status: %s"):format(
            bloodData.name or "Unknown",
            bloodData.citizenid or "UNKNOWN",
            bloodData.bloodType or "UNK",
            bloodData.isDead and "DECEASED" or "LIVING"
        )
    }
    bloods[bloodId].collected = true
    bloods[bloodId].collectedBy = Player.PlayerData.citizenid
    bloods[bloodId].collectedAt = os.time()
    if exports.ox_inventory:AddItem(src, Config.Evidence.BloodSampleItem, 1, metadata) then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.BloodCollected, 'success')
        TriggerClientEvent('evidence:removeBlood', -1, bloodId)
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to collect blood sample", 'error')
    end
end)

QBCore.Commands.Add("checkevidence", "Check nearby evidence", {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('evidence:requestNearby', src)
    else
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NotPolice, 'error')
    end
end)

QBCore.Commands.Add("checkblood", "Check nearby blood evidence", {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('evidence:client:checkBlood', src)
    else
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NotPolice, 'error')
    end
end)

RegisterNetEvent('evidence:requestSync', function()
    local src = source
    TriggerClientEvent('evidence:syncCasings', src, casings)
    TriggerClientEvent('evidence:syncBlood', src, bloods)
end)

QBCore.Commands.Add('testblood', 'Test blood sample', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local info = {
        donorCitizenid = 'TEST'..math.random(1000,9999),
        donorName = "Test Subject",
        bloodType = "O+",
        isDead = false,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S"),
        collectedBy = Player.PlayerData.citizenid,
        collectedByName = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
    }
    local description = ("Blood sample from %s | Type: %s | Status: %s"):format(
        info.donorName,
        info.bloodType,
        info.isDead and "DECEASED" or "LIVING"
    )
    if Player.Functions.AddItem('blood_sample', 1, nil, info, description) then
        TriggerClientEvent('QBCore:Notify', src, 'Test blood sample added', 'success')
    end
end, 'admin')
