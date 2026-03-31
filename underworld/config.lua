Config = {}

-- ============================================================
-- ORGANIZATION TYPES
-- ============================================================
Config.OrgTypes = {
    legal = {
        label       = 'Corporation',
        color       = '#2196F3',
        canLaunder  = false,
        heatMult    = 0.0,
        incomeMult  = 0.8,
        missions    = { 'delivery', 'vip_transport', 'inspection', 'negotiation' }
    },
    illegal = {
        label       = 'Organization',
        color       = '#F44336',
        canLaunder  = true,
        heatMult    = 1.0,
        incomeMult  = 1.2,
        missions    = { 'supply_run', 'debt_collection', 'patrol', 'dirty_work' }
    },
    family = {
        label       = 'Family',
        color       = '#9C27B0',
        canLaunder  = true,
        heatMult    = 0.5,
        incomeMult  = 1.0,
        missions    = { 'delivery', 'supply_run', 'debt_collection', 'vip_transport' }
    }
}

-- ============================================================
-- OFFICE TIERS
-- ============================================================
Config.Tiers = {
    [1] = {
        label              = 'Street',
        price              = 500000,
        maxMembers         = 10,
        maxDailyPassive    = 50000,
        missionsRequired   = 3,
        missionReward      = { min = 5000,  max = 15000 }
    },
    [2] = {
        label              = 'Established',
        price              = 2000000,
        maxMembers         = 25,
        maxDailyPassive    = 200000,
        missionsRequired   = 5,
        missionReward      = { min = 10000, max = 35000 }
    },
    [3] = {
        label              = 'Syndicate',
        price              = 10000000,
        maxMembers         = 50,
        maxDailyPassive    = 500000,
        missionsRequired   = 8,
        missionReward      = { min = 25000, max = 75000 }
    },
    [4] = {
        label              = 'Empire',
        price              = 70000000,
        maxMembers         = 100,
        maxDailyPassive    = 1000000,
        missionsRequired   = 12,
        missionReward      = { min = 50000, max = 150000 }
    }
}

-- ============================================================
-- RANKS
-- ============================================================
Config.Ranks = {
    [1] = { name = 'Associé',       canWithdraw = false, canAssignJobs = false, dailyWithdraw = 0         },
    [2] = { name = 'Soldat',        canWithdraw = true,  canAssignJobs = false, dailyWithdraw = 10000     },
    [3] = { name = 'Kapten',        canWithdraw = true,  canAssignJobs = true,  dailyWithdraw = 50000     },
    [4] = { name = 'Underdirektör', canWithdraw = true,  canAssignJobs = true,  dailyWithdraw = 200000    },
    [5] = { name = 'Direktör',      canWithdraw = true,  canAssignJobs = true,  dailyWithdraw = 999999999 }
}

