local AddonName, ns = ...
local R = _G.Robui
ns.UnitFrames = ns.UnitFrames or {}
ns.UnitFrames.Pet = ns.UnitFrames.Pet or {}

local P = ns.UnitFrames.Pet
local UNIT = "pet"
local PROF = ns.PROF

-- 1. DEFAULTS
local DEFAULTS = {
    shown = true,
    locked = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = -540,
    y = 60,

    w = 260,
    hpH = 22,
    powerH = 10,
    gap = 4,

    -- Elements
    showName = true,
    showHPText = true,
    showPowerText = true,
    showPower = true,

    -- Fonts
    nameSize = 12,
    hpSize = 11,
    powerSize = 10,

    -- Offsets
    nameOffX = 0, nameOffY = 0,
    hpOffX = 0,   hpOffY = 0,
    powOffX = 0,  powOffY = 0,

    -- Text Colors
    nameR=1, nameG=1, nameB=1,
    hpTextR=1, hpTextG=1, hpTextB=1,
    powTextR=1, powTextG=1, powTextB=1,

    -- Skinning
    useTexture = true,
    baseTexturePath = "Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
    noColorOverride = true,
    tintOnlyOnBase  = true,

    -- Fallback tint
    useCustomHP = false,
    hpR=0.2, hpG=0.8, hpB=0.2,

    useCustomPower = false,
    powR=0.2, powG=0.4, powB=1.0,
}

-- Database Helper
local function GetCfg()
    if R and R.Database and R.Database.profile and R.Database.profile.unitframes and R.Database.profile.unitframes.pet then
        return R.Database.profile.unitframes.pet
    end
    return DEFAULTS
end

P.Defaults = DEFAULTS

-- ------------------------------------------------------------
-- 2) HELPERS (secret-safe + low GC)
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
local function IsNumberAny(v) return type(v) == "number" end
local function IsPositiveAny(v)
    if type(v) ~= "number" then return false end
    if issecret(v) then return true end
    return v > 0
end
local function CanShowTextNumber(v) return type(v) == "number" and not issecret(v) end

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

local function IsVehicleStateActive()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return true
    end
    if HasVehicleActionBar and HasVehicleActionBar() then
        return true
    end
    if IsPossessBarVisible and IsPossessBarVisible() then
        return true
    end
    return false
end

-- secret-safe cached SetText (avoids spam)
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
-- 3) TEXTURE MAPPING (pet uses NPC textures)
-- ------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\"..AddonName.."\\media\\"
local NPC_TEXTURES = {
    hostile  = MEDIA .. "robui_statusbar_hostile_256x32.tga",
    neutral  = MEDIA .. "robui_statusbar_neutral_256x32.tga",
    friendly = MEDIA .. "robui_statusbar_friendly_256x32.tga",
}

local function GetSkinInfo()
    local cfg = GetCfg()
    local base = cfg.baseTexturePath or (MEDIA .. "base.tga")

    if not cfg.useTexture then
        return "Interface\\TARGETINGFRAME\\UI-StatusBar", false, "blizz", base
    end

    if not UnitExists(UNIT) then
        return base, true, "none", base
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
-- 4) STYLE (NO string skinKey churn)
-- ------------------------------------------------------------
P.__last = P.__last or {}

local function ApplyHPStyle(force)
    if not P.hp then return end
    local cfg = GetCfg()
    local texPath, preferWhite, kindKey, base = GetSkinInfo()
    texPath = texPath or base

    local guid = UnitGUID(UNIT)

    local L = P.__last
    if not force then
        if L.guid == guid
            and L.tex == texPath
            and L.useTexture == cfg.useTexture
            and L.noColor == cfg.noColorOverride
            and L.tintOnly == cfg.tintOnlyOnBase
            and L.kind == kindKey
            and L.base == base
        then
            return
        end
    end

    L.guid = guid
    L.tex = texPath
    L.useTexture = cfg.useTexture
    L.noColor = cfg.noColorOverride
    L.tintOnly = cfg.tintOnlyOnBase
    L.kind = kindKey
    L.base = base

    pcall(P.hp.SetStatusBarTexture, P.hp, texPath)

    local tex = P.hp:GetStatusBarTexture()
    if tex then
        if tex.SetHorizTile then tex:SetHorizTile(false) end
        if tex.SetVertTile then tex:SetVertTile(false) end
    end

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
        P.hp:SetStatusBarColor(1,1,1)
        if tex and tex.SetVertexColor then tex:SetVertexColor(1,1,1) end
        return
    end

    local r,g,b = 0.2,0.8,0.2
    if cfg.useCustomHP then
        r,g,b = Clamp01(cfg.hpR), Clamp01(cfg.hpG), Clamp01(cfg.hpB)
    elseif UnitExists(UNIT) then
        r,g,b = GetReactionColorRGB(UNIT)
    end

    P.hp:SetStatusBarColor(r,g,b)
    if tex and tex.SetVertexColor then tex:SetVertexColor(r,g,b) end
