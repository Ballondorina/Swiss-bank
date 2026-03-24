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
-- LEADERBOARD
-- ============================================================
Config.LeaderboardRewards = {
    [1] = 500000,
    [2] = 250000,
    [3] = 100000
}
