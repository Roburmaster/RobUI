-- ============================================================================
-- Robui/UI/PlayerFrame.lua  (Midnight-safe)
--
-- GOAL:
--   - HP TEXT + POWER TEXT must ALWAYS show when enabled.
--   - NO secret-string comparisons (fixes crashes).
--   - USE BLIZZARD STANDARD VEHICLE UI:
--       * Hide this custom player frame when WoW takes over control:
--         [vehicleui] [overridebar] [possessbar]
--
-- RULES USED:
--   ✅ NEVER compare any strings that might be secret (no prev-text caching, no ~= checks).
--   ✅ Always generate text from numbers and set it directly.
--   ✅ Do NOT blank text just because something "might be secret".
--
-- Event-driven, no ticker.
-- Overlays update only on heal/absorb events.
-- Pips rebuild deferred.
-- ============================================================================

local AddonName, ns = ...
local R = _G.Robui

ns.UnitFrames = ns.UnitFrames or {}
ns.UnitFrames.Player = ns.UnitFrames.Player or {}

local PF   = ns.UnitFrames.Player
local PROF = ns.PROF
local UNIT = "player"

local pcall = pcall
local type  = type
local tonumber = tonumber
local floor = math.floor
local pairs = pairs

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitName = UnitName
local UnitClass = UnitClass

local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

-- PowerType constants
local POW_MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- ============================================================
-- DEFAULTS
-- ============================================================
local DEFAULTS = {
    shown = true,
    locked = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = -280,
    y = 120,

    w = 320,
    hpH = 26,
    powerH = 12,
    pipH = 14,
    gap = 4,

    showName = true,
    showHPText = true,
    showPowerText = true,
    showPower = true,
    pipEnabled = true,

    nameSize = 12,
    hpSize = 11,
    powerSize = 10,

    nameOffX = 0, nameOffY = 0,
    hpOffX = 0,   hpOffY = 0,
    powOffX = 0,  powOffY = 0,

    nameR=1, nameG=1, nameB=1,
    hpTextR=1, hpTextG=1, hpTextB=1,
    powTextR=1, powTextG=1, powTextB=1,

    showIncomingHeals = true,
    showHealAbsorb    = true,
    showAbsorb        = true,

    useTexture = true,
    texturePath = "Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
    noColorOverride = false,
    tintOnlyOnBase  = true,

    useClassColor = true,
    useCustomHP = false,
    hpR=0.2, hpG=0.8, hpB=0.2,

    useCustomPower = false,
    powR=0.2, powG=0.4, powB=1.0,
}

PF.Defaults = DEFAULTS

-- ============================================================
-- PROFILE DB (merge defaults)
-- ============================================================
local function EnsureTable(t) return type(t) == "table" and t or {} end

local function EnsureDefaults(dst, src)
    dst = EnsureTable(dst)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = EnsureDefaults({}, v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            EnsureDefaults(dst[k], v)
        end
    end
    return dst
end

local function GetCfg()
    if R and R.Database and R.Database.profile then
        R.Database.profile.unitframes = EnsureTable(R.Database.profile.unitframes)
        R.Database.profile.unitframes.player = EnsureTable(R.Database.profile.unitframes.player)
        EnsureDefaults(R.Database.profile.unitframes.player, DEFAULTS)
        return R.Database.profile.unitframes.player
    end
    return DEFAULTS
end

-- ============================================================
-- SECRET HELPER (only used where we must compare)
-- ============================================================
local function issecret(v)
    if type(_G.issecretvalue) == "function" then
        local ok, r = pcall(_G.issecretvalue, v)
        if ok and r then return true end
    end
    return false
end

local function Clamp(n, lo, hi)
    n = tonumber(n) or lo
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function Clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function EnsureBackdrop(f, alpha)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.25)
    f:SetBackdropBorderColor(0,0,0,1)
end

-- IMPORTANT: no prev-text caching, no compares, just set
local function SafeSetText(fs, txt)
    if not fs or not fs.SetText then return end
    if txt == nil then txt = "" end
    fs:SetText(txt)
end

