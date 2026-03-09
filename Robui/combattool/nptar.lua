-- ============================================================================
-- RobUI - CASTMARK: Nameplate "Casting on You" Marker + Settings (12.0)
--
-- Stores settings inside RobuiDB (NO separate SavedVariables):
--   RobuiDB.castmark = { ... }
--
-- Slash:
--   /castmark              toggle settings
--   /castmark preview      toggle preview-on-target
--   /castmark reset        reset settings
--   /castmark dump         print DB values
-- ============================================================================

local ADDON, ns = ...
ns = _G[ADDON] or ns or {}
_G[ADDON] = ns

ns.CastMark = ns.CastMark or {}
local M = ns.CastMark

local pcall = pcall
local tonumber = tonumber
local pairs = pairs
local wipe = wipe
local string_lower = string.lower

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local InCombatLockdown = InCombatLockdown
local C_NamePlate = C_NamePlate

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,

    markerType = "SQUARE", -- SQUARE|DIAMOND|CIRCLE
    size = 14,
    xOff = 0,
    yOff = 14,

    blink = true,
    blinkDur = 0.35,

    color  = { r=0.10, g=1.00, b=0.10, a=1.00 },
    border = { r=0.00, g=0.00, b=0.00, a=1.00 },

    showText = false,
    text = "ON YOU",
    textSize = 10,
    textOutline = "OUTLINE",
    textColor = { r=1, g=1, b=1, a=1 },

    previewOnTarget = false,

    settings = { point="CENTER", relPoint="CENTER", x=0, y=0 },

    __touch = 0,
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
    v = tonumber(v)
    if v == nil then v = lo end
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
end

local function Touch(DB)
    DB.__touch = (tonumber(DB.__touch) or 0) + 1
end

-- ---------------------------------------------------------------------------
-- DB in RobuiDB
-- ---------------------------------------------------------------------------
local function GetDB()
    -- RobuiDB is your real saved DB that we know persists
    if type(_G.RobuiDB) ~= "table" then
        _G.RobuiDB = _G.RobuiDB or {}
    end
    local root = _G.RobuiDB
    root.castmark = root.castmark or {}
    local DB = root.castmark
    DeepDefaults(DB, DEFAULTS)
    return DB
end

local function Sanitize(DB)
    DB.size     = Clamp(DB.size, 8, 48)
    DB.xOff     = Clamp(DB.xOff, -60, 60)
    DB.yOff     = Clamp(DB.yOff, -20, 80)
    DB.blinkDur = Clamp(DB.blinkDur, 0.10, 1.00)
    DB.textSize = Clamp(DB.textSize, 8, 18)

    local t = DB.markerType
    if t ~= "SQUARE" and t ~= "DIAMOND" and t ~= "CIRCLE" then
        DB.markerType = "SQUARE"
    end

    if type(DB.color) ~= "table" then DB.color = { r=0.10, g=1.00, b=0.10, a=1.00 } end
    if type(DB.border) ~= "table" then DB.border = { r=0, g=0, b=0, a=1 } end
    if type(DB.textColor) ~= "table" then DB.textColor = { r=1, g=1, b=1, a=1 } end
    if type(DB.settings) ~= "table" then DB.settings = { point="CENTER", relPoint="CENTER", x=0, y=0 } end
end

-- ---------------------------------------------------------------------------
-- Secret-safe alpha helper
-- ---------------------------------------------------------------------------
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

local function IsCasting(unit)
    if UnitCastingInfo(unit) then return true end
    if UnitChannelInfo(unit) then return true end
    return false
end

-- ---------------------------------------------------------------------------
-- Marker
-- ---------------------------------------------------------------------------
local function ApplyMarkerStyle(marker)
    if not marker then return end
    local DB = GetDB()
    Sanitize(DB)

    marker:SetSize(DB.size, DB.size)

    local c = DB.color
    marker.tex:SetVertexColor(c.r or 0.1, c.g or 1, c.b or 0.1, c.a or 1)

    local bc = DB.border
    marker.border:SetVertexColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)

    if DB.markerType == "CIRCLE" then
        marker.tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        marker.tex:SetTexCoord(0, 1, 0, 1)
        marker.tex:SetRotation(0)
    else
        marker.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        marker.tex:SetTexCoord(0, 1, 0, 1)
        if DB.markerType == "DIAMOND" then
            marker.tex:SetRotation(0.785398163)
        else
            marker.tex:SetRotation(0)
        end
    end

    if marker.ag then
        local d = DB.blinkDur or 0.35
        marker.a1:SetDuration(d)
        marker.a2:SetDuration(d)
    end

    if DB.showText then
        marker.text:Show()
        marker.text:SetText(DB.text or "")
        marker.text:SetFontObject("GameFontNormalSmall")
        pcall(marker.text.SetFont, marker.text, "Fonts\\FRIZQT__.TTF", DB.textSize or 10, DB.textOutline or "OUTLINE")
        local tc = DB.textColor
        marker.text:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)
    else
        marker.text:Hide()
    end

    if DB.blink then
        if marker.ag and not marker.ag:IsPlaying() then marker.ag:Play() end
    else
        if marker.ag and marker.ag:IsPlaying() then marker.ag:Stop() end
        marker.tex:SetAlpha(1)
    end
