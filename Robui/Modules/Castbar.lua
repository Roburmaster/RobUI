-- ============================================================================
-- ROBUI: Castbars v7.3.2
--
-- FIX:
-- - Cast text/time no longer parented to ShieldBar
-- - ShieldBar alpha no longer hides text
-- - Safe text assignment kept
-- - DurationObject / SetTimerDuration model kept
-- ============================================================================

local addonName, ns = ...
local R = _G.Robui
if not R then return end

R.Castbar = R.Castbar or {}
local CB = R.Castbar

-- WoW API locals
local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCastingInfo = UnitCastingInfo or UnitSpellcastInfo
local UnitChannelInfo = UnitChannelInfo or UnitSpellcastChannelInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration

local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local pcall = pcall
local floor = math.floor
local max = math.max
local min = math.min

-- Dropdown globals
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = UIDropDownMenu_SetText

local TAB_ID = "castbars"

local bars = CB._bars or {}
CB._bars = bars
CB.isUnlocked = CB.isUnlocked or false

-- -----------------------------------------------------------------------------
-- rgrid / GridCore discovery + helpers
-- -----------------------------------------------------------------------------
local function GetGridCore()
    local GC = _G.RGridCore
    if GC then return GC end
    if R and R.GridCore then return R.GridCore end
    if ns and ns.GridCore then return ns.GridCore end
    if _G.RobUI and _G.RobUI.GridCore then return _G.RobUI.GridCore end
    return nil
end

local function GridIsAttached(pluginId)
    local GC = GetGridCore()
    if not (GC and type(GC.IsPluginAttached) == "function") then return false end
    local ok, v = pcall(GC.IsPluginAttached, GC, pluginId)
    return ok and v and true or false
end

local function GridAttach(pluginId)
    local GC = GetGridCore()
    if not (GC and type(GC.AttachPlugin) == "function") then return end
    pcall(GC.AttachPlugin, GC, pluginId)
end

local function GridRegister(pluginId, opts)
    local GC = GetGridCore()
    if not (GC and type(GC.RegisterPlugin) == "function") then return end
    pcall(GC.RegisterPlugin, GC, pluginId, opts)
end

