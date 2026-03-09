-- ============================================================================
-- RobUI PlayerFrame - Mythic+ Mode (12.0 SECRET-SAFE, VISUAL FIXED)
-- No DB / no saving
-- THIS FILE DOES NOT DEFINE CLICK-CAST SPELLS.
-- It ONLY exposes a unit button and registers it to RobHeal cast.lua so it can
-- attach its secure overlay (RobHealOverlayX) for mouseover/click/hover casts.
-- ============================================================================

local AddonName, ns = ...
ns.PlayerFrameMPlus = ns.PlayerFrameMPlus or {}
local PF = ns.PlayerFrameMPlus

-- ------------------------------------------------------------
-- CONFIG (owned by settings lua; no persistence here)
-- ------------------------------------------------------------
PF.Config = PF.Config or {
    shown = true,

    point = "CENTER",
    relPoint = "CENTER",
    x = -280,
    y = 120,

    w = 340,
    hpH = 28,
    powerH = 12,
    gap = 4,

    showName = true,
    showHPText = true,
    showPowerText = true,

    nameSize = 12,
    hpSize = 11,
    powerSize = 10,

    useTexture = true,
    texturePath = "Interface\\TARGETINGFRAME\\UI-StatusBar",

    useClassColor = true,
    useCustomHP = false,
    hpR=0.2, hpG=0.8, hpB=0.2,

    useCustomPower = false,
    powR=0.2, powG=0.4, powB=1.0,

    showIncomingHeals = true,
    showHealAbsorb = true,
    showAbsorb = true,

    lowHPBlink = true,
    lowHPThreshold = 0.35,
    blinkSpeed = 0.18,
}

-- ------------------------------------------------------------
-- Secret helpers
-- ------------------------------------------------------------
local function issecret(v)
    if type(_G.issecretvalue) == "function" then
        local ok, r = pcall(_G.issecretvalue, v)
        if ok and r then return true end
    end
    return false
end

local function Clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function GetClassColorRGB()
    local _, class = UnitClass("player")
    if class then
        if C_ClassColor and C_ClassColor.GetClassColor then
            local c = C_ClassColor.GetClassColor(class)
            if c then return c.r, c.g, c.b end
        end
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end
    return 0.2, 0.8, 0.2
end

local function EnsureBackdrop(f, alpha)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.25)
    f:SetBackdropBorderColor(0,0,0,1)
end

local function GetFontPath(fs)
    if not fs or not fs.GetFont then return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
    local path = select(1, fs:GetFont())
    return path or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- ------------------------------------------------------------
-- SAFE text set (NO compares on secret strings)
-- ------------------------------------------------------------
local function SafeSetText(self, key, fs, txt)
    if not fs or not fs.SetText then return end
    if txt == nil then txt = "" end

    if issecret(txt) then
        self[key] = nil
        fs:SetText(txt)
        return
    end

    local prev = self[key]
    if prev ~= nil and issecret(prev) then
        self[key] = nil
        fs:SetText(txt)
        return
    end

    if prev ~= txt then
        self[key] = txt
        fs:SetText(txt)
    end
end

-- ------------------------------------------------------------
-- Formatting (NO string compares at all)
-- ------------------------------------------------------------
local function AbbrevAny(n)
    if n == nil then return nil end

    if _G.AbbreviateLargeNumbers then
        local ok, s = pcall(_G.AbbreviateLargeNumbers, n)
        if ok and type(s) == "string" then return s end
    end

    if type(n) == "number" and not issecret(n) then
        if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
        if n >= 1000 then return string.format("%.1fk", n / 1000) end
        return tostring(math.floor(n + 0.5))
    end

    local ok, s = pcall(string.format, "%s", n)
    if ok and type(s) == "string" then return s end
    return nil
end

local function FormatCurMaxNoCompare(cur, maxv)
    local a = AbbrevAny(cur)
    local b = AbbrevAny(maxv)
    if a == nil or b == nil then return nil end
    return a .. " / " .. b
end

-- ------------------------------------------------------------
-- Styles
-- ------------------------------------------------------------
local function ApplyHPStyle(hpBar)
    local cfg = PF.Config
    local texPath = cfg.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"

    if cfg.useTexture then
        pcall(hpBar.SetStatusBarTexture, hpBar, texPath)
    else
        pcall(hpBar.SetStatusBarTexture, hpBar, "Interface\\TARGETINGFRAME\\UI-StatusBar")
    end

    local r,g,b = 0.2, 0.8, 0.2
    if cfg.useCustomHP then
        r,g,b = Clamp01(cfg.hpR), Clamp01(cfg.hpG), Clamp01(cfg.hpB)
    elseif cfg.useClassColor then
        r,g,b = GetClassColorRGB()
    end

    hpBar:SetStatusBarColor(r,g,b)
    local tex = hpBar:GetStatusBarTexture()
    if tex and tex.SetVertexColor then tex:SetVertexColor(r,g,b) end