local function SafeSetFont(fs, path, size, flags)
    if not fs or not fs.SetFont then return end
    path = path or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    size = tonumber(size) or 12
    flags = flags or "OUTLINE"
    pcall(fs.SetFont, fs, path, size, flags)
end

-- Same mechanism as TargetFrame
local function RegFont(fs, size, flags)
    local M = ns and ns.media
    if M and M.RegisterTarget and fs then
        M:RegisterTarget(fs, size, flags)
        return true
    end
    SafeSetFont(fs, _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    return false
end

-- ============================================================
-- TEXT FORMAT (HP + POWER) - ALWAYS SHOW, NO STRING COMPARES
-- ============================================================
local function AbbrevAlways(v)
    if type(v) ~= "number" then return "" end

    if _G.AbbreviateLargeNumbers then
        local ok, s = pcall(_G.AbbreviateLargeNumbers, v)
        if ok and type(s) == "string" then
            return s
        end
    end

    if v >= 1000000 then return string.format("%.1fm", v / 1000000) end
    if v >= 1000 then return string.format("%.1fk", v / 1000) end
    return tostring(floor(v + 0.5))
end

local function FormatCurMaxAlways(cur, maxv)
    if type(cur) ~= "number" or type(maxv) ~= "number" then return "" end
    if maxv <= 0 then return "" end
    return AbbrevAlways(cur) .. " / " .. AbbrevAlways(maxv)
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

-- ============================================================
-- PRIMARY POWER TYPE (fixed)
-- ============================================================
local function GetPrimaryPowerType()
    local pType = UnitPowerType("player")
    if type(pType) == "number" then return pType end
    return POW_MANA
end

-- ============================================================
-- HEAL PREDICTION CALC
-- ============================================================
local healCalc = nil
local function EnsureHealCalc()
    if healCalc then return healCalc end
    if type(CreateUnitHealPredictionCalculator) == "function" then
        healCalc = CreateUnitHealPredictionCalculator()
    end
    return healCalc
end

-- ============================================================
-- PIPS (deferred)
-- ============================================================
local function ClearChildren(holder)
    local kids = { holder:GetChildren() }
    for i = 1, #kids do
        local c = kids[i]
        if c then
            if c.Hide then c:Hide() end
            if c.SetParent then c:SetParent(nil) end
        end
    end
end

local function RebuildPips(self)
    local holder = self.pips
    if not holder then return end

    local cfg = GetCfg()
    if (not cfg.pipEnabled) or self.__pipAutoHidden then
        holder:Hide()
        ClearChildren(holder)
        holder.__prev = nil
        holder.__pipTok = nil
        return
    end

    holder:Show()

    holder.__pipTok = (holder.__pipTok or 0) + 1
    local tok = holder.__pipTok

    local function DoBuild()
        if not holder or not holder.GetChildren then return end
        if holder.__pipTok ~= tok then return end
        if not holder:IsShown() then return end

        if holder.__prev and holder.__prev.Hide then holder.__prev:Hide() end
        if holder.__prev and holder.__prev.SetParent then holder.__prev:SetParent(nil) end
        ClearChildren(holder)

        local _, cls = UnitClass("player")
        local builder = ns.classbars and cls and ns.classbars[cls]
        local created

        if type(builder) == "function" then
            local ok, res = pcall(builder, holder)
            if ok then created = res end
        end

        if not created then
            local kids = { holder:GetChildren() }
            created = kids[1]
        end

        if created and created.SetAllPoints then
            created:ClearAllPoints()
            created:SetAllPoints(holder)
            if created.Show then created:Show() end
        end

        holder.__prev = created
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, DoBuild)
    else
        DoBuild()
    end
end

