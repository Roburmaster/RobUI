-- class/classbar_monk.lua
-- Monk Classbar (fixed sizing / reflow-safe):
-- - Windwalker: Chi pips (dynamic layout, supports 4/5/6)
-- - Brewmaster: single Stagger bar
-- - Mistweaver: hides classbar
--
-- Fixes:
--  - Never compute segment widths once at build time.
--  - Layout() runs on holder size changes and when max chi changes.
--  - Segments are built BEFORE any layout (fixes nil seg crash).

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["MONK"] = function(holder)
    local C_Timer = C_Timer
    local POW_CHI = (Enum and Enum.PowerType and Enum.PowerType.Chi) or 12

    ------------------------------------------------------------------------
    -- Shared state
    ------------------------------------------------------------------------
    local Root = CreateFrame("Frame", nil, holder)
    Root:SetAllPoints(holder)
    Root:SetFrameStrata(holder:GetFrameStrata() or "HIGH")
    Root:SetFrameLevel((holder:GetFrameLevel() or 0) + 5)

    local Chi = CreateFrame("Frame", nil, Root)
    Chi:SetAllPoints(Root)
    Chi.segs = {}
    Chi.maxBuilt = 6
    Chi.activeMax = 0

    local Stagger = CreateFrame("StatusBar", nil, Root, "BackdropTemplate")
    Stagger:SetAllPoints(Root)
    Stagger:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    Stagger:Hide()

    local StaggerBG = Stagger:CreateTexture(nil, "BACKGROUND")
    StaggerBG:SetAllPoints(Stagger)
    StaggerBG:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    StaggerBG:SetVertexColor(.1, .1, .1, 1)

    ------------------------------------------------------------------------
    -- Spec helpers
    ------------------------------------------------------------------------
    local function GetMonkSpecID()
        local idx = GetSpecialization()
        return idx and select(1, GetSpecializationInfo(idx)) or nil -- 268/269/270
    end

    local function IsBrewmaster()  return GetMonkSpecID() == 268 end
    local function IsWindwalker()  return GetMonkSpecID() == 269 end

    ------------------------------------------------------------------------
    -- Chi segments (build once up to 6)
    ------------------------------------------------------------------------
    local function EnsureChiSegments()
        if Chi.__built then return end
        Chi.__built = true

        for i = 1, Chi.maxBuilt do
            local seg = CreateFrame("StatusBar", nil, Chi, "BackdropTemplate")
            seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(0)

            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints(seg)
            seg.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            seg.bg:SetVertexColor(.1, .1, .1, 1)

            -- teal-ish gradient across pips (kept from your original)
            if i <= 2 then
                seg:SetStatusBarColor(10/255, 186/255, 181/255, 1)
            elseif i <= 4 then
                seg:SetStatusBarColor(86/255, 223/255, 207/255, 1)
            else -- 5-6
                seg:SetStatusBarColor(173/255, 238/255, 217/255, 1)
            end

            Chi.segs[i] = seg
        end
    end

    local function GetMaxChi()
        local m = UnitPowerMax("player", POW_CHI) or 0
        if m <= 0 then m = 4 end
        if m > Chi.maxBuilt then m = Chi.maxBuilt end
        return m
    end

    local function LayoutChi(maxChi)
        EnsureChiSegments()

        maxChi = tonumber(maxChi) or 4
        if maxChi < 1 then maxChi = 1 end
        if maxChi > Chi.maxBuilt then maxChi = Chi.maxBuilt end

        local w = Root:GetWidth() or 0
        local h = Root:GetHeight() or 0
        if w <= 1 or h <= 1 then return end

        local spacing = 4
        local totalGap = spacing * (maxChi - 1)
        local segW = (w - totalGap) / maxChi
        if segW < 1 then segW = 1 end

        for i = 1, Chi.maxBuilt do
            local seg = Chi.segs[i]
            if seg then
                seg:ClearAllPoints()

                if i <= maxChi then
                    seg:SetSize(segW, h)
                    seg:Show()

                    if i == 1 then
                        seg:SetPoint("LEFT", Chi, "LEFT", 0, 0)
                    else
                        seg:SetPoint("LEFT", Chi.segs[i - 1], "RIGHT", spacing, 0)
                    end
                else
                    seg:Hide()
                end
            end
        end

        Chi.activeMax = maxChi
    end

    local function FillChi()
        if not IsWindwalker() then return end
        EnsureChiSegments()

        local maxChi = GetMaxChi()
        if Chi.activeMax ~= maxChi then
            LayoutChi(maxChi)
        end

        local cur = UnitPower("player", POW_CHI) or 0
        if cur < 0 then cur = 0 end
        if cur > maxChi then cur = maxChi end

        for i = 1, maxChi do
            local seg = Chi.segs[i]
            if seg then
                seg:SetValue(i <= cur and 1 or 0)
            end
        end
    end

    ------------------------------------------------------------------------
    -- Stagger (Brewmaster)
    ------------------------------------------------------------------------
    local function GetStaggerColors()
        local pb = PowerBarColor and PowerBarColor["STAGGER"]
        if pb and pb[1] and pb[2] and pb[3] then
            return pb[1], pb[2], pb[3] -- light/moderate/heavy {r,g,b}
        end
        return
            { r = 0.52, g = 1.00, b = 0.52 },
            { r = 1.00, g = 0.98, b = 0.72 },
            { r = 1.00, g = 0.42, b = 0.42 }
    end

    local lightC, moderateC, heavyC = GetStaggerColors()
    local LIGHT_T    = 0.30
    local MODERATE_T = 0.60

    local function UpdateStagger()
        if not IsBrewmaster() then return end

        local stagger = UnitStagger("player") or 0
        local hpMax   = UnitHealthMax("player") or 1
        if hpMax <= 0 then hpMax = 1 end

        local pct = stagger / hpMax
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end

        Stagger:SetMinMaxValues(0, 1)
        Stagger:SetValue(pct)

        if pct < LIGHT_T then
            Stagger:SetStatusBarColor(lightC.r, lightC.g, lightC.b, 1)
        elseif pct < MODERATE_T then
            Stagger:SetStatusBarColor(moderateC.r, moderateC.g, moderateC.b, 1)
        else
            Stagger:SetStatusBarColor(heavyC.r, heavyC.g, heavyC.b, 1)
        end
    end

    ------------------------------------------------------------------------
    -- Swap active bar based on spec
    ------------------------------------------------------------------------
    local function ApplyActiveBar()
        if IsBrewmaster() then
            Chi:Hide()
            Stagger:Show()
            UpdateStagger()
        elseif IsWindwalker() then
            EnsureChiSegments()
            Stagger:Hide()
            Chi:Show()
            LayoutChi(GetMaxChi())
            FillChi()
        else
            Stagger:Hide()
            Chi:Hide()
        end
    end

    ------------------------------------------------------------------------
    -- Reflow-safe: re-layout on size changes (guarded)
    ------------------------------------------------------------------------
    Root:SetScript("OnSizeChanged", function()
        if IsWindwalker() and Chi:IsShown() then
            if not Chi.__built then return end
            LayoutChi(GetMaxChi())
            FillChi()
        elseif IsBrewmaster() and Stagger:IsShown() then
            UpdateStagger()
        end
    end)

    ------------------------------------------------------------------------
    -- Events
    ------------------------------------------------------------------------
    local evt = CreateFrame("Frame")
    evt:RegisterEvent("PLAYER_LOGIN")
    evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    evt:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    evt:RegisterEvent("PLAYER_TALENT_UPDATE")
    evt:RegisterUnitEvent("UNIT_POWER_UPDATE",   "player")
    evt:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    evt:RegisterUnitEvent("UNIT_MAXPOWER",       "player")
    evt:RegisterUnitEvent("UNIT_POWER_BAR_SHOW", "player")
    evt:RegisterUnitEvent("UNIT_AURA",           "player")
    evt:RegisterUnitEvent("UNIT_HEALTH",         "player")
    evt:RegisterUnitEvent("UNIT_MAXHEALTH",      "player")

    evt:SetScript("OnEvent", function(_, event, unit, powerToken)
        if unit and unit ~= "player" then return end

        if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then
            ApplyActiveBar()
            return
        end

        if (event == "UNIT_MAXPOWER" or event == "UNIT_POWER_BAR_SHOW") then
            if IsWindwalker() then
                EnsureChiSegments()
                LayoutChi(GetMaxChi())
                FillChi()
            end
            return
        end

        if (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") then
            if IsWindwalker() then
                FillChi()
            end
            return
        end

        if event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            if IsBrewmaster() then
                UpdateStagger()
            end
            return
        end
    end)

    -- Deferred init (spec/size not ready instantly)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, ApplyActiveBar)
        C_Timer.After(0.30, ApplyActiveBar)
    else
        ApplyActiveBar()
    end

    return Root
end