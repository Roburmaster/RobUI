-- ============================================================================
-- player.lua (ctDB) + HealPred/Absorb overlays + GridCore plugin support
-- PluginId: ct_player
--
-- FIXES:
--  - Uses unique global frame name: RobUI_CT_PlayerFrame
--  - Hides automatically during Blizzard vehicle / override / possess UI
--  - Re-applies secure visibility after combat if needed
--  - Keeps existing ctDB/grid behavior
-- ============================================================================
local AddonName, ns = ...
ns = _G[AddonName] or ns or {}
_G[AddonName] = ns

ns.Player = ns.Player or {}
local PF = ns.Player

PF._nextHealPred   = PF._nextHealPred or 0
PF._driverApplied  = PF._driverApplied or false
PF._pendingDriver  = PF._pendingDriver or false
PF._hiddenBySetting = PF._hiddenBySetting or false

local PLUGIN_ID = "ct_player"

local pcall = pcall
local tonumber = tonumber
local type = type
local max = math.max
local floor = math.floor

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime

local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

-- =========================================================
-- DB (PROFILE-BACKED FIX)
-- =========================================================
local function GetPlayerDB()
    if ns.GetCTDB then ns.GetCTDB() end
    local ctDB = _G.ctDB
    if type(ctDB) ~= "table" then
        _G.ctDB = {}
        ctDB = _G.ctDB
    end
    ctDB.player = ctDB.player or {}

    local db = ctDB.player

    if db.shown == nil then db.shown = true end
    if db.point == nil then db.point = "CENTER" end
    if db.relPoint == nil then db.relPoint = "CENTER" end
    if db.x == nil then db.x = -240 end
    if db.y == nil then db.y = -120 end
    if db.scale == nil then db.scale = 1 end
    if db.w == nil then db.w = 260 end
    if db.hpH == nil then db.hpH = 22 end
    if db.showHP == nil then db.showHP = true end
    if db.showIncomingHeals == nil then db.showIncomingHeals = true end
    if db.showHealAbsorb == nil then db.showHealAbsorb = true end
    if db.showAbsorb == nil then db.showAbsorb = true end

    return db
end

local function GC_IsEditMode()
    local GC = ns and ns.GridCore
    if not GC then return false end
    if type(GC.IsEditMode) == "function" then
        local ok, r = pcall(GC.IsEditMode, GC)
        if ok and r then return true end
    end
    return false
end

local function GC_IsAttached(pluginId)
    local GC = ns and ns.GridCore
    if not GC then return false end
    if type(GC.IsPluginAttached) == "function" then
        local ok, r = pcall(GC.IsPluginAttached, GC, pluginId)
        if ok and r then return true end
    end
    return false
end

local function IsGridDrivingNow()
    if GC_IsEditMode() then return true end
    if GC_IsAttached(PLUGIN_ID) then return true end
    return false
end

-- =========================================================
-- Visibility
-- =========================================================
local function ApplySecureVisibility(self)
    if not self or not self.root then return end
    local db = GetPlayerDB()

    if InCombatLockdown and InCombatLockdown() then
        self._pendingDriver = true
        return
    end
    self._pendingDriver = false

    if not RegisterStateDriver then
        if db.shown then
            self.root:Show()
            self._hiddenBySetting = false
        else
            self.root:Hide()
            self._hiddenBySetting = true
        end
        return
    end

    if self._driverApplied and UnregisterStateDriver then
        pcall(UnregisterStateDriver, self.root)
        self._driverApplied = false
    end

    if db.shown then
        pcall(RegisterStateDriver, self.root, "visibility", "[vehicleui][overridebar][possessbar] hide; show")
        self._hiddenBySetting = false
    else
        pcall(RegisterStateDriver, self.root, "visibility", "hide")
        self._hiddenBySetting = true
    end

    self._driverApplied = true
end

function PF:ApplyVisibility()
    if not self.root then return end
    ApplySecureVisibility(self)
end

-- =========================================================
-- Overlays
-- =========================================================
local function SetupOverlays(self)
    if self.clipFrame then return end
    local hp = self.hp

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
end