-- ============================================================
-- STYLE (avoid secret-string compare)
-- ============================================================
local function ApplyHPStyle()
    if not PF.hp then return end
    local cfg = GetCfg()

    local base = "Interface\\AddOns\\"..AddonName.."\\media\\base.tga"
    local texPath = cfg.texturePath or base

    if cfg.useTexture then
        pcall(PF.hp.SetStatusBarTexture, PF.hp, texPath)
    else
        pcall(PF.hp.SetStatusBarTexture, PF.hp, "Interface\\TARGETINGFRAME\\UI-StatusBar")
    end

    local tex = PF.hp:GetStatusBarTexture()
    if tex then
        if tex.SetHorizTile then tex:SetHorizTile(false) end
        if tex.SetVertTile then tex:SetVertTile(false) end
    end

    local forceWhite = false
    if cfg.useTexture then
        if cfg.noColorOverride then
            forceWhite = true
        elseif cfg.tintOnlyOnBase then
            if type(texPath) == "string" and type(base) == "string" and (not issecret(texPath)) and (not issecret(base)) then
                if texPath ~= base then
                    forceWhite = true
                end
            end
        end
    end

    if forceWhite then
        PF.hp:SetStatusBarColor(1,1,1)
        if tex and tex.SetVertexColor then tex:SetVertexColor(1,1,1) end
        return
    end

    local r,g,b = 0.2, 0.8, 0.2
    if cfg.useCustomHP then
        r,g,b = Clamp01(cfg.hpR), Clamp01(cfg.hpG), Clamp01(cfg.hpB)
    elseif cfg.useClassColor then
        r,g,b = GetClassColorRGB()
    end

    PF.hp:SetStatusBarColor(r,g,b)
    if tex and tex.SetVertexColor then tex:SetVertexColor(r,g,b) end
end

local function ApplyPowerColor()
    if not PF.power then return end
    local cfg = GetCfg()

    if cfg.useCustomPower then
        PF.power:SetStatusBarColor(Clamp01(cfg.powR), Clamp01(cfg.powG), Clamp01(cfg.powB))
        return
    end

    local _, token = UnitPowerType("player")
    local col = (PowerBarColor and token and PowerBarColor[token]) or (PowerBarColor and PowerBarColor.MANA) or { r=0.2, g=0.4, b=1.0 }
    PF.power:SetStatusBarColor(col.r or 0.7, col.g or 0.7, col.b or 0.7)
end

-- ============================================================
-- OVERLAYS
-- ============================================================
local function ReanchorOverlays()
    if not PF.root or not PF.hp or not PF.incBar or not PF.healAbsBar or not PF.shieldAbsBar then return end

    local hpTexture = PF.hp:GetStatusBarTexture()
    if hpTexture then
        PF.incBar:ClearAllPoints()
        PF.incBar:SetPoint("TOPLEFT", hpTexture, "TOPRIGHT")
        PF.incBar:SetPoint("BOTTOMLEFT", hpTexture, "BOTTOMRIGHT")

        PF.healAbsBar:ClearAllPoints()
        PF.healAbsBar:SetPoint("TOPRIGHT", hpTexture, "TOPRIGHT")
        PF.healAbsBar:SetPoint("BOTTOMRIGHT", hpTexture, "BOTTOMRIGHT")
    end

    PF.shieldAbsBar:ClearAllPoints()
    PF.shieldAbsBar:SetPoint("TOPRIGHT", PF.hp, "TOPRIGHT")
    PF.shieldAbsBar:SetPoint("BOTTOMRIGHT", PF.hp, "BOTTOMRIGHT")
end

-- ============================================================
-- VISIBILITY (secure driver)  +  HIDE DURING VEHICLE/OVERRIDE
-- ============================================================
PF.__driverApplied = false
PF.__pendingDriver = false
PF.__pendingLayout = false

local function ApplySecureVisibility()
    if not PF.root then return end
    local cfg = GetCfg()

    if InCombatLockdown() then
        PF.__pendingDriver = true
        return
    end
    PF.__pendingDriver = false

    if not RegisterStateDriver then
        PF.root:SetShown(cfg.shown and true or false)
        return
    end

    if PF.__driverApplied and UnregisterStateDriver then
        pcall(UnregisterStateDriver, PF.root)
        PF.__driverApplied = false
    end

    if cfg.shown then
        -- IMPORTANT: Let Blizzard show its standard vehicle/override/possess UI
        -- Hide our custom player frame whenever those bars are active.
        local cond = "[vehicleui][overridebar][possessbar] hide; show"
        pcall(RegisterStateDriver, PF.root, "visibility", cond)
    else
        pcall(RegisterStateDriver, PF.root, "visibility", "hide")
    end

    PF.__driverApplied = true
