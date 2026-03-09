-- ============================================================================
-- RCA_Filter.lua
-- Redundancy filtering and Pandemic Window (30%) logic.
-- ============================================================================

local AddonName, ns = ...
ns.Filter = {}

local GetTime = GetTime
local C_UnitAuras = C_UnitAuras
local wipe = wipe

-- O(1) Aura cache to prevent looping 40 buffs multiple times per frame
local auraCache = {}
local lastAuraUpdate = 0

local function RefreshAuras()
    local now = GetTime()
    if now == lastAuraUpdate then return end 
    
    wipe(auraCache)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            
            -- Store safely, avoiding secret values
            if not ns.API.IsSecret(aura.spellId) then
                auraCache[aura.spellId] = aura
            end
        end
    end
    lastAuraUpdate = now
end

local function IsAuraRedundant(aura)
    if not aura then return false end
    
    local dur = aura.duration
    local exp = aura.expirationTime
    
    if not dur or dur == 0 or ns.API.IsSecret(dur) or ns.API.IsSecret(exp) then 
        return true 
    end
    
    local remaining = exp - GetTime()
    if remaining < (dur * 0.3) then
        return false -- Pandemic window active: needs refresh
    end
    
    return true
end

function ns.Filter.PlayerHasBuff(targetID)
    if not targetID or targetID <= 0 then return false end
    
    -- Build cache exactly once per frame
    RefreshAuras()
    
    -- O(1) lookup
    local aura = auraCache[targetID]
    if aura then
        return IsAuraRedundant(aura)
    end
    
    return false
end