-- -----------------------------------------------------------------------------
-- DB (ensure defaults)
-- -----------------------------------------------------------------------------
local DEFAULT_DB = {
    global = {
        enabled = true,
        font = "Fonts\\FRIZQT__.TTF",
        texture = "Interface\\Buttons\\WHITE8x8",
    },

    player = {
        enabled = true,
        width = 260,
        height = 18,
        x = -220,
        y = 140,
        color = {0.20, 0.70, 1.00, 1},
        showIcon = true,
        showLatency = true,
        textSize = 12,
        timeSize = 12,
        iconSize = 0,
    },

    player_mini = {
        enabled = true,
        width = 200,
        height = 14,
        x = -220,
        y = 110,
        color = {0.20, 0.70, 1.00, 1},
        showIcon = false,
        showLatency = false,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
    },

    player_extra = {
        enabled = true,
        width = 240,
        height = 14,
        x = -220,
        y = 80,
        color = {0.20, 0.70, 1.00, 1},
        showIcon = false,
        showLatency = false,
        vertical = false,
        textX = 0,
        textY = 0,
        timeX = 0,
        timeY = 0,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
        textBoxW = 160,
        textBoxH = 18,
        timeBoxW = 60,
        timeBoxH = 18,
    },

    target = {
        enabled = true,
        width = 260,
        height = 18,
        x = 220,
        y = 140,
        color = {1.00, 0.30, 0.30, 1},
        showIcon = true,
        showLatency = false,
        textSize = 12,
        timeSize = 12,
        iconSize = 0,
    },

    target_mini = {
        enabled = true,
        width = 200,
        height = 14,
        x = 220,
        y = 110,
        color = {1.00, 0.30, 0.30, 1},
        showIcon = false,
        showLatency = false,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
    },

    target_extra = {
        enabled = true,
        width = 240,
        height = 14,
        x = 220,
        y = 80,
        color = {1.00, 0.30, 0.30, 1},
        showIcon = false,
        showLatency = false,
        vertical = false,
        textX = 0,
        textY = 0,
        timeX = 0,
        timeY = 0,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
        textBoxW = 160,
        textBoxH = 18,
        timeBoxW = 60,
        timeBoxH = 18,
    },
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(dst[k], v)
        else
            if dst[k] == nil then
                dst[k] = v
            end
        end
    end
end

local function GetDB()
    if not (R and R.Database and R.Database.profile) then return nil end
    R.Database.profile.castbar = R.Database.profile.castbar or {}
    local db = R.Database.profile.castbar
    CopyDefaults(db, DEFAULT_DB)
    return db
end

local function IsExtraKey(key)
    return key == "player_extra" or key == "target_extra"
end

local function IsVerticalKey(key)
    if not IsExtraKey(key) then return false end
    local dbAll = GetDB()
    local db = dbAll and dbAll[key]
    return (db and db.vertical) and true or false
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function Clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function SafeSetText(fs, txt, fallback)
    if not fs then return end
    local ok = pcall(fs.SetText, fs, txt)
    if not ok and fallback ~= nil then
        pcall(fs.SetText, fs, fallback)
    end
end

local function SafeSetTexture(tex, val)
    if not tex then return end
    pcall(tex.SetTexture, tex, val)
end

local function SafeSetCastText(fs, primary, secondary, fallback)
    if not fs then return end

    if primary ~= nil then
        local ok = pcall(fs.SetText, fs, primary)
        if ok then return end
        ok = pcall(fs.SetFormattedText, fs, "%s", primary)
        if ok then return end
    end

    if secondary ~= nil then
        local ok = pcall(fs.SetText, fs, secondary)
        if ok then return end
        ok = pcall(fs.SetFormattedText, fs, "%s", secondary)
        if ok then return end
    end

    if fallback ~= nil then
        local ok = pcall(fs.SetText, fs, fallback)
        if ok then return end
        pcall(fs.SetFormattedText, fs, "%s", fallback)
    end
end

local function UnitIsCastRelevant(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    return true
end

-- -----------------------------------------------------------------------------
-- Border + fonts
-- -----------------------------------------------------------------------------
local function CreateSafeBorder(parent, inset, edge, bgRGBA, borderRGBA)
    if parent.__bg then return end

    inset = inset or 0
    edge = edge or 1
    bgRGBA = bgRGBA or {0.1, 0.1, 0.1, 0.9}
    borderRGBA = borderRGBA or {0, 0, 0, 1}

    local bg = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    bg:SetVertexColor(bgRGBA[1], bgRGBA[2], bgRGBA[3], bgRGBA[4])
    parent.__bg = bg

    local function MakeEdge()
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetVertexColor(borderRGBA[1], borderRGBA[2], borderRGBA[3], borderRGBA[4])
        return t
    end

    local top = MakeEdge()
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    top:SetHeight(edge)

    local bot = MakeEdge()
    bot:SetPoint("BOTTOMLEFT", 0, 0)
    bot:SetPoint("BOTTOMRIGHT", 0, 0)
    bot:SetHeight(edge)

    local left = MakeEdge()
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(edge)

    local right = MakeEdge()
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(edge)

    parent.__bTop, parent.__bBot, parent.__bLeft, parent.__bRight = top, bot, left, right
end

local function CreateFontString(f, align, size)
    local db = GetDB()
    local font = (db and db.global and db.global.font) or "Fonts\\FRIZQT__.TTF"
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size or 10, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(align)
    fs:SetWordWrap(false)
    return fs
end

-- -----------------------------------------------------------------------------
-- EMPOWER VISUALS (safe simplified version)
-- -----------------------------------------------------------------------------
local EMPOWER_SEGMENT_COLORS = {
    { r = 0.30, g = 0.80, b = 1.00, a = 0.22 },
    { r = 0.45, g = 1.00, b = 0.45, a = 0.22 },
    { r = 1.00, g = 0.92, b = 0.25, a = 0.22 },
    { r = 1.00, g = 0.45, b = 0.20, a = 0.22 },
}

local EMPOWER_SEP_COLOR = { r = 0, g = 0, b = 0, a = 0.35 }
local EMPOWER_SEP_WIDTH = 1

local function EnsureEmpowerVisuals(bar)
    if bar.__empower then return end

    bar.__empower = {}
    bar.__empower.baseSeg = {}

    for i = 1, 4 do
        local t = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:Hide()
        bar.__empower.baseSeg[i] = t
    end

    bar.__empower.baseSep = {}
    for i = 1, 3 do
        local s = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        s:SetTexture("Interface\\Buttons\\WHITE8x8")
        s:SetVertexColor(EMPOWER_SEP_COLOR.r, EMPOWER_SEP_COLOR.g, EMPOWER_SEP_COLOR.b, EMPOWER_SEP_COLOR.a)
        s:Hide()
        bar.__empower.baseSep[i] = s
    end
end

local function HideEmpowerVisuals(bar)
    if not bar.__empower then return end
    local e = bar.__empower

    if e.baseSeg then
        for _, t in ipairs(e.baseSeg) do
            t:Hide()
        end
    end

    if e.baseSep then
        for _, s in ipairs(e.baseSep) do
            s:Hide()
        end
    end
end

local function LayoutEmpower4Segments(bar)
    EnsureEmpowerVisuals(bar)

    local e = bar.__empower
    local W = bar:GetWidth() or 0
    local H = bar:GetHeight() or 0
    if W <= 0 or H <= 0 then return end

    local segW = W * 0.25

    for i = 1, 4 do
        local t = e.baseSeg[i]
        local c = EMPOWER_SEGMENT_COLORS[i]
        t:SetVertexColor(c.r, c.g, c.b, c.a or 0.22)
        t:SetWidth(segW)
        t:SetHeight(H)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * segW, 0)
        t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * segW, 0)
        t:Show()
    end

    for i = 1, 3 do
        local s = e.baseSep[i]
        local px = i * segW
        s:SetWidth(EMPOWER_SEP_WIDTH)
        s:SetHeight(H)
        s:ClearAllPoints()
        s:SetPoint("TOP", bar, "TOPLEFT", px, 0)
        s:SetPoint("BOTTOM", bar, "BOTTOMLEFT", px, 0)
        s:Show()
    end
end

-- -----------------------------------------------------------------------------
-- Text + orientation + icon sizing
-- -----------------------------------------------------------------------------
local function ApplyTextLayout(bar, key, db)
    if not (bar and bar.Text and bar.Time) then return end

    bar.Text:ClearAllPoints()
    bar.Time:ClearAllPoints()

    local isExtra = IsExtraKey(key)
    local vertical = (isExtra and db and db.vertical) and true or false

    local tx = (isExtra and tonumber(db.textX)) or 0
    local ty = (isExtra and tonumber(db.textY)) or 0
    local timex = (isExtra and tonumber(db.timeX)) or 0
    local timey = (isExtra and tonumber(db.timeY)) or 0

    if isExtra then
        local tbw = tonumber(db.textBoxW) or 160
        local tbh = tonumber(db.textBoxH) or 18
        local mbw = tonumber(db.timeBoxW) or 60
        local mbh = tonumber(db.timeBoxH) or 18

        tbw = max(20, floor(tbw + 0.5))
        tbh = max(8, floor(tbh + 0.5))
        mbw = max(20, floor(mbw + 0.5))
        mbh = max(8, floor(mbh + 0.5))

        bar.Text:SetWidth(tbw)
        bar.Text:SetHeight(tbh)
        bar.Time:SetWidth(mbw)
        bar.Time:SetHeight(mbh)

        if vertical then
            bar.Text:SetJustifyH("CENTER")
            bar.Time:SetJustifyH("CENTER")
            bar.Text:SetPoint("CENTER", bar.TextHolder, "CENTER", tx, ty)
            bar.Time:SetPoint("CENTER", bar.TextHolder, "CENTER", timex, timey)
        else
            bar.Text:SetJustifyH("LEFT")
            bar.Time:SetJustifyH("RIGHT")
            bar.Text:SetPoint("LEFT", bar.TextHolder, "LEFT", 4 + tx, ty)
            bar.Time:SetPoint("RIGHT", bar.TextHolder, "RIGHT", -4 + timex, timey)
        end
        return
    end

    bar.Text:SetJustifyH("LEFT")
    bar.Time:SetJustifyH("RIGHT")
    bar.Text:SetPoint("LEFT", bar.TextHolder, "LEFT", 4, 0)
    bar.Time:SetPoint("RIGHT", bar.TextHolder, "RIGHT", -4, 0)
    bar.Text:SetWidth(160)
