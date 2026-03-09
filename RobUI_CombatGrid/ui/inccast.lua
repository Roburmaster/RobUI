-- ============================================================================
-- test55.lua (RobUI) - "PIC" Incoming Casts ON PLAYER (stacked bars)
-- PERFORMANCE UPDATE:
--  - Debounced rendering (coalesces spammy events)
--  - Style/layout only re-applied when settings change
--  - Single holder OnUpdate (20hz) instead of per-bar tickers
--  - Stops only unused bars, not all bars every render
--
-- Slash:
--   /pic            open settings
--   /pic preview    toggle preview mode
--   /pic add        force-attach plugin into rgrid (creates anchor if missing)
-- ============================================================================

local ADDON, ns = ...
ns = _G[ADDON] or ns or {}
_G[ADDON] = ns

ns.IncomingPlayerCasts = ns.IncomingPlayerCasts or {}
local M = ns.IncomingPlayerCasts

local pcall = pcall
local pairs = pairs
local wipe = wipe
local tonumber = tonumber
local tremove = table.remove
local string_lower = string.lower
local type = type
local math_floor = math.floor
local math_max = math.max

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer

local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration
local UnitName = UnitName
local InCombatLockdown = InCombatLockdown

local GetTime = GetTime
local C_NamePlate = C_NamePlate

-- UIDropDown
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetSelectedID = UIDropDownMenu_SetSelectedID
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth

-- Dynamic GridCore fetch to prevent nil capture on load
local function GetGridCore()
    return _G.RGridCore
end

-- ---------------------------------------------------------------------------
-- DB & INITIALIZATION
-- ---------------------------------------------------------------------------
local DB = {} -- Local reference

local DEFAULTS = {
    enabled = true,

    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 180,

    alwaysShowHolder = true,
    maxBars = 3,

    width = 260,
    height = 16,
    scale = 1.0,
    spacing = 1,

    showIcon = true,
    showBorder = true,
    preview = false,

    skins = { index = 1 },
    fonts = { index = 1, outline = "OUTLINE" },

    colors = {
        bg     = { r=0.10, g=0.10, b=0.10, a=0.80 },
        border = { r=0.00, g=0.00, b=0.00, a=1.00 },
        text   = { r=1.00, g=1.00, b=1.00, a=1.00 },

        normal      = { r=0.90, g=0.60, b=0.20, a=1.0 },
        important   = { r=1.00, g=0.10, b=0.10, a=1.0 },
        noKick      = { r=0.60, g=0.60, b=0.60, a=1.0 },
        interrupted = { r=0.60, g=0.60, b=0.60, a=1.0 },

        glow = { r=1.00, g=0.10, b=0.10, a=0.45 },
    },

    settings = {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0,
    },
}

local function DeepDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                DeepDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            DeepDefaults(dst[k], v)
        end
    end
end

local function Clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
end

local function InitDB()
    if type(RobUIIncomingCastDB) ~= "table" then
        RobUIIncomingCastDB = {}
    end

    wipe(DB)
    for k, v in pairs(RobUIIncomingCastDB) do
        DB[k] = v
    end

    DeepDefaults(DB, DEFAULTS)

    DB.maxBars = Clamp(DB.maxBars, 1, 10)
    DB.width   = Clamp(DB.width, 120, 520)
    DB.height  = Clamp(DB.height, 10, 50)
    DB.scale   = Clamp(DB.scale, 0.7, 1.6)
    DB.spacing = Clamp(DB.spacing, 0, 14)

    RobUIIncomingCastDB = DB
end

-- ---------------------------------------------------------------------------
-- DATA
-- ---------------------------------------------------------------------------
local FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
    { name = "2002",          path = "Fonts\\2002.TTF" },
}