end

local function EnsureMarker(plate)
    if not plate then return nil end
    local uf = plate.UnitFrame or plate.unitFrame or plate
    if not uf then return nil end

    if uf.RobUI_CastMark then
        return uf.RobUI_CastMark
    end

    local f = CreateFrame("Frame", nil, uf)
    uf.RobUI_CastMark = f

    f:SetFrameStrata("HIGH")
    f:SetFrameLevel((uf:GetFrameLevel() or 1) + 80)
    f:SetAlpha(0)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()

    local border = f:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOP", f, "BOTTOM", 0, -2)
    text:SetJustifyH("CENTER")
    text:SetText("")

    local ag = tex:CreateAnimationGroup()
    ag:SetLooping("REPEAT")

    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.25)
    a1:SetToAlpha(1.0)
    a1:SetOrder(1)

    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1.0)
    a2:SetToAlpha(0.25)
    a2:SetOrder(2)

    f.tex = tex
    f.border = border
    f.text = text
    f.ag = ag
    f.a1 = a1
    f.a2 = a2

    ApplyMarkerStyle(f)
    return f
end

local function ReanchorMarker(marker, uf)
    if not (marker and uf) then return end
    local DB = GetDB()
    Sanitize(DB)
    marker:ClearAllPoints()
    marker:SetPoint("BOTTOM", uf, "TOP", DB.xOff or 0, DB.yOff or 14)
end

local function HideAllMarkers()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
            local plate = C_NamePlate.GetNamePlateForUnit(u)
            if plate then
                local uf = plate.UnitFrame or plate.unitFrame or plate
                if uf and uf.RobUI_CastMark then
                    uf.RobUI_CastMark:SetAlpha(0)
                end
            end
        end
    end
end

local function UpdateUnit(unit)
    if not (unit and UnitExists(unit)) then return end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end

    local DB = GetDB()
    Sanitize(DB)

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end

    local uf = plate.UnitFrame or plate.unitFrame or plate
    if not uf then return end

    local marker = EnsureMarker(plate)
    if not marker then return end

    ApplyMarkerStyle(marker)
    ReanchorMarker(marker, uf)

    if not DB.enabled then
        marker:SetAlpha(0)
        return
    end

    if UnitCanAttack and not UnitCanAttack("player", unit) then
        marker:SetAlpha(0)
        return
    end

    if DB.previewOnTarget then
        marker:SetAlpha(0)
        if UnitExists("target") then
            local tplate = C_NamePlate.GetNamePlateForUnit("target")
            if tplate == plate then marker:SetAlpha(1) end
        end
        return
    end

    if not IsCasting(unit) then
        marker:SetAlpha(0)
        return
    end

    local tok = UnitIsUnit(unit .. "target", "player")
    SafeAlphaFromToken(marker, tok, 1, 0)
end

local function HideUnit(unit)
    if not (unit and UnitExists(unit)) then return end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local uf = plate.UnitFrame or plate.unitFrame or plate
    if uf and uf.RobUI_CastMark then
        uf.RobUI_CastMark:SetAlpha(0)
    end
end

local function RescanVisible()
    local DB = GetDB()
    Sanitize(DB)

    if not DB.enabled then
        HideAllMarkers()
        return
    end

    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
            UpdateUnit(u)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Settings UI
-- ---------------------------------------------------------------------------
M.settings = M.settings or {}
local S = M.settings

local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function MakeEditBox(parent, w, h)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(w, h)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("LEFT")
    eb:SetTextInsets(8, 8, 0, 0)
    return eb
end

local function SetCheckLabel(btn, label)
    local g = btn:GetName() and _G[btn:GetName().."Text"] or nil
    if g then g:SetText(label) return end
    if btn.Text then btn.Text:SetText(label) return end
    if btn.text then btn.text:SetText(label) return end
end

