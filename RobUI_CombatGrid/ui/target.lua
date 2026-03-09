-- ============================================================================
-- target.lua (ctDB) + HealPred/Absorb overlays + GridCore plugin support
-- PluginId: ct_target
-- IMPORTANT:
--  - Plugin MUST NOT call GridCore:ReflowAll() inside ApplyLayout (prevents reflow loop)
--  - If no target: frame should NOT be visible (except Grid Edit Mode)  [when shown=true]
--  - VISIBILITY: frame is fully hidden when db.shown == false
--  - PERFORMANCE: avoid lock/visibility work on every UNIT_* event
-- ============================================================================

local AddonName, ns = ...
ns.Target = ns.Target or {}
local TF = ns.Target

TF._nextHealPred = TF._nextHealPred or 0
local PLUGIN_ID = "ct_target"

local pcall = pcall
local tonumber = tonumber
local type = type
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime

local UnitExists = UnitExists
local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack

local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver

local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

-- =========================================================
-- GridCore safe wrappers
-- =========================================================
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
-- DB (profile-backed via ns.GetCTDB from ptsettings.lua)
-- =========================================================
local function GetTargetDB()
    if ns.GetCTDB then ns.GetCTDB() end
    local ctDB = _G.ctDB
    if type(ctDB) ~= "table" then _G.ctDB = {}; ctDB = _G.ctDB end
    ctDB.target = ctDB.target or {}

    local db = ctDB.target

    -- Defaults
    if db.shown == nil then db.shown = true end

    if db.w == nil then db.w = 260 end
    if db.hpH == nil then db.hpH = 22 end
    if db.scale == nil then db.scale = 1 end
    if db.point == nil then db.point = "CENTER" end
    if db.relPoint == nil then db.relPoint = "CENTER" end
    if db.x == nil then db.x = 200 end
    if db.y == nil then db.y = -80 end
    if db.showHP == nil then db.showHP = true end
    if db.showName == nil then db.showName = true end
    if db.isVertical == nil then db.isVertical = false end
    if db.skinIndex == nil then db.skinIndex = 1 end
    if db.useClassColor == nil then db.useClassColor = true end
    if db.useCustomHP == nil then db.useCustomHP = false end
    if db.hpR == nil then db.hpR = 0.8 end
    if db.hpG == nil then db.hpG = 0.2 end
    if db.hpB == nil then db.hpB = 0.2 end
    if db.hpTextX == nil then db.hpTextX = 0 end
    if db.hpTextY == nil then db.hpTextY = 0 end
    if db.hpTextR == nil then db.hpTextR = 1 end
    if db.hpTextG == nil then db.hpTextG = 1 end
    if db.hpTextB == nil then db.hpTextB = 1 end
    if db.nameTextX == nil then db.nameTextX = 0 end
    if db.nameTextY == nil then db.nameTextY = 0 end
    if db.nameTextR == nil then db.nameTextR = 1 end
    if db.nameTextG == nil then db.nameTextG = 1 end
    if db.nameTextB == nil then db.nameTextB = 1 end
    if db.showIncomingHeals == nil then db.showIncomingHeals = true end
    if db.showHealAbsorb == nil then db.showHealAbsorb = true end
    if db.showAbsorb == nil then db.showAbsorb = true end

    return db
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

local function ApplyTargetColor(hpBar, db, unit)
    local skinIdx = db.skinIndex or 1
    local texPath = ns.SKINS[skinIdx] and ns.SKINS[skinIdx].path or (ns.SKINS[1] and ns.SKINS[1].path) or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    pcall(hpBar.SetStatusBarTexture, hpBar, texPath)

    local r, g, b = 0.2, 0.8, 0.2

    if db.useCustomHP then
        r, g, b = ns.Clamp01(db.hpR), ns.Clamp01(db.hpG), ns.Clamp01(db.hpB)
    else
        if unit and UnitIsPlayer(unit) then
            if db.useClassColor then
                r, g, b = ns.GetClassColorRGB(unit)
            end
        elseif unit then
            local reaction = UnitReaction("player", unit)
            if reaction then
                if reaction <= 3 then r, g, b = 0.9, 0.1, 0.1
                elseif reaction == 4 then r, g, b = 0.9, 0.9, 0.1
                else r, g, b = 0.2, 0.8, 0.2 end
            elseif UnitCanAttack("player", unit) then
                r, g, b = 0.9, 0.1, 0.1
            end
        end
    end

    pcall(hpBar.SetStatusBarColor, hpBar, r, g, b)
    local tex = hpBar:GetStatusBarTexture()
    if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b) end
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
-- Visibility rules
-- Priority:
--  1) db.shown == false -> ALWAYS hidden (no drivers)
--  2) Grid Edit Mode    -> show (even with no target)
--  3) No target         -> hide
--  4) unlocked          -> show
--  5) else              -> state driver
-- =========================================================
function TF:ApplySecureVisibility()
    if not self.root then return end
    if InCombatLockdown() then return end

    local db = GetTargetDB()

    if not db.shown then
        UnregisterStateDriver(self.root, "visibility")
        self.root:Hide()
        self._hiddenBySetting = true
        return
    end

    self._hiddenBySetting = false

    local hasTarget = UnitExists("target")

    if GC_IsEditMode() then
        UnregisterStateDriver(self.root, "visibility")
        self.root:Show()
        return
    end

    if not hasTarget then
        UnregisterStateDriver(self.root, "visibility")
        self.root:Hide()
        return
    end

    local ctDB = _G.ctDB
    if ctDB and ctDB.unlocked then
        UnregisterStateDriver(self.root, "visibility")
        self.root:Show()
        return
    end

    RegisterStateDriver(self.root, "visibility", "[@target,exists] show; hide")