end

local function ApplyPowerColor()
    if not P.power then return end
    local cfg = GetCfg()

    if cfg.useCustomPower then
        P.power:SetStatusBarColor(Clamp01(cfg.powR), Clamp01(cfg.powG), Clamp01(cfg.powB))
        return
    end

    if not UnitExists(UNIT) then return end

    local powerType, token = UnitPowerType(UNIT)
    local col = nil
    if token and PowerBarColor then col = PowerBarColor[token] end
    if not col and powerType ~= nil and PowerBarColor then col = PowerBarColor[powerType] end

    if col then
        P.power:SetStatusBarColor(col.r or 0.7, col.g or 0.7, col.b or 0.7)
    else
        P.power:SetStatusBarColor(0.7, 0.7, 0.7)
    end
end

-- ------------------------------------------------------------
-- 5) SECURE VISIBILITY DRIVER
-- ------------------------------------------------------------
P.__driverApplied = false
P.__pendingDriver = false

local function ApplySecureVisibility()
    if not P.root then return end
    local cfg = GetCfg()

    if InCombatLockdown() then
        P.__pendingDriver = true
        return
    end
    P.__pendingDriver = false

    if not RegisterStateDriver then
        if cfg.shown and UnitExists(UNIT) and not IsVehicleStateActive() then
            P.root:Show()
        else
            P.root:Hide()
        end
        return
    end

    if P.__driverApplied and UnregisterStateDriver then
        pcall(UnregisterStateDriver, P.root)
        P.__driverApplied = false
    end

    if cfg.shown then
        pcall(RegisterStateDriver, P.root, "visibility", "[vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide")
    else
        pcall(RegisterStateDriver, P.root, "visibility", "hide")
    end

    P.__driverApplied = true
end

-- ------------------------------------------------------------
-- 6) DEFERRED SKIN REFRESH
-- ------------------------------------------------------------
P.__skinQueued = false
function P:QueueSkinRefresh()
    if P.__skinQueued then return end
    P.__skinQueued = true

    C_Timer.After(0, function()
        P.__skinQueued = false
        if not P.root or not UnitExists(UNIT) or IsVehicleStateActive() then return end
        ApplyHPStyle(true)
        ApplyPowerColor()
    end)

    C_Timer.After(0.05, function()
        if not P.root or not UnitExists(UNIT) or IsVehicleStateActive() then return end
        ApplyHPStyle(true)
        ApplyPowerColor()
    end)
end

-- ------------------------------------------------------------
-- 7) LAYOUT DEFERRAL
-- ------------------------------------------------------------
P.__pendingLayout = false
function P:RequestLayout()
    if InCombatLockdown() then
        P.__pendingLayout = true
        return
    end
    P.__pendingLayout = false
    P:ApplyLayout()
end

-- ------------------------------------------------------------
-- 7.5) LIGHT TICKER (pet can be flaky; keep it stable)
-- ------------------------------------------------------------
P.__ticker = P.__ticker or nil
function P:StartTicker()
    if self.__ticker then return end
    self.__ticker = C_Timer.NewTicker(0.30, function()
        if not P or not P.root then return end
        local cfg = GetCfg()
        if not cfg.shown then return end
        if IsVehicleStateActive() then return end
        if not UnitExists(UNIT) then return end
        P:UpdateAll()
    end)
end

function P:StopTicker()
    if self.__ticker then
        self.__ticker:Cancel()
        self.__ticker = nil
    end
end

-- ------------------------------------------------------------
-- 8) PUBLIC API
-- ------------------------------------------------------------
function P:GetConfig() return GetCfg() end

function P:ToggleSettings()
    if ns.UnitFrames.Pet.Settings and ns.UnitFrames.Pet.Settings.Toggle then
        ns.UnitFrames.Pet.Settings.Toggle()
    else
        print("|cffff4444[RobUI]|r Pet settings file not loaded.")
    end
end

