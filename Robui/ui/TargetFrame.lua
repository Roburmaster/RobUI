local AddonName, ns = ...
local R = _G.Robui
ns.UnitFrames = ns.UnitFrames or {}
ns.UnitFrames.Target = ns.UnitFrames.Target or {}

local TF = ns.UnitFrames.Target
local UNIT = "target"
local PROF = ns.PROF

-- 1. DEFAULTS
local DEFAULTS = {
    shown = true,
    locked = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = 280,
    y = 120,

    w = 320,
    hpH = 26,
    powerH = 12,
    gap = 4,

    showName = true,
    showHPText = true,
    showPowerText = true,
    showPower = true,
    showLevel = true,
    showClassTag = true,

    nameSize = 12,
    hpSize = 11,
    powerSize = 10,
    lvlSize = 11,
    tagSize = 10,

    nameOffX = 0, nameOffY = 0,
    hpOffX = 0,   hpOffY = 0,
    powOffX = 0,  powOffY = 0,
    lvlOffX = 0,  lvlOffY = 0,
    tagOffX = 0,  tagOffY = 0,

    nameR=1, nameG=1, nameB=1,
    hpTextR=1, hpTextG=1, hpTextB=1,
    powTextR=1, powTextG=1, powTextB=1,
    lvlTextR=1, lvlTextG=1, lvlTextB=1,
    tagTextR=1, tagTextG=1, tagTextB=1,

    showIncomingHeals = true,
    showHealAbsorb    = true,
    showAbsorb        = true,

    useTexture = true,
    baseTexturePath = "Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
    noColorOverride = true,
    tintOnlyOnBase  = true,

    useClassColor = true,
    useCustomHP = false,
    hpR=0.2, hpG=0.8, hpB=0.2,

    useCustomPower = false,
    powR=0.2, powG=0.4, powB=1.0,
}

local function GetCfg()
    if R and R.Database and R.Database.profile and R.Database.profile.unitframes and R.Database.profile.unitframes.target then
        return R.Database.profile.unitframes.target
    end
    return DEFAULTS
end
TF.Defaults = DEFAULTS

local function GetScale()
    if R and R.GetMainUnitFrameScale then
        return R:GetMainUnitFrameScale()
    end
    return 1
end

-- ------------------------------------------------------------
-- 2) Secret-safe helpers
-- ------------------------------------------------------------
local function issecret(v)
    if type(_G.issecretvalue) == "function" then
        local ok, r = pcall(_G.issecretvalue, v)
        if ok and r then return true end
    end
    return false
end

local function IsSafeNumber(v) return type(v) == "number" and not issecret(v) end
local function IsSafePositive(v) return IsSafeNumber(v) and v > 0 end

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

local function SafeStr(v)
    if v == nil then return "" end
    if issecret(v) then return "secret" end
    local t = type(v)
    if t == "boolean" then return v and "1" or "0" end
    if t == "number" then return tostring(v) end
    if t == "string" then return v end
    return tostring(v)
end

local function IsNumberAny(v) return type(v) == "number" end
local function IsPositiveAny(v)
    if type(v) ~= "number" then return false end
    if issecret(v) then return true end
    return v > 0
end

local function CanShowTextNumber(v) return type(v) == "number" and not issecret(v) end

local function Abbrev(v)
    if type(v) ~= "number" or issecret(v) then return "" end
    if _G.AbbreviateLargeNumbers then
        local ok, s = pcall(_G.AbbreviateLargeNumbers, v)
        if ok and type(s) == "string" then return s end
    end
    if v >= 1000000 then return string.format("%.1fm", v / 1000000) end
    if v >= 1000 then return string.format("%.1fk", v / 1000) end
    return tostring(math.floor(v + 0.5))
end

local function FormatCurMax(cur, maxv)
    if not IsSafePositive(maxv) or not IsSafeNumber(cur) then return "" end
    return Abbrev(cur) .. " / " .. Abbrev(maxv)
end

