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
    [1] = { name = 'Associé',       canWithdraw = false, canAssignJobs = false, dailyWithdraw = 0       },
    [2] = { name = 'Soldat',        canWithdraw = true,  canAssignJobs = false, dailyWithdraw = 10000   },
    [3] = { name = 'Kapten',        canWithdraw = true,  canAssignJobs = true,  dailyWithdraw = 50000   },
    [4] = { name = 'Underdirektör', canWithdraw = true,  canAssignJobs = true,  dailyWithdraw = 200000  },
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
        skillCheck  = { 'easy', 'easy' }
    },
    debt_collection = {
        label       = 'Debt Collection',
        description = 'Locate the target and collect what is owed. Do not leave empty-handed.',
        duration    = 20,
        minRank     = 2,
        rewardMult  = 1.2,
        skillCheck  = { 'easy', 'medium' }
    },
    patrol = {
        label       = 'Territory Patrol',
        description = 'Hold the designated zone for the required time. Report any intrusions.',
        duration    = 10,
        minRank     = 2,
        rewardMult  = 0.8,
        skillCheck  = {}
    },
    dirty_work = {
        label       = 'Dirty Work',
        description = 'Eliminate the target. Clean job. No witnesses.',
        duration    = 25,
        minRank     = 3,
        rewardMult  = 1.5,
        skillCheck  = { 'medium', 'medium' }
    },
    delivery = {
        label       = 'Contract Delivery',
        description = 'Deliver the cargo to the client on time. Do not attract attention.',
        duration    = 15,
        minRank     = 2,
        rewardMult  = 1.0,
        skillCheck  = { 'easy' }
    },
    vip_transport = {
        label       = 'VIP Transport',
        description = 'Transport the VIP safely to the destination. Any incident is on you.',
        duration    = 20,
        minRank     = 2,
        rewardMult  = 1.1,
        skillCheck  = { 'easy', 'easy' }
    },
    inspection = {
        label       = 'Site Inspection',
        description = 'Visit all designated sites and submit the inspection report.',
        duration    = 12,
        minRank     = 2,
        rewardMult  = 0.9,
        skillCheck  = {}
    },
    negotiation = {
        label       = 'Business Negotiation',
        description = 'Meet the contact at the location and close the deal.',
        duration    = 15,
        minRank     = 3,
        rewardMult  = 1.0,
        skillCheck  = { 'medium' }
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
    { coords = vector4(440.67,  -985.66, 30.69, 0.0), label = 'Downtown Office' },
    { coords = vector4(-1038.93, -236.23, 37.76, 0.0), label = 'West Vinewood' },
    { coords = vector4(136.96,  -818.18, 31.35, 0.0), label = 'City Hall Area' },
}

-- ============================================================
-- TIMERS
-- ============================================================
Config.PassiveTickMinutes = 60   -- How often passive income is paid out
Config.SalaryDayOfWeek   = 1    -- 1 = Monday. Salaries paid weekly on this day.
