-- SpellDB.lua
local addonName, RCA = ...
RCA.SpellDB = {}

-- Defensive Spells (DR, Shields, Immunities)
local DEFENSIVE = {
    [48707] = true, [48792] = true, [49028] = true, [198589] = true, [22812] = true,
    [186265] = true, [45438] = true, [115203] = true, [642] = true, [47585] = true,
    [31224] = true, [5277] = true, [108271] = true, [104773] = true, [871] = true,
    [363916] = true, [118038] = true, [184364] = true, [108416] = true, [61336] = true
}

-- Utility (CC, Interrupts, Movement)
local UTILITY = {
    [47528] = true, [1766] = true, [6552] = true, [57994] = true, [2139] = true,
    [118] = true, [106839] = true, [1850] = true, [1953] = true, [2983] = true,
    [10060] = true, [29166] = true, [32182] = true, [2825] = true, [80353] = true
}

-- Filtreringsfunksjon
function RCA.SpellDB.IsOffensive(spellID)
if not spellID or spellID <= 0 then return false end
    if DEFENSIVE[spellID] or UTILITY[spellID] then return false end
        return true
        end

        -- Terskelverdier og Klasse-standarder
        RCA.SpellDB.SelfHealThreshold = 0.80

        RCA.SpellDB.ClassDefaults = {
            DEATHKNIGHT = {49998, 48792, 48707},
            DEMONHUNTER = {198589, 196555},
            DRUID       = {8936, 22842, 61336},
            HUNTER      = {109304, 186265},
            MAGE        = {11426, 45438},
            PALADIN     = {85673, 642, 633},
            ROGUE       = {185311, 31224, 5277},
            WARRIOR     = {34428, 871, 118038},
            PRIEST      = {19236, 47585},
            SHAMAN      = {108271, 8004},
            WARLOCK     = {108416, 104773},
            MONK        = {322101, 115203},
            EVOKER      = {363916, 360995}
        }