local function EnsureBackdrop(f, alpha)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.25)
    f:SetBackdropBorderColor(0,0,0,1)
end

local function RegFont(fs, size, flags)
    local M = ns and ns.media
    if M and M.RegisterTarget and fs then
        M:RegisterTarget(fs, size, flags)
    end
end

local function GetFontPath(fs)
    if not fs or not fs.GetFont then return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
    local path = select(1, fs:GetFont())
    return path or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function GetUnitClassColorRGB(unit)
    local _, class = UnitClass(unit)
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

local function GetReactionColorRGB(unit)
    local r, g, b = 0.2, 0.8, 0.2
    local rc = UnitReaction("player", unit)
    if rc and FACTION_BAR_COLORS and FACTION_BAR_COLORS[rc] then
        local c = FACTION_BAR_COLORS[rc]
        r, g, b = c.r, c.g, c.b
    end
    if UnitCanAttack("player", unit) then
        r, g, b = 0.9, 0.1, 0.1
    end
    return r, g, b
end

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
-- 3) Texture mapping
-- ------------------------------------------------------------
local MEDIA_PATH = "Interface\\AddOns\\"..AddonName.."\\media\\"

local CLASS_TEXTURES = {
    WARRIOR     = MEDIA_PATH .. "robui_statusbar_warrior_256x32.tga",
    PALADIN     = MEDIA_PATH .. "robui_statusbar_paladin_256x32.tga",
    HUNTER      = MEDIA_PATH .. "robui_statusbar_hunter_256x32.tga",
    ROGUE       = MEDIA_PATH .. "robui_statusbar_rogue_256x32.tga",
    PRIEST      = MEDIA_PATH .. "robui_statusbar_priest_256x32.tga",
    DEATHKNIGHT = MEDIA_PATH .. "robui_statusbar_deathknight_256x32.tga",
    SHAMAN      = MEDIA_PATH .. "robui_statusbar_shaman_256x32.tga",
    MAGE        = MEDIA_PATH .. "robui_statusbar_mage_256x32.tga",
    WARLOCK     = MEDIA_PATH .. "robui_statusbar_warlock_256x32.tga",
    MONK        = MEDIA_PATH .. "robui_statusbar_monk_256x32.tga",
    DRUID       = MEDIA_PATH .. "robui_statusbar_druid_256x32.tga",
    DEMONHUNTER = MEDIA_PATH .. "robui_statusbar_demonhunter_256x32.tga",
    EVOKER      = MEDIA_PATH .. "robui_statusbar_evoker_256x32.tga",
}

local NPC_TEXTURES = {
    hostile  = MEDIA_PATH .. "robui_statusbar_hostile_256x32.tga",
    neutral  = MEDIA_PATH .. "robui_statusbar_neutral_256x32.tga",
    friendly = MEDIA_PATH .. "robui_statusbar_friendly_256x32.tga",
}

local function GetTargetSkinInfo()
    local cfg = GetCfg()
    local base = cfg.baseTexturePath or (MEDIA_PATH .. "base.tga")

    if not cfg.useTexture then
        return "Interface\\TARGETINGFRAME\\UI-StatusBar", false, "blizz", base
    end

    if not UnitExists(UNIT) then
        return base, true, "none", base
    end

    if UnitIsPlayer(UNIT) then
        local _, class = UnitClass(UNIT)
        local tex = class and CLASS_TEXTURES[class]
        if tex then
            return tex, true, "p:" .. tostring(class), base
        end
        return base, false, "p:base", base
    end

    if UnitCanAttack("player", UNIT) then
        return (NPC_TEXTURES.hostile or base), true, "npc:hostile", base
    end

    local rc = UnitReaction("player", UNIT)
    if rc == nil then
        return (NPC_TEXTURES.neutral or base), true, "npc:neutral?", base
    end

    if rc >= 5 then
        return (NPC_TEXTURES.friendly or base), true, "npc:friendly", base
    elseif rc == 4 then
        return (NPC_TEXTURES.neutral or base), true, "npc:neutral", base
    end

    return (NPC_TEXTURES.hostile or base), true, "npc:hostile2", base