local SKINS = {
    { name = "Flat (WHITE8x8)", texture = "Interface\\Buttons\\WHITE8x8" },
    { name = "Blizzard",        texture = "Interface\\TargetingFrame\\UI-StatusBar" },
    { name = "Raid HP Fill",    texture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}

local OUTLINES = {
    { name = "None", value = "" },
    { name = "Outline", value = "OUTLINE" },
    { name = "Thick", value = "THICKOUTLINE" },
    { name = "Mono", value = "MONOCHROME" },
    { name = "Mono+Outline", value = "MONOCHROME,OUTLINE" },
    { name = "Mono+Thick", value = "MONOCHROME,THICKOUTLINE" },
}

-- ---------------------------------------------------------------------------
-- UTIL
-- ---------------------------------------------------------------------------
local function RGBA(t)
    if not t then return 1,1,1,1 end
    return t.r or 1, t.g or 1, t.b or 1, t.a or 1
end

local function SafeSetFont(fs, fontPath, size, outline)
    if not fs then return end
    fs:SetFontObject("GameFontNormalSmall")
    pcall(fs.SetFont, fs, fontPath or "Fonts\\FRIZQT__.TTF", size or 10, outline or "OUTLINE")
end

local function GetSkinTexture()
    local idx = (DB.skins and DB.skins.index and tonumber(DB.skins.index)) or 1
    local s = SKINS[idx] or SKINS[1]
    return (s and s.texture) or "Interface\\Buttons\\WHITE8x8"
end

local function GetFont()
    local fidx = (DB.fonts and DB.fonts.index and tonumber(DB.fonts.index)) or 1
    local outline = (DB.fonts and DB.fonts.outline)
    if outline == nil then outline = "OUTLINE" end
    local f = FONTS[fidx] or FONTS[1]
    return f.path, outline
end

local function SafeAlphaFromToken(frame, token, aTrue, aFalse)
    if not frame then return end
    if aTrue == nil then aTrue = 1 end
    if aFalse == nil then aFalse = 0 end

    if frame.SetAlphaFromBoolean then
        local ok = pcall(frame.SetAlphaFromBoolean, frame, token, aTrue, aFalse)
        if ok then return end
    end
    frame:SetAlpha(aFalse)
end

local function SafeSetText(fs, value)
    if not fs then return end
    local ok = pcall(fs.SetText, fs, value)
    if not ok then pcall(fs.SetText, fs, "") end
end

local function SafeSetTexture(tex, value)
    if not tex then return end
    local ok = pcall(tex.SetTexture, tex, value)
    if not ok then pcall(tex.SetTexture, tex, nil) end
end

local function CreateThinBorder(f)
    local b = CreateFrame("Frame", nil, f)
    b:SetAllPoints()
    b:SetFrameLevel((f:GetFrameLevel() or 1) + 10)

    local function Line()
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        return t
    end

    b.top = Line()
    b.bot = Line()
    b.l   = Line()
    b.r   = Line()

    function b:SetColor(r,g,bb,a)
        self.top:SetVertexColor(r,g,bb,a)
        self.bot:SetVertexColor(r,g,bb,a)
        self.l:SetVertexColor(r,g,bb,a)
        self.r:SetVertexColor(r,g,bb,a)
    end

    function b:UpdateSize(w, h, thickness)
        thickness = thickness or 1

        self.top:ClearAllPoints()
        self.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        self.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        self.top:SetHeight(thickness)

        self.bot:ClearAllPoints()
        self.bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        self.bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        self.bot:SetHeight(thickness)

        self.l:ClearAllPoints()
        self.l:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        self.l:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        self.l:SetWidth(thickness)

        self.r:ClearAllPoints()
        self.r:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        self.r:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        self.r:SetWidth(thickness)
    end

    return b
end

-- ---------------------------------------------------------------------------
-- Tracking
-- ---------------------------------------------------------------------------
M.active = M.active or {}
M.order  = M.order  or {}

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function IsValidHostile(unit)
    if not unit or not UnitExists(unit) then return false end
    if not IsNameplateUnit(unit) then return false end
    return UnitCanAttack("player", unit)
end

local function GetCastInfo(unit)
    local name, _, texture, _, _, _, _, notInterruptibleToken = UnitCastingInfo(unit)
    if name then return name, texture, notInterruptibleToken, false end

    local name2, _, texture2, _, _, _, notInterruptibleToken2 = UnitChannelInfo(unit)
    if name2 then return name2, texture2, notInterruptibleToken2, true end

    return nil
end

local function GetCastTimesMS(unit, isChannel)
    if not isChannel then
        local _, _, _, st, et = UnitCastingInfo(unit)
        return st, et
    else
        local _, _, _, st, et = UnitChannelInfo(unit)
        return st, et
    end
end

local function GetImportantToken(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local uf = plate and plate.UnitFrame
    local blizz = uf and (uf.castBar or uf.CastBar or uf.castbar)
    if blizz then
        return blizz.isHighlightedImportantCast
    end
    return nil
end

local function RemoveFromOrder(unit)
    for i = #M.order, 1, -1 do
        if M.order[i] == unit then
            tremove(M.order, i)
            return
        end
    end
end

local function EnsureInOrder(unit)
    for i = 1, #M.order do
        if M.order[i] == unit then return end
    end
    M.order[#M.order + 1] = unit
end

local function EnforceMaxBars()
    DB.maxBars = Clamp(DB.maxBars, 1, 10)
    while #M.order > DB.maxBars do
        local oldest = tremove(M.order, 1)
        if oldest then M.active[oldest] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
M.ui = M.ui or {}
local UI = M.ui

-- perf flags
M._styleDirty = true
M._layoutDirty = true
M._renderScheduled = false
M._wantRender = false
M._lastRescan = 0

-- single ticker (20hz) for visible bars
M._tickFrame = M._tickFrame or CreateFrame("Frame")
M._tickFrame:Hide()
M._tickFrame._acc = 0

local function ComputeHolderHeight()
    local rows = Clamp(DB.maxBars, 1, 10)
    local barH = Clamp(DB.height, 10, 50)
    local gap = Clamp(DB.spacing, 0, 14)
    return (rows * barH) + ((rows - 1) * gap)
end

local function CreateBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata("HIGH")
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture(GetSkinTexture())
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()

    f.sep = f:CreateTexture(nil, "OVERLAY")
    f.sep:SetTexture("Interface\\Buttons\\WHITE8x8")

    f.border = CreateThinBorder(f)

    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:SetWidth(10)

    f.text = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", 4, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetMaxLines(1)
    f.text:SetWordWrap(false)

    f.timeText = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.timeText:SetPoint("RIGHT", -4, 0)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetMaxLines(1)

    f.shieldIcon = f.bar:CreateTexture(nil, "OVERLAY")
    f.shieldIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    f.shieldIcon:SetAlpha(0)
    f.shieldIcon:Show()

    f.glow = f.bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    f.glow:SetPoint("TOPLEFT", -2, 2)
    f.glow:SetPoint("BOTTOMRIGHT", 2, -2)
    f.glow:SetBlendMode("ADD")
    f.glow:SetAlpha(0)

    f.important = CreateFrame("StatusBar", nil, f.bar)
    f.important:SetAllPoints(f.bar)
    f.important:SetStatusBarTexture(GetSkinTexture())
    f.important:SetMinMaxValues(0, 1)
    f.important:SetValue(0)
    f.important:SetAlpha(0)

    f.noKick = CreateFrame("StatusBar", nil, f.bar)
    f.noKick:SetAllPoints(f.bar)
    f.noKick:SetStatusBarTexture(GetSkinTexture())
    f.noKick:SetMinMaxValues(0, 1)
    f.noKick:SetValue(0)
    f.noKick:SetAlpha(0)

    f.interrupt = CreateFrame("StatusBar", nil, f.bar)
    f.interrupt:SetAllPoints(f.bar)
    f.interrupt:SetStatusBarTexture(GetSkinTexture())
    f.interrupt:SetMinMaxValues(0, 1)
    f.interrupt:SetValue(0)
    f.interrupt:SetAlpha(0)

    -- cache last tokens/strings to avoid spam
    f.unit = nil
    f._lastSpell = nil
    f._lastCaster = nil
    f._lastTex = nil
    f._lastImportantTok = nil
    f._lastNoKickTok = nil
    f._lastOnMeTok = nil
    f._isChannel = false
    f._startMS = nil
    f._endMS = nil
    f._dur = 1

    return f
end

local function UpdateBarLayout(f, w, h)
    w = Clamp(w, 120, 520)
    h = Clamp(h, 10, 50)
    f:SetSize(w, h)

    local showIcon = (DB.showIcon == true)
    local iconSize = h

    if showIcon then
        f.icon:Show()
        f.icon:SetSize(iconSize, iconSize)
        f.icon:ClearAllPoints()
        f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)

        f.bar:ClearAllPoints()
        f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 0, 0)
        f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

        f.sep:Show()
        f.sep:SetVertexColor(0,0,0,1)
        f.sep:SetSize(1, h)
        f.sep:ClearAllPoints()
        f.sep:SetPoint("LEFT", f.bar, "LEFT", 0, 0)
    else
        f.icon:Hide()
        f.bar:ClearAllPoints()
        f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.sep:Hide()
    end

    f.border:UpdateSize(w, h, 1)

    local fp, fo = GetFont()
    local fs = math_max(8, math_floor(h * 0.6))
    SafeSetFont(f.text, fp, fs, fo)
    SafeSetFont(f.timeText, fp, fs, fo)

    f.spark:SetHeight(h * 2.2)

    f.shieldIcon:SetSize(h - 4, h - 4)
    f.shieldIcon:ClearAllPoints()
    f.shieldIcon:SetPoint("LEFT", f.text, "RIGHT", 2, 0)
end

local function ApplyStyle(cb)
    if not cb then return end

    local w = Clamp(DB.width, 120, 520)
    local h = Clamp(DB.height, 10, 50)
    UpdateBarLayout(cb, w, h)

    local tex = GetSkinTexture()
    cb.bar:SetStatusBarTexture(tex)
    cb.important:SetStatusBarTexture(tex)
    cb.noKick:SetStatusBarTexture(tex)
    cb.interrupt:SetStatusBarTexture(tex)

    local c = DB.colors or DEFAULTS.colors
    cb.bg:SetColorTexture(RGBA(c.bg))
    cb.border:SetColor(RGBA(c.border))

    cb.text:SetTextColor(RGBA(c.text))
    cb.timeText:SetTextColor(RGBA(c.text))

    cb.bar:SetStatusBarColor(RGBA(c.normal))
    cb.important:SetStatusBarColor(RGBA(c.important))
    cb.noKick:SetStatusBarColor(RGBA(c.noKick))
    cb.interrupt:SetStatusBarColor(RGBA(c.interrupted))

    cb.glow:SetVertexColor(RGBA(c.glow))

    if DB.showBorder then cb.border:Show() else cb.border:Hide() end
end

local function LayoutBars()
    if not UI.holder then return end

    local gap = Clamp(DB.spacing, 0, 14)
    UI.holder:SetSize(Clamp(DB.width, 120, 520), ComputeHolderHeight())

    for i = 1, 10 do
        local cb = UI.bars[i]
        if cb then
            cb:ClearAllPoints()
            if i == 1 then
                cb:SetPoint("TOPLEFT", UI.holder, "TOPLEFT", 0, 0)
            else
                cb:SetPoint("TOPLEFT", UI.bars[i-1], "BOTTOMLEFT", 0, -gap)
            end
        end
    end
end

local function StopBar(cb)
    if not cb then return end
    cb.unit = nil
    cb._lastSpell = nil
    cb._lastCaster = nil
    cb._lastTex = nil
    cb._lastImportantTok = nil
    cb._lastNoKickTok = nil
    cb._lastOnMeTok = nil
    cb._isChannel = false
    cb._startMS = nil
    cb._endMS = nil
    cb._dur = 1

    SafeSetText(cb.text, "")
    SafeSetText(cb.timeText, "")

    cb.bar:SetMinMaxValues(0, 1); cb.bar:SetValue(0)
    cb.important:SetMinMaxValues(0, 1); cb.important:SetValue(0)
    cb.noKick:SetMinMaxValues(0, 1); cb.noKick:SetValue(0)
    cb.interrupt:SetMinMaxValues(0, 1); cb.interrupt:SetValue(0)

    cb.important:SetAlpha(0)
    cb.noKick:SetAlpha(0)
    cb.interrupt:SetAlpha(0)
    cb.glow:SetAlpha(0)
    cb.shieldIcon:SetAlpha(0)
    cb.spark:Hide()

    cb:SetAlpha(0)
    cb:Hide()
end

local function ApplyOnMeAlpha(cb, unit)
    local tok = UnitIsUnit(unit .. "target", "player")
    if tok ~= cb._lastOnMeTok then
        cb._lastOnMeTok = tok
        SafeAlphaFromToken(cb, tok, 1, 0)
    end
end

-- only sets up bar data; time/spark updated by single ticker
local function PrimeBarForUnit(cb, unit)
    if not (cb and unit and UnitExists(unit)) then
        StopBar(cb); return false
    end

    local spellName, texture, notInterruptibleToken, isChannel = GetCastInfo(unit)
    if not spellName then
        StopBar(cb); return false
    end

    local casterName = UnitName(unit) or "?"
    if casterName ~= cb._lastCaster or spellName ~= cb._lastSpell then
        cb._lastCaster = casterName
        cb._lastSpell = spellName
        SafeSetText(cb.text, casterName .. " - " .. spellName)
    end

    if DB.showIcon and cb.icon and texture ~= cb._lastTex then
        cb._lastTex = texture
        SafeSetTexture(cb.icon, texture)
    end

    local stMS, etMS = GetCastTimesMS(unit, isChannel)
    cb._isChannel = isChannel
    cb._startMS = stMS
    cb._endMS = etMS

    if stMS and etMS then
        local dur = (etMS - stMS) / 1000
        if dur <= 0 then dur = 0.1 end
        cb._dur = dur

        cb.bar:SetMinMaxValues(0, dur)
        cb.important:SetMinMaxValues(0, dur)
        cb.noKick:SetMinMaxValues(0, dur)
        cb.interrupt:SetMinMaxValues(0, dur)
    else
        cb._dur = 1
        cb.bar:SetMinMaxValues(0, 1)
        cb.important:SetMinMaxValues(0, 1)
        cb.noKick:SetMinMaxValues(0, 1)
        cb.interrupt:SetMinMaxValues(0, 1)
    end

    local importantToken = GetImportantToken(unit)
    if importantToken ~= cb._lastImportantTok then
        cb._lastImportantTok = importantToken
        SafeAlphaFromToken(cb.important, importantToken, 1, 0)
        SafeAlphaFromToken(cb.glow, importantToken, 0.9, 0)
    end

    if notInterruptibleToken ~= cb._lastNoKickTok then
        cb._lastNoKickTok = notInterruptibleToken
        SafeAlphaFromToken(cb.noKick, notInterruptibleToken, 1, 0)
        cb.shieldIcon:Show()
        SafeAlphaFromToken(cb.shieldIcon, notInterruptibleToken, 1, 0)
    end

    cb.spark:Hide()
    cb:SetAlpha(1)
    cb.unit = unit
    cb:Show()

    ApplyOnMeAlpha(cb, unit)
    return true
end

local function UpdateHolderVisibility()
    if not UI.holder then return end

    if not DB.enabled then
        UI.holder:Hide()
        return
    end

    if DB.alwaysShowHolder or DB.preview then
        UI.holder:Show()
        return
    end

    if #M.order > 0 then UI.holder:Show() else UI.holder:Hide() end
end

-- ---------------------------------------------------------------------------
-- Debounced render (massive CPU saver)
-- ---------------------------------------------------------------------------
local function RenderBarsNow()
    M._renderScheduled = false
    if not UI.holder then return end

    if not DB.enabled then
        -- hard hide + stop ticker
        for i = 1, 10 do
            local cb = UI.bars[i]
            if cb then StopBar(cb) end
        end
        UI.holder:Hide()
        M._tickFrame:Hide()
        return
    end

    if M._layoutDirty then
        LayoutBars()
        M._layoutDirty = false
    end

    if M._styleDirty then
        for i = 1, 10 do
            ApplyStyle(UI.bars[i])
        end
        M._styleDirty = false
    end

    -- preview: build static bars once per render (still light now)
    if DB.preview then
        for i = 1, 10 do StopBar(UI.bars[i]) end

        local c = DB.colors or DEFAULTS.colors

        local b1 = UI.bars[1]
        b1:Show(); b1:SetAlpha(1)
        SafeSetText(b1.text, "Shadow Bolt")
        SafeSetTexture(b1.icon, 136197)
        b1.bar:SetStatusBarColor(RGBA(c.normal))
        b1.bar:SetValue(0.35)
        SafeSetText(b1.timeText, "1.6")
        b1.spark:ClearAllPoints()
        b1.spark:SetPoint("CENTER", b1.bar, "LEFT", b1.bar:GetWidth() * 0.35, 0)
        b1.spark:Show()

        local b2 = UI.bars[2]
        b2:Show(); b2:SetAlpha(1)
        SafeSetText(b2.text, "Uninterruptible Cast")
        SafeSetTexture(b2.icon, 135963)
        b2.noKick:SetAlpha(1)
        b2.shieldIcon:SetAlpha(1)
        b2.bar:SetStatusBarColor(RGBA(c.noKick))
        b2.bar:SetValue(0.55)
        SafeSetText(b2.timeText, "2.8")
        b2.spark:ClearAllPoints()
        b2.spark:SetPoint("CENTER", b2.bar, "LEFT", b2.bar:GetWidth() * 0.55, 0)
        b2.spark:Show()

        local b3 = UI.bars[3]
        b3:Show(); b3:SetAlpha(1)
        SafeSetText(b3.text, "IMPORTANT CAST")
        SafeSetTexture(b3.icon, 136071)
        b3.important:SetAlpha(1)
        b3.glow:SetAlpha(0.9)
        b3.bar:SetStatusBarColor(RGBA(c.important))
        b3.bar:SetValue(0.80)
        SafeSetText(b3.timeText, "0.4")
        b3.spark:ClearAllPoints()
        b3.spark:SetPoint("CENTER", b3.bar, "LEFT", b3.bar:GetWidth() * 0.80, 0)
        b3.spark:Show()

        UpdateHolderVisibility()
        M._tickFrame:Hide()
        return
    end

    -- normal mode: assign bars to active units (only up to maxBars)
    local want = Clamp(DB.maxBars, 1, 10)
    local shown = 0

    for i = 1, #M.order do
        if shown >= want then break end
        local unit = M.order[i]
        if unit and M.active[unit] and UnitExists(unit) and GetCastInfo(unit) then
            shown = shown + 1
            PrimeBarForUnit(UI.bars[shown], unit)
        end
    end

    -- stop unused bars (only those above shown)
    for i = shown + 1, 10 do
        local cb = UI.bars[i]
        if cb and cb.unit then StopBar(cb) end
    end

    UpdateHolderVisibility()

    -- start/stop single ticker depending on shown
    if shown > 0 and UI.holder:IsShown() then
        M._tickFrame:Show()
    else
        M._tickFrame:Hide()
    end
end

local function RequestRender(styleDirty, layoutDirty)
    if styleDirty then M._styleDirty = true end
    if layoutDirty then M._layoutDirty = true end
    M._wantRender = true

    if M._renderScheduled then return end
    M._renderScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not M._wantRender then M._renderScheduled = false return end
            M._wantRender = false
            RenderBarsNow()
        end)
    else
        -- worst-case fallback
        RenderBarsNow()
    end