local function MakeCheck(parent, label, x, y, get, set, onAfter)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    SetCheckLabel(b, label)

    local function Refresh()
        b:SetChecked(get() and true or false)
    end

    b:SetScript("OnShow", Refresh)
    b:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        set(v)
        local DB = GetDB()
        Touch(DB)
        if onAfter then pcall(onAfter, v) end
        RescanVisible()
    end)

    Refresh()
    return b
end

local function MakeNumberField(parent, label, x, y, width, get, set, lo, hi, decimals)
    MakeLabel(parent, label, x, y)

    local eb = MakeEditBox(parent, width or 90, 20)
    eb:SetPoint("TOPLEFT", x + 140, y + 4)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    if lo and hi then hint:SetText("("..tostring(lo).."-"..tostring(hi)..")") else hint:SetText("") end

    local function fmt(v)
        if decimals and decimals > 0 then
            return string.format("%."..decimals.."f", v)
        end
        return tostring(v)
    end

    local function Refresh()
        local v = get()
        if v == nil then v = lo or 0 end
        eb:SetText(fmt(v))
    end

    local function Apply()
        local v = tonumber(eb:GetText() or "")
        if v == nil then Refresh(); return end
        if lo then v = Clamp(v, lo, hi or v) end
        set(v)
        local DB = GetDB()
        Touch(DB)
        Refresh()
        RescanVisible()
    end

    eb:SetScript("OnShow", Refresh)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
    eb:SetScript("OnEditFocusLost", Apply)

    Refresh()
    return eb
end

local function EnsureSettingsFrame()
    if S.frame then return end

    local DB = GetDB()
    Sanitize(DB)

    local f = CreateFrame("Frame", "RobUI_CastMarkSettings", UIParent, "BackdropTemplate")
    S.frame = f
    f:SetSize(560, 340)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(500)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    f:SetBackdropColor(0,0,0,0.90)
    f:SetBackdropBorderColor(1,1,1,0.18)
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
        local DB2 = GetDB()
        DB2.settings = DB2.settings or {}
        local p, _, rp, x, y = self:GetPoint(1)
        DB2.settings.point = p or "CENTER"
        DB2.settings.relPoint = rp or "CENTER"
        DB2.settings.x = tonumber(x) or 0
        DB2.settings.y = tonumber(y) or 0
        Touch(DB2)
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("CASTMARK - Marker (Casting on YOU)")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    MakeCheck(
        f, "Enable", 14, -40,
        function() return GetDB().enabled end,
        function(v) local d=GetDB(); d.enabled=v; Touch(d) end,
        function(v) if not v then HideAllMarkers() end end
    )

    MakeCheck(
        f, "Preview on Target", 120, -40,
        function() return GetDB().previewOnTarget end,
        function(v) local d=GetDB(); d.previewOnTarget=v; Touch(d) end
    )

    MakeCheck(
        f, "Blink", 290, -40,
        function() return GetDB().blink end,
        function(v) local d=GetDB(); d.blink=v; Touch(d) end
    )

    MakeNumberField(f, "Blink Duration", 14, -70, 90,
        function() return GetDB().blinkDur end,
        function(v) local d=GetDB(); d.blinkDur = Clamp(v, 0.10, 1.00); Touch(d) end,
        0.10, 1.00, 2
    )

    MakeLabel(f, "Marker Type", 14, -110)
    local types = { "SQUARE", "DIAMOND", "CIRCLE" }
    local typeName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeName:SetPoint("TOPLEFT", 160, -110)

    local function RefreshType()
        local d = GetDB()
        local t = d.markerType
        if t ~= "SQUARE" and t ~= "DIAMOND" and t ~= "CIRCLE" then t = "SQUARE"; d.markerType = t; Touch(d) end
        typeName:SetText(t)
    end

    local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prev:SetSize(34, 20)
    prev:SetPoint("TOPLEFT", 160, -132)
    prev:SetText("<")

    local nextb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextb:SetSize(34, 20)
    nextb:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    nextb:SetText(">")

    local function Cycle(dir)
        local d = GetDB()
        local cur = d.markerType or "SQUARE"
        local idx = 1
        for i=1,#types do if types[i] == cur then idx = i break end end
        idx = idx + dir
        if idx < 1 then idx = #types end
        if idx > #types then idx = 1 end
        d.markerType = types[idx]
        Touch(d)
        RefreshType()
        RescanVisible()
    end

    prev:SetScript("OnClick", function() Cycle(-1) end)
    nextb:SetScript("OnClick", function() Cycle(1) end)
    RefreshType()

    MakeNumberField(f, "Size", 14, -180, 90,
        function() return GetDB().size end,
        function(v) local d=GetDB(); d.size=Clamp(v,8,48); Touch(d) end,
        8, 48, 0
    )
    MakeNumberField(f, "X Offset", 14, -210, 90,
        function() return GetDB().xOff end,
        function(v) local d=GetDB(); d.xOff=Clamp(v,-60,60); Touch(d) end,
        -60, 60, 0
    )
    MakeNumberField(f, "Y Offset", 14, -240, 90,
        function() return GetDB().yOff end,
        function(v) local d=GetDB(); d.yOff=Clamp(v,-20,80); Touch(d) end,
        -20, 80, 0
    )

    MakeCheck(
        f, "Show Text", 320, -180,
        function() return GetDB().showText end,
        function(v) local d=GetDB(); d.showText=v; Touch(d) end
    )

    MakeLabel(f, "Text", 320, -210)
    local tb = MakeEditBox(f, 200, 20)
    tb:SetPoint("TOPLEFT", 370, -206)
    tb:SetScript("OnShow", function(self) self:SetText(GetDB().text or "") end)
    tb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local d=GetDB(); d.text=self:GetText() or ""; Touch(d)
        RescanVisible()
    end)
    tb:SetScript("OnEditFocusLost", function(self)
        local d=GetDB(); d.text=self:GetText() or ""; Touch(d)
        RescanVisible()
    end)

    MakeNumberField(f, "Text Size", 320, -240, 90,
        function() return GetDB().textSize end,
        function(v) local d=GetDB(); d.textSize=Clamp(v,8,18); Touch(d) end,
        8, 18, 0
    )

    local tip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("BOTTOMLEFT", 14, 44)
    tip:SetWidth(530)
    tip:SetJustifyH("LEFT")
    tip:SetText("Marker shows only when enemy is casting/channeling AND targeting you.\nPreview forces marker on your target's nameplate for placement.")

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("BOTTOMLEFT", 14, 14)
    reset:SetText("Reset Settings")
    reset:SetScript("OnClick", function()
        local d = GetDB()
        wipe(d)
        DeepDefaults(d, DEFAULTS)
        Touch(d)
        HideAllMarkers()
        RescanVisible()
        if S.frame then S.frame:Hide(); S.frame:Show() end
    end)

    local rescan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rescan:SetSize(120, 22)
    rescan:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    rescan:SetText("Rescan Now")
    rescan:SetScript("OnClick", function() RescanVisible() end)