end

-- ------------------------------------------------------------
-- 4) Heal prediction
-- ------------------------------------------------------------
local healCalc = nil
local function EnsureHealCalc()
    if healCalc then return healCalc end
    if type(CreateUnitHealPredictionCalculator) == "function" then
        healCalc = CreateUnitHealPredictionCalculator()
    end
    return healCalc
end

-- ------------------------------------------------------------
-- 5) HP style
-- ------------------------------------------------------------
TF.__lastSkinKey = nil

local function ReanchorOverlays()
    if not TF.root or not TF.hp or not TF.incBar or not TF.healAbsBar or not TF.shieldAbsBar then return end

    local hpTexture = TF.hp:GetStatusBarTexture()
    if hpTexture then
        TF.incBar:ClearAllPoints()
        TF.incBar:SetPoint("TOPLEFT", hpTexture, "TOPRIGHT")
        TF.incBar:SetPoint("BOTTOMLEFT", hpTexture, "BOTTOMRIGHT")

        TF.healAbsBar:ClearAllPoints()
        TF.healAbsBar:SetPoint("TOPRIGHT", hpTexture, "TOPRIGHT")
        TF.healAbsBar:SetPoint("BOTTOMRIGHT", hpTexture, "BOTTOMRIGHT")
    end

    TF.shieldAbsBar:ClearAllPoints()
    TF.shieldAbsBar:SetPoint("TOPRIGHT", TF.hp, "TOPRIGHT")
    TF.shieldAbsBar:SetPoint("BOTTOMRIGHT", TF.hp, "BOTTOMRIGHT")
end

local function ApplyHPStyle(force)
    if not TF.hp then return end
    local cfg = GetCfg()
    local base = cfg.baseTexturePath or (MEDIA_PATH .. "base.tga")

    local texPath, preferWhite, kindKey = GetTargetSkinInfo()
    texPath = texPath or base

    local guid = UnitGUID(UNIT)
    local skinKey =
        SafeStr(guid) .. "|" ..
        SafeStr(texPath) .. "|" ..
        SafeStr(cfg.useTexture) .. "|" ..
        SafeStr(cfg.noColorOverride) .. "|" ..
        SafeStr(cfg.tintOnlyOnBase) .. "|" ..
        SafeStr(base) .. "|" ..
        SafeStr(kindKey)

    if not force and TF.__lastSkinKey == skinKey then
        return
    end
    TF.__lastSkinKey = skinKey

    pcall(TF.hp.SetStatusBarTexture, TF.hp, texPath)

    local tex = TF.hp:GetStatusBarTexture()
    if tex then
        if tex.SetHorizTile then tex:SetHorizTile(false) end
        if tex.SetVertTile then tex:SetVertTile(false) end
    end

    ReanchorOverlays()

    local forceWhite = false
    if cfg.useTexture then
        if cfg.noColorOverride then
            forceWhite = true
        elseif cfg.tintOnlyOnBase and texPath ~= base then
            forceWhite = true
        elseif preferWhite then
            forceWhite = true
        end
    end

    if forceWhite then
        TF.hp:SetStatusBarColor(1,1,1)
        if tex and tex.SetVertexColor then tex:SetVertexColor(1,1,1) end
        return
    end

    local r,g,b = 0.2,0.8,0.2
    if cfg.useCustomHP then
        r,g,b = Clamp01(cfg.hpR), Clamp01(cfg.hpG), Clamp01(cfg.hpB)
    else
        if UnitExists(UNIT) and UnitIsPlayer(UNIT) and cfg.useClassColor then
            r,g,b = GetUnitClassColorRGB(UNIT)
        elseif UnitExists(UNIT) then
            r,g,b = GetReactionColorRGB(UNIT)
        end
    end

    TF.hp:SetStatusBarColor(r,g,b)
    if tex and tex.SetVertexColor then tex:SetVertexColor(r,g,b) end