-- ============================================================
-- MISSION TYPES
-- ============================================================
Config.Missions = {
    supply_run = {
        label       = 'Supply Run',
        description = 'Pick up supplies from the source and deliver them to the stash.',
        duration    = 15,
        minRank     = 2,
        rewardMult  = 1.0,
        skillCheck  = { 'easy', 'easy' },
        heatGain    = 5
    },
    debt_collection = {
        label       = 'Debt Collection',
        description = 'Locate the target and collect what is owed. Do not leave empty-handed.',
        duration    = 20,
        minRank     = 2,
        rewardMult  = 1.2,
        skillCheck  = { 'easy', 'medium' },
        heatGain    = 8
    },
    patrol = {
        label       = 'Territory Patrol',
        description = 'Hold the designated zone for the required time. Report any intrusions.',
        duration    = 10,
        minRank     = 2,
        rewardMult  = 0.8,
        skillCheck  = {},
        heatGain    = 5
    },
    dirty_work = {
        label       = 'Dirty Work',
        description = 'Eliminate the target. Clean job. No witnesses.',
        duration    = 25,
        minRank     = 3,
        rewardMult  = 1.5,
        skillCheck  = { 'medium', 'medium' },
        heatGain    = 12
    },
    delivery = {
        label       = 'Contract Delivery',
        description = 'Deliver the cargo to the client on time. Do not attract attention.',
        duration    = 15,
        minRank     = 2,
        rewardMult  = 1.0,
        skillCheck  = { 'easy' },
        heatGain    = 0
    },
    vip_transport = {
        label       = 'VIP Transport',
        description = 'Transport the VIP safely to the destination. Any incident is on you.',
        duration    = 20,
        minRank     = 2,
        rewardMult  = 1.1,
        skillCheck  = { 'easy', 'easy' },
        heatGain    = 0
    },
    inspection = {
        label       = 'Site Inspection',
        description = 'Visit all designated sites and submit the inspection report.',
        duration    = 12,
        minRank     = 2,
        rewardMult  = 0.9,
        skillCheck  = {},
        heatGain    = 0
    },
    negotiation = {
        label       = 'Business Negotiation',
        description = 'Meet the contact at the location and close the deal.',
        duration    = 15,
        minRank     = 3,
        rewardMult  = 1.0,
        skillCheck  = { 'medium' },
        heatGain    = 0
    }
}

-- ============================================================
-- MISSION LOCATIONS
-- ============================================================
Config.MissionLocations = {
    pickups = {
        vector3(892.68,   -2025.55,  30.43),
        vector3(1701.45,   3762.55,  34.55),
        vector3(-1464.26,  4552.80,  20.49),
        vector3(2550.73,   2600.68,  37.94),
        vector3(-73.49,   -1768.61,  29.42),
        vector3(1383.89,   1148.42, 114.33),
        vector3(-2230.35,   264.25, 173.91),
        vector3(427.71,   -1948.05,  27.11)
    },
    deliveries = {
        vector3(108.79,  -1963.93,  20.70),
        vector3(1961.44,  3741.89,  32.34),
        vector3(-1604.97, 5163.78,  21.19),
        vector3(2640.83,  1661.45,  25.76),
        vector3(-694.96,  -933.53,  19.22),
        vector3(1705.10,  6415.36,  32.24),
        vector3(-3035.04,   585.43,   7.91),
        vector3(376.04,  -1650.27,  29.29)
    }
}

-- ============================================================
-- OFFICE TERMINAL LOCATIONS
-- ============================================================
Config.OfficeLocations = {
    { coords = vector4(440.67,  -985.66, 30.69, 0.0),   label = 'Downtown Office'  },
    { coords = vector4(-1038.93, -236.23, 37.76, 0.0),  label = 'West Vinewood'    },
    { coords = vector4(136.96,  -818.18, 31.35, 0.0),   label = 'City Hall Area'   },
}

-- ============================================================
-- TIMERS
-- ============================================================
Config.PassiveTickMinutes = 60   -- How often passive income is paid out
Config.SalaryDayOfWeek   = 1    -- 1 = Monday. Salaries paid weekly on this day.

-- ============================================================
-- ORG LEVEL PROGRESSION
-- ============================================================
Config.LevelThresholds = {
    [1]  = 0,
    [2]  = 500,
    [3]  = 1500,
    [4]  = 3500,
    [5]  = 7500,
    [6]  = 15000,
    [7]  = 30000,
    [8]  = 60000,
    [9]  = 100000,
    [10] = 200000
}

Config.XPGains = {
    mission_complete = 50,
    passive_tick     = 10,
    new_member       = 25
}

-- What each level unlocks (displayed in UI, enforced in code)
Config.LevelUnlocks = {
    [2]  = 'Harder missions unlocked',
    [3]  = 'Stash capacity increased',
    [4]  = 'Influence zones unlocked',
    [5]  = 'Second office terminal active',
    [6]  = 'Mission cooldown reduced',
    [8]  = 'Tier upgrade discount (10%)',
    [10] = 'Empire-class status badge'
}

