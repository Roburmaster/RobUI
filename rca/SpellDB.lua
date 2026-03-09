-- SpellDB.lua
local addonName, addonTable = ...

addonTable.SpellDB = addonTable.SpellDB or {}
local db = addonTable.SpellDB

--------------------------------------------------------------------------------
-- DEFENSIVE SPELLS: Major cooldowns, shields, damage reduction, immunities
--------------------------------------------------------------------------------
db.DEFENSIVE_SPELLS = {
    -- Death Knight
    [48707] = true, [48792] = true, [49028] = true, [55233] = true, [194679] = true, [206931] = true, [219809] = true, [49039] = true, [51052] = true, [327574] = true,
    -- Demon Hunter
    [187827] = true, [196555] = true, [198589] = true, [203720] = true, [204021] = true, [212084] = true, [263648] = true,
    -- Druid
    [22812] = true, [61336] = true, [102342] = true, [106922] = true, [108238] = true, [22842] = true, [192081] = true, [203974] = true,
    -- Evoker
    [363916] = true, [370960] = true, [374348] = true, [357170] = true, [378441] = true, [406732] = true,
    -- Hunter
    [186265] = true, [109304] = true, [264735] = true, [281195] = true, [53480] = true, [264667] = true,
    -- Mage
    [45438] = true, [55342] = true, [66] = true, [110959] = true, [235313] = true, [235450] = true, [11426] = true, [342245] = true, [108839] = true,
    -- Monk
    [115176] = true, [115203] = true, [116849] = true, [122278] = true, [122783] = true, [120954] = true, [243435] = true, [201318] = true, [322507] = true, [325197] = true, [115295] = true, [116844] = true,
    -- Paladin
    [498] = true, [642] = true, [1022] = true, [6940] = true, [31850] = true, [86659] = true, [184662] = true, [204018] = true, [228049] = true, [152262] = true, [378974] = true, [387174] = true, [389539] = true,
    -- Priest
    [19236] = true, [47536] = true, [47585] = true, [33206] = true, [62618] = true, [81782] = true, [109964] = true, [108968] = true, [586] = true, [213602] = true, [271466] = true, [372760] = true, [421453] = true,
    -- Rogue
    [1966] = true, [5277] = true, [31224] = true, [45182] = true, [185311] = true, [114018] = true, [1856] = true,
    -- Shaman
    [108271] = true, [198103] = true, [207399] = true, [108281] = true, [114052] = true, [98008] = true, [192077] = true, [192249] = true, [16191] = true,
    -- Warlock
    [104773] = true, [108416] = true, [212295] = true, [6789] = true, [386997] = true, [264106] = true,
    -- Warrior
    [871] = true, [12975] = true, [23920] = true, [97462] = true, [118038] = true, [184364] = true, [190456] = true, [213871] = true, [386208] = true, [385060] = true, [384318] = true
}

--------------------------------------------------------------------------------
-- HEALING SPELLS: Direct heals, HoTs, healing cooldowns
--------------------------------------------------------------------------------
db.HEALING_SPELLS = {
    -- Death Knight
    [48743] = true, [206940] = true,
    -- Druid
    [774] = true, [8936] = true, [18562] = true, [33763] = true, [48438] = true, [102351] = true, [102401] = true, [145205] = true, [155777] = true, [197721] = true, [203651] = true, [207385] = true, [391888] = true, [740] = true,
    -- Evoker
    [355913] = true, [360823] = true, [360827] = true, [360995] = true, [361469] = true, [363534] = true, [366155] = true, [367226] = true, [382614] = true, [382731] = true, [395152] = true, [409311] = true, [406732] = true,
    -- Monk
    [115175] = true, [116670] = true, [116680] = true, [119611] = true, [124682] = true, [191837] = true, [198898] = true, [205234] = true, [322118] = true, [325197] = true, [388615] = true, [388193] = true,
    -- Paladin
    [19750] = true, [82326] = true, [85222] = true, [85673] = true, [633] = true, [20473] = true, [53563] = true, [114158] = true, [114165] = true, [183998] = true, [213644] = true, [223306] = true, [200025] = true, [216331] = true, [388007] = true, [388010] = true, [388011] = true, [388013] = true, [31821] = true, [4987] = true, [213652] = true,
    -- Priest
    [17] = true, [139] = true, [186263] = true, [194509] = true, [2050] = true, [2060] = true, [2061] = true, [32546] = true, [34861] = true, [64843] = true, [88625] = true, [110744] = true, [120517] = true, [200183] = true, [204883] = true, [289666] = true, [73325] = true, [596] = true, [33076] = true, [527] = true, [528] = true,
    -- Shaman
    [5394] = true, [61295] = true, [73920] = true, [77472] = true, [8004] = true, [108280] = true, [157153] = true, [197995] = true, [198838] = true, [207778] = true, [382024] = true, [51886] = true, [77130] = true,
    -- Warlock
    [755] = true,
    -- Warrior
    [34428] = true, [202168] = true
}

