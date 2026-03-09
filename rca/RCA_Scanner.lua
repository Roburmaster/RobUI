-- ============================================================================
-- RCA_Scanner.lua
-- Highly optimized scanner for Action Bars, Keybinds, and Proc Overlays.
-- ============================================================================

local AddonName, ns = ...
ns.Scanner = {}

local GetTime = GetTime
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local wipe = wipe

local activeProcs = {}
local hotkeyCache = {}
local lastScanTime = 0
local scannerFrame = CreateFrame("Frame")

function ns.Scanner.IsSpellProcced(spellID)
    if not spellID then return false end
    if activeProcs[spellID] then return true end
    
    local actualID = ns.API.GetActualSpellID(spellID)
    if actualID ~= spellID and activeProcs[actualID] then
        return true
    end
    return false
end

function ns.Scanner.GetActiveProcs()
    return activeProcs
end

local function GetSlotBindingName(slot)
    if slot >= 1 and slot <= 12 then return "ACTIONBUTTON" .. slot end
    if slot >= 25 and slot <= 36 then return "MULTIACTIONBAR3BUTTON" .. (slot - 24) end
    if slot >= 37 and slot <= 48 then return "MULTIACTIONBAR4BUTTON" .. (slot - 36) end
    if slot >= 49 and slot <= 60 then return "MULTIACTIONBAR2BUTTON" .. (slot - 48) end
    if slot >= 61 and slot <= 72 then return "MULTIACTIONBAR1BUTTON" .. (slot - 60) end
    if slot >= 73 and slot <= 84 then return "MULTIACTIONBAR5BUTTON" .. (slot - 72) end
    if slot >= 85 and slot <= 96 then return "MULTIACTIONBAR6BUTTON" .. (slot - 84) end
    if slot >= 97 and slot <= 108 then return "MULTIACTIONBAR7BUTTON" .. (slot - 96) end
    return nil
end

function ns.Scanner.UpdateActionBarCache()
    wipe(hotkeyCache)

    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        local targetSpellID = nil

        if actionType == "spell" and id then
            targetSpellID = id
        elseif actionType == "macro" and id then
            local mSpell = GetMacroSpell(id)
            if mSpell then
                targetSpellID = mSpell
            end
        end

        if targetSpellID then
            local bindName = GetSlotBindingName(slot)
            if bindName then
                local key = GetBindingKey(bindName)
                if key then
                    local cleanKey = GetBindingText(key)
                    cleanKey = cleanKey
                        :gsub("CTRL%-", "C")
                        :gsub("ALT%-", "A")
                        :gsub("SHIFT%-", "S")
                        :gsub("NUMPAD", "N")
                        :gsub("STRG%-", "C")
                    
                    hotkeyCache[targetSpellID] = cleanKey
                    local actualID = ns.API.GetActualSpellID(targetSpellID)
                    if actualID ~= targetSpellID then
                        hotkeyCache[actualID] = cleanKey
                    end
                end
            end
        end
    end
end

function ns.Scanner.GetCachedHotkey(spellID)
    if not spellID then return "" end
    
    if ns.CONFIG and ns.CONFIG.customBinds and ns.CONFIG.customBinds[spellID] then
        local customBind = ns.CONFIG.customBinds[spellID]
        if customBind ~= "" then
            return customBind
        end
    end

    local actualID = ns.API.GetActualSpellID(spellID)
    return hotkeyCache[spellID] or hotkeyCache[actualID] or ""
end

scannerFrame:RegisterEvent("PLAYER_LOGIN")
scannerFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
scannerFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
scannerFrame:RegisterEvent("UPDATE_BINDINGS")
scannerFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
scannerFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

scannerFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        if spellID then activeProcs[spellID] = true end
        
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        if spellID then activeProcs[spellID] = nil end
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BINDINGS" or event == "PLAYER_LOGIN" then
        local now = GetTime()
        if (now - lastScanTime) > 1.0 then
            lastScanTime = now
            C_Timer.After(0.2, ns.Scanner.UpdateActionBarCache)
        end
    end
end)