end

-- =========================================================
-- Init
-- =========================================================
function TF:Initialize()
    if self.root then return end
    if ns.GetCTDB then ns.GetCTDB() end

    local root = CreateFrame("Button", "RobUI_TargetFrame", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    self.root = root
    root:SetClampedToScreen(true)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(20)
    root:RegisterForClicks("AnyUp")
    root:EnableMouse(true)
    root:SetMovable(true)
    if root.SetMouseMotionEnabled then root:SetMouseMotionEnabled(true) end
    root:SetAttribute("unit", "target")

    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    ns.EnsureBackdrop(hp, 0.0)
    ns.DisableMouseOn(hp)

    hp.bg = hp:CreateTexture(nil, "BACKGROUND")
    hp.bg:SetAllPoints()
    hp.bg:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    self.nameText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ns.DisableMouseOn(self.nameText)

    self.hpText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ns.DisableMouseOn(self.hpText)

    self._lastName = nil
    self._lastHPVal = nil

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
    mtext:SetText("Drag Target (ctDB)")

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        if IsGridDrivingNow() then return end
        root:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        if IsGridDrivingNow() then return end
        local db = GetTargetDB()
        local point, _, relPoint, x, y = root:GetPoint()
        db.point = point
        db.relPoint = relPoint
        db.x = x
        db.y = y
    end)

    self:ApplyLayout()
    self:ApplySecureVisibility()
    self:UpdateLockState()
    self:UpdateValues()

    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[self.root] = true
    if type(_G.ClickCastFrame_Register) == "function" then pcall(_G.ClickCastFrame_Register, self.root) end
    if ns.ClickCast and type(ns.ClickCast.RegisterFrame) == "function" then
        pcall(ns.ClickCast.RegisterFrame, ns.ClickCast, self.root, "target")
    end
end

function TF:UpdateLockState()
    if not self.root or not self.mover then return end
    if InCombatLockdown() then return end

    if self._hiddenBySetting then
        self.mover:Hide()
        return
    end

    if IsGridDrivingNow() then
        self.mover:Hide()
        return
    end

    local ctDB = _G.ctDB
    if ctDB and ctDB.unlocked then
        self.mover:Show()
    else
        self.mover:Hide()
    end
end

function TF:ApplyLayout()
    if not self.root then return end
    local db = GetTargetDB()

    if not GC_IsAttached(PLUGIN_ID) then
        self.root:ClearAllPoints()
        self.root:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end

    self.root:SetScale(db.scale or 1)

    self.hp:ClearAllPoints()
    self.hp:SetAllPoints(self.root)

    self.hpText:ClearAllPoints()
    self.nameText:ClearAllPoints()

    if db.isVertical then
        self.root:SetSize(db.hpH, db.w)
        self.hp:SetOrientation("VERTICAL")

        self.hpText:SetPoint("BOTTOM", self.hp, "BOTTOM", (db.hpTextX or 0), 10 + (db.hpTextY or 0))
        self.hpText:SetJustifyH("CENTER")

        self.nameText:SetPoint("TOP", self.hp, "TOP", (db.nameTextX or 0), -10 + (db.nameTextY or 0))
        self.nameText:SetJustifyH("CENTER")
    else
        self.root:SetSize(db.w, db.hpH)
        self.hp:SetOrientation("HORIZONTAL")

        self.hpText:SetPoint("RIGHT", self.hp, "RIGHT", -6 + (db.hpTextX or 0), (db.hpTextY or 0))
        self.hpText:SetJustifyH("RIGHT")

        self.nameText:SetPoint("LEFT", self.hp, "LEFT", 6 + (db.nameTextX or 0), (db.nameTextY or 0))
        self.nameText:SetJustifyH("LEFT")
    end

    self.hpText:SetTextColor(db.hpTextR or 1, db.hpTextG or 1, db.hpTextB or 1)
    self.hpText:SetShown(db.showHP and true or false)

    self.nameText:SetTextColor(db.nameTextR or 1, db.nameTextG or 1, db.nameTextB or 1)
    self.nameText:SetShown(db.showName and true or false)

    local font = ns.GetFontPath(self.hpText)
    local fontSize = math.max(10, math.floor((db.hpH or 22) * 0.45))
    self.hpText:SetFont(font, fontSize, "OUTLINE")
    self.nameText:SetFont(font, fontSize, "OUTLINE")

    ApplyTargetColor(self.hp, db, "target")
    AnchorOverlays(self, db)