end

local function ApplyOrientation(bar, key, db)
    if not bar then return end
    local vertical = (IsExtraKey(key) and db and db.vertical) and true or false

    if vertical then
        pcall(bar.SetOrientation, bar, "VERTICAL")
        if bar.ShieldBar then
            pcall(bar.ShieldBar.SetOrientation, bar.ShieldBar, "VERTICAL")
        end
    else
        pcall(bar.SetOrientation, bar, "HORIZONTAL")
        if bar.ShieldBar then
            pcall(bar.ShieldBar.SetOrientation, bar.ShieldBar, "HORIZONTAL")
        end
    end
end

local function ComputeIconSize(key, db)
    local vertical = (IsExtraKey(key) and db and db.vertical) and true or false
    local override = tonumber(db.iconSize) or 0
    if override > 0 then
        return max(4, floor(override + 0.5))
    end
    if vertical then
        return max(4, floor((tonumber(db.width) or 14) + 0.5))
    end
    return max(4, floor((tonumber(db.height) or 14) + 0.5))
end

-- -----------------------------------------------------------------------------
-- Layout update
-- -----------------------------------------------------------------------------
local function UpdateBarLayout(key)
    local bar = bars[key]
    local dbAll = GetDB()
    if not dbAll then return end

    local db = dbAll[key]
    if not bar or not db then return end

    if not (dbAll.global and dbAll.global.enabled) then
        bar:Hide()
        return
    end

    if not db.enabled and not CB.isUnlocked then
        bar:Hide()
        return
    end

    local tex = dbAll.global.texture or "Interface\\Buttons\\WHITE8x8"

    bar:SetStatusBarTexture(tex)
    if bar.ShieldBar then
        bar.ShieldBar:SetStatusBarTexture(tex)
    end

    bar:SetSize(db.width, db.height)
    if bar.TextHolder then
        bar.TextHolder:SetAllPoints(bar)
    end
    ApplyOrientation(bar, key, db)

    local pluginId = bar.__gridPluginId
    local attachedToGrid = (type(pluginId) == "string" and pluginId ~= "" and GridIsAttached(pluginId)) and true or false

    if not attachedToGrid then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", db.x, db.y)
    end

    if type(db.color) == "table" then
        bar._defaultColor = db.color
        bar:SetStatusBarColor(unpack(db.color))
    else
        bar._defaultColor = {1, 1, 1, 1}
        bar:SetStatusBarColor(1, 1, 1, 1)
    end

    local iconSize = ComputeIconSize(key, db)
    if db.showIcon or CB.isUnlocked then
        bar.Icon:Show()
        bar.iconBorder:Show()
        bar.Icon:ClearAllPoints()
        bar.iconBorder:ClearAllPoints()
        bar.Icon:SetSize(iconSize, iconSize)
        bar.iconBorder:SetSize(iconSize, iconSize)
        bar.Icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
        bar.iconBorder:SetPoint("CENTER", bar.Icon, "CENTER", 0, 0)
    else
        bar.Icon:Hide()
        bar.iconBorder:Hide()
    end

    if bar.SafeZone then
        bar.SafeZone:Hide()
    end

    local font = dbAll.global.font or "Fonts\\FRIZQT__.TTF"
    local tSize = tonumber(db.textSize)
    if type(tSize) ~= "number" then tSize = 11 end
    local tiSize = tonumber(db.timeSize)
    if type(tiSize) ~= "number" then tiSize = tSize end

    tSize = max(6, min(32, floor(tSize + 0.5)))
    tiSize = max(6, min(32, floor(tiSize + 0.5)))

    bar.Text:SetFont(font, tSize, "OUTLINE")
    bar.Time:SetFont(font, tiSize, "OUTLINE")
    ApplyTextLayout(bar, key, db)

    if CB.isUnlocked then
        bar:Show()
        bar:SetAlpha(1)
        bar:SetValue(1)
        SafeSetText(bar.Text, key:upper(), key:upper())
        SafeSetText(bar.Time, attachedToGrid and "rgrid" or "Move Me", "Move Me")
        if bar.Spark then bar.Spark:Hide() end
        SafeSetTexture(bar.Icon, 134400)
        bar:EnableMouse(not attachedToGrid)
        HideEmpowerVisuals(bar)
        return
    end

    bar:EnableMouse(false)

    if not bar.castState then
        bar:Hide()
        HideEmpowerVisuals(bar)
        return
    end

    if bar.castState.kind == "empower" then
        LayoutEmpower4Segments(bar)
    else
        HideEmpowerVisuals(bar)
    end
end