-- ============================================================
-- MISSION COOLDOWNS (minutes per tier, reduced at level 6+)
-- ============================================================
Config.MissionCooldowns = {
    [1] = 30,
    [2] = 20,
    [3] = 15,
    [4] = 10
}
Config.MissionCooldownReduction = 5  -- minutes removed when org >= level 6

-- ============================================================
-- SHARED STASH
-- ============================================================
Config.StashSlots   = { 10, 20, 35, 50 }    -- per tier index
Config.StashWeights = { 5000, 10000, 20000, 40000 }  -- max weight per tier

-- ============================================================
-- INFLUENCE ZONES (Territory System)
-- ============================================================
Config.InfluenceZones = {
    { id = 'downtown',    label = 'Downtown LS',     coords = vector3(202.0,  -812.0,  30.0),   radius = 350, passiveBonus = 2000 },
    { id = 'vinewood',    label = 'Vinewood Hills',  coords = vector3(-408.0,  545.0, 100.0),   radius = 300, passiveBonus = 1500 },
    { id = 'vespucci',    label = 'Vespucci Beach',  coords = vector3(-1227.0, -981.0,   7.0),  radius = 280, passiveBonus = 1200 },
    { id = 'ls_port',     label = 'LS Port',         coords = vector3(781.0, -2426.0,   7.0),   radius = 400, passiveBonus = 2000 },
    { id = 'sandy',       label = 'Sandy Shores',    coords = vector3(1836.0, 3681.0,  33.0),   radius = 450, passiveBonus = 800  },
    { id = 'paleto',      label = 'Paleto Bay',      coords = vector3(-194.0, 6237.0,  31.0),   radius = 350, passiveBonus = 700  },
    { id = 'rockford',    label = 'Rockford Hills',  coords = vector3(-756.0,  175.0,  58.0),   radius = 280, passiveBonus = 1800 },
    { id = 'la_mesa',     label = 'La Mesa',         coords = vector3(817.0,  -736.0,  26.0),   radius = 300, passiveBonus = 1000 }
}

Config.InfluenceDecayPerHour    = 2    -- score lost per hour of inactivity
Config.InfluencePresenceGain    = 1    -- score gained per minute of zone presence
Config.InfluenceMissionGain     = 10   -- score gained per mission completed in zone
Config.InfluenceContestThresh   = 10   -- if two orgs within this many points, zone is "contested"
Config.InfluenceMissionBonus    = 1.05 -- 5% reward multiplier for zone owner

-- ============================================================
-- HEAT SYSTEM
-- ============================================================
Config.HeatDecayPerHour  = 1    -- natural heat reduction per passive tick hour
Config.HeatPassivePenalty = {   -- passive income multiplier based on heat level
    normal   = 1.0,             -- 0-30  heat
    elevated = 0.85,            -- 31-60 heat
    hot      = 0.60,            -- 61-90 heat
    burned   = 0.0              -- 91-100 heat
}

-- ============================================================
-- PLAYER-PAID ORG CREATION
-- ============================================================
Config.RequireAdminApproval = false

Config.CreationFees = {
    legal   = 250000,
    illegal = 500000,
    family  = 350000
}

Config.CreationNPC = {
    coords = vector4(372.36, 329.41, 103.57, 250.0),
    model  = 'a_m_m_business_01',
    label  = 'Notary Office'
}

-- ============================================================
-- DRUG LAB SYSTEM (Grand RP-style multi-step pipeline)
--
-- Pipeline per lab type:
--   1. GATHER  — player goes to raw material site, skill check
--   2. DEPOSIT — player brings raw materials to their lab
--   3. COLLECT — player picks up finished product from lab
--   4. SELL    — player sells at a deal point → vault $$$
--
-- Passive production is a small trickle (1 unit/hr) on top.
-- Primary income requires active gathering.
-- ============================================================