local function AnchorOverlays(self, db)
    if not self.incBar or not self.healAbsBar or not self.shieldAbsBar then return end
    local hp = self.hp
    if not hp then return end

    local hpTex = hp.GetStatusBarTexture and hp:GetStatusBarTexture()

    local w, h = hp:GetSize()
    self.incBar:SetSize(w, h)
    self.healAbsBar:SetSize(w, h)
    self.shieldAbsBar:SetSize(w, h)

    self.incBar:ClearAllPoints()
    self.healAbsBar:ClearAllPoints()
    self.shieldAbsBar:ClearAllPoints()

    local vertical = db and db.isVertical
    if vertical or not hpTex then
        self.incBar:SetAllPoints(hp)
        self.healAbsBar:SetAllPoints(hp)
        self.shieldAbsBar:SetAllPoints(hp)
        return
    end

    self.incBar:SetPoint("TOPLEFT", hpTex, "TOPRIGHT")
    self.incBar:SetPoint("BOTTOMLEFT", hpTex, "BOTTOMRIGHT")

    self.healAbsBar:SetPoint("TOPRIGHT", hpTex, "TOPRIGHT")
    self.healAbsBar:SetPoint("BOTTOMRIGHT", hpTex, "BOTTOMRIGHT")

    self.shieldAbsBar:SetPoint("TOPRIGHT", hp, "TOPRIGHT")
    self.shieldAbsBar:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT")
end

-- =========================================================
-- Init
-- =========================================================
function PF:Initialize()
    if self.root then return end
    if ns.GetCTDB then ns.GetCTDB() end

    local root = CreateFrame("Button", "RobUI_CT_PlayerFrame", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    self.root = root
    root:SetClampedToScreen(true)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(20)
    root:RegisterForClicks("AnyUp")
    root:EnableMouse(true)
    root:SetMovable(true)
    if root.SetMouseMotionEnabled then root:SetMouseMotionEnabled(true) end
    root:SetAttribute("unit", "player")

    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    ns.EnsureBackdrop(hp, 0.0)
    ns.DisableMouseOn(hp)

    hp.bg = hp:CreateTexture(nil, "BACKGROUND")
    hp.bg:SetAllPoints()
    hp.bg:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    self.hpText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText:SetJustifyH("CENTER")
    ns.DisableMouseOn(self.hpText)
    self._lastHPText = nil

    SetupOverlays(self)

    local mover = CreateFrame("Frame", nil, root, "BackdropTemplate")
    mover:SetAllPoints(root)
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(100)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    self.mover = mover

    local mbg = mover:CreateTexture(nil, "BACKGROUND")
    mbg:SetAllPoints()
    mbg:SetColorTexture(0, 1, 0, 0.35)

    local mtext = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mtext:SetPoint("CENTER")
    mtext:SetText("Drag Player (ctDB)")

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then return end
        if IsGridDrivingNow() then return end
        root:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        if IsGridDrivingNow() then return end

        local db = GetPlayerDB()
        local point, _, relPoint, x, y = root:GetPoint()
        db.point = point
        db.relPoint = relPoint
        db.x = x
        db.y = y
    end)

    self:ApplyLayout()
    self:ApplyVisibility()
    self:UpdateValues()
    self:UpdateLockState()

    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[self.root] = true
    if type(_G.ClickCastFrame_Register) == "function" then
        pcall(_G.ClickCastFrame_Register, self.root)
    end
    if ns.ClickCast and type(ns.ClickCast.RegisterFrame) == "function" then
        pcall(ns.ClickCast.RegisterFrame, ns.ClickCast, self.root, "player")
    end
end

function PF:UpdateLockState()
    if not self.root or not self.mover then return end

    if self._hiddenBySetting then
        self.mover:Hide()
        self.mover:EnableMouse(false)
        return
    end

    if IsGridDrivingNow() then
        self.mover:Hide()
        self.mover:EnableMouse(false)
        return
    end

    local ctDB = _G.ctDB
    if ctDB and ctDB.unlocked then
        self.mover:Show()
        self.mover:EnableMouse(true)
    else
        self.mover:Hide()
        self.mover:EnableMouse(false)
    end
end

function PF:ApplyLayout()
    if not self.root then return end
    local db = GetPlayerDB()

    if not GC_IsAttached(PLUGIN_ID) then
        self.root:ClearAllPoints()
        self.root:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end

    self.root:SetScale(db.scale or 1)

    self.hpText:ClearAllPoints()

    if db.isVertical then
        self.root:SetSize(db.hpH, db.w)
        self.hp:SetOrientation("VERTICAL")
    else
        self.root:SetSize(db.w, db.hpH)
        self.hp:SetOrientation("HORIZONTAL")
    end

    self.hp:ClearAllPoints()
    self.hp:SetAllPoints(self.root)

    self.hpText:SetPoint("CENTER", self.hp, "CENTER", db.textX or 0, db.textY or 0)
    self.hpText:SetTextColor(db.textR or 1, db.textG or 1, db.textB or 1)
    self.hpText:SetShown(db.showHP and true or false)

    local font = ns.GetFontPath(self.hpText)
    local fontSize = max(10, floor((db.hpH or 22) * 0.45))
    self.hpText:SetFont(font, fontSize, "OUTLINE")

    ns.ApplyHPStyle(self.hp, db, "player")
    AnchorOverlays(self, db)
