-- Modules/Data/Stats.lua
-- Inneholder stat-vekting/mål for specs (brukes av LiveStats og CharacterStats)

local ADDON, ns = ...
ns.stats_data = {} -- Endret fra ns.stats_mplus for tydelighet

-- Demon Hunter Vengeance
local DEMON_HUNTER_VENGEANCE_STATS = {
    Strike      = { raw = 18660, percent = 37.00 },
    Haste       = { raw = 21487, percent = 32.00 },
    Mastery     = { raw = 5646, percent = 26.00 },
    Versatility = { raw = 6451, percent = 8.00 },
    Avoidance   = { raw = 434, percent = 1.00 },
    Leech       = { raw = 3285, percent = 13.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_DEMON_HUNTER_VENGEANCE()
    local copy = {}
    for stat,data in pairs(DEMON_HUNTER_VENGEANCE_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Shaman Enhancement
local SHAMAN_ENHANCEMENT_STATS = {
    Strike      = { raw = 5328, percent = 18.00 },
    Haste       = { raw = 22182, percent = 33.00 },
    Mastery     = { raw = 20796, percent = 75.00 },
    Versatility = { raw = 2444, percent = 3.00 },
    Avoidance   = { raw = 1900, percent = 3.00 },
    Leech       = { raw = 774, percent = 1.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_SHAMAN_ENHANCEMENT()
    local copy = {}
    for stat,data in pairs(SHAMAN_ENHANCEMENT_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Warrior Arms
local WARRIOR_ARMS_STATS = {
    Strike      = { raw = 18261, percent = 35.00 },
    Haste       = { raw = 19491, percent = 32.00 },
    Mastery     = { raw = 8738, percent = 25.00 },
    Versatility = { raw = 4578, percent = 6.00 },
    Avoidance   = { raw = 1260, percent = 2.00 },
    Leech       = { raw = 1265, percent = 4.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_WARRIOR_ARMS()
    local copy = {}
    for stat,data in pairs(WARRIOR_ARMS_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Death Knight Frost
local DEATH_KNIGHT_FROST_STATS = {
    Strike      = { raw = 16434, percent = 28.00 },
    Haste       = { raw = 9179, percent = 16.00 },
    Mastery     = { raw = 22308, percent = 79.00 },
    Versatility = { raw = 3540, percent = 5.00 },
    Avoidance   = { raw = 1627, percent = 3.00 },
    Leech       = { raw = 1021, percent = 4.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_DEATH_KNIGHT_FROST()
    local copy = {}
    for stat,data in pairs(DEATH_KNIGHT_FROST_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Druid Feral
local DRUID_FERAL_STATS = {
    Strike      = { raw = 8770, percent = 23.00 },
    Haste       = { raw = 14073, percent = 21.00 },
    Mastery     = { raw = 23494, percent = 82.00 },
    Versatility = { raw = 6120, percent = 8.00 },
    Avoidance   = { raw = 2060, percent = 4.00 },
    Leech       = { raw = 611, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_DRUID_FERAL()
    local copy = {}
    for stat,data in pairs(DRUID_FERAL_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Paladin Protection
local PALADIN_PROTECTION_STATS = {
    Strike      = { raw = 19932, percent = 38.00 },
    Haste       = { raw = 21183, percent = 32.00 },
    Mastery     = { raw = 9238, percent = 25.00 },
    Versatility = { raw = 2582, percent = 3.00 },
    Avoidance   = { raw = 674, percent = 1.00 },
    Leech       = { raw = 3316, percent = 3.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_PALADIN_PROTECTION()
    local copy = {}
    for stat,data in pairs(PALADIN_PROTECTION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Evoker Devastation
local EVOKER_DEVASTATION_STATS = {
    Strike      = { raw = 16516, percent = 29.00 },
    Haste       = { raw = 23299, percent = 35.00 },
    Mastery     = { raw = 9044, percent = 33.00 },
    Versatility = { raw = 2596, percent = 3.00 },
    Avoidance   = { raw = 2147, percent = 4.00 },
    Leech       = { raw = 779, percent = 3.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_EVOKER_DEVASTATION()
    local copy = {}
    for stat,data in pairs(EVOKER_DEVASTATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Mage Arcane
local MAGE_ARCANE_STATS = {
    Strike      = { raw = 5233, percent = 14.00 },
    Haste       = { raw = 19522, percent = 32.00 },
    Mastery     = { raw = 11016, percent = 31.00 },
    Versatility = { raw = 17429, percent = 22.00 },
    Avoidance   = { raw = 2150, percent = 4.00 },
    Leech       = { raw = 819, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_MAGE_ARCANE()
    local copy = {}
    for stat,data in pairs(MAGE_ARCANE_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Monk Windwalker
local MONK_WINDWALKER_STATS = {
    Strike      = { raw = 6401, percent = 21.00 },
    Haste       = { raw = 14986, percent = 23.00 },
    Mastery     = { raw = 19478, percent = 83.00 },
    Versatility = { raw = 11856, percent = 15.00 },
    Avoidance   = { raw = 1825, percent = 3.00 },
    Leech       = { raw = 679, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_MONK_WINDWALKER()
    local copy = {}
    for stat,data in pairs(MONK_WINDWALKER_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Paladin Holy
local PALADIN_HOLY_STATS = {
    Strike      = { raw = 12868, percent = 28.00 },
    Haste       = { raw = 21511, percent = 32.00 },
    Mastery     = { raw = 7861, percent = 35.00 },
    Versatility = { raw = 9806, percent = 13.00 },
    Avoidance   = { raw = 1286, percent = 2.00 },
    Leech       = { raw = 2554, percent = 3.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_PALADIN_HOLY()
    local copy = {}
    for stat,data in pairs(PALADIN_HOLY_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Priest Holy
local PRIEST_HOLY_STATS = {
    Strike      = { raw = 15509, percent = 27.00 },
    Haste       = { raw = 16129, percent = 24.00 },
    Mastery     = { raw = 10420, percent = 22.00 },
    Versatility = { raw = 10095, percent = 13.00 },
    Avoidance   = { raw = 956, percent = 2.00 },
    Leech       = { raw = 2818, percent = 7.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_PRIEST_HOLY()
    local copy = {}
    for stat,data in pairs(PRIEST_HOLY_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Priest Shadow
local PRIEST_SHADOW_STATS = {
    Strike      = { raw = 9048, percent = 18.00 },
    Haste       = { raw = 19704, percent = 30.00 },
    Mastery     = { raw = 20461, percent = 19.00 },
    Versatility = { raw = 2452, percent = 3.00 },
    Avoidance   = { raw = 1548, percent = 3.00 },
    Leech       = { raw = 1222, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_PRIEST_SHADOW()
    local copy = {}
    for stat,data in pairs(PRIEST_SHADOW_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Warlock Affliction
local WARLOCK_AFFLICTION_STATS = {
    Strike      = { raw = 18542, percent = 31.00 },
    Haste       = { raw = 17085, percent = 26.00 },
    Mastery     = { raw = 14836, percent = 73.00 },
    Versatility = { raw = 3099, percent = 4.00 },
    Avoidance   = { raw = 1560, percent = 3.00 },
    Leech       = { raw = 894, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_WARLOCK_AFFLICTION()
    local copy = {}
    for stat,data in pairs(WARLOCK_AFFLICTION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Death Knight Blood
local DEATH_KNIGHT_BLOOD_STATS = {
    Strike      = { raw = 11116, percent = 21.00 },
    Haste       = { raw = 12723, percent = 22.00 },
    Mastery     = { raw = 13270, percent = 54.00 },
    Versatility = { raw = 15719, percent = 20.00 },
    Avoidance   = { raw = 896, percent = 2.00 },
    Leech       = { raw = 1694, percent = 3.00 },
    Speed       = { raw = 0, percent = 6.00 },
}

function ns.stats_data:Get_DEATH_KNIGHT_BLOOD()
    local copy = {}
    for stat,data in pairs(DEATH_KNIGHT_BLOOD_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Druid Balance
local DRUID_BALANCE_STATS = {
    Strike      = { raw = 5128, percent = 12.00 },
    Haste       = { raw = 17852, percent = 27.00 },
    Mastery     = { raw = 24140, percent = 21.00 },
    Versatility = { raw = 4805, percent = 6.00 },
    Avoidance   = { raw = 1960, percent = 4.00 },
    Leech       = { raw = 688, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_DRUID_BALANCE()
    local copy = {}
    for stat,data in pairs(DRUID_BALANCE_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Warlock Destruction
local WARLOCK_DESTRUCTION_STATS = {
    Strike      = { raw = 18280, percent = 34.00 },
    Haste       = { raw = 17506, percent = 26.00 },
    Mastery     = { raw = 13813, percent = 56.00 },
    Versatility = { raw = 3211, percent = 4.00 },
    Avoidance   = { raw = 1849, percent = 3.00 },
    Leech       = { raw = 823, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_WARLOCK_DESTRUCTION()
    local copy = {}
    for stat,data in pairs(WARLOCK_DESTRUCTION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Druid Restoration
local DRUID_RESTORATION_STATS = {
    Strike      = { raw = 2580, percent = 9.00 },
    Haste       = { raw = 23895, percent = 36.00 },
    Mastery     = { raw = 15175, percent = 22.00 },
    Versatility = { raw = 11557, percent = 15.00 },
    Avoidance   = { raw = 1724, percent = 3.00 },
    Leech       = { raw = 1973, percent = 2.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_DRUID_RESTORATION()
    local copy = {}
    for stat,data in pairs(DRUID_RESTORATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Mage Frost
local MAGE_FROST_STATS = {
    Strike      = { raw = 12720, percent = 25.00 },
    Haste       = { raw = 20266, percent = 44.00 },
    Mastery     = { raw = 6627, percent = 18.00 },
    Versatility = { raw = 15519, percent = 20.00 },
    Avoidance   = { raw = 1670, percent = 3.00 },
    Leech       = { raw = 911, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_MAGE_FROST()
    local copy = {}
    for stat,data in pairs(MAGE_FROST_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Monk Brewmaster
local MONK_BREWMASTER_STATS = {
    Strike      = { raw = 17258, percent = 35.00 },
    Haste       = { raw = 3928, percent = 6.00 },
    Mastery     = { raw = 10099, percent = 21.00 },
    Versatility = { raw = 21729, percent = 28.00 },
    Avoidance   = { raw = 516, percent = 1.00 },
    Leech       = { raw = 3129, percent = 3.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_MONK_BREWMASTER()
    local copy = {}
    for stat,data in pairs(MONK_BREWMASTER_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Rogue Outlaw
local ROGUE_OUTLAW_STATS = {
    Strike      = { raw = 8734, percent = 23.00 },
    Haste       = { raw = 12497, percent = 19.00 },
    Mastery     = { raw = 3857, percent = 24.00 },
    Versatility = { raw = 25251, percent = 32.00 },
    Avoidance   = { raw = 1808, percent = 3.00 },
    Leech       = { raw = 857, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_ROGUE_OUTLAW()
    local copy = {}
    for stat,data in pairs(ROGUE_OUTLAW_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Shaman Elemental
local SHAMAN_ELEMENTAL_STATS = {
    Strike      = { raw = 8078, percent = 17.00 },
    Haste       = { raw = 17261, percent = 26.00 },
    Mastery     = { raw = 19906, percent = 68.00 },
    Versatility = { raw = 7631, percent = 10.00 },
    Avoidance   = { raw = 2273, percent = 4.00 },
    Leech       = { raw = 985, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_SHAMAN_ELEMENTAL()
    local copy = {}
    for stat,data in pairs(SHAMAN_ELEMENTAL_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Shaman Restoration
local SHAMAN_RESTORATION_STATS = {
    Strike      = { raw = 16936, percent = 29.00 },
    Haste       = { raw = 19884, percent = 30.00 },
    Mastery     = { raw = 3942, percent = 41.00 },
    Versatility = { raw = 11461, percent = 15.00 },
    Avoidance   = { raw = 1801, percent = 3.00 },
    Leech       = { raw = 1913, percent = 2.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_SHAMAN_RESTORATION()
    local copy = {}
    for stat,data in pairs(SHAMAN_RESTORATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Demon Hunter Havoc
local DEMON_HUNTER_HAVOC_STATS = {
    Strike      = { raw = 22016, percent = 41.00 },
    Haste       = { raw = 7732, percent = 12.00 },
    Mastery     = { raw = 17253, percent = 78.00 },
    Versatility = { raw = 4134, percent = 5.00 },
    Avoidance   = { raw = 2017, percent = 4.00 },
    Leech       = { raw = 892, percent = 11.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_DEMON_HUNTER_HAVOC()
    local copy = {}
    for stat,data in pairs(DEMON_HUNTER_HAVOC_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Hunter Survival
local HUNTER_SURVIVAL_STATS = {
    Strike      = { raw = 13541, percent = 33.00 },
    Haste       = { raw = 14136, percent = 21.00 },
    Mastery     = { raw = 21121, percent = 32.00 },
    Versatility = { raw = 2935, percent = 4.00 },
    Avoidance   = { raw = 1512, percent = 3.00 },
    Leech       = { raw = 1517, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_HUNTER_SURVIVAL()
    local copy = {}
    for stat,data in pairs(HUNTER_SURVIVAL_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Monk Mistweaver
local MONK_MISTWEAVER_STATS = {
    Strike      = { raw = 13975, percent = 25.00 },
    Haste       = { raw = 21838, percent = 33.00 },
    Mastery     = { raw = 4181, percent = 97.00 },
    Versatility = { raw = 12182, percent = 16.00 },
    Avoidance   = { raw = 1112, percent = 2.00 },
    Leech       = { raw = 2567, percent = 3.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_MONK_MISTWEAVER()
    local copy = {}
    for stat,data in pairs(MONK_MISTWEAVER_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Paladin Retribution
local PALADIN_RETRIBUTION_STATS = {
    Strike      = { raw = 19360, percent = 37.00 },
    Haste       = { raw = 14533, percent = 22.00 },
    Mastery     = { raw = 16876, percent = 49.00 },
    Versatility = { raw = 1125, percent = 1.00 },
    Avoidance   = { raw = 1754, percent = 3.00 },
    Leech       = { raw = 894, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_PALADIN_RETRIBUTION()
    local copy = {}
    for stat,data in pairs(PALADIN_RETRIBUTION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Rogue Assassination
local ROGUE_ASSASSINATION_STATS = {
    Strike      = { raw = 11918, percent = 27.00 },
    Haste       = { raw = 6104, percent = 9.00 },
    Mastery     = { raw = 22541, percent = 68.00 },
    Versatility = { raw = 10086, percent = 13.00 },
    Avoidance   = { raw = 2097, percent = 4.00 },
    Leech       = { raw = 613, percent = 6.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_ROGUE_ASSASSINATION()
    local copy = {}
    for stat,data in pairs(ROGUE_ASSASSINATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Rogue Subtlety
local ROGUE_SUBTLETY_STATS = {
    Strike      = { raw = 9914, percent = 26.00 },
    Haste       = { raw = 1858, percent = 3.00 },
    Mastery     = { raw = 20568, percent = 91.00 },
    Versatility = { raw = 18890, percent = 24.00 },
    Avoidance   = { raw = 1624, percent = 3.00 },
    Leech       = { raw = 994, percent = 3.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_ROGUE_SUBTLETY()
    local copy = {}
    for stat,data in pairs(ROGUE_SUBTLETY_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Warlock Demonology
local WARLOCK_DEMONOLOGY_STATS = {
    Strike      = { raw = 19036, percent = 32.00 },
    Haste       = { raw = 16168, percent = 25.00 },
    Mastery     = { raw = 9856, percent = 38.00 },
    Versatility = { raw = 8354, percent = 11.00 },
    Avoidance   = { raw = 1583, percent = 3.00 },
    Leech       = { raw = 648, percent = 1.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_WARLOCK_DEMONOLOGY()
    local copy = {}
    for stat,data in pairs(WARLOCK_DEMONOLOGY_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Druid Guardian
local DRUID_GUARDIAN_STATS = {
    Strike      = { raw = 6973, percent = 20.00 },
    Haste       = { raw = 21015, percent = 32.00 },
    Mastery     = { raw = 9093, percent = 15.00 },
    Versatility = { raw = 16242, percent = 21.00 },
    Avoidance   = { raw = 610, percent = 1.00 },
    Leech       = { raw = 3059, percent = 3.00 },
    Speed       = { raw = 0, percent = 4.00 },
}

function ns.stats_data:Get_DRUID_GUARDIAN()
    local copy = {}
    for stat,data in pairs(DRUID_GUARDIAN_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Hunter Marksmanship
local HUNTER_MARKSMANSHIP_STATS = {
    Strike      = { raw = 27855, percent = 53.00 },
    Haste       = { raw = 8813, percent = 13.00 },
    Mastery     = { raw = 11213, percent = 15.00 },
    Versatility = { raw = 4371, percent = 6.00 },
    Avoidance   = { raw = 1859, percent = 3.00 },
    Leech       = { raw = 828, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_HUNTER_MARKSMANSHIP()
    local copy = {}
    for stat,data in pairs(HUNTER_MARKSMANSHIP_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Priest Discipline
local PRIEST_DISCIPLINE_STATS = {
    Strike      = { raw = 11743, percent = 22.00 },
    Haste       = { raw = 22508, percent = 33.00 },
    Mastery     = { raw = 9338, percent = 29.00 },
    Versatility = { raw = 8797, percent = 11.00 },
    Avoidance   = { raw = 1593, percent = 3.00 },
    Leech       = { raw = 1450, percent = 5.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_PRIEST_DISCIPLINE()
    local copy = {}
    for stat,data in pairs(PRIEST_DISCIPLINE_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Warrior Protection
local WARRIOR_PROTECTION_STATS = {
    Strike      = { raw = 13689, percent = 26.00 },
    Haste       = { raw = 22212, percent = 39.00 },
    Mastery     = { raw = 4167, percent = 21.00 },
    Versatility = { raw = 12988, percent = 17.00 },
    Avoidance   = { raw = 484, percent = 1.00 },
    Leech       = { raw = 3594, percent = 10.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_WARRIOR_PROTECTION()
    local copy = {}
    for stat,data in pairs(WARRIOR_PROTECTION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Evoker Preservation
local EVOKER_PRESERVATION_STATS = {
    Strike      = { raw = 13647, percent = 24.00 },
    Haste       = { raw = 19492, percent = 29.00 },
    Mastery     = { raw = 12696, percent = 49.00 },
    Versatility = { raw = 6890, percent = 9.00 },
    Avoidance   = { raw = 1185, percent = 2.00 },
    Leech       = { raw = 2442, percent = 3.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_EVOKER_PRESERVATION()
    local copy = {}
    for stat,data in pairs(EVOKER_PRESERVATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Evoker Augmentation
local EVOKER_AUGMENTATION_STATS = {
    Strike      = { raw = 17498, percent = 30.00 },
    Haste       = { raw = 19923, percent = 30.00 },
    Mastery     = { raw = 10766, percent = 7.00 },
    Versatility = { raw = 3432, percent = 4.00 },
    Avoidance   = { raw = 1731, percent = 3.00 },
    Leech       = { raw = 926, percent = 1.00 },
    Speed       = { raw = 0, percent = 2.00 },
}

function ns.stats_data:Get_EVOKER_AUGMENTATION()
    local copy = {}
    for stat,data in pairs(EVOKER_AUGMENTATION_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Mage Fire
local MAGE_FIRE_STATS = {
    Strike      = { raw = 4235, percent = 13.00 },
    Haste       = { raw = 29618, percent = 46.00 },
    Mastery     = { raw = 11214, percent = 13.00 },
    Versatility = { raw = 8483, percent = 11.00 },
    Avoidance   = { raw = 1627, percent = 3.00 },
    Leech       = { raw = 1090, percent = 1.00 },
    Speed       = { raw = 0, percent = 3.00 },
}

function ns.stats_data:Get_MAGE_FIRE()
    local copy = {}
    for stat,data in pairs(MAGE_FIRE_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

-- Death Knight Unholy
local DEATH_KNIGHT_UNHOLY_STATS = {
    Strike      = { raw = 11276, percent = 21.00 },
    Haste       = { raw = 19468, percent = 32.00 },
    Mastery     = { raw = 19628, percent = 65.00 },
    Versatility = { raw = 948, percent = 1.00 },
    Avoidance   = { raw = 1511, percent = 3.00 },
    Leech       = { raw = 1021, percent = 2.00 },
    Speed       = { raw = 0, percent = 5.00 },
}

function ns.stats_data:Get_DEATH_KNIGHT_UNHOLY()
    local copy = {}
    for stat,data in pairs(DEATH_KNIGHT_UNHOLY_STATS) do copy[stat] = { raw = data.raw, percent = data.percent } end
    return copy
end

return ns.stats_data