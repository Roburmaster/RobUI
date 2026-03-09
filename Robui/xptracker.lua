-- =========================================================
-- XPROB - XP Bar + Dropoff (XP/s) + ETA that increases during no-XP time
-- Slash: /rxp
-- Per-character SavedVariable: XPROBDB
-- =========================================================

local ADDON = (select(1, ...))

local DB = { enabled = true }

-- -------------------------
-- Settings
-- -------------------------
local WIDTH  = 280
local HEIGHT = 55
local BAR_H  = 16

local UI_EVERY       = 0.25
local HALF_LIFE_FAST = 15.0   -- Dropoff smoothing (responsive)
local HALF_LIFE_SLOW = 90.0   -- ETA smoothing (stable)
local ETA_MIN_RATE   = 0.05   -- XP/s minimum to compute ETA (avoid insane numbers)
local ETA_MAX_SEC    = 24 * 60 * 60 -- clamp to 24h to avoid runaway display

-- -------------------------
-- Frame
-- -------------------------
local f = CreateFrame("Frame", "XPROB_Frame", UIParent)
f:SetSize(WIDTH, HEIGHT)
f:SetPoint("CENTER", 0, 0)
f:SetFrameStrata("MEDIUM")

f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.bg = f:CreateTexture(nil, "BACKGROUND")
f.bg:SetAllPoints(true)
f.bg:SetColorTexture(0, 0, 0, 0.6)

f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
f.close:SetPoint("TOPRIGHT", 2, 2)
f.close:SetScale(0.85)
f.close:SetScript("OnClick", function()
    DB.enabled = false
    f:Hide()
    print("XPROB: Disabled (saved)")
end)

f.barBG = f:CreateTexture(nil, "BORDER")
f.barBG:SetPoint("TOPLEFT", 8, -8)
f.barBG:SetPoint("TOPRIGHT", -28, -8)
f.barBG:SetHeight(BAR_H)
f.barBG:SetColorTexture(0.15, 0.15, 0.15, 0.9)

f.bar = f:CreateTexture(nil, "ARTWORK")
f.bar:SetPoint("LEFT", f.barBG, "LEFT", 0, 0)
f.bar:SetHeight(BAR_H)
f.bar:SetColorTexture(0.2, 0.7, 1.0, 0.95)
f.bar:SetWidth(1)

f.line1 = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
f.line1:SetPoint("TOPLEFT", f.barBG, "BOTTOMLEFT", 0, -6)

f.line2 = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
f.line2:SetPoint("TOPLEFT", f.line1, "BOTTOMLEFT", 0, -2)

-- -------------------------
-- Helpers
-- -------------------------
local function FormatMMSS(sec)
    if not sec or sec <= 0 then return "00:00" end
    local s = math.floor(sec + 0.5)
    local m = math.floor(s / 60)
    local r = s % 60
    if m >= 60 then
        local h = math.floor(m / 60)
        local mm = m % 60
        return string.format("%d:%02d:%02d", h, mm, r)
    end
    return string.format("%02d:%02d", m, r)
end

local function MaxLevelReached()
    local fn = GetMaxPlayerLevel
    if type(fn) ~= "function" then return false end
    local maxLevel = fn()
    if type(maxLevel) ~= "number" or maxLevel <= 0 then return false end
    return (UnitLevel("player") or 0) >= maxLevel
end

local function Alpha(dt, halfLife)
    return 1 - (0.5 ^ (dt / halfLife))
end

-- -------------------------
-- Runtime
-- -------------------------
local lastXP = UnitXP("player") or 0
local fastRate = 0       -- XP/s (dropoff)
local slowRate = 0       -- XP/s (eta base)
local lastT = GetTime()

local etaSec = nil       -- our running ETA that increases during no-XP time
local uiTimer = 0

local function ResetRate()
    lastXP = UnitXP("player") or 0
    fastRate = 0
    slowRate = 0
    lastT = GetTime()
    etaSec = nil
end

local function ApplyEnabledState()
    if DB.enabled then f:Show() else f:Hide() end
end

local function RecomputeETA()
    local curXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    if maxXP <= 0 then return end
    local remain = maxXP - curXP
    if remain <= 0 then
        etaSec = 0
        return
    end
    if slowRate and slowRate > ETA_MIN_RATE then
        etaSec = remain / slowRate
        if etaSec > ETA_MAX_SEC then etaSec = ETA_MAX_SEC end
    end
