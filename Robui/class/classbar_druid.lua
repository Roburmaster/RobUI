-- class/classbar_druid.lua
-- Druid Combo Point pips (FERAL only)
-- Fix: dynamic Layout() on size changes; never lock widths at build time.

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["DRUID"] = function(holder)
    local SPEC_FERAL = 103
    local POW_CP = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4

    -- Container
    local DP = CreateFrame("Frame", nil, holder)
    DP:SetAllPoints(holder)
    DP:SetFrameStrata(holder:GetFrameStrata() or "HIGH")
    DP:SetFrameLevel((holder:GetFrameLevel() or 0) + 5)
    DP:Hide()

    local spacing = 4
    local MAX_SEG = 6 -- build up to 6 so we can show 5 or 6 depending on UnitPowerMax

    -- Colors for each point (1..6)
    local cpColors = {
        {1.00, 0.00, 0.00}, -- red
        {0.60, 0.30, 0.00}, -- brown
        {0.90, 0.70, 0.00}, -- dark yellow
        {0.00, 0.80, 0.20}, -- green
        {0.00, 0.50, 0.10}, -- dark green
        {0.20, 0.90, 0.90}, -- extra (cyan-ish) for 6th
    }

    -- Build segments (hidden/unused ones can be toggled)
    DP.segs = {}
    for i = 1, MAX_SEG do
        local bar = CreateFrame("StatusBar", nil, DP, "BackdropTemplate")
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetReverseFill(true)

        local c = cpColors[i] or {1,1,1}
        bar:SetStatusBarColor(c[1], c[2], c[3], 1)

        -- Background
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar.bg:SetVertexColor(0.05, 0.05, 0.05, 1)

        -- Thin black top line
        bar.TopLine = bar:CreateTexture(nil, "OVERLAY")
        bar.TopLine:SetColorTexture(0, 0, 0, 1)
        bar.TopLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.TopLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        bar.TopLine:SetHeight(1)

        -- Glow overlay (fake bloom)
        bar.Glow = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        bar.Glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        bar.Glow:SetPoint("TOPLEFT", bar, "TOPLEFT", -10, 6)
        bar.Glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 10, -6)
        bar.Glow:SetBlendMode("ADD")
        bar.Glow:SetAlpha(0.8)
        bar.Glow:Hide()

        DP.segs[i] = bar
    end

    -- Spec helper (use specID, not spec index)
    local function GetSpecID()
        if not GetSpecialization or not GetSpecializationInfo then return nil end
        local idx = GetSpecialization()
        if not idx then return nil end
        return GetSpecializationInfo(idx)
    end

    local function IsFeral()
        return GetSpecID() == SPEC_FERAL
    end

    -- Layout segments based on current DP size
    local function Layout(maxCP)
        local w = DP:GetWidth() or 0
        local h = DP:GetHeight() or 0
        if w <= 1 or h <= 1 then return end

        maxCP = tonumber(maxCP) or 5
        if maxCP < 1 then maxCP = 1 end
        if maxCP > MAX_SEG then maxCP = MAX_SEG end

        local totalGap = spacing * (maxCP - 1)
        local segW = (w - totalGap) / maxCP
        if segW < 1 then segW = 1 end

        for i = 1, MAX_SEG do
            local bar = DP.segs[i]
            bar:ClearAllPoints()

            if i <= maxCP then
                bar:SetSize(segW, h)
                bar:Show()

                if i == 1 then
                    bar:SetPoint("LEFT", DP, "LEFT", 0, 0)
                else
                    bar:SetPoint("LEFT", DP.segs[i - 1], "RIGHT", spacing, 0)
                end
            else
                bar:Hide()
            end
        end
    end

    -- Update values
    local function Update()
        if not IsFeral() then
            DP:Hide()
            return
        end

        DP:Show()

        local maxCP = UnitPowerMax("player", POW_CP) or 5
        if maxCP <= 0 then maxCP = 5 end
        if maxCP > MAX_SEG then maxCP = MAX_SEG end

        Layout(maxCP)

        local cur = UnitPower("player", POW_CP) or 0
        if cur < 0 then cur = 0 end
        if cur > maxCP then cur = maxCP end

        for i = 1, maxCP do
            local bar = DP.segs[i]
            if i <= cur then
                bar:SetValue(1)
                bar.Glow:Show()
            else
                bar:SetValue(0)
                bar.Glow:Hide()
            end
        end
    end

    -- Relayout on size changes (fixes the "wrong in combat/out of combat" look)
    DP:SetScript("OnSizeChanged", function()
        Update()
    end)

    -- Events
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("UNIT_DISPLAYPOWER")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")

    ev:SetScript("OnEvent", function(_, event, unit, powToken)
        if unit and unit ~= "player" then return end

        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            -- Token can be unreliable; update is cheap.
            Update()
            return
        end

        Update()
    end)

    -- Deferred init (spec/size not ready immediately)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, Update)
        C_Timer.After(0.30, Update)
    else
        Update()
    end

    return DP
end