end

-- ------------------------------------------------------------
-- 5.5) POWER COLOR
-- ------------------------------------------------------------
local function GetPowerColorRGB(unit, cfg)
    if cfg and cfg.useCustomPower then
        return Clamp01(cfg.powR), Clamp01(cfg.powG), Clamp01(cfg.powB)
    end

    if UnitExists(unit) then
        local powerType, token = UnitPowerType(unit)

        local col = nil
        if token and PowerBarColor then col = PowerBarColor[token] end
        if not col and powerType ~= nil and PowerBarColor then col = PowerBarColor[powerType] end
        if col then return col.r or 1, col.g or 1, col.b or 1 end
    end

    return 0.2, 0.4, 1.0
end

local function ApplyPowerColor()
    if not TF.power then return end
    local cfg = GetCfg()
    local r, g, b = GetPowerColorRGB(UNIT, cfg)
    TF.power:SetStatusBarColor(r, g, b)
end

-- ------------------------------------------------------------
-- 6) Secure visibility driver
-- ------------------------------------------------------------
TF.__driverApplied = false
TF.__pendingDriver = false

local function ApplySecureVisibility()
    local cfg = GetCfg()

    if InCombatLockdown() then
        TF.__pendingDriver = true
        return
    end
    TF.__pendingDriver = false

    if TF.holder and TF.__driverApplied and UnregisterStateDriver then
        pcall(UnregisterStateDriver, TF.holder)
        TF.__driverApplied = false
    end

    if not TF.holder then return end

    if not RegisterStateDriver then
        TF.holder:SetShown(cfg.shown and true or false)
        if TF.anchor then
            TF.anchor:SetShown(cfg.shown and true or false)
        end
        return
    end

    if cfg.shown then
        pcall(RegisterStateDriver, TF.holder, "visibility", "[@target,exists] show; hide")
    else
        pcall(RegisterStateDriver, TF.holder, "visibility", "hide")
    end

    TF.__driverApplied = true

    if TF.anchor then
        TF.anchor:SetShown(cfg.shown and true or false)
    end
end

-- ------------------------------------------------------------
-- 7) Deferred skin refresh
-- ------------------------------------------------------------
TF.__skinQueued = false
function TF:QueueSkinRefresh()
    if TF.__skinQueued then return end
    TF.__skinQueued = true

    C_Timer.After(0, function()
        TF.__skinQueued = false
        if not TF.root then return end
        TF.__lastSkinKey = nil
        ApplyHPStyle(true)
        ApplyPowerColor()
    end)
end

-- ------------------------------------------------------------
-- 8) Layout deferral
-- ------------------------------------------------------------
TF.__pendingLayout = false
function TF:RequestLayout()
    if InCombatLockdown() then
        TF.__pendingLayout = true
        return
    end
    TF.__pendingLayout = false
    TF:ApplyLayout()
end

-- ------------------------------------------------------------
-- 10) Public API
-- ------------------------------------------------------------
function TF:GetConfig() return GetCfg() end

function TF:ToggleSettings()
    if ns.UnitFrames.Target.Settings and ns.UnitFrames.Target.Settings.Toggle then
        ns.UnitFrames.Target.Settings.Toggle()
    else
        print("|cffff4444[RobUI]|r TargetFrame settings not loaded.")
    end
end