end

-- ---------------------------------------------------------------------------
-- HOLDER: ensure exists ALWAYS (fixes preview) + adds single ticker
-- ---------------------------------------------------------------------------
local function EnsureHolder()
    if UI.holder then return UI.holder end

    local h = CreateFrame("Frame", "RobUI_IncomingPlayerCastsHolder", UIParent)
    UI.holder = h
    h:SetFrameStrata("HIGH")
    h:SetFrameLevel(260)
    h:SetIgnoreParentAlpha(true)

    h:SetPoint(DB.point or "CENTER", UIParent, DB.relPoint or "CENTER", DB.x or 0, DB.y or 180)
    h:SetSize(Clamp(DB.width, 120, 520), ComputeHolderHeight())
    h:SetScale(Clamp(DB.scale or 1.0, 0.7, 1.6))

    h:SetScript("OnSizeChanged", function()
        RequestRender(false, true)
    end)

    UI.bars = UI.bars or {}
    for i = 1, 10 do
        UI.bars[i] = UI.bars[i] or CreateBar(h)
    end

    -- single ticker updates ONLY visible bars at 20hz
    M._tickFrame:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + (elapsed or 0)
        if self._acc < 0.05 then return end
        self._acc = 0

        if not (UI.holder and UI.holder:IsShown()) then return end
        if DB.preview or not DB.enabled then return end

        local now = GetTime()

        for i = 1, 10 do
            local cb = UI.bars[i]
            local unit = cb and cb.unit
            if unit and UnitExists(unit) then
                local name = GetCastInfo(unit)
                if not name then
                    StopBar(cb)
                else
                    local stMS, etMS = GetCastTimesMS(unit, cb._isChannel)
                    if stMS and etMS then
                        local startS = stMS / 1000
                        local endS = etMS / 1000
                        local dur = endS - startS
                        if dur <= 0 then dur = 0.1 end
                        cb._dur = dur

                        local v = now - startS
                        if v < 0 then v = 0 end
                        if v > dur then v = dur end

                        cb.bar:SetMinMaxValues(0, dur)
                        cb.important:SetMinMaxValues(0, dur)
                        cb.noKick:SetMinMaxValues(0, dur)
                        cb.interrupt:SetMinMaxValues(0, dur)

                        cb.bar:SetValue(v)
                        cb.important:SetValue(v)
                        cb.noKick:SetValue(v)

                        local remaining = dur - v
                        if remaining < 0 then remaining = 0 end
                        cb.timeText:SetFormattedText("%.1f", remaining)

                        local pct = v / dur
                        cb.spark:ClearAllPoints()
                        cb.spark:SetPoint("CENTER", cb.bar, "LEFT", cb.bar:GetWidth() * pct, 0)
                        cb.spark:Show()
                    end

                    -- cheap alpha refresh (tokens can change)
                    ApplyOnMeAlpha(cb, unit)

                    local impTok = GetImportantToken(unit)
                    if impTok ~= cb._lastImportantTok then
                        cb._lastImportantTok = impTok
                        SafeAlphaFromToken(cb.important, impTok, 1, 0)
                        SafeAlphaFromToken(cb.glow, impTok, 0.9, 0)
                    end

                    local _, _, noKickTok = GetCastInfo(unit)
                    if noKickTok ~= cb._lastNoKickTok then
                        cb._lastNoKickTok = noKickTok
                        SafeAlphaFromToken(cb.noKick, noKickTok, 1, 0)
                        cb.shieldIcon:Show()
                        SafeAlphaFromToken(cb.shieldIcon, noKickTok, 1, 0)
                    end
                end
            end
        end

        UpdateHolderVisibility()
    end)

    RequestRender(true, true)
    return h
