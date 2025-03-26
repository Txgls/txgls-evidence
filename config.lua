Config = Config or {}

Config.Evidence = {

    IncludeWeaponSerial = true,     -- Include or to not include unique serial IDs to casings.
    SerialNumberLength = 8,         -- Length of the serial ID.
    EvidenceExpireTime = 30,        -- Minutes
    
    CollectDistance = 2.0,
    EvidenceBagItem = 'evidence_bag',
    BulletCasingItem = 'casing',
    DropChance = 85,
    
    BlacklistedWeapons = {
        `WEAPON_RAILGUN`,
        `WEAPON_STUNGUN`,
        `WEAPON_FIREEXTINGUISHER`,
        `WEAPON_PETROLCAN`,
        `WEAPON_HATCHET`,
        `WEAPON_BAT`
    }
}

Config.Notifications = {
    NoEvidenceBag = "You need an evidence bag to collect this!",
    EvidenceCollected = "Evidence collected!",
    EvidenceExpired = "Evidence has expired and is no longer collectable!"
}

Config.Debug = false
