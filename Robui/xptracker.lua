-- =========================================================
-- XPROB - The Ultimate XP Tracker & ETA Predictor
-- =========================================================

local ADDON = (select(1, ...))
local DB = { enabled = true, locked = false, pos = nil }

local WIDTH  = 380
local HEIGHT = 45 
local BAR_H  = 16

local UI_EVERY       = 0.25
local HALF_LIFE_FAST = 60  
local HALF_LIFE_SLOW = 600 
local GRACE_PERIOD   = 15  
local ETA_MIN_RATE   = 0.0001
local LOCK_AFTER_SEC = 300 

-- -------------------------------------------------
-- FRAME SETUP
-- -------------------------------------------------
local f = CreateFrame("Frame", "XPROB_Frame", UIParent)
f:SetSize(WIDTH, HEIGHT)
f:SetPoint("CENTER")
f:SetFrameStrata("MEDIUM")
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")

f.bg = f:CreateTexture(nil, "BACKGROUND")
f.bg:SetAllPoints()
f.bg:SetColorTexture(0, 0, 0, 0.7)

f.barBG = f:CreateTexture(nil, "BORDER")
f.barBG:SetPoint("TOPLEFT", 8, -8)
f.barBG:SetPoint("TOPRIGHT", -8, -8)
f.barBG:SetHeight(BAR_H)
f.barBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)

-- Utilizing built-in textures 
f.bar = f:CreateTexture(nil, "ARTWORK")
f.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
f.bar:SetVertexColor(0.6, 0.0, 0.8, 0.95) 
f.bar:SetPoint("LEFT", f.barBG)
f.bar:SetHeight(BAR_H)
f.bar:SetWidth(1)

-- Visual Spark to make the bar look premium
f.spark = f:CreateTexture(nil, "OVERLAY")
f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
f.spark:SetBlendMode("ADD")
f.spark:SetSize(20, BAR_H * 2.2)
f.spark:SetPoint("CENTER", f.bar, "RIGHT", 0, 0)

f.line1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.line1:SetPoint("CENTER", f.barBG, "CENTER", 0, 0)

f.line2 = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
f.line2:SetPoint("TOP", f.barBG, "BOTTOM", 0, -4)

-- -------------------------------------------------
-- POSITION & DRAG SAVING
-- -------------------------------------------------
local function SavePosition()
    local point, _, relativePoint, xOfs, yOfs = f:GetPoint()
    DB.pos = { p = point, rp = relativePoint, x = xOfs, y = yOfs }
end

f:SetScript("OnDragStart", function(self)
    if not DB.locked then self:StartMoving() end
end)

f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

local function RestorePosition()
    if DB.pos then
        f:ClearAllPoints()
        f:SetPoint(DB.pos.p, UIParent, DB.pos.rp, DB.pos.x, DB.pos.y)
    end
end

-- -------------------------------------------------
-- HELPERS
-- -------------------------------------------------
local function FormatClock(t)
    if not t then return "..." end
    return date("%H:%M:%S", t)
end

local function FormatMMSS(sec)
    if not sec then return "..." end
    local s = math.floor(sec + 0.5)
    local m = math.floor(s / 60)
    local h = math.floor(m / 60)
    m = m % 60
    local r = s % 60
    
    if h > 0 then
        return string.format("%dh %02dm %02ds", h, m, r)
    end
    return string.format("%02dm %02ds", m, r)
end

local function FormatNumber(num)
    local formatted = tostring(math.floor(num))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function Alpha(dt, hl)
    return 1 - (0.5 ^ (dt / hl))
end

-- -------------------------------------------------
-- RUNTIME VARIABLES & SESSION TRACKING
-- -------------------------------------------------
local lastXP = UnitXP("player") or 0
local fastRate = 0
local slowRate = 0
local lastT = GetTime()
local etaSec = nil
local lockedDone = nil
local startTime = GetTime()
local lastLockUpdate = GetTime()

-- Session specific
local sessionStartTime = GetTime()
local sessionTotalXP = 0

local function Reset()
    lastXP = UnitXP("player") or 0
    fastRate = 0
    slowRate = 0
    lastT = GetTime()
    etaSec = nil
    lockedDone = nil
    startTime = GetTime()
    lastLockUpdate = GetTime()
end

local function RecomputeETA()
    local cur = UnitXP("player") or 0
    local max = UnitXPMax("player") or 0
    if max <= 0 then return end

    local remain = max - cur
    if remain <= 0 then
        etaSec = 0
        return
    end

    local rate = slowRate
    if rate < ETA_MIN_RATE then rate = fastRate end
    if rate > ETA_MIN_RATE then 
        etaSec = remain / rate 
    else 
        etaSec = nil 
    end
end

local function GetLiveDone()
    if not etaSec then return nil end
    return time() + etaSec
end

local function TryLock()
    if not etaSec then return end
    local now = GetTime()
    
    if not lockedDone then
        if (now - startTime) >= LOCK_AFTER_SEC then
            lockedDone = GetLiveDone()
            lastLockUpdate = now
        end
    else
        if (now - lastLockUpdate) >= LOCK_AFTER_SEC then
            lockedDone = GetLiveDone()
            lastLockUpdate = now
        end
    end
end

-- -------------------------------------------------
-- CORE LOGIC
-- -------------------------------------------------
local function OnXP()
    local now = GetTime()
    local dt = now - lastT
    if dt <= 0 then dt = 0.001 end

    local cur = UnitXP("player") or 0
    
    -- Handled level up or lost XP scenario
    if cur < lastXP then
        Reset()
        return
    end

    local dxp = cur - lastXP
    if dxp > 0 then
        sessionTotalXP = sessionTotalXP + dxp
        
        local inst = dxp / dt
        local aFast = Alpha(dt, HALF_LIFE_FAST)
        local aSlow = Alpha(dt, HALF_LIFE_SLOW)

        fastRate = fastRate + aFast * (inst - fastRate)
        slowRate = slowRate + aSlow * (inst - slowRate)

        RecomputeETA()
    end

    lastXP = cur
    lastT = now
