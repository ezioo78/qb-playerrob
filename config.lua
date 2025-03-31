Config = {}

-- General settings
Config.MinimumPolice = 0         -- Minimum police officers required for player robbery
Config.RobberyTimeout = 0--600      -- Time in seconds before a player can be robbed again (10 minutes)
Config.RobberyDuration = 0--30      -- Time in seconds the robbery lasts before auto-completing
Config.AllowAllItems = true      -- When true, allows robbing all items; when false, restricts to RobbableItems list

-- Weapons settings
Config.AllowAnyWeapon = true     -- When true, allows robbery with any weapon; when false, uses AllowedWeapons list
Config.AllowedWeapons = {        -- List of weapons that can be used for robbery when AllowAnyWeapon is false
    "weapon_pistol",
    "weapon_combatpistol", 
    "weapon_appistol",
    "weapon_pistol50",
    "weapon_snspistol", 
    "weapon_heavypistol",
    "weapon_vintagepistol",
    "weapon_revolver",
    "weapon_microsmg",
    "weapon_smg",
    "weapon_assaultsmg",
    "weapon_assaultrifle",
    "weapon_carbinerifle",
    "weapon_advancedrifle",
    "weapon_compactrifle",
    "weapon_mg",
    "weapon_combatmg",
    "weapon_pumpshotgun",
    "weapon_sawnoffshotgun",
    "weapon_assaultshotgun",
    "weapon_bullpupshotgun",
    "weapon_stungun",
    "weapon_sniperrifle",
    "weapon_heavysniper",
    "weapon_navyrevolver",
    "weapon_gusenberg",
    "weapon_knife",
    "weapon_dagger",
    "weapon_bat",
    "weapon_bottle",
    "weapon_crowbar",
    "weapon_knuckle",
    "weapon_machete",
    "weapon_switchblade"
}

-- Stash settings
Config.StashSlots = 30           -- Number of slots in the robbery stash
Config.StashWeight = 120000      -- Maximum weight for the robbery stash (set high to avoid restrictions)

-- Items that can be taken during a robbery (besides cash)
Config.RobbableItems = {
    "rolex",
    "goldchain",
    "diamond_ring",
    "cryptostick",
    "10kgoldchain",
    "tablet",
    "phone",
    "radio",
    "weed_white-widow",
    "weed_skunk",
    "weed_purple-haze",
    "cokebaggy",
    "meth",
    "weapon_combatpistol"
}

-- Chance settings
Config.SuccessChance = 85        -- Percentage chance of a successful robbery
Config.AlarmChance = 35          -- Percentage chance of alerting police automatically