end

function PF:RequestLayout()
    if InCombatLockdown() then
        PF.__pendingLayout = true
        return
    end
    PF.__pendingLayout = false
    PF:ApplyLayout()
end

-- ============================================================
-- DEFERRED REFRESH (spec/power not always ready at login)
-- ============================================================
PF.__deferToken = PF.__deferToken or 0
local function DeferRefresh()
    PF.__deferToken = (PF.__deferToken or 0) + 1
    local tok = PF.__deferToken

    if not C_Timer or not C_Timer.After then return end

    C_Timer.After(0.10, function()
        if tok ~= PF.__deferToken then return end
        PF:Initialize()
        PF:RequestLayout()
        PF:UpdateAll()
        RebuildPips(PF)
    end)

    C_Timer.After(0.30, function()
        if tok ~= PF.__deferToken then return end
        PF:Initialize()
        PF:RequestLayout()
        PF:UpdateAll()
        RebuildPips(PF)
    end)
end

-- ============================================================
-- PUBLIC
-- ============================================================
function PF:GetConfig() return GetCfg() end

function PF:ToggleSettings()
    if ns.UnitFrames.Player.Settings and ns.UnitFrames.Player.Settings.Toggle then
        ns.UnitFrames.Player.Settings.Toggle()
    else
        print("|cffff4444[RobUI]|r Settings file not loaded.")
    end
end

-- ============================================================
-- CREATE
-- ============================================================
function PF:Initialize()
    if self.root then return end

    local root = CreateFrame("Frame", "RobUI_PlayerFrame", UIParent, "BackdropTemplate")
    self.root = root
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")

    local click = CreateFrame("Button", nil, root, "SecureUnitButtonTemplate")
    self.click = click
    click:SetAllPoints(root)
    click:RegisterForClicks("AnyUp")
    click:SetAttribute("unit", "player")
    click:SetAttribute("*type1", "target")
    click:SetAttribute("*type2", "togglemenu")
    click:RegisterForDrag("LeftButton")

    local function StartMove()
        if InCombatLockdown() then return end
        local c = GetCfg()
        if c.locked then return end
        if not IsShiftKeyDown() then return end
        root:StartMoving()
    end

    local function StopMove()
        if InCombatLockdown() then return end
        root:StopMovingOrSizing()
        local c = GetCfg()
        local p, _, rp, x, y = root:GetPoint(1)
        c.point, c.relPoint, c.x, c.y = p, rp, floor((x or 0)+0.5), floor((y or 0)+0.5)
        PF:RequestLayout()

        if ns.UnitFrames.Player.Settings and ns.UnitFrames.Player.Settings.RefreshIfOpen then
            ns.UnitFrames.Player.Settings.RefreshIfOpen()
        end
    end

    root:SetScript("OnDragStart", StartMove)
    root:SetScript("OnDragStop", StopMove)
    click:SetScript("OnDragStart", StartMove)
    click:SetScript("OnDragStop", StopMove)

    -- Pips
    local pips = CreateFrame("Frame", "RobUI_PlayerPips", root, "BackdropTemplate")
    self.pips = pips
    EnsureBackdrop(pips, 0.0)
    pips:SetScript("OnSizeChanged", function() RebuildPips(self) end)

    -- HP
    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    EnsureBackdrop(hp, 0.0)

    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    hp.bg = hpBg

    -- Power
    local pow = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.power = pow
    EnsureBackdrop(pow, 0.0)
    pow:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

    local powBg = pow:CreateTexture(nil, "BACKGROUND")
    powBg:SetAllPoints()
    powBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    pow.bg = powBg

    -- Overlays (clip to HP)
    local clip = CreateFrame("Frame", nil, hp)
    self.clipFrame = clip
    clip:SetAllPoints(hp)
    clip:SetClipsChildren(true)

    local inc = CreateFrame("StatusBar", nil, clip)
    self.incBar = inc
    inc:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    inc:SetStatusBarColor(0.4, 1.0, 0.4, 0.35)
    inc:Hide()

    local healAbs = CreateFrame("StatusBar", nil, clip)
    self.healAbsBar = healAbs
    healAbs:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healAbs:SetStatusBarColor(1.0, 0.0, 0.0, 0.55)
    if healAbs.SetReverseFill then healAbs:SetReverseFill(true) end
    healAbs:Hide()

    local shield = CreateFrame("StatusBar", nil, clip)
    self.shieldAbsBar = shield
    shield:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    shield:SetStatusBarColor(0.0, 0.6, 1.0, 0.45)
    if shield.SetReverseFill then shield:SetReverseFill(true) end
    shield:Hide()

    inc:SetFrameLevel(hp:GetFrameLevel() + 2)
    healAbs:SetFrameLevel(hp:GetFrameLevel() + 3)
    shield:SetFrameLevel(hp:GetFrameLevel() + 4)

    -- Text
    self.nameText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText   = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.powText  = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    if self.nameText.SetDrawLayer then self.nameText:SetDrawLayer("OVERLAY", 7) end
    if self.hpText.SetDrawLayer then self.hpText:SetDrawLayer("OVERLAY", 7) end
    if self.powText.SetDrawLayer then self.powText:SetDrawLayer("OVERLAY", 7) end

    -- Register with media system (same as TargetFrame)
    local cfg = GetCfg()
    RegFont(self.nameText, Clamp(cfg.nameSize, 8, 28), "OUTLINE")
    RegFont(self.hpText,   Clamp(cfg.hpSize, 8, 28),   "OUTLINE")
    RegFont(self.powText,  Clamp(cfg.powerSize, 8, 28),"OUTLINE")

    self:ApplyLayout()
    ApplySecureVisibility()
    ApplyHPStyle()
    ApplyPowerColor()

    self:UpdateAll()
    self:UpdateHealPred(true)