end

local function ApplyLocalScale()
    if not UI.holder then return end
    UI.holder:SetScale(Clamp(DB.scale or 1.0, 0.7, 1.6))
end

local function TryTellGridCoreSize()
    local GC = GetGridCore()
    if GC and GC.ReflowAll then
        GC:ReflowAll("settings:pic")
    end
end

local function ApplyDesiredSize()
    EnsureHolder()
    local w = Clamp(DB.width, 120, 520)
    local h = ComputeHolderHeight()
    UI.holder:SetSize(w, h)
    TryTellGridCoreSize()
    RequestRender(true, true)
end

-- ---------------------------------------------------------------------------
-- GridCore Plugin registration
-- ---------------------------------------------------------------------------
local function BuildPluginFrame()
    return EnsureHolder()
end

local function ApplyGridScale(frame, globalScale)
    local gs = Clamp(globalScale or 1.0, 0.2, 3.0)
    local ls = Clamp(DB.scale or 1.0, 0.7, 1.6)
    if frame and frame.SetScale then
        pcall(frame.SetScale, frame, gs * ls)
    end
end

local function RegisterWithGrid()
    local GC = GetGridCore()
    if not (GC and GC.RegisterPlugin) then return end

    GC:RegisterPlugin("pic", {
        name = "PIC - Incoming Casts",
        build = BuildPluginFrame,
        setScale = ApplyGridScale,
        default = {
            gx = 0,
            gy = 140,
            group = 0,
            scaleWithGrid = false,
            label = "PIC Casts",
            showMode = "INHERIT",
        },
    })