Config.DrugLabs = {
    allowedTypes  = { 'illegal', 'family' },
    maxLabsPerOrg = 2,
    labCost       = 750000,

    -- ── Drug Types ────────────────────────────────────────────
    types = {
        weed = {
            label            = 'Cannabis Operation',
            rawLabel         = 'Cannabis Harvest',
            gatherLabel      = 'Harvest Cannabis Plants',
            color            = '#6abf69',
            icon             = '◈',
            rawPerGather     = 6,       -- raw units per gather action
            rawToProduct     = 3,       -- raw units needed per 1 packaged unit
            unitsPerHour     = 1,       -- passive trickle (bonus)
            maxStock         = 60,
            sellPricePerUnit = 8500,
            heatGainOnSell   = 5,
            gatherSkill      = { 'easy', 'easy' },
            steps = {
                '🌿 Harvest cannabis at Alamo Sea or Grapeseed fields',
                '🏭 Deposit harvest at your cannabis lab to dry & package',
                '📦 Collect packaged product from the lab',
                '💰 Sell at any deal point — goes straight to vault',
            }
        },
        heroin = {
            label            = 'Heroin Lab',
            rawLabel         = 'Opium Resin',
            gatherLabel      = 'Harvest Poppy Fields',
            color            = '#c7a97a',
            icon             = '◆',
            rawPerGather     = 4,
            rawToProduct     = 4,
            unitsPerHour     = 1,
            maxStock         = 40,
            sellPricePerUnit = 15000,
            heatGainOnSell   = 12,
            gatherSkill      = { 'easy', 'medium' },
            steps = {
                '🌸 Harvest poppy fields in the Alamo Sea region',
                '🧪 Deposit opium resin at your heroin lab to process',
                '📦 Collect processed product',
                '💰 Sell at a deal point',
            }
        },
        meth = {
            label            = 'Meth Lab',
            rawLabel         = 'Chemical Supplies',
            gatherLabel      = 'Steal Chemical Supplies',
            color            = '#88c0d0',
            icon             = '◎',
            rawPerGather     = 4,
            rawToProduct     = 2,
            unitsPerHour     = 2,
            maxStock         = 50,
            sellPricePerUnit = 12000,
            heatGainOnSell   = 10,
            gatherSkill      = { 'medium', 'easy' },
            steps = {
                '🧴 Steal chemical supplies from Harmony or Sandy Shores suppliers',
                '🔥 Deposit chemicals at your meth lab to cook',
                '📦 Collect cooked product',
                '💰 Sell at a deal point',
            }
        },
        cocaine = {
            label            = 'Cocaine Lab',
            rawLabel         = 'Coca Paste',
            gatherLabel      = 'Collect Coca Paste',
            color            = '#e8d5b7',
            icon             = '◉',
            rawPerGather     = 4,
            rawToProduct     = 3,
            unitsPerHour     = 2,
            maxStock         = 55,
            sellPricePerUnit = 10500,
            heatGainOnSell   = 8,
            gatherSkill      = { 'easy', 'medium' },
            steps = {
                '🚢 Collect coca paste from LS Docks or Elysian Island shipments',
                '⚗️  Deposit paste at your cocaine lab to refine',
                '📦 Collect processed cocaine',
                '💰 Sell at a deal point',
            }
        },
        counterfeit = {
            label            = 'Counterfeit Press',
            rawLabel         = 'Printing Supplies',
            gatherLabel      = 'Source Printing Supplies',
            color            = '#a3be8c',
            icon             = '◇',
            rawPerGather     = 8,
            rawToProduct     = 5,
            unitsPerHour     = 3,
            maxStock         = 100,
            sellPricePerUnit = 5500,
            heatGainOnSell   = 4,
            gatherSkill      = { 'easy', 'easy' },
            steps = {
                '🖨️  Source printing supplies from office/print stores',
                '💵 Deposit supplies at your counterfeit press',
                '📦 Collect printed bills',
                '💰 Launder/distribute at deal points',
            }
        },
    },

    -- ── Lab Locations in the World ────────────────────────────
    -- Real-ish GTA V landmarks used as operation bases
    locations = {
        { id = 1,  label = 'Sandy Shores Cannabis Barn',    type = 'weed',        coords = vector3(1971.13,  3810.51,  32.35) },
        { id = 2,  label = 'Alamo Sea Poppy Processing',    type = 'heroin',       coords = vector3(2363.58,  3876.23,  33.62) },
        { id = 3,  label = 'Sandy Shores Meth Cook',        type = 'meth',         coords = vector3(1725.61,  3823.96,  34.37) },
        { id = 4,  label = 'Cypress Flats Cocaine Lab',     type = 'cocaine',      coords = vector3(1010.5,  -2007.5,   29.6)  },
        { id = 5,  label = 'Davis Cocaine Lab',             type = 'cocaine',      coords = vector3(80.7,    -1951.9,   21.1)  },
        { id = 6,  label = 'Rockford Counterfeit Press',    type = 'counterfeit',  coords = vector3(-893.1,   -223.6,   37.9)  },
        { id = 7,  label = 'Paleto Bay Cannabis Farm',      type = 'weed',         coords = vector3(-344.6,   6316.0,   32.5)  },
        { id = 8,  label = 'La Mesa Heroin Lab',            type = 'heroin',       coords = vector3(869.47,  -1726.97,  30.04) },
        { id = 9,  label = 'Harmony Meth Lab',              type = 'meth',         coords = vector3(354.65,   2904.99,  44.39) },
        { id = 10, label = 'Morningwood Counterfeit',       type = 'counterfeit',  coords = vector3(-745.63,   228.47,  82.0)  },
    },

    -- ── Raw Material Gather Sites (active step) ───────────────
    gatherLocations = {
        weed = {
            { id = 'wg1', label = 'Alamo Sea Cannabis Field',    coords = vector3(2488.09,  3895.64,  37.59) },
            { id = 'wg2', label = 'Grapeseed Grow Site',         coords = vector3(2497.15,  4960.49,  46.07) },
            { id = 'wg3', label = 'Sandy Shores Fields',         coords = vector3(1738.77,  3857.97,  32.15) },
            { id = 'wg4', label = 'Harmony Grow Site',           coords = vector3(373.64,   2927.46,  44.54) },
        },
        heroin = {
            { id = 'hg1', label = 'Alamo Sea Poppy Fields',      coords = vector3(2234.0,   4748.36,  37.57) },
            { id = 'hg2', label = 'Desert Poppy Ridge',          coords = vector3(2639.83,  4895.14,  38.21) },
            { id = 'hg3', label = 'Sandy Shores Poppy Patch',    coords = vector3(1951.8,   3842.22,  32.55) },
        },
        meth = {
            { id = 'mg1', label = 'Harmony Chemical Supplier',   coords = vector3(1208.42,  2660.74,  37.9)  },
            { id = 'mg2', label = 'Sandy Airfield Chemicals',    coords = vector3(1732.54,  3287.83,  41.1)  },
            { id = 'mg3', label = 'Grapeseed Chemical Store',    coords = vector3(1697.67,  4925.75,  42.08) },
        },
        cocaine = {
            { id = 'cg1', label = 'LS Docks Cargo Shipment',     coords = vector3(613.33,  -2548.37,   6.89) },
            { id = 'cg2', label = 'Elysian Island Drop',         coords = vector3(419.16,  -2992.14,   5.0)  },
            { id = 'cg3', label = 'Port of South LS',            coords = vector3(886.06,  -3016.26,   5.9)  },
        },
        counterfeit = {
            { id = 'fg1', label = 'Downtown Print Supply',       coords = vector3(226.84,   -795.49,  29.98) },
            { id = 'fg2', label = 'Rockford Office Supplies',    coords = vector3(-748.63,   231.47,  82.33) },
            { id = 'fg3', label = 'La Mesa Ink Supplier',        coords = vector3(858.63,   -762.21,  26.4)  },
        },
    },

    -- ── Sell / Deal Points ────────────────────────────────────
    sellPoints = {
        { id = 1, label = 'LS Port Deal',          coords = vector3(686.6,   -2534.0,    7.2)  },
        { id = 2, label = 'Elysian Island Deal',   coords = vector3(419.16,  -2992.14,   5.0)  },
        { id = 3, label = 'Sandy Shores Deal',     coords = vector3(2032.0,   3124.0,   48.0)  },
        { id = 4, label = 'Vespucci Deal',         coords = vector3(-1380.7,  -626.7,   30.5)  },
        { id = 5, label = 'Vinewood Hills Deal',   coords = vector3(-630.2,    266.4,   83.4)  },
        { id = 6, label = 'Mirror Park Deal',      coords = vector3(1172.0,   -734.0,   58.26) },
        { id = 7, label = 'Little Seoul Deal',     coords = vector3(-656.67,  -932.17,  21.83) },
    },

    -- ── Raid & Production ────────────────────────────────────
    raidHeatThreshold = 60,
    raidChancePerTick = 0.12,
    gatherCooldownSecs = 180,   -- 3 min per-player per gather location
    collectCooldownSecs = 300,  -- 5 min per-player collect cooldown
}