end

-- ============================================================
-- LAYOUT
-- ============================================================
function PF:ApplyLayout()
    if not self.root then return end
    local cfg = GetCfg()

    local root = self.root
    root:ClearAllPoints()
    if cfg.point then
        root:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    else
        root:SetPoint("CENTER", UIParent, "CENTER", -280, 120)
    end

    local w    = Clamp(cfg.w, 140, 900)
    local hpH  = Clamp(cfg.hpH, 10, 60)
    local powH = Clamp(cfg.powerH, 6, 40)
    local pipH = Clamp(cfg.pipH, 6, 40)
    local gap  = Clamp(cfg.gap, 0, 30)

    local showPower = cfg.showPower and true or false
    local showPips  = (cfg.pipEnabled and (not self.__pipAutoHidden)) and true or false

    local totalH = hpH
    if showPips  then totalH = totalH + gap + pipH end
    if showPower then totalH = totalH + gap + powH end

    root:SetSize(w, totalH)

    if showPips then
        self.pips:ClearAllPoints()
        self.pips:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        self.pips:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
        self.pips:SetHeight(pipH)
        self.pips:Show()
    else
        self.pips:Hide()
    end

    self.hp:ClearAllPoints()
    if showPips then
        self.hp:SetPoint("TOPLEFT", self.pips, "BOTTOMLEFT", 0, -gap)
        self.hp:SetPoint("TOPRIGHT", self.pips, "BOTTOMRIGHT", 0, -gap)
    else
        self.hp:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        self.hp:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    end
    self.hp:SetHeight(hpH)

    if showPower then
        self.power:ClearAllPoints()
        self.power:SetPoint("TOPLEFT", self.hp, "BOTTOMLEFT", 0, -gap)
        self.power:SetPoint("TOPRIGHT", self.hp, "BOTTOMRIGHT", 0, -gap)
        self.power:SetHeight(powH)
        self.power:Show()
    else
        self.power:Hide()
    end

    self.incBar:SetSize(w, hpH)
    self.healAbsBar:SetSize(w, hpH)
    self.shieldAbsBar:SetSize(w, hpH)

    RegFont(self.nameText, Clamp(cfg.nameSize, 8, 28), "OUTLINE")
    RegFont(self.hpText,   Clamp(cfg.hpSize, 8, 28),   "OUTLINE")
    RegFont(self.powText,  Clamp(cfg.powerSize, 8, 28),"OUTLINE")

    self.nameText:ClearAllPoints()
    self.nameText:SetPoint("LEFT", self.hp, "LEFT", 6 + (cfg.nameOffX or 0), (cfg.nameOffY or 0))

    self.hpText:ClearAllPoints()
    self.hpText:SetPoint("RIGHT", self.hp, "RIGHT", -6 + (cfg.hpOffX or 0), (cfg.hpOffY or 0))

    self.powText:ClearAllPoints()
    self.powText:SetPoint("RIGHT", self.power, "RIGHT", -6 + (cfg.powOffX or 0), (cfg.powOffY or 0))

    self.nameText:SetShown(cfg.showName and true or false)
    self.hpText:SetShown(cfg.showHPText and true or false)
    self.powText:SetShown((cfg.showPowerText and showPower) and true or false)

    self.nameText:SetTextColor(Clamp01(cfg.nameR), Clamp01(cfg.nameG), Clamp01(cfg.nameB), 1)
    self.hpText:SetTextColor(Clamp01(cfg.hpTextR), Clamp01(cfg.hpTextG), Clamp01(cfg.hpTextB), 1)
    self.powText:SetTextColor(Clamp01(cfg.powTextR), Clamp01(cfg.powTextG), Clamp01(cfg.powTextB), 1)

    ApplyHPStyle()
    ApplyPowerColor()
    ReanchorOverlays()

    RebuildPips(self)
    ApplySecureVisibility()