-- ------------------------------------------------------------
-- 11) Create frame
-- ------------------------------------------------------------
function TF:Initialize()
    if self.root then return end

    local anchor = CreateFrame("Frame", "RobUI_TargetFrameAnchor", UIParent, "BackdropTemplate")
    self.anchor = anchor
    anchor:SetSize(1, 1)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")

    local holder = CreateFrame("Frame", "RobUI_TargetFrameHolder", UIParent, "BackdropTemplate")
    self.holder = holder
    holder:SetClampedToScreen(true)

    if R then
        R.TargetFrame = holder
    end

    local root = CreateFrame("Frame", "RobUI_TargetFrame", holder, "BackdropTemplate")
    self.root = root
    root:SetAllPoints(holder)

    local click = CreateFrame("Button", nil, root, "SecureUnitButtonTemplate")
    self.click = click
    click:SetAllPoints(root)
    click:RegisterForClicks("AnyUp")
    click:SetAttribute("unit", UNIT)
    click:SetAttribute("*type1", "target")
    click:SetAttribute("*type2", "togglemenu")
    click:RegisterForDrag("LeftButton")

    local function StartMove()
        if InCombatLockdown() then return end
        local cfg = GetCfg()
        if cfg.locked then return end
        if not IsShiftKeyDown() then return end
        anchor:StartMoving()
    end

    local function StopMove()
        if InCombatLockdown() then return end
        anchor:StopMovingOrSizing()

        local cfg = GetCfg()
        local p, _, rp, x, y = anchor:GetPoint(1)

        cfg.point = p or "CENTER"
        cfg.relPoint = rp or "CENTER"
        cfg.x = math.floor((x or 0) + 0.5)
        cfg.y = math.floor((y or 0) + 0.5)

        TF:RequestLayout()
        if ns.UnitFrames.Target.Settings and ns.UnitFrames.Target.Settings.RefreshIfOpen then
            ns.UnitFrames.Target.Settings.RefreshIfOpen()
        end
    end

    anchor:SetScript("OnDragStart", StartMove)
    anchor:SetScript("OnDragStop", StopMove)
    click:SetScript("OnDragStart", StartMove)
    click:SetScript("OnDragStop", StopMove)

    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    EnsureBackdrop(hp, 0.0)

    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    self.hp.bg = hpBg

    local pow = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.power = pow
    EnsureBackdrop(pow, 0.0)
    pow:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

    local powBg = pow:CreateTexture(nil, "BACKGROUND")
    powBg:SetAllPoints()
    powBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    self.power.bg = powBg

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

    local cfg = GetCfg()
    self.nameText  = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText    = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.powText   = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.levelText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.tagText   = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    RegFont(self.nameText, cfg.nameSize, "OUTLINE")
    RegFont(self.hpText, cfg.hpSize, "OUTLINE")
    RegFont(self.powText, cfg.powerSize, "OUTLINE")
    RegFont(self.levelText, cfg.lvlSize, "OUTLINE")
    RegFont(self.tagText, cfg.tagSize, "OUTLINE")

    self._lastName = nil
    self._lastHPText = nil
    self._lastPowText = nil
    self._lastLvl = nil
    self._lastTag = nil
    self._lastHMax = nil
    self._lastPMax = nil

    self:ApplyLayout()
    ApplySecureVisibility()

    TF.__lastSkinKey = nil
    ApplyHPStyle(true)
    ApplyPowerColor()

    self:UpdateAll()
    self:UpdateHealPred(true)
end