-- -----------------------------------------------------------------------------
-- Frame factory
-- -----------------------------------------------------------------------------
local function CreateCastbarFrame(key, unit)
    local db = GetDB()
    local texture = (db and db.global and db.global.texture) or "Interface\\Buttons\\WHITE8x8"

    local bar = CreateFrame("StatusBar", "RobUI_" .. key, UIParent)
    bar:SetStatusBarTexture(texture)
    bar:SetFrameStrata("HIGH")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")

    bar.ShieldBar = CreateFrame("StatusBar", nil, bar)
    bar.ShieldBar:SetAllPoints(bar)
    bar.ShieldBar:SetStatusBarTexture(texture)
    bar.ShieldBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
    bar.ShieldBar:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.ShieldBar:SetAlpha(0)

    bar.TextHolder = CreateFrame("Frame", nil, bar)
    bar.TextHolder:SetAllPoints(bar)
    bar.TextHolder:SetFrameLevel(bar:GetFrameLevel() + 3)

    bar:SetScript("OnDragStart", function(self)
        if not CB.isUnlocked then return end
        local pid = self.__gridPluginId
        if pid and GridIsAttached(pid) then return end
        self:StartMoving()
    end)

    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local pid = self.__gridPluginId
        if pid and GridIsAttached(pid) then
            UpdateBarLayout(key)
            return
        end

        local dbAll = GetDB()
        if dbAll and dbAll[key] then
            local centerX = self:GetCenter()
            local screenWidth = UIParent:GetSize()
            local x = centerX - (screenWidth / 2)
            local y = self:GetBottom()

            dbAll[key].x = floor(x)
            dbAll[key].y = floor(y)

            UpdateBarLayout(key)
            if CB.SettingsPanel and CB.SettingsPanel.RefreshSection then
                CB.SettingsPanel:RefreshSection()
            end
        end
    end)

    bar:Hide()

    CreateSafeBorder(bar, 0, 1, {0.1, 0.1, 0.1, 0.9}, {0, 0, 0, 1})

    bar.Icon = bar:CreateTexture(nil, "ARTWORK")
    bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    bar.iconBorder = CreateFrame("Frame", nil, bar)
    bar.iconBorder:SetFrameLevel(bar:GetFrameLevel() + 2)
    CreateSafeBorder(bar.iconBorder, 0, 1, {0, 0, 0, 0}, {0, 0, 0, 1})

    -- IMPORTANT FIX: text is NOT parented to ShieldBar
    bar.Text = CreateFontString(bar.TextHolder, "LEFT", 10)
    bar.Time = CreateFontString(bar.TextHolder, "RIGHT", 10)
    bar.Text:SetDrawLayer("OVERLAY", 7)
    bar.Time:SetDrawLayer("OVERLAY", 7)

    bar.Spark = bar:CreateTexture(nil, "OVERLAY")
    bar.Spark:SetColorTexture(1, 1, 1, 0.8)
    bar.Spark:SetBlendMode("ADD")
    bar.Spark:Hide()

    if unit == "player" then
        bar.SafeZone = bar:CreateTexture(nil, "BACKGROUND")
        bar.SafeZone:SetColorTexture(0.8, 0, 0, 0.5)
        bar.SafeZone:Hide()
    end

    bar.key = key
    bar.unit = unit
    bar.castState = nil
    bar._defaultColor = {1, 1, 1, 1}

    -- Hard guard against external Show() while idle
    bar:HookScript("OnShow", function(self)
        if CB.isUnlocked then return end
        if not self.castState then
            self:Hide()
        end
    end)

    bars[key] = bar
    return bar
end

-- -----------------------------------------------------------------------------
-- Secure cast state retrieval
-- -----------------------------------------------------------------------------
local function GetUnitCastState(unit)
    if not UnitIsCastRelevant(unit) then return nil end

    local durObj = UnitCastingDuration and UnitCastingDuration(unit)
    if durObj then
        local name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        return {
            kind = "cast",
            name = name,
            text = text,
            texture = texture,
            notInterruptible = notInterruptible,
            durationObject = durObj,
        }
    end

    local cdurObj = UnitChannelDuration and UnitChannelDuration(unit)
    if cdurObj then
        local cname, ctext, ctexture, _, _, _, _, cnotInterruptible, isEmpowered = UnitChannelInfo(unit)
        return {
            kind = isEmpowered and "empower" or "channel",
            name = cname,
            text = ctext,
            texture = ctexture,
            notInterruptible = cnotInterruptible,
            durationObject = cdurObj,
        }
    end

    return nil
end

-- -----------------------------------------------------------------------------
-- Active updates (safe)
-- -----------------------------------------------------------------------------
local function StopBar(self)
    if not self then return end

    self.castState = nil
    self:SetScript("OnUpdate", nil)

    if self.Spark then
        self.Spark:Hide()
    end

    HideEmpowerVisuals(self)
    self:Hide()
end

local function OnUpdateActive(self)
    if CB.isUnlocked then return end

    local state = self.castState
    if not state or not state.durationObject then
        StopBar(self)
        return
    end

    pcall(function()
        self.Time:SetFormattedText("%.1f", state.durationObject:GetRemainingDuration())
    end)
end

local function ApplyStateToBar(self, state)
    if not (self and state and state.durationObject) then return false end

    self.castState = state

    if self.ShieldBar and self.ShieldBar.SetAlphaFromBoolean then
        pcall(self.ShieldBar.SetAlphaFromBoolean, self.ShieldBar, state.notInterruptible, 1, 0)
    elseif self.ShieldBar then
        self.ShieldBar:SetAlpha(0)
    end

    SafeSetCastText(self.Text, state.name, state.text, "")
    SafeSetTexture(self.Icon, state.texture)

    if self.SetTimerDuration then
        pcall(self.SetTimerDuration, self, state.durationObject)
    end
    if self.ShieldBar and self.ShieldBar.SetTimerDuration then
        pcall(self.ShieldBar.SetTimerDuration, self.ShieldBar, state.durationObject)
    end

    if self.Spark then
        self.Spark:Hide()
    end

    if state.kind == "empower" then
        LayoutEmpower4Segments(self)
    else
        HideEmpowerVisuals(self)
    end

    self:SetAlpha(1)
    self:Show()
    self:SetScript("OnUpdate", OnUpdateActive)
    OnUpdateActive(self)
    return true
end

local function StartOrUpdateFromUnit(self)
    local state = GetUnitCastState(self.unit)
    if not state then
        StopBar(self)
        return false
    end
    return ApplyStateToBar(self, state)
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------
local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
}

local UPDATE_ONLY_EVENTS = {
    UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_EMPOWER_UPDATE = true,
}

local function OnEvent(self, event, unit)
    if CB.isUnlocked then return end

    if unit and unit ~= self.unit then
        return
    end

    local dbAll = GetDB()
    if not dbAll or not (dbAll.global and dbAll.global.enabled) then
        StopBar(self)
        return
    end

    local db = dbAll[self.key]
    if not db or (not db.enabled and not CB.isUnlocked) then
        StopBar(self)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        if not StartOrUpdateFromUnit(self) then
            StopBar(self)
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        if self.unit ~= "target" then
            return
        end
        if not StartOrUpdateFromUnit(self) then
            StopBar(self)
        end
        return
    end

    if STOP_EVENTS[event] then
        StopBar(self)
        return
    end

    if UPDATE_ONLY_EVENTS[event] and (not self.castState) then
        return
    end

    if not StartOrUpdateFromUnit(self) then
        StopBar(self)
    end