end

local function ApplyPowerStyle(powBar)
    local cfg = PF.Config

    if cfg.useCustomPower then
        powBar:SetStatusBarColor(Clamp01(cfg.powR), Clamp01(cfg.powG), Clamp01(cfg.powB))
        return
    end

    local _, token = UnitPowerType("player")
    local col = PowerBarColor and PowerBarColor[token or "MANA"]
    if col then
        powBar:SetStatusBarColor(col.r, col.g, col.b)
    else
        powBar:SetStatusBarColor(0.2, 0.4, 1.0)
    end
end

-- ------------------------------------------------------------
-- Heal prediction
-- ------------------------------------------------------------
local healCalc
local function EnsureHealCalc()
    if healCalc then return healCalc end
    if type(CreateUnitHealPredictionCalculator) == "function" then
        healCalc = CreateUnitHealPredictionCalculator()
    end
    return healCalc
end

local function SafeSetMinMaxAndValue(bar, maxv, curv)
    pcall(bar.SetMinMaxValues, bar, 0, maxv or 1)
    pcall(bar.SetValue, bar, curv or 0)
end

local function SafeShownFromValue(frame, v)
    local ok, gt0 = pcall(function() return v and v > 0 end)
    if ok then
        frame:SetShown(gt0 and true or false)
    else
        frame:SetShown(true)
    end
end

-- ------------------------------------------------------------
-- Low HP blink
-- ------------------------------------------------------------
PF._blinkOn = false
PF._blinkNext = 0

local function TryLowHP()
    if type(UnitHealthPercent) == "function" then
        local cfg = PF.Config
        local ok, low = pcall(function()
            local pct = UnitHealthPercent("player", true)
            return pct <= (cfg.lowHPThreshold or 0.35)
        end)
        if ok then return low and true or false end
    end
    return false
end

local function UpdateBlink(self)
    local cfg = PF.Config
    if not cfg.lowHPBlink then
        self.hp:SetAlpha(1)
        ApplyHPStyle(self.hp)
        return
    end

    if not TryLowHP() then
        self.hp:SetAlpha(1)
        ApplyHPStyle(self.hp)
        return
    end

    local now = GetTime()
    if now >= (self._blinkNext or 0) then
        self._blinkNext = now + (cfg.blinkSpeed or 0.18)
        self._blinkOn = not self._blinkOn
        self.hp:SetAlpha(self._blinkOn and 0.25 or 1.0)

        self.hp:SetStatusBarColor(1, 0.12, 0.12)
        local tex = self.hp:GetStatusBarTexture()
        if tex and tex.SetVertexColor then tex:SetVertexColor(1, 0.12, 0.12) end
    end
end

-- ------------------------------------------------------------
-- Input passthrough: root gets clicks, children do not eat them
-- ------------------------------------------------------------
local function DisableMouseOn(frame)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
    if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
end

-- ------------------------------------------------------------
-- RobHeal (cast.lua) integration
-- cast.lua exposes: _G.RobHeal_RegisterFrame(frame, unit)
-- If we never call it, RobHeal will NEVER create its overlay for this frame.
-- ------------------------------------------------------------
PF._robhealRegistered = false
PF._pendingRobHealReg = false

function PF:RegisterWithRobHeal()
    if self._robhealRegistered then return end
    if not self.root then return end

    if InCombatLockdown and InCombatLockdown() then
        self._pendingRobHealReg = true
        return
    end

    local fn = _G.RobHeal_RegisterFrame
    if type(fn) == "function" then
        -- Register our HOST frame. RobHeal will create RobHealOverlayX as a child.
        pcall(fn, self.root, "player")
        self._robhealRegistered = true
        self._pendingRobHealReg = false
    else
        -- RobHeal not loaded yet -> try again on ADDON_LOADED
        self._pendingRobHealReg = true
    end
end

-- ------------------------------------------------------------
-- Click-cast registration (Blizzard + your own system)
-- (Does NOT set spells, only exposes the frame)
-- ------------------------------------------------------------
function PF:GetClickTarget()
    return self.root
end

function PF:RegisterForClickCasting()
    if not self.root then return end
    if InCombatLockdown and InCombatLockdown() then
        PF._pendingClickReg = true
        return
    end
    PF._pendingClickReg = false

    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[self.root] = true

    if type(_G.ClickCastFrame_Register) == "function" then
        pcall(_G.ClickCastFrame_Register, self.root)
    end

    if ns and ns.ClickCast and type(ns.ClickCast.RegisterFrame) == "function" then
        pcall(ns.ClickCast.RegisterFrame, ns.ClickCast, self.root, "player")
    end
