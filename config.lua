Config = Config or {}

Config.Evidence = {

    IncludeWeaponSerial = true,
    SerialNumberLength = 8,            -- Length of the serial ID for bullet casings.
    
    EvidenceExpireTime = 30,           -- Minutes.
    CollectDistance = 2.0,             -- Keep this low.
    
    EvidenceBagItem = 'evidence_bag',
    BulletCasingItem = 'casing',
    BloodSampleItem = 'blood_sample',
    
    DropChance = 100,                   -- Bullet casings.               
    BloodDropChance = 70,               -- Blood samples.
    
    MinBleedDamage = 15,                -- Minimum damage to activate a blood sample.
    BloodTypes = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"},
    
    BlacklistedWeapons = {
        `WEAPON_RAILGUN`,
        `WEAPON_STUNGUN`,
        `WEAPON_FIREEXTINGUISHER`,
        `WEAPON_PETROLCAN`,
        `WEAPON_HATCHET`,
        `WEAPON_BAT`,
        -- Additional weapons can be added here.
    }
}

Config.Notifications = {
    NoEvidenceBag = "You need an evidence bag to collect this",
    EvidenceCollected = "Evidence collected",
    BloodCollected = "Blood sample collected",
    EvidenceExpired = "Evidence has expired and is no longer collectable",
    NotPolice = "You're not authorized to collect evidence"
}

Config.DrawBlood = {
    Enabled = true,
    RequiredJobs = {
        ['police'] = 0,                -- Grade 0 and above can use.      
        ['ambulance'] = 2,             -- Grade 2 and above can use.  
        -- Add more jobs as needed.
    },
    RequiredItem = 'bloodkit',
    Animation = {
        dict = 'anim@gangops@facility@servers@',
        anim = 'hotwire',
        duration = 5000
    },
    Notifications = {
        Success = "Blood sample collected successfully",
        NoTarget = "No player nearby",
        NoPermission = "You don't have permission to use this command",
        NoItem = "You need a blood kit to draw blood",
        TargetResisted = "The player resisted the blood draw"
    }
}

Config.Debug = false                   -- Leave this false unless you know what you are doing.