end

-- -----------------------------------------------------------------------------
-- Module state
-- -----------------------------------------------------------------------------
function CB:ToggleTestMode()
    CB.isUnlocked = not CB.isUnlocked
    for key in pairs(bars) do
        UpdateBarLayout(key)
    end
end

local function EnableBlizzardCastbar()
    if CastingBarFrame then
        pcall(function() CastingBarFrame:Show() end)
    end
    if PlayerCastingBarFrame then
        pcall(function() PlayerCastingBarFrame:Show() end)
    end
end

local function DisableBlizzardCastbar()
    if CastingBarFrame then
        pcall(function()
            CastingBarFrame:UnregisterAllEvents()
            CastingBarFrame:Hide()
        end)
    end
    if PlayerCastingBarFrame then
        pcall(function()
            PlayerCastingBarFrame:UnregisterAllEvents()
            PlayerCastingBarFrame:Hide()
        end)
    end
end

function CB:ApplyGlobalEnabledState()
    local db = GetDB()
    if not db then return end

    if not (db.global and db.global.enabled) then
        for _, bar in pairs(bars) do
            bar:UnregisterAllEvents()
            bar:SetScript("OnUpdate", nil)
            bar:SetScript("OnEvent", nil)
            bar.castState = nil
            bar:Hide()
        end
        EnableBlizzardCastbar()
        return
    end

    for _, bar in pairs(bars) do
        bar:UnregisterAllEvents()

        bar:RegisterUnitEvent("UNIT_SPELLCAST_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", bar.unit)

        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", bar.unit)

        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", bar.unit)

        if bar.unit == "target" then
            bar:RegisterEvent("PLAYER_TARGET_CHANGED")
        end

        bar:RegisterEvent("PLAYER_REGEN_ENABLED")
        bar:RegisterEvent("PLAYER_ENTERING_WORLD")

        bar:SetScript("OnUpdate", nil)
        bar:SetScript("OnEvent", OnEvent)

        UpdateBarLayout(bar.key)
    end

    DisableBlizzardCastbar()
end

function CB:Refresh()
    CB:ApplyGlobalEnabledState()
end

-- -----------------------------------------------------------------------------
-- rgrid plugins
-- -----------------------------------------------------------------------------
local GRID_GROUP_CASTBARS = 1

local function RegisterCastbarPlugins()
    local GC2 = GetGridCore()
    if not (GC2 and type(GC2.RegisterPlugin) == "function") then return end

    local function reg(key, name, gx, gy)
        local bar = bars[key]
        if not bar then return end

        local pluginId = "robui_castbar_" .. key
        bar.__gridPluginId = pluginId

        GridRegister(pluginId, {
            name = name or key,
            default = {
                gx = gx or 0,
                gy = gy or 0,
                group = GRID_GROUP_CASTBARS or 0,
                label = name or key,
            },
            build = function()
                return bars[key]
            end,
            setScale = function(frame, scale)
                if not frame or not frame.SetScale then return end
                pcall(frame.SetScale, frame, tonumber(scale) or 1)
            end,
        })

        GridAttach(pluginId)
        UpdateBarLayout(key)
    end

    reg("player",       "Castbar: Player",       -220, 140)
    reg("player_mini",  "Castbar: Player Mini",  -220, 110)
    reg("player_extra", "Castbar: Player Extra", -220, 80)
    reg("target",       "Castbar: Target",        220, 140)
    reg("target_mini",  "Castbar: Target Mini",   220, 110)
    reg("target_extra", "Castbar: Target Extra",  220, 80)
end

-- -----------------------------------------------------------------------------
-- Settings UI
-- -----------------------------------------------------------------------------
local _sliderId = 0
local function NextSliderName()
    _sliderId = _sliderId + 1
    return "RobUICastbarSlider_" .. _sliderId
end

local function CreateCheckbox(parent, label, x, y, onClick)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b.Text:SetText(label)
    b:SetScript("OnClick", function(self)
        if onClick then onClick(self, self:GetChecked() and true or false) end
    end)
    return b
end

local function CreateButton(parent, label, x, y, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 140, h or 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)
    return b
end

local function CreateHeader(parent, text, x, y)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", x, y)
    t:SetText(text)
    return t
end

local function CreateSlider(parent, label, x, y, minV, maxV, step, onValueChanged)
    local name = NextSliderName()
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(260)

    local textFS = _G[name .. "Text"]
    local lowFS = _G[name .. "Low"]
    local highFS = _G[name .. "High"]
    if textFS then textFS:SetText(label) end
    if lowFS then lowFS:Hide() end
    if highFS then highFS:Hide() end

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    s._valueFS = val

    function s:SetExactValueText(v)
        if self._valueFS then
            self._valueFS:SetText(tostring(floor((tonumber(v) or 0) + 0.5)))
        end
    end

    s:SetScript("OnValueChanged", function(self, v)
        self:SetExactValueText(v)
        if onValueChanged then onValueChanged(self, v) end
    end)

    s._labelFS = textFS
    return s
end

local SETTINGS_KEYS = {
    "player",
    "player_mini",
    "player_extra",
    "target",
    "target_mini",
    "target_extra",
}

local function PrettyKey(k)
    if k == "player" then return "Player" end
    if k == "player_mini" then return "Player Mini" end
    if k == "player_extra" then return "Player Extra" end
    if k == "target" then return "Target" end
    if k == "target_mini" then return "Target Mini" end
    if k == "target_extra" then return "Target Extra" end
    return k
end

local RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX = 80, 520
local RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX = 8, 160
local RANGE_V_THICK_MIN, RANGE_V_THICK_MAX = 2, 120
local RANGE_V_LEN_MIN, RANGE_V_LEN_MAX = 80, 900
local RANGE_TEXT_MIN, RANGE_TEXT_MAX = 6, 32
local RANGE_ICON_MIN, RANGE_ICON_MAX = 0, 128
local RANGE_BOX_W_MIN, RANGE_BOX_W_MAX = 20, 600
local RANGE_BOX_H_MIN, RANGE_BOX_H_MAX = 8, 120