end

-- ------------------------------------------------------------
-- Create / Layout
-- ------------------------------------------------------------
function PF:Initialize()
    if self.root then return end
    local cfg = self.Config

    -- NOTE: RobHeal overlay only needs a host frame.
    -- Using SecureUnitButtonTemplate is fine and lets others bind to it too.
    local root = CreateFrame("Button", "RobUI_PlayerFrame_MPlus", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    self.root = root

    root:SetClampedToScreen(true)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(20)

    root:RegisterForClicks("AnyUp")
    root:EnableMouse(true)
    if root.SetMouseMotionEnabled then root:SetMouseMotionEnabled(true) end

    root:SetAttribute("unit", "player")

    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    EnsureBackdrop(hp, 0.0)
    DisableMouseOn(hp)

    hp.bg = hp:CreateTexture(nil, "BACKGROUND")
    hp.bg:SetAllPoints()
    hp.bg:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    local pow = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.power = pow
    EnsureBackdrop(pow, 0.0)
    DisableMouseOn(pow)

    pow.bg = pow:CreateTexture(nil, "BACKGROUND")
    pow.bg:SetAllPoints()
    pow.bg:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    local clip = CreateFrame("Frame", nil, hp)
    self.clip = clip
    clip:SetAllPoints(hp)
    clip:SetClipsChildren(true)
    DisableMouseOn(clip)

    self.incBar = CreateFrame("StatusBar", nil, clip)
    self.incBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    self.incBar:SetStatusBarColor(0.2, 1.0, 0.2, 0.35)
    DisableMouseOn(self.incBar)

    self.healAbsBar = CreateFrame("StatusBar", nil, clip)
    self.healAbsBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    self.healAbsBar:SetStatusBarColor(1.0, 0.0, 0.0, 0.65)
    if self.healAbsBar.SetReverseFill then self.healAbsBar:SetReverseFill(true) end
    DisableMouseOn(self.healAbsBar)

    self.shieldAbsBar = CreateFrame("StatusBar", nil, clip)
    self.shieldAbsBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    self.shieldAbsBar:SetStatusBarColor(0.0, 0.7, 1.0, 0.55)
    if self.shieldAbsBar.SetReverseFill then self.shieldAbsBar:SetReverseFill(true) end
    DisableMouseOn(self.shieldAbsBar)

    self.nameText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText   = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.powText  = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    DisableMouseOn(self.nameText)
    DisableMouseOn(self.hpText)
    DisableMouseOn(self.powText)

    self._lastNameText = nil
    self._lastHPText = nil
    self._lastPowText = nil

    local font = GetFontPath(self.nameText)
    self.nameText:SetFont(font, cfg.nameSize or 12, "OUTLINE")
    self.hpText:SetFont(font, cfg.hpSize or 11, "OUTLINE")
    self.powText:SetFont(font, cfg.powerSize or 10, "OUTLINE")

    self:ApplyLayout()
    self:UpdateValues()

    -- Register so external systems can bind
    self:RegisterForClickCasting()

    -- Register so RobHeal cast.lua will create its overlay (THIS is the missing piece)
    self:RegisterWithRobHeal()
end

function PF:ApplyLayout()
    if not self.root then return end
    local cfg = self.Config

    self.root:ClearAllPoints()
    self.root:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or "CENTER", cfg.x or -280, cfg.y or 120)

    local w    = tonumber(cfg.w) or 340
    local hpH  = tonumber(cfg.hpH) or 28
    local powH = tonumber(cfg.powerH) or 12
    local gap  = tonumber(cfg.gap) or 4

    self.root:SetSize(w, hpH + gap + powH)

    self.hp:ClearAllPoints()
    self.hp:SetPoint("TOPLEFT", self.root, "TOPLEFT", 0, 0)
    self.hp:SetPoint("TOPRIGHT", self.root, "TOPRIGHT", 0, 0)
    self.hp:SetHeight(hpH)

    self.power:ClearAllPoints()
    self.power:SetPoint("TOPLEFT", self.hp, "BOTTOMLEFT", 0, -gap)
    self.power:SetPoint("TOPRIGHT", self.hp, "BOTTOMRIGHT", 0, -gap)
    self.power:SetHeight(powH)

    self.nameText:ClearAllPoints()
    self.nameText:SetPoint("LEFT", self.hp, "LEFT", 6, 0)

    self.hpText:ClearAllPoints()
    self.hpText:SetPoint("RIGHT", self.hp, "RIGHT", -6, 0)

    self.powText:ClearAllPoints()
    self.powText:SetPoint("RIGHT", self.power, "RIGHT", -6, 0)

    self.nameText:SetShown(cfg.showName and true or false)
    self.hpText:SetShown(cfg.showHPText and true or false)
    self.powText:SetShown(cfg.showPowerText and true or false)

    ApplyHPStyle(self.hp)
    ApplyPowerStyle(self.power)

    local hpTexture = self.hp:GetStatusBarTexture()
    if hpTexture then
        self.incBar:ClearAllPoints()
        self.incBar:SetPoint("TOPLEFT", hpTexture, "TOPRIGHT")
        self.incBar:SetPoint("BOTTOMLEFT", hpTexture, "BOTTOMRIGHT")

        self.healAbsBar:ClearAllPoints()
        self.healAbsBar:SetPoint("TOPRIGHT", hpTexture, "TOPRIGHT")
        self.healAbsBar:SetPoint("BOTTOMRIGHT", hpTexture, "BOTTOMRIGHT")
    end

    self.shieldAbsBar:ClearAllPoints()
    self.shieldAbsBar:SetPoint("TOPRIGHT", self.hp, "TOPRIGHT")
    self.shieldAbsBar:SetPoint("BOTTOMRIGHT", self.hp, "BOTTOMRIGHT")

    self.incBar:SetSize(w, hpH)
    self.healAbsBar:SetSize(w, hpH)
    self.shieldAbsBar:SetSize(w, hpH)

    self.root:SetShown(cfg.shown and true or false)