-- ------------------------------------------------------------
-- 12) Layout apply
-- ------------------------------------------------------------
function TF:ApplyLayout()
    if not self.root or not self.holder or not self.anchor then return end
    local cfg = GetCfg()
    local scale = GetScale()

    local anchor = self.anchor
    local holder = self.holder

    local w    = Clamp(cfg.w, 140, 900)
    local hpH  = Clamp(cfg.hpH, 10, 60)
    local powH = Clamp(cfg.powerH, 6, 40)
    local gap  = Clamp(cfg.gap, 0, 30)

    local showPower = cfg.showPower
    local totalH = hpH
    if showPower then totalH = totalH + gap + powH end

    anchor:ClearAllPoints()
    anchor:SetPoint(
        cfg.point or "CENTER",
        UIParent,
        cfg.relPoint or "CENTER",
        cfg.x or 280,
        cfg.y or 120
    )

    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    holder:SetScale(scale or 1)
    holder:SetSize(w, totalH)

    self.root:SetAllPoints(holder)

    self.hp:ClearAllPoints()
    self.hp:SetPoint("TOPLEFT", self.root, "TOPLEFT", 0, 0)
    self.hp:SetPoint("TOPRIGHT", self.root, "TOPRIGHT", 0, 0)
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

    local font = GetFontPath(self.nameText)
    self.nameText:SetFont(font, Clamp(cfg.nameSize, 8, 28), "OUTLINE")
    self.hpText:SetFont(font, Clamp(cfg.hpSize, 8, 28), "OUTLINE")
    self.powText:SetFont(font, Clamp(cfg.powerSize, 8, 28), "OUTLINE")
    self.levelText:SetFont(font, Clamp(cfg.lvlSize, 8, 28), "OUTLINE")
    self.tagText:SetFont(font, Clamp(cfg.tagSize, 8, 28), "OUTLINE")

    self.nameText:ClearAllPoints()
    self.nameText:SetPoint("LEFT", self.hp, "LEFT", 6 + (cfg.nameOffX or 0), (cfg.nameOffY or 0))

    self.hpText:ClearAllPoints()
    self.hpText:SetPoint("RIGHT", self.hp, "RIGHT", -6 + (cfg.hpOffX or 0), (cfg.hpOffY or 0))

    self.powText:ClearAllPoints()
    self.powText:SetPoint("RIGHT", self.power, "RIGHT", -6 + (cfg.powOffX or 0), (cfg.powOffY or 0))

    self.levelText:ClearAllPoints()
    self.levelText:SetPoint("TOPRIGHT", self.hp, "TOPRIGHT", -6 + (cfg.lvlOffX or 0), -4 + (cfg.lvlOffY or 0))

    self.tagText:ClearAllPoints()
    self.tagText:SetPoint("BOTTOMRIGHT", self.levelText, "TOPRIGHT", (cfg.tagOffX or 0), 2 + (cfg.tagOffY or 0))

    self.nameText:SetShown(cfg.showName)
    self.hpText:SetShown(cfg.showHPText)
    self.powText:SetShown(cfg.showPowerText and showPower)
    self.levelText:SetShown(cfg.showLevel)
    self.tagText:SetShown(cfg.showClassTag)

    self.nameText:SetTextColor(Clamp01(cfg.nameR), Clamp01(cfg.nameG), Clamp01(cfg.nameB), 1)
    self.hpText:SetTextColor(Clamp01(cfg.hpTextR), Clamp01(cfg.hpTextG), Clamp01(cfg.hpTextB), 1)
    self.powText:SetTextColor(Clamp01(cfg.powTextR), Clamp01(cfg.powTextG), Clamp01(cfg.powTextB), 1)
    self.levelText:SetTextColor(Clamp01(cfg.lvlTextR), Clamp01(cfg.lvlTextG), Clamp01(cfg.lvlTextB), 1)
    self.tagText:SetTextColor(Clamp01(cfg.tagTextR), Clamp01(cfg.tagTextG), Clamp01(cfg.tagTextB), 1)

    ApplyHPStyle(true)
    ApplyPowerColor()
    ReanchorOverlays()

    self._lastHMax = nil
    self._lastPMax = nil
end

local function GetClassificationTag(unit)
    local c = UnitClassification(unit)
    if c == "worldboss" then return "BOSS" end
    if c == "elite" then return "ELITE" end
    if c == "rareelite" then return "RARE ELITE" end
    if c == "rare" then return "RARE" end
    return ""
end