local function SetSliderRange(slider, minV, maxV)
    if not slider then return end
    slider:SetMinMaxValues(minV, maxV)
    local cur = tonumber(slider:GetValue()) or minV
    if cur < minV then cur = minV end
    if cur > maxV then cur = maxV end
    slider:SetValue(cur)
    slider:SetExactValueText(cur)
end

local function OpenColorPickerForKey(selectedKey, onChange)
    local dbAll = GetDB()
    if not dbAll or not dbAll[selectedKey] then return end

    local sdb = dbAll[selectedKey]
    sdb.color = sdb.color or {1, 1, 1, 1}

    local r = tonumber(sdb.color[1]) or 1
    local g = tonumber(sdb.color[2]) or 1
    local b = tonumber(sdb.color[3]) or 1
    local a = tonumber(sdb.color[4]); if type(a) ~= "number" then a = 1 end

    local function Apply(cr, cg, cb, ca)
        sdb.color[1] = cr
        sdb.color[2] = cg
        sdb.color[3] = cb
        sdb.color[4] = ca
        UpdateBarLayout(selectedKey)
        if onChange then onChange() end
    end

    if ColorPickerFrame and type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        local info = {}
        info.r, info.g, info.b = r, g, b
        info.opacity = 1 - a
        info.hasOpacity = true
        info.swatchFunc = function()
            local cr, cg, cb = ColorPickerFrame:GetColorRGB()
            local ca = 1 - (ColorPickerFrame:GetColorAlpha() or 0)
            Apply(cr, cg, cb, ca)
        end
        info.opacityFunc = function()
            local cr, cg, cb = ColorPickerFrame:GetColorRGB()
            local ca = 1 - (ColorPickerFrame:GetColorAlpha() or 0)
            Apply(cr, cg, cb, ca)
        end
        info.cancelFunc = function(prev)
            if type(prev) == "table" then
                local pr, pg, pb = prev.r or r, prev.g or g, prev.b or b
                local pa = 1 - (prev.opacity or (1 - a))
                Apply(pr, pg, pb, pa)
            else
                Apply(r, g, b, a)
            end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end

    if not ColorPickerFrame then return end
    if ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end

    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - a
    ColorPickerFrame.previousValues = { r, g, b, a }

    ColorPickerFrame.func = function()
        local cr, cg, cb = ColorPickerFrame:GetColorRGB()
        local ca = 1 - (ColorPickerFrame.opacity or 0)
        Apply(cr, cg, cb, ca)
    end

    ColorPickerFrame.opacityFunc = function()
        local cr, cg, cb = ColorPickerFrame:GetColorRGB()
        local ca = 1 - (ColorPickerFrame.opacity or 0)
        Apply(cr, cg, cb, ca)
    end

    ColorPickerFrame.cancelFunc = function(prev)
        local p = prev or ColorPickerFrame.previousValues
        if type(p) == "table" then
            Apply(p[1] or 1, p[2] or 1, p[3] or 1, p[4] or 1)
        end
    end

    if type(ColorPickerFrame.SetColorRGB) == "function" then
        ColorPickerFrame:SetColorRGB(r, g, b)
    end

    ColorPickerFrame:Show()
end

