-- class/classbar_demonhunter.lua
-- Demon Hunter Classbar:
-- - Devourer: Souls bar (up to 35) and 3 Voidfall pips layered above
-- - Vengeance/Havoc: Hides classbar (assuming standard UI handles them or no bar needed)
-- NOTE: Only position/behavior inside this module is touched. Playerframe code is untouched.

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["DEMONHUNTER"] = function(holder)
    local C_Timer = C_Timer

    ------------------------------------------------------------------------
    -- Shared state
    ------------------------------------------------------------------------
    -- Main Souls Bar (Devourer)
    local SoulsBar = CreateFrame("StatusBar", nil, holder, "BackdropTemplate")
    SoulsBar:SetAllPoints(holder)
    SoulsBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    SoulsBar:SetStatusBarColor(0.40, 0.10, 0.60, 1) -- Void purple color
    SoulsBar:Hide()

    local SoulsBG = SoulsBar:CreateTexture(nil, "BACKGROUND")
    SoulsBG:SetAllPoints(SoulsBar)
    SoulsBG:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    SoulsBG:SetVertexColor(0.1, 0.1, 0.1, 1)

    -- Voidfall Pips (Devourer)
    local Voidfall = CreateFrame("Frame", nil, holder)
    -- Position slightly above the main holder frame
    Voidfall:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 4)
    Voidfall:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 4)
    Voidfall:SetHeight(8) 
    Voidfall.segs = {}
    Voidfall:Hide()

    local MAX_VOIDFALL = 3
    local VOIDFALL_AURA_ID = 123456 -- TODO: Update with actual spell ID for Voidfall

    ------------------------------------------------------------------------
    -- Spec helpers
    ------------------------------------------------------------------------
    local function GetDHSpecID()
        local idx = GetSpecialization()
        return idx and select(1, GetSpecializationInfo(idx)) or nil
    end

    local function IsDevourer()
        -- Placeholder ID for Devourer. (Havoc = 577, Vengeance = 581)
        return GetDHSpecID() == 582 
    end

    ------------------------------------------------------------------------
    -- Voidfall (3 Pips)
    ------------------------------------------------------------------------
    local function BuildVoidfall()
        local spacing = 4
        local totalW  = holder:GetWidth()
        local segW    = (totalW - (MAX_VOIDFALL - 1) * spacing) / MAX_VOIDFALL
        local height  = Voidfall:GetHeight()

        for i = 1, MAX_VOIDFALL do
            local seg = CreateFrame("StatusBar", nil, Voidfall, "BackdropTemplate")
            seg:SetSize(segW, height)
            seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            seg:SetStatusBarColor(0.80, 0.20, 0.80, 1) -- Bright magenta for active stacks

            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints(seg)
            seg.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            seg.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

            if i == 1 then
                seg:SetPoint("LEFT", Voidfall, "LEFT", 0, 0)
            else
                seg:SetPoint("LEFT", Voidfall.segs[i - 1], "RIGHT", spacing, 0)
            end

            seg:SetMinMaxValues(0, 1)
            seg:SetValue(0)
            Voidfall.segs[i] = seg
        end
    end
    BuildVoidfall()

    local function UpdateVoidfall()
        local stacks = 0
        -- Check aura applications for Voidfall
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(VOIDFALL_AURA_ID)
        if auraData then
            stacks = auraData.applications or 1
        end

        for i, seg in ipairs(Voidfall.segs) do
            seg:SetValue(i <= stacks and 1 or 0)
        end
    end

    ------------------------------------------------------------------------
    -- Souls Bar
    ------------------------------------------------------------------------
    local function UpdateSouls()
        -- Assuming Souls track via an Alternate Power type. 
        -- If tracked via aura, switch to C_UnitAuras logic.
        local maxSouls = UnitPowerMax("player", Enum.PowerType.Alternate) or 35
        if maxSouls < 1 then maxSouls = 35 end

        local currentSouls = UnitPower("player", Enum.PowerType.Alternate) or 0
        
        SoulsBar:SetMinMaxValues(0, maxSouls)
        SoulsBar:SetValue(currentSouls)
    end

    ------------------------------------------------------------------------
    -- Swap active bar based on spec
    ------------------------------------------------------------------------
    local function ApplyActiveBar()
        if IsDevourer() then
            SoulsBar:Show()
            Voidfall:Show()
            UpdateSouls()
            UpdateVoidfall()
        else
            -- Hide for other specs (or implement Havoc/Vengeance logic here later)
            SoulsBar:Hide()
            Voidfall:Hide()
        end
    end

    ------------------------------------------------------------------------
    -- Events
    ------------------------------------------------------------------------
    local evt = CreateFrame("Frame")
    evt:RegisterEvent("PLAYER_LOGIN")
    evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    evt:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    evt:RegisterEvent("PLAYER_TALENT_UPDATE")
    evt:RegisterUnitEvent("UNIT_POWER_UPDATE",   "player")
    evt:RegisterUnitEvent("UNIT_MAXPOWER",       "player")
    evt:RegisterUnitEvent("UNIT_AURA",           "player")

    evt:SetScript("OnEvent", function(self, event, unit, powerToken)
        if unit and unit ~= "player" then return end

        if event == "PLAYER_LOGIN"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_SPECIALIZATION_CHANGED"
            or event == "PLAYER_TALENT_UPDATE" then
            ApplyActiveBar()

        elseif event == "UNIT_MAXPOWER" and IsDevourer() then
            UpdateSouls()

        elseif event == "UNIT_POWER_UPDATE" then
            -- Optional: Add specific powerToken check (e.g., "ALTERNATE") to optimize
            if IsDevourer() then
                UpdateSouls()
            end

        elseif event == "UNIT_AURA" then
            if IsDevourer() then
                UpdateVoidfall()
            end
        end
    end)

    C_Timer.After(0.10, function()
        ApplyActiveBar()
    end)
end