-- ============================================================================
-- RobUI PlayerFrame - Mythic+ Mode (12.0 SECRET-SAFE, VISUAL FIXED)
-- WITH DB, STANDALONE SETTINGS PANEL, CUSTOM SKINS, AND UNLOCK TOGGLE
-- FIXES:
--  - Reverted to original Absolute HP numbers (Abbreviated, e.g. 1.5m / 2.0m)
--  - Text is absolutely centered regardless of frame size
--  - No Resource Bar, No Name Text
-- ============================================================================

local AddonName, ns = ...
ns.PlayerFrameMPlus = ns.PlayerFrameMPlus or {}
local PF = ns.PlayerFrameMPlus

-- ------------------------------------------------------------
-- BUILT-IN SKINS (Saves addon size by using Blizzard textures)
-- ------------------------------------------------------------
local SKINS = {
    [1] = { name = "Blizzard Classic", path = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
    [2] = { name = "Flat Solid",       path = "Interface\\Buttons\\WHITE8x8" },
    [3] = { name = "Raid Frame",       path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    [4] = { name = "Character Skills", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    [5] = { name = "Class Trainer",    path = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-StatusBar" }
}

-- ------------------------------------------------------------
-- CONFIG (Defaults, will be merged with RobUIPlayerFrameDB)
-- ------------------------------------------------------------
PF.ConfigDefaults = {
    shown = true,
    unlocked = false,
    point = "CENTER",
    relPoint = "CENTER",
    x = -280,
    y = 120,
    w = 340,
    hpH = 28,
    hpSize = 14,
    skinIndex = 1,
    useClassColor = true,
    useCustomHP = false,
    hpR = 0.2, hpG = 0.8, hpB = 0.2,
    showIncomingHeals = true,
    showHealAbsorb = true,
    showAbsorb = true,
    lowHPBlink = true,
    lowHPThreshold = 0.35, -- number (cfg), not secret
    blinkSpeed = 0.18,
}

PF.Config = {} -- Will point to SavedVariables after load

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
-- SAFE text set & Formatters
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
    local skinIdx = cfg.skinIndex or 1
    local texPath = SKINS[skinIdx] and SKINS[skinIdx].path or SKINS[1].path

    pcall(hpBar.SetStatusBarTexture, hpBar, texPath)

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
-- Low HP blink (secret-safe with correct decimal handling)
-- ------------------------------------------------------------
PF._blinkOn = false
PF._blinkNext = 0

local function TryLowHP()
    local cfg = PF.Config
    local thr = cfg.lowHPThreshold or 0.35

    -- Attempt 1: Standard calculation
    local ok, low = pcall(function()
        local h = UnitHealth("player")
        local m = UnitHealthMax("player")
        if type(h) == "number" and type(m) == "number" and m > 0 then
            return (h / m) <= thr
        end
        error("Secret value detected")
    end)
    if ok then return low end

    -- Attempt 2: Secret-safe fallback
    if type(UnitHealthPercent) == "function" then
        local ok2, low2 = pcall(function()
            local pct = UnitHealthPercent("player", true)
            if type(pct) == "number" then
                if pct > 1 then return pct <= (thr * 100) end
                return pct <= thr
            end
            return pct <= thr
        end)
        if ok2 then return low2 and true or false end
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
-- ------------------------------------------------------------
PF._robhealRegistered = false
PF._pendingRobHealReg = false
PF._pendingClickReg = false

function PF:RegisterWithRobHeal()
    if self._robhealRegistered then return end
    if not self.root then return end

    if InCombatLockdown and InCombatLockdown() then
        self._pendingRobHealReg = true
        return
    end

    local fn = _G.RobHeal_RegisterFrame
    if type(fn) == "function" then
        pcall(fn, self.root, "player")
        self._robhealRegistered = true
        self._pendingRobHealReg = false
    else
        self._pendingRobHealReg = true
    end
end

-- ------------------------------------------------------------
-- Click-cast registration
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

    local root = CreateFrame("Button", "RobUI_PlayerFrame_MPlus", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    self.root = root

    root:SetClampedToScreen(true)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(20)

    root:RegisterForClicks("AnyUp")
    root:EnableMouse(true)

    -- Drag functionality (Based on settings toggle)
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and PF.Config.unlocked then
            self:StartMoving()
        end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PF.Config.point = point
        PF.Config.relPoint = relPoint
        PF.Config.x = x
        PF.Config.y = y
    end)

    if root.SetMouseMotionEnabled then root:SetMouseMotionEnabled(true) end
    root:SetAttribute("unit", "player")

    local hp = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    self.hp = hp
    EnsureBackdrop(hp, 0.0)
    DisableMouseOn(hp)

    hp.bg = hp:CreateTexture(nil, "BACKGROUND")
    hp.bg:SetAllPoints()
    hp.bg:SetColorTexture(0.07, 0.07, 0.07, 0.95)

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

    -- ------------------------------------------------------------
    -- HP TEXT (Centered original format, e.g. "1.5m / 2.0m")
    -- ------------------------------------------------------------
    self.hpText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hpText:SetJustifyH("CENTER")
    DisableMouseOn(self.hpText)
    
    local font = GetFontPath(self.hpText)
    self.hpText:SetFont(font, cfg.hpSize or 14, "OUTLINE")
    self._lastHPText = nil

    self:ApplyLayout()
    self:UpdateValues()
    self:RegisterForClickCasting()
    self:RegisterWithRobHeal()
end

function PF:ApplyLayout()
    if not self.root then return end
    local cfg = self.Config

    self.root:ClearAllPoints()
    self.root:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or "CENTER", cfg.x or -280, cfg.y or 120)

    local w   = tonumber(cfg.w) or 340
    local hpH = tonumber(cfg.hpH) or 28

    self.root:SetSize(w, hpH)

    self.hp:ClearAllPoints()
    self.hp:SetAllPoints(self.root)

    -- Force text to the absolute center of the frame
    self.hpText:ClearAllPoints()
    self.hpText:SetPoint("CENTER", self.hp, "CENTER", 0, 0)

    ApplyHPStyle(self.hp)

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

    local hMax = 1
    do
        local ok, v = pcall(UnitHealthMax, unit)
        if ok and type(v) == "number" and v > 0 then
            hMax = v
        end
    end

    local hCur = 0
    do
        local ok, v = pcall(UnitHealth, unit)
        if ok then
            hCur = v
        end
    end

    SafeSetMinMaxAndValue(self.hp, hMax, hCur)

    -- Display Original Number Format (e.g., "1.5m / 2.0m")
    local hpStr = FormatCurMaxNoCompare(hCur, hMax) or ""
    SafeSetText(self, "_lastHPText", self.hpText, hpStr)

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

    local shields = 0
    do
        local ok, v = pcall(UnitGetTotalAbsorbs, unit)
        if ok and type(v) == "number" then
            shields = v
        end
    end

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
-- Standalone Options Panel Construction
-- ------------------------------------------------------------
function PF:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "RobUIPlayerFrameOptions", UIParent, "BackdropTemplate")
    panel:SetSize(320, 320)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    tinsert(UISpecialFrames, "RobUIPlayerFrameOptions")

    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0, 0, 0, 1)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("RobUI Player Frame")

    local unlockBtn = CreateFrame("CheckButton", "RobUI_PF_UnlockBtn", panel, "UICheckButtonTemplate")
    unlockBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -60, -15)
    _G[unlockBtn:GetName().."Text"]:SetText("Unlock Frame to Move")
    unlockBtn:SetChecked(PF.Config.unlocked)
    unlockBtn:SetScript("OnClick", function(self)
        PF.Config.unlocked = self:GetChecked()
    end)

    local wSlider = CreateFrame("Slider", "RobUI_PF_WSlider", panel, "OptionsSliderTemplate")
    wSlider:SetPoint("TOP", title, "BOTTOM", 0, -65)
    wSlider:SetMinMaxValues(150, 600)
    wSlider:SetValueStep(1)
    wSlider:SetObeyStepOnDrag(true)
    wSlider:SetValue(PF.Config.w)
    _G[wSlider:GetName().."Text"]:SetText("Width")
    _G[wSlider:GetName().."Low"]:SetText("150")
    _G[wSlider:GetName().."High"]:SetText("600")
    wSlider:SetScript("OnValueChanged", function(self, val)
        PF.Config.w = val
        if not InCombatLockdown() then PF:ApplyLayout() end
    end)

    local hSlider = CreateFrame("Slider", "RobUI_PF_HSlider", panel, "OptionsSliderTemplate")
    hSlider:SetPoint("TOP", wSlider, "BOTTOM", 0, -40)
    hSlider:SetMinMaxValues(10, 100)
    hSlider:SetValueStep(1)
    hSlider:SetObeyStepOnDrag(true)
    hSlider:SetValue(PF.Config.hpH)
    _G[hSlider:GetName().."Text"]:SetText("Height")
    _G[hSlider:GetName().."Low"]:SetText("10")
    _G[hSlider:GetName().."High"]:SetText("100")
    hSlider:SetScript("OnValueChanged", function(self, val)
        PF.Config.hpH = val
        if not InCombatLockdown() then PF:ApplyLayout() end
    end)

    local skinSlider = CreateFrame("Slider", "RobUI_PF_SkinSlider", panel, "OptionsSliderTemplate")
    skinSlider:SetPoint("TOP", hSlider, "BOTTOM", 0, -40)
    skinSlider:SetMinMaxValues(1, 5)
    skinSlider:SetValueStep(1)
    skinSlider:SetObeyStepOnDrag(true)
    skinSlider:SetValue(PF.Config.skinIndex)
    _G[skinSlider:GetName().."Text"]:SetText("Skin: " .. (SKINS[PF.Config.skinIndex] and SKINS[PF.Config.skinIndex].name or SKINS[1].name))
    _G[skinSlider:GetName().."Low"]:SetText("1")
    _G[skinSlider:GetName().."High"]:SetText("5")
    skinSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(tonumber(val) or 1)
        if val < 1 then val = 1 end
        if val > 5 then val = 5 end

        PF.Config.skinIndex = val
        _G[self:GetName().."Text"]:SetText("Skin: " .. (SKINS[val] and SKINS[val].name or SKINS[1].name))
        if not InCombatLockdown() then PF:ApplyLayout() end
    end)

    local classColorBtn = CreateFrame("CheckButton", "RobUI_PF_ClassColorBtn", panel, "UICheckButtonTemplate")
    classColorBtn:SetPoint("TOPLEFT", skinSlider, "BOTTOMLEFT", -30, -25)
    _G[classColorBtn:GetName().."Text"]:SetText("Use Class Colors")
    classColorBtn:SetChecked(PF.Config.useClassColor)

    local colorSwatch = CreateFrame("Button", nil, panel)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", _G[classColorBtn:GetName().."Text"], "RIGHT", 15, 0)

    local swatchTex = colorSwatch:CreateTexture(nil, "OVERLAY")
    swatchTex:SetColorTexture(PF.Config.hpR, PF.Config.hpG, PF.Config.hpB)
    swatchTex:SetAllPoints()

    local swatchBg = colorSwatch:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetColorTexture(1, 1, 1)
    swatchBg:SetPoint("TOPLEFT", -1, 1)
    swatchBg:SetPoint("BOTTOMRIGHT", 1, -1)

    local function UpdateColors()
        PF.Config.useClassColor = classColorBtn:GetChecked()
        if PF.Config.useClassColor then
            PF.Config.useCustomHP = false
            colorSwatch:Hide()
        else
            PF.Config.useCustomHP = true
            colorSwatch:Show()
        end
        PF:ApplyLayout()
    end

    classColorBtn:SetScript("OnClick", UpdateColors)
    UpdateColors()

    colorSwatch:SetScript("OnClick", function()
        local function ColorCallback(previousValues)
            local r, g, b
            if previousValues then
                r, g, b = previousValues.r, previousValues.g, previousValues.b
            else
                r, g, b = ColorPickerFrame:GetColorRGB()
            end
            PF.Config.hpR, PF.Config.hpG, PF.Config.hpB = r, g, b
            swatchTex:SetColorTexture(r, g, b)
            PF:ApplyLayout()
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                swatchFunc = ColorCallback,
                cancelFunc = ColorCallback,
                r = PF.Config.hpR,
                g = PF.Config.hpG,
                b = PF.Config.hpB,
            })
        else
            ColorPickerFrame.func = ColorCallback
            ColorPickerFrame.cancelFunc = ColorCallback
            ColorPickerFrame:SetColorRGB(PF.Config.hpR, PF.Config.hpG, PF.Config.hpB)
            ColorPickerFrame.previousValues = {r = PF.Config.hpR, g = PF.Config.hpG, b = PF.Config.hpB}
            ColorPickerFrame:Show()
        end
    end)