local function EnsureSettingsPanel()
    if CB.SettingsPanel and CB.SettingsPanel.RefreshSection then
        return CB.SettingsPanel
    end

    local f = CreateFrame("Frame", "RobUICastbarSettings", UIParent)
    f:SetSize(780, 640)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()

    CreateSafeBorder(f, 0, 1, {0.06, 0.06, 0.06, 0.95}, {0, 0, 0, 1})

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RobUI - Castbars")

    CreateButton(f, "Close", 680, -12, 80, 22, function() f:Hide() end)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -42)
    desc:SetWidth(740)
    desc:SetJustifyH("LEFT")
    desc:SetText("Extra bars: text sizing/position/box sizing is independent of bar thickness/length. Vertical uses Width=Thickness and Height=Length.")

    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -70)
    sf:SetPoint("BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(740, 1100)
    sf:SetScrollChild(content)

    local selectedKey = "player"

    local function GetSelectedDB()
        local db = GetDB()
        return db and db[selectedKey] or nil
    end

    local LEFT_X = 10
    local RIGHT_X = 380
    local Y = -10

    local globalEnabled = CreateCheckbox(content, "Enable Castbars (disables Blizzard castbar)", LEFT_X, Y, function(_, v)
        local db = GetDB()
        if not db then return end
        db.global.enabled = v and true or false
        CB:Refresh()
    end)

    Y = Y - 34

    CreateButton(content, "Toggle Test Mode", LEFT_X, Y, 160, 22, function()
        CB:ToggleTestMode()
        if f.RefreshSection then f:RefreshSection() end
    end)

    CreateButton(content, "Reset Selected Position", LEFT_X + 170, Y, 190, 22, function()
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].x = DEFAULT_DB[selectedKey] and DEFAULT_DB[selectedKey].x or 0
        db[selectedKey].y = DEFAULT_DB[selectedKey] and DEFAULT_DB[selectedKey].y or 0
        UpdateBarLayout(selectedKey)
        if f.RefreshSection then f:RefreshSection() end
    end)

    Y = Y - 44

    local dropdown = CreateFrame("Frame", "RobUICastbarDrop", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", LEFT_X - 12, Y)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 260)
    end

    Y = Y - 50
    CreateHeader(content, "Bar", LEFT_X, Y)

    Y = Y - 18
    f.cbEnabled = CreateCheckbox(content, "Enabled (this bar)", LEFT_X, Y, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].enabled = v and true or false
        UpdateBarLayout(selectedKey)
    end)

    Y = Y - 28
    f.cbIcon = CreateCheckbox(content, "Show Icon", LEFT_X, Y, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].showIcon = v and true or false
        UpdateBarLayout(selectedKey)
    end)

    Y = Y - 28
    f.cbLatency = CreateCheckbox(content, "Show Latency (player only)", LEFT_X, Y, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].showLatency = v and true or false
        UpdateBarLayout(selectedKey)
    end)

    Y = Y - 34
    f.btnColor = CreateButton(content, "Pick Bar Color", LEFT_X, Y, 160, 22, function()
        OpenColorPickerForKey(selectedKey, function()
            if f.RefreshSection then f:RefreshSection() end
        end)
    end)

    Y = Y - 44
    CreateHeader(content, "Size", LEFT_X, Y)

    Y = Y - 18
    f.slW = CreateSlider(content, "Width", LEFT_X, Y, RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX, 1, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].width = floor(tonumber(v) or 200)
        UpdateBarLayout(selectedKey)
    end)

    Y = Y - 62
    f.slH = CreateSlider(content, "Height", LEFT_X, Y, RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX, 1, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].height = floor(tonumber(v) or 14)
        UpdateBarLayout(selectedKey)
    end)

    Y = Y - 62
    f.slIcon = CreateSlider(content, "Icon Size (0=Auto)", LEFT_X, Y, RANGE_ICON_MIN, RANGE_ICON_MAX, 1, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].iconSize = floor(tonumber(v) or 0)
        UpdateBarLayout(selectedKey)
    end)

    local RY = -10
    CreateHeader(content, "Text", RIGHT_X, RY)

    RY = RY - 18
    f.slTextSize = CreateSlider(content, "Cast Text Size", RIGHT_X, RY, RANGE_TEXT_MIN, RANGE_TEXT_MAX, 1, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].textSize = floor(tonumber(v) or 11)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTimeSize = CreateSlider(content, "Time Text Size", RIGHT_X, RY, RANGE_TEXT_MIN, RANGE_TEXT_MAX, 1, function(_, v)
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].timeSize = floor(tonumber(v) or 11)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 72
    CreateHeader(content, "Extra Bars (player_extra / target_extra)", RIGHT_X, RY)

    RY = RY - 18
    f.cbVertical = CreateCheckbox(content, "Vertical mode", RIGHT_X, RY, function(_, v)
        if not IsExtraKey(selectedKey) then
            if f.cbVertical then f.cbVertical:SetChecked(false) end
            return
        end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].vertical = v and true or false
        UpdateBarLayout(selectedKey)
        if f.RefreshSection then f:RefreshSection() end
    end)

    RY = RY - 36
    f.extraHeader = CreateHeader(content, "Extra Text Position", RIGHT_X, RY)

    RY = RY - 18
    f.slTextX = CreateSlider(content, "Cast Text X", RIGHT_X, RY, -300, 300, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].textX = floor(tonumber(v) or 0)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTextY = CreateSlider(content, "Cast Text Y", RIGHT_X, RY, -300, 300, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].textY = floor(tonumber(v) or 0)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTimeX = CreateSlider(content, "Time Text X", RIGHT_X, RY, -300, 300, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].timeX = floor(tonumber(v) or 0)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTimeY = CreateSlider(content, "Time Text Y", RIGHT_X, RY, -300, 300, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].timeY = floor(tonumber(v) or 0)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 72
    f.boxHeader = CreateHeader(content, "Extra Text Boxes", RIGHT_X, RY)

    RY = RY - 18
    f.slTextBoxW = CreateSlider(content, "Cast Text Box Width", RIGHT_X, RY, RANGE_BOX_W_MIN, RANGE_BOX_W_MAX, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].textBoxW = floor(tonumber(v) or 160)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTextBoxH = CreateSlider(content, "Cast Text Box Height", RIGHT_X, RY, RANGE_BOX_H_MIN, RANGE_BOX_H_MAX, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].textBoxH = floor(tonumber(v) or 18)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTimeBoxW = CreateSlider(content, "Time Text Box Width", RIGHT_X, RY, RANGE_BOX_W_MIN, RANGE_BOX_W_MAX, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].timeBoxW = floor(tonumber(v) or 60)
        UpdateBarLayout(selectedKey)
    end)

    RY = RY - 62
    f.slTimeBoxH = CreateSlider(content, "Time Text Box Height", RIGHT_X, RY, RANGE_BOX_H_MIN, RANGE_BOX_H_MAX, 1, function(_, v)
        if not IsExtraKey(selectedKey) then return end
        local db = GetDB()
        if not db or not db[selectedKey] then return end
        db[selectedKey].timeBoxH = floor(tonumber(v) or 18)
        UpdateBarLayout(selectedKey)
    end)

    local function ShowExtraControls(show)
        local function S(w)
            if not w then return end
            if show then w:Show() else w:Hide() end
        end

        S(f.cbVertical)
        S(f.extraHeader)
        S(f.slTextX)
        S(f.slTextY)
        S(f.slTimeX)
        S(f.slTimeY)
        S(f.boxHeader)
        S(f.slTextBoxW)
        S(f.slTextBoxH)
        S(f.slTimeBoxW)
        S(f.slTimeBoxH)
    end

    local function UpdateSizeSliderLabelsAndRanges(isExtra, isVertical)
        if f.slW and f.slW._labelFS then
            f.slW._labelFS:SetText((isExtra and isVertical) and "Thickness (Width)" or "Width")
        end
        if f.slH and f.slH._labelFS then
            f.slH._labelFS:SetText((isExtra and isVertical) and "Length (Height)" or "Height")
        end

        if isExtra and isVertical then
            SetSliderRange(f.slW, RANGE_V_THICK_MIN, RANGE_V_THICK_MAX)
            SetSliderRange(f.slH, RANGE_V_LEN_MIN, RANGE_V_LEN_MAX)
        else
            SetSliderRange(f.slW, RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX)
            SetSliderRange(f.slH, RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX)
        end
    end

    local function RefreshAllControls()
        local db = GetDB()
        if not db then return end

        globalEnabled:SetChecked(db.global.enabled and true or false)

        local sdb = GetSelectedDB()
        if not sdb then return end

        local isPlayer = (selectedKey:find("player") ~= nil)
        if f.cbLatency then
            f.cbLatency:SetEnabled(isPlayer and true or false)
            f.cbLatency:SetChecked((isPlayer and sdb.showLatency) and true or false)
        end

        if f.cbEnabled then f.cbEnabled:SetChecked(sdb.enabled and true or false) end
        if f.cbIcon then f.cbIcon:SetChecked(sdb.showIcon and true or false) end

        local isExtra = IsExtraKey(selectedKey)
        local isVertical = (isExtra and sdb.vertical) and true or false

        ShowExtraControls(isExtra)

        if isExtra and f.cbVertical then
            f.cbVertical:SetChecked(isVertical and true or false)
        end

        UpdateSizeSliderLabelsAndRanges(isExtra, isVertical)

        if f.slW then
            f.slW:SetValue(tonumber(sdb.width) or 200)
            f.slW:SetExactValueText(tonumber(sdb.width) or 200)
        end
        if f.slH then
            f.slH:SetValue(tonumber(sdb.height) or 14)
            f.slH:SetExactValueText(tonumber(sdb.height) or 14)
        end
        if f.slIcon then
            f.slIcon:SetValue(tonumber(sdb.iconSize) or 0)
            f.slIcon:SetExactValueText(tonumber(sdb.iconSize) or 0)
        end
        if f.slTextSize then
            f.slTextSize:SetValue(tonumber(sdb.textSize) or 11)
            f.slTextSize:SetExactValueText(tonumber(sdb.textSize) or 11)
        end
        if f.slTimeSize then
            f.slTimeSize:SetValue(tonumber(sdb.timeSize) or 11)
            f.slTimeSize:SetExactValueText(tonumber(sdb.timeSize) or 11)
        end

        if isExtra then
            if f.slTextX then
                f.slTextX:SetValue(tonumber(sdb.textX) or 0)
                f.slTextX:SetExactValueText(tonumber(sdb.textX) or 0)
            end
            if f.slTextY then
                f.slTextY:SetValue(tonumber(sdb.textY) or 0)
                f.slTextY:SetExactValueText(tonumber(sdb.textY) or 0)
            end
            if f.slTimeX then
                f.slTimeX:SetValue(tonumber(sdb.timeX) or 0)
                f.slTimeX:SetExactValueText(tonumber(sdb.timeX) or 0)
            end
            if f.slTimeY then
                f.slTimeY:SetValue(tonumber(sdb.timeY) or 0)
                f.slTimeY:SetExactValueText(tonumber(sdb.timeY) or 0)
            end
            if f.slTextBoxW then
                f.slTextBoxW:SetValue(tonumber(sdb.textBoxW) or 160)
                f.slTextBoxW:SetExactValueText(tonumber(sdb.textBoxW) or 160)
            end
            if f.slTextBoxH then
                f.slTextBoxH:SetValue(tonumber(sdb.textBoxH) or 18)
                f.slTextBoxH:SetExactValueText(tonumber(sdb.textBoxH) or 18)
            end
            if f.slTimeBoxW then
                f.slTimeBoxW:SetValue(tonumber(sdb.timeBoxW) or 60)
                f.slTimeBoxW:SetExactValueText(tonumber(sdb.timeBoxW) or 60)
            end
            if f.slTimeBoxH then
                f.slTimeBoxH:SetValue(tonumber(sdb.timeBoxH) or 18)
                f.slTimeBoxH:SetExactValueText(tonumber(sdb.timeBoxH) or 18)
            end
        end
    end

    local function OnSelectKey(key)
        selectedKey = key
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(dropdown, "Edit: " .. PrettyKey(key))
        end
        RefreshAllControls()
    end

    local function InitDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.isTitle = true
        info.text = "Select castbar"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        for _, k in ipairs(SETTINGS_KEYS) do
            local i = UIDropDownMenu_CreateInfo()
            i.text = PrettyKey(k)
            i.notCheckable = true
            i.func = function()
                OnSelectKey(k)
            end
            UIDropDownMenu_AddButton(i, level)
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dropdown, InitDropdown)
    end

    function f:RefreshSection()
        RefreshAllControls()
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(dropdown, "Edit: " .. PrettyKey(selectedKey))
        end
    end

    f:SetScript("OnShow", function()
        OnSelectKey(selectedKey)
    end)

    CB.SettingsPanel = f
    return f