end

-- ============================================================
-- LIGHT UPDATE (hp/power/text) - ALWAYS SHOW TEXT
-- ============================================================
function PF:UpdateAll()
    if not self.root then return end
    local cfg = GetCfg()
    if not cfg.shown then return end

    ApplyHPStyle()
    ApplyPowerColor()

    SafeSetText(self.nameText, UnitName(UNIT) or "")

    local hCur = UnitHealth(UNIT)
    local hMax = UnitHealthMax(UNIT)

    if type(hCur) ~= "number" or type(hMax) ~= "number" or hMax <= 0 then
        self.hp:SetMinMaxValues(0, 1)
        self.hp:SetValue(1)
        SafeSetText(self.hpText, "")
    else
        self.hp:SetMinMaxValues(0, hMax)
        self.hp:SetValue(hCur)

        if cfg.showHPText then
            SafeSetText(self.hpText, FormatCurMaxAlways(hCur, hMax))
        else
            SafeSetText(self.hpText, "")
        end
    end

    if not cfg.showPower then
        SafeSetText(self.powText, "")
        return
    end

    local pType = GetPrimaryPowerType()
    local pCur = UnitPower(UNIT, pType)
    local pMax = UnitPowerMax(UNIT, pType)

    if type(pCur) ~= "number" or type(pMax) ~= "number" or pMax <= 0 then
        self.power:SetMinMaxValues(0, 1)
        self.power:SetValue(0)
        SafeSetText(self.powText, "")
    else
        self.power:SetMinMaxValues(0, pMax)
        self.power:SetValue(pCur)

        if cfg.showPowerText then
            SafeSetText(self.powText, FormatCurMaxAlways(pCur, pMax))
        else
            SafeSetText(self.powText, "")
        end
    end
end

