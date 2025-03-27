local QBCore = exports['qb-core']:GetCoreObject()

-- Evidence storage
local casings = {}
local bloods = {}
local evidenceCount = 0

-- Persistent data storage
local weaponSerials = {} -- citizenid:weaponName -> serial
local playerBloodTypes = {} -- citizenid -> bloodType

-- Configuration shortcuts
local Config = Config or {}
local EvidenceConfig = Config.Evidence or {}
local Notifications = Config.Notifications or {}

-- ========================
--  Database Initialization
-- ========================

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local citizenid = Player.PlayerData.citizenid
    exports.oxmysql:scalar('SELECT blood_type FROM players WHERE citizenid = ?', {citizenid}, function(bloodType)
        if bloodType then
            playerBloodTypes[citizenid] = bloodType
        else
            AssignNewBloodType(citizenid)
        end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Initialize database schema
    InitializeDatabase()
    
    -- Load existing data
    LoadBloodTypes()
    LoadWeaponSerials()
end)

function InitializeDatabase()
    -- Execute these queries separately
    exports.oxmysql:update([[
        ALTER TABLE players 
        ADD COLUMN IF NOT EXISTS blood_type VARCHAR(10) NULL
    ]], {}, function(success)
        if not success then
            print("Failed to add blood_type column to players table")
        end
    end)
    
    exports.oxmysql:update([[
        CREATE TABLE IF NOT EXISTS weapon_serials (
            citizenid VARCHAR(50) NOT NULL,
            weapon_name VARCHAR(50) NOT NULL,
            serial VARCHAR(20) NOT NULL,
            PRIMARY KEY (citizenid, weapon_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function(success)
        if not success then
            print("Failed to create weapon_serials table")
        end
    end)
    
    exports.oxmysql:update([[
        CREATE INDEX IF NOT EXISTS idx_weapon_serials_serial 
        ON weapon_serials (serial)
    ]], {}, function(success)
        if not success then
            print("Failed to create index on weapon_serials table")
        end
    end)
end

function LoadBloodTypes()
    exports.oxmysql:fetch('SELECT citizenid, blood_type FROM players WHERE blood_type IS NOT NULL', {}, function(results)
        for _, row in ipairs(results) do
            playerBloodTypes[row.citizenid] = row.blood_type
        end
    end)
end

function LoadWeaponSerials()
    exports.oxmysql:fetch('SELECT citizenid, weapon_name, serial FROM weapon_serials', {}, function(results)
        for _, row in ipairs(results) do
            weaponSerials[row.citizenid..":"..row.weapon_name] = row.serial
        end
    end)
end

-- ========================
--  Blood Type Management
-- ========================

function AssignNewBloodType(citizenid)
    local newBloodType = EvidenceConfig.BloodTypes[math.random(#EvidenceConfig.BloodTypes)]
    playerBloodTypes[citizenid] = newBloodType
    exports.oxmysql:update('UPDATE players SET blood_type = ? WHERE citizenid = ?', {newBloodType, citizenid})
    return newBloodType
end

function GetConsistentBloodType(citizenid)
    return playerBloodTypes[citizenid] or AssignNewBloodType(citizenid)
end

-- ========================
--  Weapon Serial Management
-- ========================

function GenerateSerialNumber(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local serial = ""
    for _ = 1, length do
        serial = serial .. chars:sub(math.random(#chars), math.random(#chars))
    end
    return serial
end

function GetWeaponConsistentSerial(src, weaponName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    
    local citizenid = Player.PlayerData.citizenid
    local key = citizenid..":"..weaponName
    
    if weaponSerials[key] then
        return weaponSerials[key]
    end
    
    exports.oxmysql:scalar('SELECT serial FROM weapon_serials WHERE citizenid = ? AND weapon_name = ?', 
        {citizenid, weaponName}, function(dbSerial)
            if dbSerial then
                weaponSerials[key] = dbSerial
            else
                local newSerial = GenerateSerialNumber(EvidenceConfig.SerialNumberLength)
                weaponSerials[key] = newSerial
                exports.oxmysql:insert('INSERT INTO weapon_serials (citizenid, weapon_name, serial) VALUES (?, ?, ?)', 
                    {citizenid, weaponName, newSerial})
            end
        end)
    
    return weaponSerials[key]
end

-- ========================
--  Evidence Creation
-- ========================

function CreateEvidence(idPrefix, data, storageTable, clientAddEvent, clientRemoveEvent)
    local evidenceId = idPrefix..evidenceCount
    evidenceCount = evidenceCount + 1
    
    storageTable[evidenceId] = data
    TriggerClientEvent(clientAddEvent, -1, evidenceId, data)
    
    SetTimeout(EvidenceConfig.EvidenceExpireTime * 60000, function()
        if storageTable[evidenceId] and not storageTable[evidenceId].collected then
            storageTable[evidenceId] = nil
            TriggerClientEvent(clientRemoveEvent, -1, evidenceId)
        end
    end)
    
    return evidenceId
end

RegisterNetEvent('evidence:createCasing', function(coords, weapon)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local weaponSerial = EvidenceConfig.IncludeWeaponSerial and GetWeaponConsistentSerial(src, weapon)
    
    CreateEvidence("casing_", {
        coords = coords,
        weapon = weapon,
        weaponSerial = weaponSerial,
        collected = false,
        createdAt = os.time(),
        createdBy = Player.PlayerData.citizenid
    }, casings, 'evidence:addCasing', 'evidence:removeCasing')
end)

RegisterNetEvent('evidence:server:createBlood', function(coords, isDead)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or math.random(100) > EvidenceConfig.BloodDropChance then return end
    
    CreateEvidence("blood_", {
        coords = coords,
        citizenid = Player.PlayerData.citizenid,
        name = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname,
        bloodType = GetConsistentBloodType(Player.PlayerData.citizenid),
        isDead = isDead or false,
        collected = false,
        createdAt = os.time()
    }, bloods, 'evidence:addBlood', 'evidence:removeBlood')
end)

-- ========================
--  Evidence Collection
-- ========================

function HasEvidenceBag(src)
    return exports.ox_inventory:GetItem(src, EvidenceConfig.EvidenceBagItem, nil, false)
end

RegisterNetEvent('evidence:collectCasing', function(casingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local casing = casings[casingId]
    
    if not Player or not casing or casing.collected or not HasEvidenceBag(src) then
        TriggerClientEvent('QBCore:Notify', src, Notifications.NoEvidenceBag, 'error')
        return
    end
    
    local weaponName = QBCore.Shared.Weapons[casing.weapon]?.label or "Unknown Weapon"
    local description = casing.weaponSerial and 
        ("Bullet casing from %s (Serial: %s)"):format(weaponName, casing.weaponSerial) or
        "A spent bullet casing"
    
    casing.collected = true
    casing.collectedBy = Player.PlayerData.citizenid
    casing.collectedAt = os.time()
    
    if Player.Functions.AddItem(EvidenceConfig.BulletCasingItem, 1, nil, {
        serial = casing.weaponSerial,
        weapon = casing.weapon,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid
    }, description) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[EvidenceConfig.BulletCasingItem], "add")
        TriggerClientEvent('QBCore:Notify', src, Notifications.EvidenceCollected, 'success')
        TriggerClientEvent('evidence:removeCasing', -1, casingId)
    end
end)

RegisterNetEvent('evidence:server:collectBlood', function(bloodId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local blood = bloods[bloodId]
    
    if not Player or not blood or blood.collected or not HasEvidenceBag(src) then
        TriggerClientEvent('QBCore:Notify', src, Notifications.NoEvidenceBag, 'error')
        return
    end
    
    local charinfo = Player.PlayerData.charinfo or {}
    blood.collected = true
    blood.collectedBy = Player.PlayerData.citizenid
    blood.collectedAt = os.time()
    
    if exports.ox_inventory:AddItem(src, EvidenceConfig.BloodSampleItem, 1, {
        donorCitizenid = blood.citizenid,
        donorName = blood.name,
        bloodType = blood.bloodType,
        isDead = blood.isDead,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid,
        collectedByName = charinfo.firstname and (charinfo.firstname.." "..(charinfo.lastname or "")) or "Unknown Officer",
        description = ("Blood sample from %s (ID: %s) | Type: %s | Status: %s"):format(
            blood.name, blood.citizenid, blood.bloodType, blood.isDead and "DECEASED" or "LIVING")
    }) then
        TriggerClientEvent('QBCore:Notify', src, Notifications.BloodCollected, 'success')
        TriggerClientEvent('evidence:removeBlood', -1, bloodId)
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to collect blood sample", 'error')
    end
end)

-- ========================
--  Commands & Sync
-- ========================

local function IsPolice(player)
    return player.PlayerData.job.name == 'police'
end

QBCore.Commands.Add("checkevidence", "Check nearby evidence", {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if IsPolice(Player) then
        TriggerClientEvent('evidence:requestNearby', source)
    else
        TriggerClientEvent('QBCore:Notify', source, Notifications.NotPolice, 'error')
    end
end)

QBCore.Commands.Add("checkblood", "Check nearby blood evidence", {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if IsPolice(Player) then
        TriggerClientEvent('evidence:client:checkBlood', source)
    else
        TriggerClientEvent('QBCore:Notify', source, Notifications.NotPolice, 'error')
    end
end)

RegisterNetEvent('evidence:requestSync', function()
    local src = source
    TriggerClientEvent('evidence:syncCasings', src, casings)
    TriggerClientEvent('evidence:syncBlood', src, bloods)
end)

-- ========================
--  Draw Blood Functions
-- ========================

QBCore.Functions.CreateCallback('evidence:server:canDrawBlood', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    for jobName, minGrade in pairs(Config.DrawBlood.RequiredJobs) do
        if Player.PlayerData.job.name == jobName and Player.PlayerData.job.grade.level >= minGrade then
            return cb(true)
        end
    end
    
    cb(false)
end)

RegisterNetEvent('evidence:server:drawBlood', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not Target then return end
    
    local hasPermission = false
    for jobName, minGrade in pairs(Config.DrawBlood.RequiredJobs) do
        if Player.PlayerData.job.name == jobName and Player.PlayerData.job.grade.level >= minGrade then
            hasPermission = true
            break
        end
    end
    
    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', src, Config.DrawBlood.Notifications.NoPermission, 'error')
        return
    end
    
    if not exports['ox_inventory']:GetItem(src, Config.DrawBlood.RequiredItem, nil, false) then
        TriggerClientEvent('QBCore:Notify', src, Config.DrawBlood.Notifications.NoItem, 'error')
        return
    end
    
    if math.random(1, 100) <= 10 then
        TriggerClientEvent('QBCore:Notify', src, Config.DrawBlood.Notifications.TargetResisted, 'error')
        TriggerClientEvent('QBCore:Notify', targetId, "You resisted the blood draw", 'success')
        return
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local targetCharinfo = Target.PlayerData.charinfo or {}
    
    local metadata = {
        donorCitizenid = Target.PlayerData.citizenid,
        donorName = targetCharinfo.firstname.." "..targetCharinfo.lastname,
        bloodType = GetConsistentBloodType(Target.PlayerData.citizenid),
        isDead = false,
        collectedAt = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        collectedBy = Player.PlayerData.citizenid,
        collectedByName = charinfo.firstname.." "..charinfo.lastname,
        description = ("Blood sample from %s (ID: %s) | Type: %s | Status: LIVING"):format(
            targetCharinfo.firstname.." "..targetCharinfo.lastname,
            Target.PlayerData.citizenid,
            GetConsistentBloodType(Target.PlayerData.citizenid))
    }
    
    if exports['ox_inventory']:AddItem(src, Config.Evidence.BloodSampleItem, 1, metadata) then
        TriggerClientEvent('QBCore:Notify', src, Config.DrawBlood.Notifications.Success, 'success')
        TriggerClientEvent('QBCore:Notify', targetId, "A blood sample was taken from you", 'primary')
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to collect blood sample", 'error')
    end
end)

QBCore.Commands.Add("drawblood", "Draw blood from a nearby player", {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local hasPermission = false
    for jobName, minGrade in pairs(Config.DrawBlood.RequiredJobs) do
        if Player.PlayerData.job.name == jobName and Player.PlayerData.job.grade.level >= minGrade then
            hasPermission = true
            break
        end
    end
    
    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, Config.DrawBlood.Notifications.NoPermission, 'error')
        return
    end
    
    if not exports['ox_inventory']:GetItem(source, Config.DrawBlood.RequiredItem, nil, false) then
        TriggerClientEvent('QBCore:Notify', source, Config.DrawBlood.Notifications.NoItem, 'error')
        return
    end
    
    TriggerClientEvent('evidence:client:drawBlood', source)
end)