-- ------------------------------------------------------------
-- 9) CREATE FRAME
-- ------------------------------------------------------------
function P:Initialize()
    if self.root then return end
    local cfg = GetCfg()

    local root = CreateFrame("Frame", "RobUI_PetFrame", UIParent, "BackdropTemplate")
    self.root = root
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")

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
        c.point, c.relPoint, c.x, c.y = p, rp, math.floor((x or 0)+0.5), math.floor((y or 0)+0.5)
        P:RequestLayout()
        if ns.UnitFrames.Pet.Settings and ns.UnitFrames.Pet.Settings.RefreshIfOpen then
            ns.UnitFrames.Pet.Settings.RefreshIfOpen()
        end
    end

    root:SetScript("OnDragStart", StartMove)
    root:SetScript("OnDragStop", StopMove)
    click:SetScript("OnDragStart", StartMove)
    click:SetScript("OnDragStop", StopMove)

    -- Bars
    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    EnsureBackdrop(hp, 0.0)

    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    hp.bg = hpBg

    local pow = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.power = pow
    EnsureBackdrop(pow, 0.0)
    pow:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

    local powBg = pow:CreateTexture(nil, "BACKGROUND")
    powBg:SetAllPoints()
    powBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    pow.bg = powBg

    -- Text
    self.nameText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText   = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.powText  = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    RegFont(self.nameText, cfg.nameSize, "OUTLINE")
    RegFont(self.hpText, cfg.hpSize, "OUTLINE")
    RegFont(self.powText, cfg.powerSize, "OUTLINE")

    -- caches
    self._lastNameText = nil
    self._lastHPText = nil
    self._lastPowText = nil
    self._lastHMax = nil
    self._lastPMax = nil

    self:ApplyLayout()
    ApplySecureVisibility()

    ApplyHPStyle(true)
    ApplyPowerColor()

    self:UpdateAll()
end

-- ------------------------------------------------------------
-- 10) LAYOUT
-- ------------------------------------------------------------
function P:ApplyLayout()
    if not self.root then return end
    local cfg = GetCfg()

    local root = self.root
    root:ClearAllPoints()
    if cfg.point then
        root:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    else
        root:SetPoint("CENTER", UIParent, "CENTER", -540, 60)
    end

    local w    = Clamp(cfg.w, 140, 900)
    local hpH  = Clamp(cfg.hpH, 10, 60)
    local powH = Clamp(cfg.powerH, 6, 40)
    local gap  = Clamp(cfg.gap, 0, 30)

    local showPower = cfg.showPower
    local totalH = hpH
    if showPower then totalH = totalH + gap + powH end

    root:SetSize(w, totalH)

    self.hp:ClearAllPoints()
    self.hp:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    self.hp:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
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

    local font = GetFontPath(self.nameText)
    self.nameText:SetFont(font, Clamp(cfg.nameSize, 8, 28), "OUTLINE")
    self.hpText:SetFont(font, Clamp(cfg.hpSize, 8, 28), "OUTLINE")
    self.powText:SetFont(font, Clamp(cfg.powerSize, 8, 28), "OUTLINE")

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

    ApplyHPStyle(true)
    ApplyPowerColor()
end

-- ------------------------------------------------------------
-- 11) UPDATE VALUES (no heal prediction / no shields)
-- ------------------------------------------------------------
function P:UpdateAll()
    if not self.root then return end
    local cfg = GetCfg()

    if IsVehicleStateActive() then
        SafeSetText(self, "_lastNameText", self.nameText, "")
        SafeSetText(self, "_lastHPText", self.hpText, "")
        SafeSetText(self, "_lastPowText", self.powText, "")
        self:StopTicker()
        return
    end

    if not UnitExists(UNIT) then
        SafeSetText(self, "_lastNameText", self.nameText, "")
        SafeSetText(self, "_lastHPText", self.hpText, "")
        SafeSetText(self, "_lastPowText", self.powText, "")
        self:StopTicker()
        return
    end

    if cfg.shown then
        self:StartTicker()
    else
        self:StopTicker()
    end

    ApplyHPStyle(false)
    ApplyPowerColor()

    SafeSetText(self, "_lastNameText", self.nameText, UnitName(UNIT) or "")

    -- HP
    local hCur = UnitHealth(UNIT)
    local hMax = UnitHealthMax(UNIT)

    if not IsPositiveAny(hMax) or not IsNumberAny(hCur) then
        self.hp:SetMinMaxValues(0, 1)
        self.hp:SetValue(1)
        SafeSetText(self, "_lastHPText", self.hpText, "")
    else
        if IsSafeNumber(hMax) then
            if self._lastHMax ~= hMax then
                self._lastHMax = hMax
                self.hp:SetMinMaxValues(0, hMax)
            end
        else
            self.hp:SetMinMaxValues(0, hMax)
        end

        self.hp:SetValue(hCur)

        if cfg.showHPText and CanShowTextNumber(hCur) and CanShowTextNumber(hMax) then
            SafeSetText(self, "_lastHPText", self.hpText, FormatCurMax(hCur, hMax))
        else
            SafeSetText(self, "_lastHPText", self.hpText, "")
        end
    end

    -- POWER
    local pCur = UnitPower(UNIT)
    local pMax = UnitPowerMax(UNIT)

    if (not cfg.showPower) or (not IsPositiveAny(pMax)) or (not IsNumberAny(pCur)) then
        self.power:SetMinMaxValues(0, 1)
        self.power:SetValue(0)
        SafeSetText(self, "_lastPowText", self.powText, "")
    else
        if IsSafeNumber(pMax) then
            if self._lastPMax ~= pMax then
                self._lastPMax = pMax
                self.power:SetMinMaxValues(0, pMax)
            end
        else
            self.power:SetMinMaxValues(0, pMax)
        end

        self.power:SetValue(pCur)

        if cfg.showPowerText and cfg.showPower and CanShowTextNumber(pCur) and CanShowTextNumber(pMax) then
            SafeSetText(self, "_lastPowText", self.powText, FormatCurMax(pCur, pMax))
        else
            SafeSetText(self, "_lastPowText", self.powText, "")
        end
    end