end

-- ---------------------------------------------------------------------------
-- Events / Scan
-- ---------------------------------------------------------------------------
M.eventFrame = M.eventFrame or CreateFrame("Frame")
M.eventFrame:Hide()

local function FullRescan()
    if not DB.enabled then
        wipe(M.active); wipe(M.order)
        RequestRender(false, false)
        return
    end

    local now = GetTime()
    if (now - (M._lastRescan or 0)) < 0.25 then
        -- throttle spam
        return
    end
    M._lastRescan = now

    wipe(M.active)
    wipe(M.order)

    for i = 1, 40 do
        local np = "nameplate" .. i
        if UnitExists(np) and IsValidHostile(np) and GetCastInfo(np) then
            M.active[np] = true
            EnsureInOrder(np)
        end
    end

    EnforceMaxBars()
    RequestRender(false, false)
end

local function StartUnit(unit)
    if not DB.enabled then return end
    if not unit or not IsValidHostile(unit) then return end
    if not GetCastInfo(unit) then return end

    M.active[unit] = true
    EnsureInOrder(unit)
    EnforceMaxBars()
    RequestRender(false, false)
end

local function StopUnit(unit)
    if not unit then return end
    if M.active[unit] then
        M.active[unit] = nil
        RemoveFromOrder(unit)
        RequestRender(false, false)
    end
