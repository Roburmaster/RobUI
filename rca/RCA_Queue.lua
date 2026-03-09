-- ============================================================================
-- RCA_Queue.lua
-- The intelligent queue builder for the combat rotation.
-- Integrates Blizzard's suggestions, proc injections, and anti-flicker logic.
-- ============================================================================

local AddonName, ns = ...
ns.Queue = {}

local GetTime = GetTime
local tinsert = table.insert
local wipe = wipe
local ipairs = ipairs
local pairs = pairs

local PRIMARY_STABILIZATION_WINDOW = 0.05 -- 50ms anti-flicker delay
local lastPrimarySpellID = nil
local lastPrimaryChangeTime = 0

local addedSpells = {}
local blizzSpells = {}

local function IsBlacklisted(spellID)
    if not ns.CONFIG or type(ns.CONFIG.blacklist) ~= "table" then return false end
    for _, id in ipairs(ns.CONFIG.blacklist) do
        if id == spellID then return true end
    end
    return false
end

-- Returns the raw array of recommended offensive spells (for Core to SmartFill)
function ns.Queue.GetRawOffensiveSpells()
    wipe(addedSpells)
    wipe(blizzSpells)

    local now = GetTime()
    local nextCast = nil

    -- 1. Get Position 1 (Primary Cast)
    if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        nextCast = C_AssistedCombat.GetNextCastSpell(true)
    end

    -- 2. Anti-Flicker Stabilization
    if nextCast and nextCast > 0 then
        if nextCast ~= lastPrimarySpellID then
            if (now - lastPrimaryChangeTime) < PRIMARY_STABILIZATION_WINDOW and lastPrimarySpellID then
                nextCast = lastPrimarySpellID
            else
                lastPrimarySpellID = nextCast
                lastPrimaryChangeTime = now
            end
        else
            lastPrimaryChangeTime = now
        end

        if not IsBlacklisted(nextCast) then
            tinsert(blizzSpells, nextCast)
            addedSpells[nextCast] = true
            addedSpells[ns.API.GetActualSpellID(nextCast)] = true
        end
    else
        lastPrimarySpellID = nil
        lastPrimaryChangeTime = 0
    end

    -- 3. Inject Procs
    local activeProcs = ns.Scanner.GetActiveProcs()
    for procID in pairs(activeProcs) do
        local actualProcID = ns.API.GetActualSpellID(procID)
        
        if not addedSpells[procID] and not addedSpells[actualProcID] then
            local isOffensive = true
            if ns.SpellDB and ns.SpellDB.IsOffensive then
                isOffensive = ns.SpellDB.IsOffensive(actualProcID)
            end
            
            local isRedundant = ns.Filter.PlayerHasBuff(actualProcID)
            
            if isOffensive and not isRedundant and not IsBlacklisted(procID) then
                tinsert(blizzSpells, procID)
                addedSpells[procID] = true
                addedSpells[actualProcID] = true
            end
        end
    end

    -- 4. Fill the rest with Blizzard's standard rotation
    if C_AssistedCombat and C_AssistedCombat.GetRotationSpells then
        local rotation = C_AssistedCombat.GetRotationSpells() or {}
        for _, id in ipairs(rotation) do
            local actualID = ns.API.GetActualSpellID(id)
            
            if not addedSpells[id] and not addedSpells[actualID] and not IsBlacklisted(id) then
                tinsert(blizzSpells, id)
                addedSpells[id] = true
                addedSpells[actualID] = true
            end
        end
    end

    return blizzSpells
end