end

local function UpdateUI()
    ApplyEnabledState()
    if not DB.enabled then return end

    if MaxLevelReached() then
        f.bar:SetWidth(f.barBG:GetWidth())
        f.line1:SetText("MAX LEVEL")
        f.line2:SetText("")
        return
    end

    if IsXPUserDisabled and IsXPUserDisabled() then
        f.bar:SetWidth(1)
        f.line1:SetText("XP: DISABLED")
        f.line2:SetText("")
        return
    end

    local curXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0

    if maxXP <= 0 then
        f.bar:SetWidth(1)
        f.line1:SetText("XP: N/A")
        f.line2:SetText("")
        return
    end

    local w = f.barBG:GetWidth()
    local fill = w * (curXP / maxXP)
    if fill < 1 then fill = 1 end
    if fill > w then fill = w end
    f.bar:SetWidth(fill)

    local pct = (curXP / maxXP) * 100
    f.line1:SetText(string.format("XP: %d / %d (%.1f%%)", curXP, maxXP, pct))

    -- Dropoff (fastRate)
    local drop = fastRate or 0
    -- ETA display
    local etaText
    if etaSec and etaSec > 0 and etaSec < ETA_MAX_SEC then
        etaText = "ETA: " .. FormatMMSS(etaSec)
    else
        etaText = "ETA: ..."
    end

    f.line2:SetText(string.format("Dropoff: %.2f XP/s   %s", drop, etaText))
end

-- XP update handler (event-driven rate)
local function OnXPChanged()
    if not DB.enabled then return end
    if MaxLevelReached() then return end

    local now = GetTime()
    local dt = now - lastT
    if dt <= 0 then dt = 0.001 end
    if dt > 5 then dt = 5 end

    local curXP = UnitXP("player") or 0

    -- Level up / weird bucket reset
    if curXP < lastXP then
        ResetRate()
        UpdateUI()
        return
    end

    local dxp = curXP - lastXP
    if dxp > 0 then
        local inst = dxp / dt -- XP/s
        local aFast = Alpha(dt, HALF_LIFE_FAST)
        local aSlow = Alpha(dt, HALF_LIFE_SLOW)
        fastRate = fastRate + aFast * (inst - fastRate)
        slowRate = slowRate + aSlow * (inst - slowRate)

        -- every time XP arrives, re-anchor ETA from remaining / slowRate
        RecomputeETA()
    end

    lastXP = curXP
    lastT = now

    UpdateUI()
end

-- -------------------------
-- Events
-- -------------------------
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        XPROBDB = XPROBDB or {}
        DB = XPROBDB
        if DB.enabled == nil then DB.enabled = true end
        ApplyEnabledState()
        ResetRate()
        UpdateUI()
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        ResetRate()
        UpdateUI()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ResetRate()
        -- try to seed ETA if we already have some slowRate later; for now show ...
        UpdateUI()
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        OnXPChanged()
        return
    end
end)

-- -------------------------
-- OnUpdate
-- -------------------------
f:SetScript("OnUpdate", function(_, elapsed)
    if not DB.enabled then return end

    -- ETA should worsen while you are not gaining XP (time passes)
    if not MaxLevelReached() then
        local maxXP = UnitXPMax("player") or 0
        if maxXP > 0 then
            local curXP = UnitXP("player") or 0
            local remain = maxXP - curXP
            if remain > 0 then
                if etaSec then
                    etaSec = etaSec + elapsed
                    if etaSec > ETA_MAX_SEC then etaSec = ETA_MAX_SEC end
                else
                    -- if we don't have eta yet but we do have slowRate, seed it
                    if slowRate and slowRate > ETA_MIN_RATE then
                        RecomputeETA()
                    end
                end
            else
                etaSec = 0
            end
        end
    end

    uiTimer = uiTimer + elapsed
    if uiTimer >= UI_EVERY then
        uiTimer = 0
        UpdateUI()
    end
end)

-- -------------------------
-- Slash command
-- -------------------------
SLASH_RXP1 = "/rxp"
SlashCmdList["RXP"] = function()
    DB.enabled = not DB.enabled
    print("XPROB:", DB.enabled and "Enabled" or "Disabled")
    if DB.enabled then
        ResetRate()
        f:Show()
    else
        f:Hide()
    end
    UpdateUI()
end

-- Init baseline (Real settings apply in ADDON_LOADED)
ResetRate()
UpdateUI()