end

local function TargetChanged(unit)
    if unit and M.active[unit] then
        RequestRender(false, false)
    end
end

local function OnEvent(_, event, unit)
    if not DB.enabled then
        -- ignore all runtime work when disabled
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        if unit and UnitExists(unit) and IsValidHostile(unit) and GetCastInfo(unit) then
            StartUnit(unit)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        StopUnit(unit)

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        StartUnit(unit)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        StartUnit(unit)

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if unit and M.active[unit] then RequestRender(false, false) end

    elseif event == "UNIT_TARGET" then
        TargetChanged(unit)

    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_EMPOWER_STOP"
    then
        StopUnit(unit)

    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        FullRescan()
    end
end

M.eventFrame:SetScript("OnEvent", OnEvent)

function M:Enable()
    local ef = self.eventFrame
    ef:UnregisterAllEvents()

    if not DB.enabled then
        ef:Hide()
        if UI.holder then UI.holder:Hide() end
        if M._tickFrame then M._tickFrame:Hide() end
        return
    end

    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("GROUP_ROSTER_UPDATE")

    ef:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    ef:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    ef:RegisterEvent("UNIT_SPELLCAST_START")
    ef:RegisterEvent("UNIT_SPELLCAST_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ef:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    ef:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    ef:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")

    ef:RegisterEvent("UNIT_TARGET")

    ef:Show()
    FullRescan()
end

-- ---------------------------------------------------------------------------
-- SETTINGS UI (unchanged visually, but calls now mark dirty flags properly)
-- ---------------------------------------------------------------------------
M.settings = M.settings or {}
local S = M.settings

local function CreateGroupPanel(parent, titleText, w, h, x, y)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("TOPLEFT", x, y)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.4)
    f:SetBackdropBorderColor(1, 1, 1, 0.1)

    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 4, 4)
    t:SetText(titleText)

    return f
end

local function MakeCheck(parent, label, x, y, get, set, onChanged)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b.Text:SetText(label)

    b:SetScript("OnShow", function(self)
        self:SetChecked(get() and true or false)
    end)

    b:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        if onChanged then onChanged() end
    end)
    return b
end

local function MakeSlider(parent, sliderName, labelText, x, y, w, minVal, maxVal, step, get, set, fmt, onChanged)
    local s = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(w or 200)
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)

    local label = _G[sliderName .. "Text"]
    label:SetText(labelText)
    label:ClearAllPoints()
    label:SetPoint("BOTTOM", s, "TOP", 0, 4)

    _G[sliderName .. "Low"]:SetText(tostring(minVal))
    _G[sliderName .. "High"]:SetText(tostring(maxVal))

    s.valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.valueText:SetPoint("LEFT", s, "RIGHT", 8, 0)
    s.valueText:SetText("")

    local function UpdateValueText(v)
        if fmt == "float2" then
            s.valueText:SetText(string.format("%.2f", v))
        else
            s.valueText:SetText(tostring(math_floor(v + 0.5)))
        end
    end

    s:SetScript("OnShow", function(self)
        local v = get()
        if v == nil then v = minVal end
        self:SetValue(v)
        UpdateValueText(v)
    end)

    s:SetScript("OnValueChanged", function(self, v)
        if not self:IsShown() then return end
        if step and step > 0 then
            local k = math_floor((v / step) + 0.5)
            v = k * step
        end
        set(v)
        UpdateValueText(v)
        if onChanged then onChanged() end
    end)

    return s