end

function M:ToggleSettings()
    EnsureSettingsFrame()
    if S.frame:IsShown() then S.frame:Hide() else S.frame:Show() end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
M.eventFrame = M.eventFrame or CreateFrame("Frame")
local EF = M.eventFrame
EF:UnregisterAllEvents()

EF:RegisterEvent("PLAYER_LOGIN")
EF:RegisterEvent("PLAYER_ENTERING_WORLD")
EF:RegisterEvent("GROUP_ROSTER_UPDATE")
EF:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EF:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EF:RegisterEvent("UNIT_TARGET")
EF:RegisterEvent("UNIT_SPELLCAST_START")
EF:RegisterEvent("UNIT_SPELLCAST_STOP")
EF:RegisterEvent("UNIT_SPELLCAST_FAILED")
EF:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
EF:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
EF:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

EF:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        UpdateUnit(unit); return
    end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        HideUnit(unit); return
    end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_TARGET"
    then
        if type(unit) == "string" and unit:match("^nameplate%d+$") then
            UpdateUnit(unit)
        else
            RescanVisible()
        end
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        RescanVisible()
        return
    end
end)

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_ROBUICASTMARK1 = "/castmark"
SlashCmdList["ROBUICASTMARK"] = function(msg)
    msg = string_lower(msg or "")
    local DB = GetDB()
    Sanitize(DB)

    if msg == "preview" then
        DB.previewOnTarget = not DB.previewOnTarget
        Touch(DB)
        RescanVisible()
        print("touch", DB.__touch, "enabled", tostring(DB.enabled))
        return
    end

    if msg == "reset" then
        wipe(DB)
        DeepDefaults(DB, DEFAULTS)
        Touch(DB)
        HideAllMarkers()
        RescanVisible()
        print("touch", DB.__touch, "enabled", tostring(DB.enabled))
        return
    end

    if msg == "dump" then
        print("castmark:", "touch", DB.__touch, "enabled", tostring(DB.enabled), "blink", tostring(DB.blink), "showText", tostring(DB.showText))
        return
    end

    M:ToggleSettings()
    print("touch", DB.__touch, "enabled", tostring(DB.enabled))
end

-- Boot
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    RescanVisible()
end)
