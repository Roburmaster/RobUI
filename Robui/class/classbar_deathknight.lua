-- class/classbar_deathknight.lua
-- Death Knight Rune bar (deep red) - HOLDER/PIPE VERSION
-- CPU FIX:
--  - No permanent OnUpdate
--  - OnUpdate runs ONLY while at least one rune is cooling down
--  - Throttled updates (20Hz) with minimal text churn
-- This file only provides: ns.classbars["DEATHKNIGHT"](holder)

local ADDON, ns = ...
ns = ns or {}
ns.classbars = ns.classbars or {}

ns.classbars["DEATHKNIGHT"] = function(holder)
    if not holder then return end

    local RK = CreateFrame("Frame", nil, holder)
    RK:SetAllPoints(holder)
    RK:SetFrameStrata("HIGH")
    RK:SetFrameLevel((holder:GetFrameLevel() or 0) + 5)

    local maxRunes = 6
    local spacing  = 2

    local runeColor     = {0.6, 0.0, 0.0}       -- Deep Red
    local backdropColor = {0.15, 0.0, 0.0, 1.0}  -- Dark Red backdrop

    RK.runebars = {}

    -- throttle state
    RK.__acc = 0
    RK.__tickRate = 0.05 -- 20Hz

    local function SafeWipeBars()
        for i = 1, #RK.runebars do
            local b = RK.runebars[i]
            if b then
                b:Hide()
                b:SetParent(nil)
            end
        end
        wipe(RK.runebars)
    end

    local function BuildBars()
        SafeWipeBars()

        local totalW = holder:GetWidth()
        local height = holder:GetHeight()

        if not totalW or totalW <= 1 then totalW = 260 end
        if not height or height <= 1 then height = 18 end

        local segW = (totalW - (maxRunes - 1) * spacing) / maxRunes
        if segW < 6 then segW = 6 end

        for i = 1, maxRunes do
            local bar = CreateFrame("StatusBar", nil, RK, "BackdropTemplate")
            bar:SetSize(segW, height)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetReverseFill(false)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            bar:SetStatusBarColor(unpack(runeColor))

            bar.spark = bar:CreateTexture(nil, "OVERLAY")
            bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            bar.spark:SetSize(10, height + 4)
            bar.spark:SetBlendMode("ADD")
            bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
            bar.spark:Hide()

            bar.bg = bar:CreateTexture(nil, "BACKGROUND")
            bar.bg:SetAllPoints(bar)
            bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bar.bg:SetVertexColor(unpack(backdropColor))

            bar.backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
            bar.backdrop:SetAllPoints(bar)
            bar.backdrop:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 1,
                insets = {left=1, right=1, top=1, bottom=1},
            })
            bar.backdrop:SetBackdropBorderColor(0, 0, 0, 1)

            bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            bar.Text:SetPoint("CENTER")
            bar.Text:SetFont(bar.Text:GetFont(), 10, "OUTLINE")
            bar.Text:SetText("")

            bar.__lastText = "" -- avoid SetText spam

            if i == 1 then
                bar:SetPoint("LEFT", RK, "LEFT", 0, 0)
            else
                bar:SetPoint("LEFT", RK.runebars[i - 1], "RIGHT", spacing, 0)
            end

            RK.runebars[i] = bar
            bar:Show()
        end
    end

    local function SetBarText(bar, txt)
        txt = txt or ""
        if bar.__lastText ~= txt then
            bar.__lastText = txt
            bar.Text:SetText(txt)
        end
    end

    local function AnyCoolingDown()
        for _, bar in ipairs(RK.runebars) do
            if bar and (bar.ready == false) then
                return true
            end
        end
        return false
    end

    local function StartTickerIfNeeded()
        if RK.__ticking then return end
        if AnyCoolingDown() then
            RK.__ticking = true
            RK.__acc = 0
            RK:SetScript("OnUpdate", RK.__OnUpdate)
        end
    end

    local function StopTickerIfPossible()
        if not RK.__ticking then return end
        if not AnyCoolingDown() then
            RK.__ticking = false
            RK:SetScript("OnUpdate", nil)
        end
    end

    local function UpdateAll(snapshotOnly)
        local now = GetTime()
        local shouldTick = false

        for idx, bar in ipairs(RK.runebars) do
            local start, duration, ready = GetRuneCooldown(idx)
            if start and duration then
                bar.start = start
                bar.duration = duration
                bar.ready = (ready and true) or false

                if bar.ready then
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(1)
                    SetBarText(bar, "")
                    bar.spark:Hide()
                else
                    shouldTick = true

                    -- initial snapshot (or full update) for visuals
                    local remain = duration - (now - start)
                    if remain < 0 then remain = 0 end

                    bar:SetMinMaxValues(0, duration)
                    bar:SetValue(duration - remain)

                    if snapshotOnly then
                        -- keep it light on snapshot; OnUpdate will handle text/spark
                        bar.spark:Show()
                    else
                        local txt = (remain > 0) and string.format("%.1f", remain) or ""
                        SetBarText(bar, txt)
                        bar.spark:Show()
                        if bar:GetStatusBarTexture() then
                            bar.spark:ClearAllPoints()
                            bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
                        end
                    end
                end
            end
        end

        if shouldTick then
            StartTickerIfNeeded()
        else
            StopTickerIfPossible()
        end
    end

    -- throttled OnUpdate (assigned after locals exist)
    RK.__OnUpdate = function(self, elapsed)
        self.__acc = (self.__acc or 0) + (elapsed or 0)
        if self.__acc < self.__tickRate then return end
        self.__acc = 0

        local now = GetTime()
        local anyActive = false

        for _, bar in ipairs(self.runebars) do
            if bar and (bar.ready == false) and bar.start and bar.duration then
                local remain = bar.duration - (now - bar.start)
                if remain < 0 then remain = 0 end

                -- still cooling?
                if remain > 0 then
                    anyActive = true
                    bar:SetValue(bar.duration - remain)

                    local txt = string.format("%.1f", remain)
                    SetBarText(bar, txt)

                    local tex = bar:GetStatusBarTexture()
                    if tex then
                        bar.spark:ClearAllPoints()
                        bar.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0)
                    end
                    bar.spark:Show()
                else
                    -- became ready
                    bar.ready = true
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(1)
                    SetBarText(bar, "")
                    bar.spark:Hide()
                end
            end
        end

        if not anyActive then
            self.__ticking = false
            self:SetScript("OnUpdate", nil)
        end
    end

    -- Build now + rebuild when holder becomes sized
    BuildBars()
    UpdateAll(true)

    holder:HookScript("OnSizeChanged", function()
        BuildBars()
        UpdateAll(true)
    end)

    RK:SetScript("OnEvent", function()
        -- event updates are cheap snapshots; OnUpdate handles smooth ticking
        UpdateAll(true)
    end)

    RK:RegisterEvent("PLAYER_ENTERING_WORLD")
    RK:RegisterEvent("RUNE_POWER_UPDATE")
    RK:RegisterEvent("RUNE_TYPE_UPDATE")

    return RK
end