end

function PF:UpdateValues()
    if not self.root then return end

    local db = GetPlayerDB()
    if not db.shown then
        return
    end

    local unit = "player"
    local hMax = UnitHealthMax(unit)
    local hCur = UnitHealth(unit)

    ns.SafeSetMinMaxAndValue(self.hp, hMax, hCur)

    local hpStr = ns.FormatCurMax(hCur, hMax) or ""
    ns.SafeSetText(self, "_lastHPText", self.hpText, hpStr)

    local now = GetTime()
    if InCombatLockdown and InCombatLockdown() then
        if now < (self._nextHealPred or 0) then return end
        self._nextHealPred = now + 0.10
    end

    local calc = ns.EnsureHealCalc()
    if not (calc and type(hMax) == "number" and not ns.issecret(hMax) and hMax > 0) then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    AnchorOverlays(self, db)

    UnitGetDetailedHealPrediction(unit, unit, calc)
    local incoming = calc:GetIncomingHeals()
    local healAbs  = calc:GetHealAbsorbs()
    local shields  = UnitGetTotalAbsorbs(unit)

    if self.incBar then
        self.incBar:SetMinMaxValues(0, hMax)
        self.incBar:SetValue(incoming or 0)
        self.incBar:SetShown(db.showIncomingHeals and ns.ShouldShowNumber(incoming))
    end

    if self.healAbsBar then
        self.healAbsBar:SetMinMaxValues(0, hMax)
        self.healAbsBar:SetValue(healAbs or 0)
        self.healAbsBar:SetShown(db.showHealAbsorb and ns.ShouldShowNumber(healAbs))
    end

    if self.shieldAbsBar then
        self.shieldAbsBar:SetMinMaxValues(0, hMax)
        self.shieldAbsBar:SetValue(shields or 0)
        self.shieldAbsBar:SetShown(db.showAbsorb and ns.ShouldShowNumber(shields))
    end
end

function PF:RegisterRobHeal()
    if not self.root or self._robhealRegistered then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local fn = _G.RobHeal_RegisterFrame
    if type(fn) == "function" then
        pcall(fn, self.root, "player")
        self._robhealRegistered = true
    end
end

-- =========================================================
-- Grid plugin
-- =========================================================
local function RegisterGridPlugin()
    if PF._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
        name = "ctDB Player",
        default = { gx = -240, gy = 60, scaleWithGrid = false, label = "Player" },

        build = function()
            PF:Initialize()
            PF:RegisterRobHeal()
            return PF.root
        end,

        standard = { position = true, size = true, scale = true },

        setSize = function(frame, w, h)
            if not frame then return end
            local db = GetPlayerDB()

            w = tonumber(w) or db.w or 260
            h = tonumber(h) or db.hpH or 22
            if w < 40 then w = 40 end
            if h < 10 then h = 10 end

            if db.isVertical then
                db.hpH = w
                db.w   = h
            else
                db.w   = w
                db.hpH = h
            end

            PF:ApplyLayout()
            PF:ApplyVisibility()
            PF:UpdateValues()
            PF:UpdateLockState()
        end,

        setScale = function(frame, s)
            if not frame then return end
            local db = GetPlayerDB()

            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end

            db.scale = s
            pcall(frame.SetScale, frame, s)
            PF:ApplyLayout()
            PF:ApplyVisibility()
            PF:UpdateValues()
            PF:UpdateLockState()
        end,
    })

    PF._gridRegistered = true
end

-- =========================================================
-- Events
-- =========================================================
local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
E:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
E:RegisterEvent("ADDON_LOADED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterUnitEvent("UNIT_HEALTH", "player")
E:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
E:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "player")
E:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
E:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if ns.GetCTDB then ns.GetCTDB() end
        PF:Initialize()
        PF:RegisterRobHeal()
        RegisterGridPlugin()

        PF:ApplyLayout()
        PF:ApplyVisibility()
        PF:UpdateLockState()
        PF:UpdateValues()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if ns.GetCTDB then ns.GetCTDB() end
        PF:ApplyLayout()
        PF:ApplyVisibility()
        PF:UpdateLockState()
        PF:UpdateValues()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if PF._pendingDriver then
            PF:ApplyVisibility()
            PF:UpdateLockState()
        end

    elseif event == "ADDON_LOADED" and arg1 == "RobHeal" then
        PF:RegisterRobHeal()

    else
        if PF.root then
            PF:UpdateValues()
        end
    end
end)