end

local function MakeDropdown(parent, name, labelText, x, y, w, items, getIndex, setIndex, onChanged)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x + 16, y)
    label:SetText(labelText)

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, y - 12)
    UIDropDownMenu_SetWidth(dd, w or 180)

    UIDropDownMenu_Initialize(dd, function(self, level)
        local idx = getIndex() or 1
        for i = 1, #items do
            local info = UIDropDownMenu_CreateInfo()
            info.text = items[i].name
            info.checked = (i == idx)
            info.func = function()
                setIndex(i)
                UIDropDownMenu_SetSelectedID(dd, i)
                UIDropDownMenu_SetText(dd, items[i].name)
                if onChanged then onChanged() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd:SetScript("OnShow", function()
        local idx = getIndex() or 1
        UIDropDownMenu_SetSelectedID(dd, idx)
        UIDropDownMenu_SetText(dd, (items[idx] and items[idx].name) or "Select")
    end)

    return dd
end

local function ApplyAllNow()
    EnforceMaxBars()
    EnsureHolder()
    ApplyLocalScale()
    ApplyDesiredSize()
    UpdateHolderVisibility()
    RequestRender(true, true)
end

local function EnsureSettings()
    if S.frame then return end

    local f = CreateFrame("Frame", "RobUI_IncomingPlayerCastsSettings", UIParent, "BackdropTemplate")
    S.frame = f
    f:SetSize(600, 480)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(500)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(1, 1, 1, 0.2)
    f:Hide()

    local sp = DB.settings or DEFAULTS.settings
    f:SetPoint(sp.point or "CENTER", UIParent, sp.relPoint or "CENTER", sp.x or 0, sp.y or 0)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        DB.settings = DB.settings or {}
        local p, _, rp, x, y = self:GetPoint(1)
        DB.settings.point = p or "CENTER"
        DB.settings.relPoint = rp or "CENTER"
        DB.settings.x = tonumber(x) or 0
        DB.settings.y = tonumber(y) or 0
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PIC - Incoming Casts")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 18, -36)
    sub:SetText("Preview overrides dynamic display. RGrid can override size via fw/fh.")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local div = f:CreateTexture(nil, "BORDER")
    div:SetTexture("Interface\\Buttons\\WHITE8x8")
    div:SetVertexColor(1, 1, 1, 0.1)
    div:SetPoint("TOPLEFT", 16, -56)
    div:SetPoint("TOPRIGHT", -16, -56)
    div:SetHeight(1)

    local leftPanelX, topPanelY = 20, -85
    local panelSpacing = 20

    local togglesGroup = CreateGroupPanel(f, "Toggles", 270, 150, leftPanelX, topPanelY)

    MakeCheck(togglesGroup, "Enable PIC", 10, -10,
        function() return DB.enabled end,
        function(v)
            DB.enabled = v
            if v then
                M:Enable()
                if UI.holder then UI.holder:Show() end
            else
                if M.eventFrame then M.eventFrame:UnregisterAllEvents(); M.eventFrame:Hide() end
                if UI.holder then UI.holder:Hide() end
                if M._tickFrame then M._tickFrame:Hide() end
                wipe(M.active); wipe(M.order)
            end
        end,
        function() RequestRender(false, false) UpdateHolderVisibility() end
    )

    MakeCheck(togglesGroup, "Preview (Static Bars)", 10, -36, function() return DB.preview end, function(v) DB.preview = v end, function() RequestRender(false, false) end)
    MakeCheck(togglesGroup, "Always Show Holder", 10, -62, function() return DB.alwaysShowHolder end, function(v) DB.alwaysShowHolder = v end, function() UpdateHolderVisibility() end)
    MakeCheck(togglesGroup, "Show Spell Icon", 10, -88, function() return DB.showIcon end, function(v) DB.showIcon = v end, function() RequestRender(true, true) end)
    MakeCheck(togglesGroup, "Show Bar Border", 10, -114, function() return DB.showBorder end, function(v) DB.showBorder = v end, function() RequestRender(true, false) end)

    local styleGroupY = topPanelY - 150 - panelSpacing
    local styleGroup = CreateGroupPanel(f, "Style & Textures", 270, 170, leftPanelX, styleGroupY)

    S.ddSkin = MakeDropdown(styleGroup, "RobUIPIC_DropdownSkin", "Bar Texture", -4, -16, 230, SKINS,
        function() return (DB.skins and DB.skins.index) or 1 end,
        function(i) DB.skins = DB.skins or {}; DB.skins.index = i end,
        function() RequestRender(true, false) end
    )
    S.ddFont = MakeDropdown(styleGroup, "RobUIPIC_DropdownFont", "Font", -4, -66, 230, FONTS,
        function() return (DB.fonts and DB.fonts.index) or 1 end,
        function(i) DB.fonts = DB.fonts or {}; DB.fonts.index = i end,
        function() RequestRender(true, false) end
    )
    S.ddOutline = MakeDropdown(styleGroup, "RobUIPIC_DropdownOutline", "Font Outline", -4, -116, 230, OUTLINES,
        function()
            local cur = DB.fonts and DB.fonts.outline
            if cur == nil then cur = "OUTLINE" end
            for i = 1, #OUTLINES do
                if OUTLINES[i].value == cur then return i end
            end
            return 2
        end,
        function(i)
            DB.fonts = DB.fonts or {}
            DB.fonts.outline = OUTLINES[i] and OUTLINES[i].value or "OUTLINE"
        end,
        function() RequestRender(true, false) end
    )

    local rightPanelX = leftPanelX + 270 + panelSpacing
    local sizeGroup = CreateGroupPanel(f, "Dimensions & Scale", 270, 340, rightPanelX, topPanelY)

    local sY = -34
    S.sliderWidth = MakeSlider(sizeGroup, "RobUIPIC_SliderWidth", "Total Width", 16, sY, 210, 120, 520, 1,
        function() return DB.width end,
        function(v) DB.width = Clamp(v, 120, 520) end,
        "int",
        function() RequestRender(true, true) ApplyDesiredSize() end
    )
    sY = sY - 60
    S.sliderBarH = MakeSlider(sizeGroup, "RobUIPIC_SliderBarHeight", "Bar Height", 16, sY, 210, 10, 50, 1,
        function() return DB.height end,
        function(v) DB.height = Clamp(v, 10, 50) end,
        "int",
        function() RequestRender(true, true) ApplyDesiredSize() end
    )
    sY = sY - 60
    S.sliderMaxBars = MakeSlider(sizeGroup, "RobUIPIC_SliderMaxBars", "Maximum Bars", 16, sY, 210, 1, 10, 1,
        function() return DB.maxBars end,
        function(v) DB.maxBars = Clamp(v, 1, 10) end,
        "int",
        function() EnforceMaxBars() RequestRender(false, true) end
    )
    sY = sY - 60
    S.sliderSpacing = MakeSlider(sizeGroup, "RobUIPIC_SliderSpacing", "Spacing Between Bars", 16, sY, 210, 0, 14, 1,
        function() return DB.spacing end,
        function(v) DB.spacing = Clamp(v, 0, 14) end,
        "int",
        function() RequestRender(false, true) end
    )
    sY = sY - 60
    S.sliderScale = MakeSlider(sizeGroup, "RobUIPIC_SliderLocalScale", "Local Scale Multiplier", 16, sY, 210, 0.7, 1.6, 0.05,
        function() return DB.scale end,
        function(v) DB.scale = Clamp(v, 0.7, 1.6) end,
        "float2",
        function()
            EnsureHolder()
            ApplyLocalScale()
            RequestRender(false, false)
        end
    )

    local bdiv = f:CreateTexture(nil, "BORDER")
    bdiv:SetTexture("Interface\\Buttons\\WHITE8x8")
    bdiv:SetVertexColor(1, 1, 1, 0.1)
    bdiv:SetPoint("BOTTOMLEFT", 16, 46)
    bdiv:SetPoint("BOTTOMRIGHT", -16, 46)
    bdiv:SetHeight(1)

    local attach = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    attach:SetSize(140, 24)
    attach:SetPoint("BOTTOMLEFT", 16, 16)
    attach:SetText("Attach to /rgrid")
    attach:SetScript("OnClick", function()
        local GC = GetGridCore()
        RegisterWithGrid()
        EnsureHolder()
        if GC and GC.AttachPlugin then
            GC:AttachPlugin("pic", true)
            if GC.ReflowAll then GC:ReflowAll("attach:pic") end
        end
    end)

    local apply = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    apply:SetSize(100, 24)
    apply:SetPoint("LEFT", attach, "RIGHT", 10, 0)
    apply:SetText("Apply All")
    apply:SetScript("OnClick", ApplyAllNow)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(120, 24)
    reset:SetPoint("LEFT", apply, "RIGHT", 10, 0)
    reset:SetText("Reset Defaults")
    reset:SetScript("OnClick", function()
        wipe(DB)
        DeepDefaults(DB, DEFAULTS)

        DB.maxBars = Clamp(DB.maxBars, 1, 10)
        DB.width   = Clamp(DB.width, 120, 520)
        DB.height  = Clamp(DB.height, 10, 50)
        DB.scale   = Clamp(DB.scale, 0.7, 1.6)
        DB.spacing = Clamp(DB.spacing, 0, 14)

        RobUIIncomingCastDB = DB

        EnsureHolder()
        RequestRender(true, true)
        ApplyAllNow()
        f:Hide(); f:Show()
    end)
end

function M:ToggleSettings()
    EnsureSettings()
    EnsureHolder()
    if S.frame:IsShown() then S.frame:Hide() else S.frame:Show() end
end

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_ROBUIPIC1 = "/pic"
SlashCmdList["ROBUIPIC"] = function(msg)
    msg = string_lower(msg or "")
    local GC = GetGridCore()

    if msg == "preview" then
        EnsureHolder()
        DB.preview = not DB.preview
        RequestRender(false, false)
        UpdateHolderVisibility()
        return
    elseif msg == "add" then
        RegisterWithGrid()
        EnsureHolder()
        if GC and GC.AttachPlugin then
            GC:AttachPlugin("pic", true)
            if GC.ReflowAll then GC:ReflowAll("attach:pic") end
        end
        return
    end

    M:ToggleSettings()
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON then return end

    InitDB()
    RegisterWithGrid()
    EnsureHolder()
    M:Enable()

    boot:UnregisterAllEvents()
end)