-- ============================================================
-- STORE ROBBERY SYSTEM (Grand RP-style — ~$250K/hr per org)
-- ============================================================

Config.StoreRobbery = {
    minTier       = 1,
    allowedTypes  = { 'illegal', 'family' },
    cooldownSecs  = 3600,
    payoutMin     = 180000,
    payoutMax     = 280000,
    heatGain      = 15,
    minRank       = 2,

    stores = {
        { id = 1, label = '24/7 — Strawberry',         coords = vector3(-706.1,   -913.0,   19.2) },
        { id = 2, label = '24/7 — La Mesa',            coords = vector3(817.6,    -775.9,   26.4) },
        { id = 3, label = 'Liquor Mart — Vinewood',    coords = vector3(1164.3,   -323.3,   69.2) },
        { id = 4, label = '24/7 — Paleto Bay',         coords = vector3(-60.1,    6249.4,   31.1) },
        { id = 5, label = "Rob's Liquor — Vespucci",   coords = vector3(-1224.5,  -908.5,   12.0) },
        { id = 6, label = '24/7 — Sandy Shores',       coords = vector3(1736.0,   3709.1,   33.5) },
        { id = 7, label = '24/7 — Harmony',            coords = vector3(542.73,   2661.51,  42.14) },
        { id = 8, label = '24/7 — Chamberlain Hills',  coords = vector3(251.6,   -1388.5,   29.3) },
    }
}

-- ============================================================
-- SCHEDULED TERRITORY WAR WINDOWS (Grand RP-style)
-- Territory capture events only active during these windows.
-- Outside these windows, influence gain from presence is blocked.
-- ============================================================

Config.TerritoryWarWindows = {
    enabled = true,
    -- Days: 1=Monday, 2=Tuesday ... 7=Sunday
    activeDays = { 1, 3, 5, 7 },  -- Mon, Wed, Fri, Sun
    -- Hour range (24h, server local time)
    startHour  = 16,   -- 4:00 PM
    endHour    = 23,   -- 11:00 PM
    -- Score multiplier for captures during war window
    warWindowBonus = 3,
    -- Notification sent to all online org members when window opens
    notifyOnOpen = true,
}

-- ============================================================
-- LEADERBOARD
-- ============================================================
Config.LeaderboardRewards = {
    [1] = 500000,
    [2] = 250000,
    [3] = 100000
}