-- ------------------------------------------------------------
-- 13) Lightweight update
-- ------------------------------------------------------------
function TF:UpdateAll()
    if not self.root then return end
    local cfg = GetCfg()

    if not UnitExists(UNIT) then
        SafeSetText(self, "_lastName", self.nameText, "")
        SafeSetText(self, "_lastHPText", self.hpText, "")
        SafeSetText(self, "_lastPowText", self.powText, "")
        SafeSetText(self, "_lastLvl", self.levelText, "")
        SafeSetText(self, "_lastTag", self.tagText, "")
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    ApplyHPStyle(false)

    SafeSetText(self, "_lastName", self.nameText, UnitName(UNIT) or "")

    if cfg.showLevel then
        local lvl = UnitLevel(UNIT)
        if IsSafeNumber(lvl) and lvl > 0 then
            SafeSetText(self, "_lastLvl", self.levelText, tostring(lvl))
        else
            SafeSetText(self, "_lastLvl", self.levelText, "")
        end
    else
        SafeSetText(self, "_lastLvl", self.levelText, "")
    end

    if cfg.showClassTag then
        SafeSetText(self, "_lastTag", self.tagText, GetClassificationTag(UNIT))
    else
        SafeSetText(self, "_lastTag", self.tagText, "")
    end

    local hCur = UnitHealth(UNIT)
    local hMax = UnitHealthMax(UNIT)

    if not IsPositiveAny(hMax) or not IsNumberAny(hCur) then
        self.hp:SetMinMaxValues(0, 1)
        self.hp:SetValue(1)
        SafeSetText(self, "_lastHPText", self.hpText, "")
    else
        if IsSafeNumber(hMax) and self._lastHMax ~= hMax then
            self._lastHMax = hMax
            self.hp:SetMinMaxValues(0, hMax)
        elseif not IsSafeNumber(hMax) then
            self.hp:SetMinMaxValues(0, hMax)
        end

        self.hp:SetValue(hCur)

        if cfg.showHPText and CanShowTextNumber(hCur) and CanShowTextNumber(hMax) then
            SafeSetText(self, "_lastHPText", self.hpText, FormatCurMax(hCur, hMax))
        else
            SafeSetText(self, "_lastHPText", self.hpText, "")
        end
    end

    local pCur = UnitPower(UNIT)
    local pMax = UnitPowerMax(UNIT)

    if not cfg.showPower or not IsPositiveAny(pMax) or not IsNumberAny(pCur) then
        self.power:SetMinMaxValues(0, 1)
        self.power:SetValue(0)
        SafeSetText(self, "_lastPowText", self.powText, "")
    else
        if IsSafeNumber(pMax) and self._lastPMax ~= pMax then
            self._lastPMax = pMax
            self.power:SetMinMaxValues(0, pMax)
        elseif not IsSafeNumber(pMax) then
            self.power:SetMinMaxValues(0, pMax)
        end

        self.power:SetValue(pCur)

        if cfg.showPowerText and CanShowTextNumber(pCur) and CanShowTextNumber(pMax) then
            SafeSetText(self, "_lastPowText", self.powText, FormatCurMax(pCur, pMax))
        else
            SafeSetText(self, "_lastPowText", self.powText, "")
        end
    end

    ApplyPowerColor()
end

-- ------------------------------------------------------------
-- 13.5) Heavy update
-- ------------------------------------------------------------
function TF:UpdateHealPred(force)
    if not self.root or not UnitExists(UNIT) then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    local cfg = GetCfg()
    if not (cfg.showIncomingHeals or cfg.showHealAbsorb or cfg.showAbsorb) then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    local hMax = UnitHealthMax(UNIT)
    if not IsPositiveAny(hMax) then
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

    UnitGetDetailedHealPrediction(UNIT, "player", calc)

    local incoming = calc:GetIncomingHeals()
    local healAbs  = calc:GetHealAbsorbs()
    local shields  = UnitGetTotalAbsorbs(UNIT)

    if self.incBar then
        self.incBar:SetMinMaxValues(0, hMax)
        self.incBar:SetValue(incoming)
        local showInc = cfg.showIncomingHeals and (issecret(incoming) or (IsSafeNumber(incoming) and incoming > 0))
        self.incBar:SetShown(showInc and true or false)
    end

    if self.healAbsBar then
        self.healAbsBar:SetMinMaxValues(0, hMax)
        self.healAbsBar:SetValue(healAbs)
        local showHA = cfg.showHealAbsorb and (issecret(healAbs) or (IsSafeNumber(healAbs) and healAbs > 0))
        self.healAbsBar:SetShown(showHA and true or false)
    end

    if self.shieldAbsBar then
        self.shieldAbsBar:SetMinMaxValues(0, hMax)
        self.shieldAbsBar:SetValue(shields)
        local showS = cfg.showAbsorb and (issecret(shields) or (IsSafeNumber(shields) and shields > 0))
        self.shieldAbsBar:SetShown(showS and true or false)
    end
