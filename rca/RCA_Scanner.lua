-- ============================================================================
-- RCA_Scanner.lua
-- Highly optimized scanner for Action Bars, Keybinds, Proc Overlays, and Cooldowns.
-- Midnight-safe: avoids direct comparisons on secret values.
-- ============================================================================

local AddonName, ns = ...
ns.Scanner = {}

local GetTime = GetTime
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local CreateFrame = CreateFrame
local wipe = wipe
local C_Timer = C_Timer
local C_Spell = C_Spell
local GetSpellCooldown = GetSpellCooldown
local type = type

local activeProcs = {}
local hotkeyCache = {}
local lastScanTime = 0
local scannerFrame = CreateFrame("Frame")

local GCD_SPELL_ID = 61304

local function IsSecret(v)
    return ns.API and ns.API.IsSecret and ns.API.IsSecret(v) or false
end

local function SafeGetSpellCooldown(spellID)
    if not spellID then
        return 0, 0, 1, false
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            local startTime = info.startTime
            local duration = info.duration
            local isEnabled = info.isEnabled
            local modRate = info.modRate

            if isEnabled == nil then
                isEnabled = true
            end
            if modRate == nil then
                modRate = 1
            end

            return startTime, duration, modRate, isEnabled
        end
    end

    if GetSpellCooldown then
        local startTime, duration, isEnabled, modRate = GetSpellCooldown(spellID)
        return startTime or 0, duration or 0, modRate or 1, isEnabled ~= 0
    end

    return 0, 0, 1, false
end

local function NormalizeRemaining(startTime, duration, now)
    if startTime == nil or duration == nil then
        return 0
    end

    if IsSecret(startTime) or IsSecret(duration) then
        return 0
    end

    if type(startTime) ~= "number" or type(duration) ~= "number" then
        return 0
    end

    if startTime <= 0 or duration <= 0 then
        return 0
    end

    local remaining = (startTime + duration) - now
    if remaining < 0 then
        return 0
    end

    return remaining
end

function ns.Scanner.IsSpellProcced(spellID)
    if not spellID then
        return false
    end

    if activeProcs[spellID] then
        return true
    end

    local actualID = ns.API and ns.API.GetActualSpellID and ns.API.GetActualSpellID(spellID) or spellID
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
                    if cleanKey and cleanKey ~= "" then
                        cleanKey = cleanKey
                            :gsub("CTRL%-", "C")
                            :gsub("ALT%-", "A")
                            :gsub("SHIFT%-", "S")
                            :gsub("NUMPAD", "N")
                            :gsub("STRG%-", "C")

                        hotkeyCache[targetSpellID] = cleanKey

                        local actualID = ns.API and ns.API.GetActualSpellID and ns.API.GetActualSpellID(targetSpellID) or targetSpellID
                        if actualID ~= targetSpellID then
                            hotkeyCache[actualID] = cleanKey
                        end
                    end
                end
            end
        end
    end
end

function ns.Scanner.GetCachedHotkey(spellID)
    if not spellID then
        return ""
    end

    if ns.CONFIG and ns.CONFIG.customBinds and ns.CONFIG.customBinds[spellID] then
        local customBind = ns.CONFIG.customBinds[spellID]
        if customBind ~= "" then
            return customBind
        end
    end

    local actualID = ns.API and ns.API.GetActualSpellID and ns.API.GetActualSpellID(spellID) or spellID
    return hotkeyCache[spellID] or hotkeyCache[actualID] or ""
end

function ns.Scanner.GetGCDInfo()
    local now = GetTime()
    local startTime, duration, modRate, enabled = SafeGetSpellCooldown(GCD_SPELL_ID)
    local remaining = NormalizeRemaining(startTime, duration, now)

    if IsSecret(startTime) then startTime = 0 end
    if IsSecret(duration) then duration = 0 end
    if IsSecret(modRate) then modRate = 1 end

    return {
        startTime = type(startTime) == "number" and startTime or 0,
        duration = type(duration) == "number" and duration or 0,
        modRate = type(modRate) == "number" and modRate or 1,
        enabled = enabled and true or false,
        remaining = remaining,
        active = remaining > 0,
    }
end

function ns.Scanner.GetSpellCooldownInfo(spellID)
    if not spellID then
        return {
            spellID = nil,
            startTime = 0,
            duration = 0,
            modRate = 1,
            enabled = false,
            remaining = 0,
            gcdStartTime = 0,
            gcdDuration = 0,
            gcdRemaining = 0,
            displayStartTime = 0,
            displayDuration = 0,
            displayRemaining = 0,
            isOnCooldown = false,
            isOnGCD = false,
            isBlockedByGCDOnly = false,
        }
    end

    local actualID = ns.API and ns.API.GetActualSpellID and ns.API.GetActualSpellID(spellID) or spellID
    local now = GetTime()

    local spellStart, spellDuration, spellModRate, spellEnabled = SafeGetSpellCooldown(actualID)
    local spellRemaining = NormalizeRemaining(spellStart, spellDuration, now)

    local gcdStart, gcdDuration, gcdModRate, gcdEnabled = SafeGetSpellCooldown(GCD_SPELL_ID)
    local gcdRemaining = NormalizeRemaining(gcdStart, gcdDuration, now)

    if IsSecret(spellStart) or type(spellStart) ~= "number" then spellStart = 0 end
    if IsSecret(spellDuration) or type(spellDuration) ~= "number" then spellDuration = 0 end
    if IsSecret(spellModRate) or type(spellModRate) ~= "number" then spellModRate = 1 end

    if IsSecret(gcdStart) or type(gcdStart) ~= "number" then gcdStart = 0 end
    if IsSecret(gcdDuration) or type(gcdDuration) ~= "number" then gcdDuration = 0 end
    if IsSecret(gcdModRate) or type(gcdModRate) ~= "number" then gcdModRate = 1 end

    local displayStart = spellStart
    local displayDuration = spellDuration
    local displayRemaining = spellRemaining

    local isOnGCD = gcdRemaining > 0
    local isOnCooldown = spellRemaining > 0
    local isBlockedByGCDOnly = false

    if gcdRemaining > spellRemaining then
        displayStart = gcdStart
        displayDuration = gcdDuration
        displayRemaining = gcdRemaining
        isBlockedByGCDOnly = (spellRemaining <= 0 and gcdRemaining > 0)
    end

    return {
        spellID = actualID,

        startTime = spellStart,
        duration = spellDuration,
        modRate = spellModRate,
        enabled = spellEnabled and true or false,
        remaining = spellRemaining,

        gcdStartTime = gcdStart,
        gcdDuration = gcdDuration,
        gcdModRate = gcdModRate,
        gcdEnabled = gcdEnabled and true or false,
        gcdRemaining = gcdRemaining,

        displayStartTime = displayStart,
        displayDuration = displayDuration,
        displayRemaining = displayRemaining,

        isOnCooldown = isOnCooldown,
        isOnGCD = isOnGCD,
        isBlockedByGCDOnly = isBlockedByGCDOnly,
    }
end

scannerFrame:RegisterEvent("PLAYER_LOGIN")
scannerFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
scannerFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
scannerFrame:RegisterEvent("UPDATE_BINDINGS")
scannerFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
scannerFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

scannerFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        if spellID then
            activeProcs[spellID] = true
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        if spellID then
            activeProcs[spellID] = nil
        end

    elseif event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BINDINGS"
        or event == "PLAYER_LOGIN" then

        local now = GetTime()
        if (now - lastScanTime) > 1.0 then
            lastScanTime = now
            C_Timer.After(0.2, ns.Scanner.UpdateActionBarCache)
        end
    end
end)
