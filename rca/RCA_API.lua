-- ============================================================================
-- RCA_API.lua
-- Core API wrappers for WoW 12.0+ (Midnight) compatibility.
-- ============================================================================

local AddonName, ns = ...
ns.API = {}

local type = type
local GetTime = GetTime
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetItemSpell = GetItemSpell

-- O(1) sjekk uten pcall closure (Sparer Garbage Collection CPU)
function ns.API.IsSecret(val)
    if issecretvalue and issecretvalue(val) then 
        return true 
    end
    return false
end

function ns.API.GetActualSpellID(spellID)
    if not spellID or spellID <= 0 then return spellID end
    local override = spellID
    
    if C_Spell and C_Spell.GetOverrideSpell then
        override = C_Spell.GetOverrideSpell(spellID)
    elseif FindSpellOverrideByID then
        override = FindSpellOverrideByID(spellID)
    end
    
    return override or spellID
end

function ns.API.IsSpellReadySafe(spellID)
    if not spellID then return false end

    local startTime, duration = 0, 0
    
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo then
            startTime = cdInfo.startTime
            duration = cdInfo.duration
        end
    end

    local isSecretDuration = ns.API.IsSecret(duration)

    if not isSecretDuration and (not duration or duration <= 0) then
        for slot = 1, 19 do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                local _, itemSpellID = GetItemSpell(itemID)
                if itemSpellID == spellID then
                    local itemStart, itemDur = GetInventoryItemCooldown("player", slot)
                    if itemStart and itemDur then
                        startTime, duration = itemStart, itemDur
                        isSecretDuration = ns.API.IsSecret(duration)
                        break
                    end
                end
            end
        end
    end

    if ns.API.IsSecret(startTime) or isSecretDuration then 
        return true 
    end

    if type(startTime) == "number" and type(duration) == "number" then
        if duration <= 1.5 then return true end
        return startTime == 0 or (startTime + duration) <= GetTime()
    end
    
    return true
end

function ns.API.IsSpellUsableSafe(spellID)
    if not spellID then return false, false end

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spellID)
        if ok then
            if ns.API.IsSecret(usable) or ns.API.IsSecret(noMana) then
                return true, false
            end
            return usable, noMana
        end
    end
    
    local ok, usable, noMana = pcall(IsUsableSpell, spellID)
    if ok then return usable, noMana end
    
    return true, false
end

function ns.API.GetHealthPctSafe()
    local hp = UnitHealth("player")
    local maxHp = UnitHealthMax("player")

    if ns.API.IsSecret(hp) or ns.API.IsSecret(maxHp) then
        local lhf = LowHealthFrame
        if lhf and lhf:IsShown() then
            local alpha = lhf:GetAlpha() or 0
            if ns.API.IsSecret(alpha) then return 1.0 end
            if alpha > 0.5 then 
                return 0.30 
            else 
                return 0.50 
            end
        end
        return 1.0 
    end

    if maxHp and maxHp > 0 then
        return hp / maxHp
    end
    
    return 1.0
end