end

function TF:ForceUpdate()
    self:Initialize()
    TF.__lastSkinKey = nil
    TF:RequestLayout()
    ApplySecureVisibility()
    ApplyHPStyle(true)
    ApplyPowerColor()
    self:UpdateAll()
    self:UpdateHealPred(true)
end

function TF:SetShown(v)
    GetCfg().shown = v and true or false
    ApplySecureVisibility()
    self:UpdateAll()
    self:UpdateHealPred(true)
end

-- ------------------------------------------------------------
-- 14) Events
-- ------------------------------------------------------------
local HEAL_EVENTS = {
    UNIT_HEAL_PREDICTION = true,
    UNIT_ABSORB_AMOUNT_CHANGED = true,
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true,
    UNIT_MAXHEALTH = true,
}

local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("PLAYER_TARGET_CHANGED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")

E:RegisterUnitEvent("UNIT_FACTION", UNIT)
E:RegisterUnitEvent("UNIT_FLAGS", UNIT)
E:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", UNIT)

E:RegisterUnitEvent("UNIT_HEALTH", UNIT)
E:RegisterUnitEvent("UNIT_MAXHEALTH", UNIT)
E:RegisterUnitEvent("UNIT_POWER_UPDATE", UNIT)
E:RegisterUnitEvent("UNIT_MAXPOWER", UNIT)
E:RegisterUnitEvent("UNIT_DISPLAYPOWER", UNIT)
E:RegisterUnitEvent("UNIT_NAME_UPDATE", UNIT)
E:RegisterUnitEvent("UNIT_LEVEL", UNIT)

E:RegisterUnitEvent("UNIT_HEAL_PREDICTION", UNIT)
E:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", UNIT)
E:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UNIT)

E:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        TF:ForceUpdate()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if TF.__pendingDriver then ApplySecureVisibility() end
        if TF.__pendingLayout then TF:RequestLayout() end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        TF:ForceUpdate()
        TF:QueueSkinRefresh()
        return
    end

    if unit and unit ~= UNIT then return end

    if event == "UNIT_DISPLAYPOWER" then
        TF:RequestLayout()
        ApplyPowerColor()
        TF:UpdateAll()
        return
    end

    if event == "UNIT_FACTION" or event == "UNIT_FLAGS" or event == "UNIT_CLASSIFICATION_CHANGED" then
        TF:QueueSkinRefresh()
        TF:UpdateAll()
        TF:UpdateHealPred(false)
        return
    end

    if HEAL_EVENTS[event] then
        TF:UpdateAll()
        TF:UpdateHealPred(false)
        return
    end

    TF:UpdateAll()
end)

-- ------------------------------------------------------------
-- 15) Slash
-- ------------------------------------------------------------
SLASH_TTF1 = "/ttf"
SlashCmdList.TTF = function()
    TF:SetShown(not (GetCfg().shown))
    if InCombatLockdown() then
        print("|cffffaa00[RobUI]|r TargetFrame visibility will apply after combat.")
    end
end

SLASH_TTFSET1 = "/ttfset"
SlashCmdList.TTFSET = function()
    TF:ToggleSettings()
end

if PROF and PROF.Wrap then
    TF.UpdateAll = PROF:Wrap("UF:Target", "UpdateAll", TF.UpdateAll)
    TF.ApplyLayout = PROF:Wrap("UF:Target", "ApplyLayout", TF.ApplyLayout)
    TF.UpdateHealPred = PROF:Wrap("UF:Target", "UpdateHealPred", TF.UpdateHealPred)
end