end

-- ------------------------------------------------------------
-- Slash Commands
-- ------------------------------------------------------------
SLASH_ROBCOM1 = "/robcom"
SlashCmdList["ROBCOM"] = function()
    if RobUIPlayerFrameOptions then
        if RobUIPlayerFrameOptions:IsShown() then
            RobUIPlayerFrameOptions:Hide()
        else
            RobUIPlayerFrameOptions:Show()
        end
    end
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterEvent("ADDON_LOADED")

E:RegisterUnitEvent("UNIT_HEALTH", "player")
E:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
E:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "player")
E:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
E:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        RobUIPlayerFrameDB = RobUIPlayerFrameDB or {}
        for k, v in pairs(PF.ConfigDefaults) do
            if RobUIPlayerFrameDB[k] == nil then
                RobUIPlayerFrameDB[k] = v
            end
        end
        PF.Config = RobUIPlayerFrameDB

        PF:CreateOptionsPanel()

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        PF:ForceUpdate()
        PF:RegisterWithRobHeal()

    elseif event == "ADDON_LOADED" and arg1 == "RobHeal" then
        PF:RegisterWithRobHeal()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if PF._pendingClickReg then
            PF:RegisterForClickCasting()
        end
        if PF._pendingRobHealReg then
            PF:RegisterWithRobHeal()
        end

    else
        PF:UpdateValues()
    end
end)