--------------------------------------------------------------------------------
-- CROWD CONTROL SPELLS: Stuns, fears, roots, incapacitates, silences
--------------------------------------------------------------------------------
db.CROWD_CONTROL_SPELLS = {
    -- Death Knight
    [47528] = true, [91800] = true, [108194] = true, [207167] = true, [221562] = true,
    -- Demon Hunter
    [179057] = true, [183752] = true, [211881] = true, [217832] = true, [207684] = true, [202137] = true,
    -- Druid
    [99] = true, [339] = true, [2637] = true, [5211] = true, [22570] = true, [33786] = true, [78675] = true, [102359] = true, [102793] = true, [106839] = true, [203123] = true,
    -- Evoker
    [351338] = true, [357208] = true, [360806] = true, [372048] = true,
    -- Hunter
    [1513] = true, [5116] = true, [19386] = true, [24394] = true, [117405] = true, [147362] = true, [162488] = true, [187650] = true, [187707] = true, [213691] = true, [236776] = true,
    -- Mage
    [31661] = true, [33395] = true, [44572] = true, [82691] = true, [118] = true, [122] = true, [2139] = true, [157981] = true, [157997] = true, [113724] = true, [61305] = true, [161353] = true, [161354] = true, [161355] = true, [161372] = true, [126819] = true, [28272] = true, [28271] = true,
    -- Monk
    [115078] = true, [116705] = true, [119381] = true, [198898] = true, [233759] = true,
    -- Paladin
    [853] = true, [20066] = true, [31935] = true, [96231] = true, [105421] = true, [115750] = true, [10326] = true, [217824] = true,
    -- Priest
    [8122] = true, [9484] = true, [15487] = true, [64044] = true, [205369] = true, [605] = true,
    -- Rogue
    [408] = true, [1330] = true, [1776] = true, [1833] = true, [2094] = true, [6770] = true, [1766] = true, [199804] = true, [207777] = true,
    -- Shaman
    [51490] = true, [51514] = true, [57994] = true, [64695] = true, [77505] = true, [118905] = true, [192058] = true, [196932] = true, [197214] = true, [210873] = true, [211004] = true, [211010] = true, [211015] = true, [269352] = true, [277778] = true, [277784] = true, [309328] = true,
    -- Warlock
    [5484] = true, [6358] = true, [6789] = true, [19647] = true, [30283] = true, [89766] = true, [710] = true, [118699] = true, [171017] = true, [212619] = true,
    -- Warrior
    [5246] = true, [6552] = true, [46968] = true, [107570] = true, [132168] = true, [132169] = true
}

--------------------------------------------------------------------------------
-- UTILITY SPELLS: Movement, dispels, rezzes, taunts, externals, transfers
--------------------------------------------------------------------------------
db.UTILITY_SPELLS = {
    -- Movement Abilities (pure mobility, no damage)
    [2983] = true, [1953] = true, [212653] = true, [186257] = true, [781] = true, [109132] = true, [116841] = true, [1850] = true, [252216] = true, [106898] = true, [111771] = true, [48265] = true, [212552] = true, [79206] = true, [192063] = true, [355] = true, [190784] = true, [358267] = true,

    -- Taunts
    [56222] = true, [185245] = true, [6795] = true, [115546] = true, [62124] = true,

    -- Resurrects / Battle Resurrects
    [2006] = true, [2008] = true, [7328] = true, [50769] = true, [115178] = true, [361227] = true, [212056] = true, [212036] = true, [20484] = true, [61999] = true, [20707] = true, [391054] = true,

    -- External Buffs
    [10060] = true, [29166] = true, [1044] = true, [6940] = true, [1022] = true, [204018] = true, [80353] = true, [32182] = true, [2825] = true, [264667] = true, [390386] = true, [381748] = true, [1038] = true,

    -- Threat Transfers
    [34477] = true, [57934] = true,

    -- Dispels/Purges
    [528] = true, [370] = true, [19801] = true, [30449] = true, [2782] = true, [88423] = true, [115450] = true, [218164] = true, [475] = true, [2908] = true, [89808] = true, [132411] = true, [365585] = true, [374251] = true,

    -- Pet Utility
    [2641] = true, [883] = true, [83242] = true, [83243] = true, [83244] = true, [83245] = true, [272651] = true,

    -- Miscellaneous Utility
    [115313] = true, [115315] = true, [61304] = true, [1725] = true, [921] = true, [3714] = true, [111400] = true, [131347] = true, [202138] = true, [375087] = true
}