end

-- -------------------------------------------------
-- UPDATE UI
-- -------------------------------------------------
local uiTimer = 0

local function UpdateUI()
    -- Auto-hide if disabled OR if player is Max Level
    if not DB.enabled or UnitLevel("player") == GetMaxPlayerLevel() then 
        f:Hide() 
        return 
    else 
        f:Show() 
    end

    local cur = UnitXP("player") or 0
    local max = UnitXPMax("player") or 1
    
    local w = f.barBG:GetWidth()
    local fill = w * (cur / max)
    local clampedFill = math.max(1, math.min(fill, w))
    f.bar:SetWidth(clampedFill)
    
    -- Hide spark if bar is full to prevent overflow
    if clampedFill >= w then
        f.spark:Hide()
    else
        f.spark:Show()
    end

    local isRested = GetRestState()
    if isRested == 1 then
        f.bar:SetVertexColor(0.0, 0.4, 0.9, 0.95) 
    else
        f.bar:SetVertexColor(0.6, 0.0, 0.8, 0.95)
    end

    local pct = (cur / max) * 100
    f.line1:SetText(string.format("%s / %s (%.1f%%)", FormatNumber(cur), FormatNumber(max), pct))

    local dropPerMin = (fastRate or 0) * 60
    f.line2:SetText(string.format("Speed: %.0f XP/min", dropPerMin))
end

-- -------------------------------------------------
-- TOOLTIP (Mouseover)
-- -------------------------------------------------
f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("XPROB Statistics", 0.2, 0.7, 1.0)
    
    local dropPerMin = (fastRate or 0) * 60
    local etaText = etaSec and FormatMMSS(etaSec) or "Calculating..."
    local liveText = GetLiveDone() and FormatClock(GetLiveDone()) or "..."
    local lockText = lockedDone and FormatClock(lockedDone) or "..."
    local nextLock = lockedDone and FormatMMSS(LOCK_AFTER_SEC - (GetTime() - lastLockUpdate)) or "Waiting..."
    local sessionTime = FormatMMSS(GetTime() - sessionStartTime)
    local restedXP = GetXPExhaustion() or 0

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Current Speed:", string.format("%.0f XP/min", dropPerMin), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time to Level:", etaText, 1, 1, 1, 1, 1, 1)
    
    if restedXP > 0 then
        GameTooltip:AddDoubleLine("Rested XP Remaining:", FormatNumber(restedXP), 0.2, 0.6, 1.0, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Live Completion:", liveText, 0.2, 1, 0.2, 1, 1, 1)
    GameTooltip:AddDoubleLine("Locked Prediction:", lockText, 1, 0.8, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Next Lock Update In:", nextLock, 0.5, 0.5, 0.5, 0.8, 0.8, 0.8)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Session Time:", sessionTime, 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session XP Gained:", FormatNumber(sessionTotalXP), 0.8, 0.8, 0.8, 1, 1, 1)
    
    GameTooltip:Show()
end)

f:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- -------------------------------------------------
-- EVENTS & ONUPDATE
-- -------------------------------------------------
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("UPDATE_EXHAUSTION")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        XPROBDB = XPROBDB or {}
        for k, v in pairs(DB) do
            if XPROBDB[k] == nil then XPROBDB[k] = v end
        end
        DB = XPROBDB
        
        RestorePosition()
        Reset()
        UpdateUI()
    elseif event == "PLAYER_LEVEL_UP" then
        Reset()
        UpdateUI()
    elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" then
        OnXP()
        UpdateUI()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateUI()
    end
end)

f:SetScript("OnUpdate", function(_, elapsed)
    uiTimer = uiTimer + elapsed
    
    if GetTime() - lastT > GRACE_PERIOD then
        local inst = 0 
        local aFast = Alpha(elapsed, HALF_LIFE_FAST)
        local aSlow = Alpha(elapsed, HALF_LIFE_SLOW)
        
        fastRate = fastRate + aFast * (inst - fastRate)
        slowRate = slowRate + aSlow * (inst - slowRate)
        RecomputeETA()
    end

    if uiTimer > UI_EVERY then
        uiTimer = 0
        TryLock()
        UpdateUI()
        if GameTooltip:IsOwned(f) then
            f:GetScript("OnEnter")(f)
        end
    end
end)

-- -------------------------------------------------
-- SLASH COMMANDS
-- -------------------------------------------------
SLASH_XPROB1 = "/xprob"
SlashCmdList["XPROB"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "toggle" then
        DB.enabled = not DB.enabled
        UpdateUI()
        print("|cff33AAFFXPROB:|r " .. (DB.enabled and "Enabled" or "Disabled"))
    elseif msg == "lock" then
        DB.locked = not DB.locked
        print("|cff33AAFFXPROB:|r Frame is now " .. (DB.locked and "Locked" or "Unlocked"))
    elseif msg == "reset" then
        Reset()
        sessionTotalXP = 0
        sessionStartTime = GetTime()
        print("|cff33AAFFXPROB:|r Statistics and session have been reset.")
    else
        print("|cff33AAFFXPROB Commands:|r")
        print("  /xprob toggle - Show/hide the frame")
        print("  /xprob lock - Lock/unlock dragging")
        print("  /xprob reset - Reset current session statistics")
    end
end