end

function P:ForceUpdate()
    self:Initialize()
    P:RequestLayout()
    ApplySecureVisibility()

    ApplyHPStyle(true)
    ApplyPowerColor()

    if UnitExists(UNIT) and GetCfg().shown and not IsVehicleStateActive() then
        P:StartTicker()
    else
        P:StopTicker()
    end

    self:UpdateAll()
end

function P:SetShown(v)
    GetCfg().shown = v and true or false
    ApplySecureVisibility()

    if v and UnitExists(UNIT) and not IsVehicleStateActive() then
        P:StartTicker()
        P:UpdateAll()
    else
        P:StopTicker()
    end
end

-- ------------------------------------------------------------
-- 12) EVENTS
-- ------------------------------------------------------------
local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("UNIT_PET")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterEvent("PLAYER_REGEN_DISABLED")
E:RegisterEvent("UNIT_ENTERED_VEHICLE")
E:RegisterEvent("UNIT_EXITED_VEHICLE")
E:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
E:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
E:RegisterEvent("PET_BAR_UPDATE")

E:RegisterUnitEvent("UNIT_HEALTH", UNIT)
E:RegisterUnitEvent("UNIT_MAXHEALTH", UNIT)
E:RegisterUnitEvent("UNIT_POWER_UPDATE", UNIT)
E:RegisterUnitEvent("UNIT_MAXPOWER", UNIT)
E:RegisterUnitEvent("UNIT_DISPLAYPOWER", UNIT)
E:RegisterUnitEvent("UNIT_NAME_UPDATE", UNIT)
E:RegisterUnitEvent("UNIT_FACTION", UNIT)
E:RegisterUnitEvent("UNIT_FLAGS", UNIT)

E:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        P:ForceUpdate()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if P.__pendingDriver then ApplySecureVisibility() end
        if P.__pendingLayout then P:RequestLayout() end
        P:UpdateAll()
        return
    end

    if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then
            ApplySecureVisibility()
            P:UpdateAll()
        end
        return
    end

    if event == "UPDATE_VEHICLE_ACTIONBAR" or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "PET_BAR_UPDATE" then
        ApplySecureVisibility()
        P:UpdateAll()
        return
    end

    if event == "UNIT_PET" then
        P:Initialize()
        P:RequestLayout()
        ApplySecureVisibility()
        P:QueueSkinRefresh()
        P:UpdateAll()
        return
    end

    if unit and unit ~= UNIT then return end

    if event == "UNIT_DISPLAYPOWER" then
        P:RequestLayout()
        P:UpdateAll()
        return
    end

    if event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        P:QueueSkinRefresh()
        P:UpdateAll()
        return
    end

    P:UpdateAll()
end)

-- ------------------------------------------------------------
-- 13) SLASH
-- ------------------------------------------------------------
SLASH_TPET1 = "/tpet"
SlashCmdList.TPET = function()
    P:SetShown(not (GetCfg().shown))
    if InCombatLockdown() then
        print("|cffffaa00[RobUI]|r Pet visibility applies after combat.")
    end
end

SLASH_TPETSET1 = "/tpetset"
SlashCmdList.TPETSET = function()
    P:ToggleSettings()
end

-- Optional profiler hooks
if PROF and PROF.Wrap then
    P.UpdateAll   = PROF:Wrap("UF:Pet", "UpdateAll", P.UpdateAll)
    P.ApplyLayout = PROF:Wrap("UF:Pet", "ApplyLayout", P.ApplyLayout)
end