--------------------------------------------------------------------------------
-- API Function for the rotation queue
--------------------------------------------------------------------------------
function db.IsOffensive(spellID)
    if not spellID or spellID <= 0 then return false end

    -- If it's in any of the non-offensive tables, it's not offensive
    if db.DEFENSIVE_SPELLS[spellID] then return false end
    if db.HEALING_SPELLS[spellID] then return false end
    if db.CROWD_CONTROL_SPELLS[spellID] then return false end
    if db.UTILITY_SPELLS[spellID] then return false end

    return true
end

--------------------------------------------------------------------------------
-- Spec-aware helper:
-- Supports:
--   tbl.CLASS = { ... }               (class-only list)
--   tbl.CLASS = { [1]={...}, [2]={...} } (spec lists)
--------------------------------------------------------------------------------
function db.GetClassSpecList(tbl, classToken, specId)
    if type(tbl) ~= "table" then return {} end
    if type(classToken) ~= "string" or classToken == "" then return {} end
    specId = tonumber(specId) or 0

    local entry = tbl[classToken]
    if type(entry) ~= "table" then return {} end

    -- If entry[specId] is a list table, prefer it
    if specId > 0 and type(entry[specId]) == "table" then
        return entry[specId]
    end

    -- If entry looks like a flat list (array), return it
    return entry
end

--------------------------------------------------------------------------------
-- CLASS DEFAULTS
--------------------------------------------------------------------------------

-- Self-heal spells (shown at 80% health threshold)
-- Can be:
--   DRUID = {...}  or DRUID = { [1]={...}, [2]={...}, [3]={...}, [4]={...} }
db.CLASS_SELFHEAL_DEFAULTS = {
    DEATHKNIGHT = {49998},
    DEMONHUNTER = {198589, 228477},
    DRUID = {8936, 22842, 108238, 22812},
    EVOKER = {363916, 360995},
    HUNTER = {109304},
    MAGE = {11426, 235313, 235450},
    MONK = {322101},
    PALADIN = {85673, 498},
    PRIEST = {19236, 17},
    ROGUE = {185311, 1966},
    SHAMAN = {108271, 8004},
    WARLOCK = {108416, 234153},
    WARRIOR = {34428, 202168, 190456}
}

-- Major cooldowns for critical situations (shown at 60% health threshold)
-- Can be spec-aware using [specId] keys later.
db.CLASS_COOLDOWN_DEFAULTS = {
    DEATHKNIGHT = {48792, 48707},
    DEMONHUNTER = {196555, 196718},
    DRUID = {61336},
    EVOKER = {374348},
    HUNTER = {186265, 388035},
    MAGE = {45438, 110959},
    MONK = {115203, 122470, 122783},
    PALADIN = {642, 633},
    PRIEST = {47585, 586},
    ROGUE = {31224, 5277},
    SHAMAN = {198103},
    WARLOCK = {104773},
    WARRIOR = {871, 118038, 97462}
}

-- Offensive burst buffs / major damage CDs (used by BuildCDQueue fallback)
-- This replaces the hardcoded DEFAULT_OFFENSIVE_BUFFS in Core.lua over tid.
db.CLASS_OFFENSIVE_BUFF_DEFAULTS = {
    WARRIOR     = {107574, 1719, 167105, 262161},
    PALADIN     = {31884, 231895, 327193},
    DEATHKNIGHT = {51271, 152279, 275699},
    HUNTER      = {19574, 288613, 266779},
    MAGE        = {190319, 12042, 12472},
    ROGUE       = {13750, 51690, 121471},
    WARLOCK     = {113858, 205180, 113860},
    SHAMAN      = {114050, 114051, 114052},
    MONK        = {137639, 123904},
    DEMONHUNTER = {191427, 200146},
    DRUID       = {102560, 102543, 194223},
    PRIEST      = {10060, 34433},
    EVOKER      = {375087, 368847},
}