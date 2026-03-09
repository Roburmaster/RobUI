-- ============================================================================
-- Robui/UI/PipVisibility.lua  (Midnight-safe)
--
-- PURPOSE:
--   Controls whether the PlayerFrame pips-holder (RobUI_PlayerPips) should be shown
--   based on class + spec, while always respecting the user's setting (pipEnabled).
--
-- IMPORTANT:
--   - If spec is NOT ready yet (login/entering world), we do NOT force hide/show.
--     We retry shortly after to avoid "micro-blink" and wrong state.
--   - If pips frame is NOT created yet, we also retry (this was the DH bug).
--   - If spec IS known and not allowed => we hide.
--   - If allowed => we show.
-- ============================================================================

local AddonName, ns = ...
local R = _G.Robui

ns.UI = ns.UI or {}
ns.UI.PipVisibility = ns.UI.PipVisibility or {}
local M = ns.UI.PipVisibility

local pcall = pcall
local CreateFrame = CreateFrame
local UnitClass = UnitClass

-- ============================================================
-- CONFIG
-- ============================================================
local SPEC = {
    DRUID_FERAL      = 103,
    MAGE_ARCANE      = 62,
    SHAMAN_ELEMENTAL = 262,
    DH_DEVOURER      = 1480, -- Devourer (Midnight) :contentReference[oaicite:0]{index=0}
}

-- Classes that should ALWAYS show pips (when pipEnabled=true)
local ALWAYS_ON = {
    WARLOCK     = true, -- Soul Shards
    ROGUE       = true, -- Combo Points
    PALADIN     = true, -- Holy Power
    MONK        = true, -- Chi
    DEATHKNIGHT = true, -- Runes
    EVOKER      = true, -- Essence
}

-- Classes where ONLY specific specs should show pips
local SPEC_ONLY = {
    DRUID       = { [SPEC.DRUID_FERAL] = true },
    MAGE        = { [SPEC.MAGE_ARCANE] = true },
    SHAMAN      = { [SPEC.SHAMAN_ELEMENTAL] = true },
    DEMONHUNTER = { [SPEC.DH_DEVOURER] = true },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function GetPlayerClassToken()
    local _, classToken = UnitClass("player")
    return classToken
end

local function GetPlayerSpecInfo()
    if not GetSpecialization or not GetSpecializationInfo then return nil end
    local idx = GetSpecialization()
    if not idx then return nil end
    local specID, specName = GetSpecializationInfo(idx)
    return specID, specName
end

-- Returns:
--   true  => allowed (show)
--   false => not allowed (hide)
--   nil   => spec not ready (do nothing, retry later)
local function ShouldShowByClassSpec()
    local class = GetPlayerClassToken()
    if not class then return nil end

    if ALWAYS_ON[class] then
        return true
    end

    local specID, specName = GetPlayerSpecInfo()
    if not specID then
        return nil -- spec not ready yet
    end

    if class == "SHAMAN" then
        return (specID == SPEC.SHAMAN_ELEMENTAL) and true or false
    end

    if class == "DEMONHUNTER" then
        -- Primary: by ID (stable, non-localized)
        if specID == SPEC.DH_DEVOURER then
            return true
        end
        -- Fallback: by name (localized risk, but harmless)
        if type(specName) == "string" and specName:lower() == "devourer" then
            return true
        end
        return false
    end

    local allow = SPEC_ONLY[class]
    if allow then
        return allow[specID] and true or false
    end

    return false
end

local function GetPlayerDB()
    if not (R and R.Database and R.Database.profile) then return nil end
    local uf = R.Database.profile.unitframes
    return uf and uf.player or nil
end

-- ============================================================
-- RETRY CORE (frame missing OR spec not ready)
-- ============================================================
M.__tok = 0
M.__tries = 0

function M:RetrySoon()
    self.__tok = (self.__tok or 0) + 1
    local tok = self.__tok

    self.__tries = (self.__tries or 0) + 1
    if self.__tries > 50 then
        -- stop hard looping; events + deferred init will re-trigger later
        self.__tries = 0
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.20, function()
            if M.__tok ~= tok then return end
            M:ApplyOverride()
        end)
    end
end

-- ============================================================
-- CORE
-- ============================================================
function M:ApplyOverride()
    local db = GetPlayerDB()
    if not db then
        -- profile not ready yet; retry
        self:RetrySoon()
        return
    end

    local pipsFrame = _G["RobUI_PlayerPips"]
    if not pipsFrame then
        -- IMPORTANT FIX:
        -- PlayerFrame might create RobUI_PlayerPips after this module runs.
        -- If we just return here, DH/others can get stuck hidden forever.
        self:RetrySoon()
        return
    end

    -- Respect user's setting first
    if not db.pipEnabled then
        pipsFrame:Hide()
        return
    end

    local should = ShouldShowByClassSpec()

    if should == true then
        pipsFrame:Show()
        return
    end

    if should == false then
        pipsFrame:Hide()
        return
    end

    -- should == nil => spec not ready yet
    self:RetrySoon()
end

function M:Initialize()
    if self.__inited then return end
    self.__inited = true

    local ev = CreateFrame("Frame")
    self.__ev = ev

    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_TALENT_UPDATE")
    ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    ev:RegisterEvent("UNIT_ENTERED_VEHICLE")
    ev:RegisterEvent("UNIT_EXITED_VEHICLE")

    if ev.RegisterEvent then
        pcall(ev.RegisterEvent, ev, "TRAIT_CONFIG_UPDATED")
        pcall(ev.RegisterEvent, ev, "TRAIT_TREE_CHANGED")
    end

    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
        M.__tries = 0
        M:ApplyOverride()
    end)

    -- defer: let PlayerFrame + DB settle
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function() M.__tries = 0; M:ApplyOverride() end)
        C_Timer.After(1.00, function() M.__tries = 0; M:ApplyOverride() end)
        C_Timer.After(2.00, function() M.__tries = 0; M:ApplyOverride() end)
    else
        self.__tries = 0
        self:ApplyOverride()
    end
end

-- Auto-start when addon loads
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, arg1)
    if arg1 == AddonName then
        M:Initialize()
    end
end)