end

local function RegisterWithRobUIMenu()
    local panel = EnsureSettingsPanel()
    CB.SettingsPanel = panel

    if type(R.RegisterModulePanel) == "function" then
        pcall(R.RegisterModulePanel, R, TAB_ID, panel)
        return
    end
    if R.MasterConfig and type(R.MasterConfig.RegisterTab) == "function" then
        pcall(R.MasterConfig.RegisterTab, R.MasterConfig, TAB_ID, panel)
        return
    end
    if R.MasterConfig and type(R.MasterConfig.AddPanel) == "function" then
        pcall(R.MasterConfig.AddPanel, R.MasterConfig, TAB_ID, panel)
        return
    end
end

local function OpenSettings()
    local panel = EnsureSettingsPanel()

    if R.MasterConfig and type(R.MasterConfig.Toggle) == "function" then
        if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
            R.MasterConfig:Toggle()
        end
        if type(R.MasterConfig.SelectTab) == "function" then
            pcall(R.MasterConfig.SelectTab, R.MasterConfig, TAB_ID)
            pcall(R.MasterConfig.SelectTab, R.MasterConfig, "Castbars")
            pcall(R.MasterConfig.SelectTab, R.MasterConfig, "CastBars")
        end
        panel:Show()
        panel:Raise()
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

-- -----------------------------------------------------------------------------
-- Init
-- -----------------------------------------------------------------------------
local function BuildAllBars()
    CreateCastbarFrame("player", "player")
    CreateCastbarFrame("player_mini", "player")
    CreateCastbarFrame("player_extra", "player")
    CreateCastbarFrame("target", "target")
    CreateCastbarFrame("target_mini", "target")
    CreateCastbarFrame("target_extra", "target")
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if not GetDB() then return end

    C_Timer.After(1, function()
        if not GetDB() then return end
        BuildAllBars()
        RegisterCastbarPlugins()
        RegisterWithRobUIMenu()
        CB:ApplyGlobalEnabledState()
    end)
end)

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------
SLASH_ROBCAST1 = "/robcast"
SlashCmdList["ROBCAST"] = function(msg)
    msg = (msg or ""):lower()

    if msg == "test" then
        CB:ToggleTestMode()
        return
    elseif msg == "on" then
        local db = GetDB()
        if not db then return end
        db.global.enabled = true
        CB:Refresh()
        return
    elseif msg == "off" then
        local db = GetDB()
        if not db then return end
        db.global.enabled = false
        CB:Refresh()
        return
    end

    OpenSettings()
end