-- ============================================================
-- HEAVY UPDATE (incoming/healabsorb/absorb) - event only
-- ============================================================
function PF:UpdateHealPred(force)
    if not self.root then return end
    local cfg = GetCfg()
    if not cfg.shown then return end

    if not (cfg.showIncomingHeals or cfg.showHealAbsorb or cfg.showAbsorb) then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    local hMax = UnitHealthMax(UNIT)
    if type(hMax) ~= "number" or issecret(hMax) or hMax <= 0 then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    local calc = EnsureHealCalc()
    local hpTexture = self.hp and self.hp:GetStatusBarTexture()
    if not (calc and hpTexture) then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    ReanchorOverlays()
    UnitGetDetailedHealPrediction(UNIT, UNIT, calc)

    local incoming = calc:GetIncomingHeals()
    local healAbs  = calc:GetHealAbsorbs()
    local shields  = UnitGetTotalAbsorbs(UNIT)

    if self.incBar then
        self.incBar:SetMinMaxValues(0, hMax)
        self.incBar:SetValue(type(incoming) == "number" and incoming or 0)
        local show = cfg.showIncomingHeals and (
            issecret(incoming) or (type(incoming) == "number" and (not issecret(incoming)) and incoming > 0)
        )
        self.incBar:SetShown(show and true or false)
    end

    if self.healAbsBar then
        self.healAbsBar:SetMinMaxValues(0, hMax)
        self.healAbsBar:SetValue(type(healAbs) == "number" and healAbs or 0)
        local show = cfg.showHealAbsorb and (
            issecret(healAbs) or (type(healAbs) == "number" and (not issecret(healAbs)) and healAbs > 0)
        )
        self.healAbsBar:SetShown(show and true or false)
    end

    if self.shieldAbsBar then
        self.shieldAbsBar:SetMinMaxValues(0, hMax)
        self.shieldAbsBar:SetValue(type(shields) == "number" and shields or 0)
        local show = cfg.showAbsorb and (
            issecret(shields) or (type(shields) == "number" and (not issecret(shields)) and shields > 0)
        )
        self.shieldAbsBar:SetShown(show and true or false)
    end
end

-- ============================================================
-- FORCE + SHOWN
-- ============================================================
function PF:ForceUpdate()
    self:Initialize()
    self:RequestLayout()
    ApplySecureVisibility()
    ApplyHPStyle()
    ApplyPowerColor()
    self:UpdateAll()
    self:UpdateHealPred(true)
end

function PF:SetShown(v)
    GetCfg().shown = v and true or false
    ApplySecureVisibility()
    self:UpdateAll()
    self:UpdateHealPred(true)
end

-- ============================================================
-- EVENTS
-- ============================================================
local function SafeRegisterUnitEvent(frame, eventName, ...)
    local ok = pcall(frame.RegisterUnitEvent, frame, eventName, ...)
    return ok
end

local HEAL_EVENTS = {
    UNIT_HEAL_PREDICTION = true,
    UNIT_ABSORB_AMOUNT_CHANGED = true,
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true,
    UNIT_MAXHEALTH = true,
}

local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")

SafeRegisterUnitEvent(E, "UNIT_HEALTH", UNIT)
SafeRegisterUnitEvent(E, "UNIT_MAXHEALTH", UNIT)
SafeRegisterUnitEvent(E, "UNIT_POWER_UPDATE", UNIT)
SafeRegisterUnitEvent(E, "UNIT_MAXPOWER", UNIT)
SafeRegisterUnitEvent(E, "UNIT_DISPLAYPOWER", UNIT)

SafeRegisterUnitEvent(E, "UNIT_HEAL_PREDICTION", UNIT)
SafeRegisterUnitEvent(E, "UNIT_ABSORB_AMOUNT_CHANGED", UNIT)
SafeRegisterUnitEvent(E, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UNIT)

local function Player_OnEvent(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        PF:ForceUpdate()
        DeferRefresh()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if PF.__pendingDriver then ApplySecureVisibility() end
        if PF.__pendingLayout then PF:RequestLayout() end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        PF:Initialize()
        PF:RequestLayout()
        PF:UpdateAll()
        PF:UpdateHealPred(false)
        RebuildPips(PF)
        DeferRefresh()
        return
    end

    if unit and unit ~= UNIT then return end

    if event == "UNIT_DISPLAYPOWER" then
        PF:RequestLayout()
        PF:UpdateAll()
        DeferRefresh()
        return
    end

    if HEAL_EVENTS[event] then
        PF:UpdateAll()
        PF:UpdateHealPred(false)
        return
    end

    PF:UpdateAll()
end

E:SetScript("OnEvent", Player_OnEvent)

-- ============================================================
-- SLASH
-- ============================================================
SLASH_TPF1 = "/tpf"
SlashCmdList.TPF = function()
    PF:SetShown(not (GetCfg().shown))
    if InCombatLockdown() then
        print("|cffffaa00[RobUI]|r Player visibility applies after combat.")
    end
end

SLASH_TPFSET1 = "/tpfset"
SlashCmdList.TPFSET = function()
    PF:ToggleSettings()
end