end

function TF:UpdateValues()
    if not self.root then return end
    local db = GetTargetDB()

    -- Hard off: do nothing
    if not db.shown then return end

    -- No target: keep hidden + stop work
    if not UnitExists("target") then
        if self.incBar then self.incBar:Hide() end
        if self.healAbsBar then self.healAbsBar:Hide() end
        if self.shieldAbsBar then self.shieldAbsBar:Hide() end
        return
    end

    ApplyTargetColor(self.hp, db, "target")

    local targetName = UnitName("target") or ""
    ns.SafeSetText(self, "_lastName", self.nameText, targetName)

    local hMax = UnitHealthMax("target")
    local hCur = UnitHealth("target")
    ns.SafeSetMinMaxAndValue(self.hp, hMax, hCur)

    local hpString = ns.FormatCurMax(hCur, hMax) or ""
    ns.SafeSetText(self, "_lastHPVal", self.hpText, hpString)

    local now = GetTime()
    if InCombatLockdown() then
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

    -- Anchor once per update
    AnchorOverlays(self, db)

    UnitGetDetailedHealPrediction("target", "target", calc)
    local incoming = calc:GetIncomingHeals()
    local healAbs  = calc:GetHealAbsorbs()
    local shields  = UnitGetTotalAbsorbs("target")

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

function TF:RegisterRobHeal()
    if not self.root or self._robhealRegistered then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local fn = _G.RobHeal_RegisterFrame
    if type(fn) == "function" then
        pcall(fn, self.root, "target")
        self._robhealRegistered = true
    end
end

-- =========================================================
-- Grid plugin
-- =========================================================
local function RegisterGridPlugin()
    if TF._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
        name = "ctDB Target",
        default = { gx = 240, gy = 60, scaleWithGrid = false, label = "Target" },

        build = function()
            TF:Initialize()
            TF:RegisterRobHeal()
            return TF.root
        end,

        standard = { position = true, size = true, scale = true },

        setSize = function(frame, w, h)
            if not frame then return end
            local db = GetTargetDB()

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

            TF:ApplyLayout()
            TF:ApplySecureVisibility()
            TF:UpdateLockState()
            TF:UpdateValues()
        end,

        setScale = function(frame, s)
            if not frame then return end
            local db = GetTargetDB()

            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end

            db.scale = s
            pcall(frame.SetScale, frame, s)
            TF:ApplyLayout()
            TF:ApplySecureVisibility()
            TF:UpdateLockState()
            TF:UpdateValues()
        end,

        settings = function(parent)
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints()
            local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", 0, 0)
            t:SetJustifyH("LEFT")
            t:SetText("ctDB Target\n\n- Hidden when no target (except Grid Edit Mode) when enabled.\n- Fully hidden when disabled in overrides.\n")
            return f
        end,
    })

    TF._gridRegistered = true
end

-- =========================================================
-- Events
-- =========================================================
local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("PLAYER_TARGET_CHANGED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterEvent("UNIT_NAME_UPDATE")
E:RegisterEvent("ADDON_LOADED")
E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
E:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
E:RegisterUnitEvent("UNIT_HEALTH", "target")
E:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
E:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "target")
E:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
E:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "target")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if ns.GetCTDB then ns.GetCTDB() end
        TF:Initialize()
        TF:RegisterRobHeal()
        RegisterGridPlugin()

        TF:ApplyLayout()
        TF:ApplySecureVisibility()
        TF:UpdateLockState()
        TF:UpdateValues()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if ns.GetCTDB then ns.GetCTDB() end
        TF:ApplyLayout()
        TF:ApplySecureVisibility()
        TF:UpdateLockState()
        TF:UpdateValues()

    elseif event == "PLAYER_TARGET_CHANGED" then
        TF:ApplySecureVisibility()
        TF:UpdateLockState()
        TF:UpdateValues()

    elseif event == "PLAYER_REGEN_ENABLED" then
        TF:ApplySecureVisibility()
        TF:UpdateLockState()

    elseif event == "UNIT_NAME_UPDATE" and arg1 == "target" then
        TF:UpdateValues()

    elseif event == "ADDON_LOADED" and arg1 == "RobHeal" then
        TF:RegisterRobHeal()

    else
        -- UNIT_* events: ONLY update values (cheaper)
        if TF.root then
            TF:UpdateValues()
        end
    end
end)