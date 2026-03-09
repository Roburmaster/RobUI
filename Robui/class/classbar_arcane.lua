-- class/classbar_arcane.lua
-- Arcane Mage pips (Arcane Charges)
-- Midnight-safe layout: never sizes off holder:GetWidth() at build time.
-- Re-layouts on holder size changes so it can't "lock" into wrong widths.

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["MAGE"] = function(holder)
    -- Only Arcane should show pips (specID 62)
    local SPEC_ARCANE = 62

    local function GetSpecID()
        if not GetSpecialization or not GetSpecializationInfo then return nil end
        local idx = GetSpecialization()
        if not idx then return nil end
        return GetSpecializationInfo(idx)
    end

    local function IsArcane()
        return GetSpecID() == SPEC_ARCANE
    end

    -- =========================================================
    -- Frame
    -- =========================================================
    local f = CreateFrame("Frame", nil, holder)
    f:SetAllPoints(holder)
    f:Hide()

    -- Background (subtle, to see holder bounds)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.15)

    -- =========================================================
    -- Segments (4 charges)
    -- =========================================================
    local SEG_COUNT = 4
    local GAP = 3

    local segs = {}
    for i = 1, SEG_COUNT do
        local seg = CreateFrame("StatusBar", nil, f, "BackdropTemplate")
        seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        seg:SetMinMaxValues(0, 1)
        seg:SetValue(0)

        -- Arcane-ish color
        seg:SetStatusBarColor(0.2, 0.6, 1.0, 0.95)

        -- Border/backdrop
        if seg.SetBackdrop then
            seg:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            seg:SetBackdropColor(0,0,0,0.25)
            seg:SetBackdropBorderColor(0,0,0,1)
        end

        local fill = seg:GetStatusBarTexture()
        if fill then
            fill:SetHorizTile(false)
            fill:SetVertTile(false)
        end

        segs[i] = seg
    end

    -- Relayout based on current size (NO holder:GetWidth() at build-time)
    local function Layout()
        local w = f:GetWidth() or 0
        local h = f:GetHeight() or 0
        if w <= 1 or h <= 1 then return end

        local totalGap = GAP * (SEG_COUNT - 1)
        local segW = (w - totalGap) / SEG_COUNT
        if segW < 1 then segW = 1 end

        for i = 1, SEG_COUNT do
            local seg = segs[i]
            seg:ClearAllPoints()
            if i == 1 then
                seg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            else
                seg:SetPoint("TOPLEFT", segs[i-1], "TOPRIGHT", GAP, 0)
            end
            seg:SetSize(segW, h)
        end
    end

    f:SetScript("OnSizeChanged", function()
        Layout()
    end)

    -- =========================================================
    -- Value update (Arcane Charges)
    -- =========================================================
    local POW_ARCANE_CHARGES = (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges) or 16

    local function GetCharges()
        -- Safe fallbacks
        local cur = UnitPower("player", POW_ARCANE_CHARGES) or 0
        local max = UnitPowerMax("player", POW_ARCANE_CHARGES) or SEG_COUNT
        if max <= 0 then max = SEG_COUNT end
        if cur < 0 then cur = 0 end
        if cur > max then cur = max end
        return cur, max
    end

    local function Update()
        if not IsArcane() then
            f:Hide()
            return
        end

        f:Show()
        Layout()

        local cur = GetCharges()
        for i = 1, SEG_COUNT do
            segs[i]:SetValue(i <= cur and 1 or 0)
        end
    end

    -- =========================================================
    -- Events
    -- =========================================================
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("UNIT_DISPLAYPOWER")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")

    ev:SetScript("OnEvent", function(_, event, unit, powToken)
        if unit and unit ~= "player" then return end

        -- Filter power updates if token provided
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            -- Sometimes token comes as string; don't rely on it being stable
            -- Just update (cheap: 4 bars)
            Update()
            return
        end

        Update()
    end)

    -- Deferred init (spec/size not always ready on the first tick)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, Update)
        C_Timer.After(0.30, Update)
    else
        Update()
    end

    return f
end