end

-- ------------------------------------------------------------
-- Update values
-- ------------------------------------------------------------
PF._nextHealPred = 0

function PF:UpdateValues()
    if not self.root then return end
    local cfg = self.Config
    local unit = "player"

    if cfg.showName then
        SafeSetText(self, "_lastNameText", self.nameText, UnitName("player") or "Player")
    end

    local hCur = UnitHealth(unit)
    local hMax = UnitHealthMax(unit)
    if hMax == nil then hMax = 1 end

    SafeSetMinMaxAndValue(self.hp, hMax, hCur)

    if cfg.showHPText then
        local hpStr = FormatCurMaxNoCompare(hCur, hMax) or ""
        SafeSetText(self, "_lastHPText", self.hpText, hpStr)
    end

    local pCur = UnitPower(unit)
    local pMax = UnitPowerMax(unit)
    if pMax == nil then pMax = 1 end

    SafeSetMinMaxAndValue(self.power, pMax, pCur)

    if cfg.showPowerText then
        local powStr = FormatCurMaxNoCompare(pCur, pMax) or ""
        SafeSetText(self, "_lastPowText", self.powText, powStr)
    end

    UpdateBlink(self)

    local now = GetTime()
    local doHealPred = true
    if InCombatLockdown and InCombatLockdown() then
        if now < (PF._nextHealPred or 0) then
            doHealPred = false
        else
            PF._nextHealPred = now + 0.08
        end
    end
    if not doHealPred then return end

    local calc = EnsureHealCalc()
    if not calc then return end

    UnitGetDetailedHealPrediction(unit, unit, calc)
    local incoming = calc:GetIncomingHeals()
    local healAbs  = calc:GetHealAbsorbs()
    local shields  = UnitGetTotalAbsorbs(unit)

    if cfg.showIncomingHeals then
        SafeSetMinMaxAndValue(self.incBar, hMax, incoming)
        SafeShownFromValue(self.incBar, incoming)
    else
        self.incBar:Hide()
    end

    if cfg.showHealAbsorb then
        SafeSetMinMaxAndValue(self.healAbsBar, hMax, healAbs)
        SafeShownFromValue(self.healAbsBar, healAbs)
    else
        self.healAbsBar:Hide()
    end

    if cfg.showAbsorb then
        SafeSetMinMaxAndValue(self.shieldAbsBar, hMax, shields)
        SafeShownFromValue(self.shieldAbsBar, shields)
    else
        self.shieldAbsBar:Hide()
    end
end

function PF:ForceUpdate()
    self:Initialize()
    self:ApplyLayout()
    self:UpdateValues()
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("UNIT_DISPLAYPOWER")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterEvent("ADDON_LOADED")

E:RegisterUnitEvent("UNIT_HEALTH", "player")
E:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
E:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
E:RegisterUnitEvent("UNIT_MAXPOWER", "player")
E:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "player")
E:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
E:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        PF:ForceUpdate()
        PF:RegisterWithRobHeal()

    elseif event == "ADDON_LOADED" then
        -- If RobHeal loads after this file, register then.
        if arg1 == "RobHeal" then
            PF:RegisterWithRobHeal()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if PF._pendingClickReg then
            PF:RegisterForClickCasting()
        end
        if PF._pendingRobHealReg then
            PF:RegisterWithRobHeal()
        end

    elseif event == "UNIT_DISPLAYPOWER" then
        if PF.power then ApplyPowerStyle(PF.power) end
        PF:UpdateValues()

    else
        PF:UpdateValues()
    end
end)
