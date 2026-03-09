local AddonName, ns = ...
local R = _G.Robui
ns.UnitFrames.Pet.Settings = ns.UnitFrames.Pet.Settings or {}
local UI = ns.UnitFrames.Pet.Settings

-- 1. TILGANG TIL CORE
local function Pet() return ns.UnitFrames.Pet end
local function CFG() return Pet() and Pet().GetConfig and Pet():GetConfig() or nil end
local function Apply()
    local p = Pet()
    if p and p.ForceUpdate then p:ForceUpdate() end
end

-- 2. TEKSTUR LISTE
local MEDIA_PATH = "Interface\\AddOns\\"..AddonName.."\\media\\"
local TEXTURES = {
    { name = "Base (Flat)",   path = MEDIA_PATH .. "base.tga" },
    { name = "Cool Blue",     path = MEDIA_PATH .. "coolblue.tga" },
    { name = "Statusbar 1",   path = MEDIA_PATH .. "statusbar1.tga" },

    { name = "NPC: Hostile",  path = MEDIA_PATH .. "robui_statusbar_hostile_256x32.tga" },
    { name = "NPC: Neutral",  path = MEDIA_PATH .. "robui_statusbar_neutral_256x32.tga" },
    { name = "NPC: Friendly", path = MEDIA_PATH .. "robui_statusbar_friendly_256x32.tga" },
}

local function NameForPath(p)
    for _,t in ipairs(TEXTURES) do
        if t.path == p then return t.name end
    end
    return "Custom/Unknown"
end

-- 3. VISUELL STIL
local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"
local C_BG  = {0.08, 0.08, 0.10, 0.95}
local C_PAN = {0.14, 0.14, 0.16, 1.00}
local C_BRD = {0, 0, 0, 1}
local C_TXT = {0.9, 0.9, 0.9, 1}

local function Skin(f, bg)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile=WHITE8x8, edgeFile=WHITE8x8, edgeSize=1 })
    local c = bg or C_PAN
    f:SetBackdropColor(c[1], c[2], c[3], c[4])
    f:SetBackdropBorderColor(C_BRD[1], C_BRD[2], C_BRD[3], C_BRD[4])
end

local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetTextColor(C_TXT[1], C_TXT[2], C_TXT[3], 1)
    fs:SetText(text or "")
    return fs
end

local function CreateSection(parent, title, x, y, w)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(C_PAN[1], C_PAN[2], C_PAN[3], 1)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    bar:SetSize(w, 24)

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    fs:SetPoint("LEFT", bar, "LEFT", 10, 0)
    fs:SetText(title)

    return y - 35
end

-- 4. KOMPONENTER
local function EditBox(parent, w, x, y)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(w, 20)
    eb:SetPoint("TOPLEFT", x, y)
    Skin(eb, {0.2,0.2,0.2,1})
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(6,6,0,0)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    return eb
end

local function Button(parent, text, w, h, x, y, fn)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetPoint("TOPLEFT", x, y)
    Skin(b, {0.20,0.20,0.22,1})
    local fs = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text or "")
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function() Skin(b, {0.3,0.3,0.35,1}) end)
    b:SetScript("OnLeave", function() Skin(b, {0.20,0.20,0.22,1}) end)
    return b
end

local function Check(parent, text, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(text or "")
    cb.Text:SetTextColor(C_TXT[1], C_TXT[2], C_TXT[3], 1)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Apply()
        UI.RefreshIfOpen()
    end)
    cb._get = get
    return cb
end

local function OpenColorPicker(r, g, b, a, callback)
    r = tonumber(r) or 1
    g = tonumber(g) or 1
    b = tonumber(b) or 1
    a = tonumber(a) or 1
    local info = {
        r = r, g = g, b = b, opacity = a,
        hasOpacity = (a ~= nil),
        swatchFunc = function()
            local rr, gg, bb = ColorPickerFrame:GetColorRGB()
            local aa = a
            if a and ColorPickerFrame.GetColorAlpha then
                aa = ColorPickerFrame:GetColorAlpha()
            end
            callback(rr, gg, bb, aa)
        end,
        cancelFunc = function()
            callback(r, g, b, a)
        end,
    }
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

-- 5. SLIDER + NUDGE
local function SliderRow(parent, label, key, minV, maxV, step, x, y, w)
    local cfg = CFG()
    if not cfg then return nil end

    Label(parent, label, x, y + 16)

    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(w or 240)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    Skin(s, {0.12, 0.12, 0.14, 1})

    local eb = EditBox(parent, 50, x + (w or 240) + 10, y - 2)

    local function setValue(v)
        v = tonumber(v) or minV
        if v < minV then v = minV end
        if v > maxV then v = maxV end
        cfg[key] = v
        s:SetValue(v)
        eb:SetText(tostring(math.floor(v + 0.5)))
        Apply()
    end

    s:SetScript("OnValueChanged", function(_, v)
        if UI._suspend then return end
        v = math.floor((v or 0) + 0.5)
        cfg[key] = v
        eb:SetText(tostring(v))
        Apply()
    end)

    eb:SetScript("OnEnterPressed", function()
        local v = tonumber(eb:GetText())
        if v then setValue(v) end
        eb:ClearFocus()
    end)

    local bx = x + (w or 240) + 65
    local function mkBtn(txt, dx, offX)
        Button(parent, txt, 24, 20, bx + offX, y - 2, function()
            setValue((cfg[key] or 0) + dx)
        end)
    end

    mkBtn("-1",  -1, 0)
    mkBtn("+1",   1, 26)
    mkBtn("-10", -10, 56)
    mkBtn("+10",  10, 82)

    return { slider=s, edit=eb, key=key, min=minV, max=maxV }
end

-- 6. HOVEDVINDU
function UI:Build()
    if self.frame then return end
    if not CFG() then
        print("|cffff4444[RobUI]|r Pet settings not ready.")
        return
    end

    local f = CreateFrame("Frame", "RobUI_PetFrame_Settings", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(860, 800)
    f:SetPoint("CENTER")
    Skin(f, C_BG)
    f:Hide()

    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if IsShiftKeyDown() then f:StartMoving() end end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(30)
    Skin(header, C_PAN)

    local title = header:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("RobUI PetFrame Settings (Shift+Drag window)")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

    for _, region in ipairs({scroll:GetRegions()}) do
        if region:IsObjectType("Texture") then region:Hide() end
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(800, 1350)
    scroll:SetScrollChild(content)

    local x = 10
    local y = -10
    local W = 800
    local rowH = 50

    -- A. GENERAL
    y = CreateSection(content, "General", x, y, W)
    self.cbShown  = Check(content, "Enable Frame", x+10, y, nil, function(v) CFG().shown = v end)
    self.cbLocked = Check(content, "Lock Frame (Disable Drag)", x+200, y, nil, function(v) CFG().locked = v end)
    y = y - 40

    -- B. POSITION
    y = CreateSection(content, "Position (Shift + Left Drag pet frame)", x, y, W)
    self.rows = {}
    self.rows.x = SliderRow(content, "X Position", "x", -1500, 1500, 1, x+10, y, 240); y = y - rowH
    self.rows.y = SliderRow(content, "Y Position", "y", -1000, 1000, 1, x+10, y, 240); y = y - rowH

    -- C. SIZE
    y = CreateSection(content, "Size & Bars", x, y, W)
    self.rows.w      = SliderRow(content, "Total Width",   "w",      100, 1200, 1, x+10, y, 240); y = y - rowH
    self.rows.hpH    = SliderRow(content, "Health Height", "hpH",     10,  100, 1, x+10, y, 240); y = y - rowH
    self.rows.powerH = SliderRow(content, "Power Height",  "powerH",   5,   60, 1, x+10, y, 240); y = y - rowH
    self.rows.gap    = SliderRow(content, "Gap Spacing",   "gap",      0,   30, 1, x+10, y, 240); y = y - rowH

    -- D. SKINNING
    y = CreateSection(content, "Skinning (Texture & Tint)", x, y, W)

    Label(content, "Base Texture (used when tinting / fallback):", x+10, y+10)
    local dd = CreateFrame("Frame", "RobUI_Pet_BaseTexDD", content, "UIDropDownMenuTemplate")
    self.baseTexDD = dd
    dd:SetPoint("TOPLEFT", x, y-10)
    UIDropDownMenu_SetWidth(dd, 280)

    UIDropDownMenu_Initialize(dd, function()
        local cfg = CFG()
        for _,t in ipairs(TEXTURES) do
            UIDropDownMenu_AddButton({
                text = t.name,
                checked = (cfg.baseTexturePath == t.path),
                func = function()
                    cfg.baseTexturePath = t.path
                    cfg.useTexture = true
                    UIDropDownMenu_SetText(dd, t.name)
                    Apply()
                end
            })
        end
    end)

    self.cbUseTex   = Check(content, "Use Textures (RobUI TGAs)", x+320, y-14, nil, function(v) CFG().useTexture = v end)
    self.cbNoTint   = Check(content, "Force White (No Tint)", x+540, y-14, nil, function(v) CFG().noColorOverride = v end)
    y = y - 40

    self.cbTintBase = Check(content, "Tint ONLY when using Base Texture", x+320, y-6, nil, function(v) CFG().tintOnlyOnBase = v end)
    y = y - 40

    Label(content, "HP Tint (only used if tinting is allowed):", x+10, y+10)
    self.cbCustom = Check(content, "Use Custom HP Tint", x+10, y-10, nil, function(v) CFG().useCustomHP = v end)
    Button(content, "Pick HP Tint", 120, 22, x+250, y-10, function()
        local cfg = CFG()
        OpenColorPicker(cfg.hpR or 0.2, cfg.hpG or 0.8, cfg.hpB or 0.2, 1, function(r,g,b)
            cfg.hpR, cfg.hpG, cfg.hpB = r, g, b
            cfg.useCustomHP = true
            Apply(); UI.RefreshIfOpen()
        end)
    end)
    y = y - 55

    Label(content, "Power Color:", x+10, y+10)
    self.cbPowCustom = Check(content, "Use Custom Power Color", x+250, y-10, nil, function(v) CFG().useCustomPower = v end)
    Button(content, "Pick Power Color", 140, 22, x+460, y-10, function()
        local cfg = CFG()
        OpenColorPicker(cfg.powR or 0.2, cfg.powG or 0.4, cfg.powB or 1.0, 1, function(r,g,b)
            cfg.powR, cfg.powG, cfg.powB = r, g, b
            cfg.useCustomPower = true
            Apply(); UI.RefreshIfOpen()
        end)
    end)
    y = y - 60

    -- E. ELEMENTS
    y = CreateSection(content, "Elements & Overlays", x, y, W)
    self.cbName = Check(content, "Show Name", x+10, y, nil, function(v) CFG().showName = v end)
    self.cbHP   = Check(content, "Show HP Text", x+150, y, nil, function(v) CFG().showHPText = v end)
    self.cbPow  = Check(content, "Show Power Bar", x+300, y, nil, function(v) CFG().showPower = v end)
    self.cbPowT = Check(content, "Show Power Text", x+470, y, nil, function(v) CFG().showPowerText = v end)
    y = y - 35

    self.cbInc = Check(content, "Incoming Heal (Green)", x+10, y, nil, function(v) CFG().showIncomingHeals = v end)
    self.cbHA  = Check(content, "Heal Absorb (Red)", x+250, y, nil, function(v) CFG().showHealAbsorb = v end)
    self.cbAbs = Check(content, "Shields (Blue)", x+470, y, nil, function(v) CFG().showAbsorb = v end)
    y = y - 50

    -- F. TEXT SETTINGS
    y = CreateSection(content, "Text Settings (Size, Position, Color)", x, y, W)

    Label(content, "Name Text:", x+10, y+10)
    self.rows.nameSize = SliderRow(content, "Size", "nameSize", 8, 40, 1, x+10, y-10, 180)
    self.rows.nameOffX = SliderRow(content, "Offset X", "nameOffX", -200, 200, 1, x+10, y-60, 180)
    self.rows.nameOffY = SliderRow(content, "Offset Y", "nameOffY", -100, 100, 1, x+400, y-60, 180)
    Button(content, "Color", 60, 22, x+400, y-8, function()
        local cfg = CFG()
        OpenColorPicker(cfg.nameR or 1, cfg.nameG or 1, cfg.nameB or 1, 1, function(r,g,b)
            cfg.nameR, cfg.nameG, cfg.nameB = r, g, b
            Apply()
        end)
    end)
    y = y - 110

    Label(content, "HP Text:", x+10, y+10)
    self.rows.hpSize = SliderRow(content, "Size", "hpSize", 8, 40, 1, x+10, y-10, 180)
    self.rows.hpOffX = SliderRow(content, "Offset X", "hpOffX", -200, 200, 1, x+10, y-60, 180)
    self.rows.hpOffY = SliderRow(content, "Offset Y", "hpOffY", -100, 100, 1, x+400, y-60, 180)
    Button(content, "Color", 60, 22, x+400, y-8, function()
        local cfg = CFG()
        OpenColorPicker(cfg.hpTextR or 1, cfg.hpTextG or 1, cfg.hpTextB or 1, 1, function(r,g,b)
            cfg.hpTextR, cfg.hpTextG, cfg.hpTextB = r, g, b
            Apply()
        end)
    end)
    y = y - 110

    Label(content, "Power Text:", x+10, y+10)
    self.rows.powerSize = SliderRow(content, "Size", "powerSize", 8, 40, 1, x+10, y-10, 180)
    self.rows.powOffX   = SliderRow(content, "Offset X", "powOffX", -200, 200, 1, x+10, y-60, 180)
    self.rows.powOffY   = SliderRow(content, "Offset Y", "powOffY", -100, 100, 1, x+400, y-60, 180)
    Button(content, "Color", 60, 22, x+400, y-8, function()
        local cfg = CFG()
        OpenColorPicker(cfg.powTextR or 1, cfg.powTextG or 1, cfg.powTextB or 1, 1, function(r,g,b)
            cfg.powTextR, cfg.powTextG, cfg.powTextB = r, g, b
            Apply()
        end)
    end)

    UI.RefreshIfOpen()
end

function UI.RefreshIfOpen()
    if not UI.frame or not UI.frame:IsShown() then return end
    local cfg = CFG()
    if not cfg then return end

    UI._suspend = true

    if UI.cbShown  then UI.cbShown:SetChecked(cfg.shown) end
    if UI.cbLocked then UI.cbLocked:SetChecked(cfg.locked) end

    if UI.cbUseTex then UI.cbUseTex:SetChecked(cfg.useTexture) end
    if UI.cbNoTint then UI.cbNoTint:SetChecked(cfg.noColorOverride) end
    if UI.cbTintBase then UI.cbTintBase:SetChecked(cfg.tintOnlyOnBase) end

    if UI.cbCustom then UI.cbCustom:SetChecked(cfg.useCustomHP) end
    if UI.cbPowCustom then UI.cbPowCustom:SetChecked(cfg.useCustomPower) end

    if UI.cbName then UI.cbName:SetChecked(cfg.showName) end
    if UI.cbHP then UI.cbHP:SetChecked(cfg.showHPText) end
    if UI.cbPow then UI.cbPow:SetChecked(cfg.showPower) end
    if UI.cbPowT then UI.cbPowT:SetChecked(cfg.showPowerText) end

    if UI.cbInc then UI.cbInc:SetChecked(cfg.showIncomingHeals) end
    if UI.cbHA then UI.cbHA:SetChecked(cfg.showHealAbsorb) end
    if UI.cbAbs then UI.cbAbs:SetChecked(cfg.showAbsorb) end

    if UI.baseTexDD then
        UIDropDownMenu_SetText(UI.baseTexDD, NameForPath(cfg.baseTexturePath))
    end

    if UI.rows then
        for _,row in pairs(UI.rows) do
            local v = cfg[row.key]
            v = tonumber(v) or row.min
            if v < row.min then v = row.min end
            if v > row.max then v = row.max end
            row.slider:SetValue(v)
            row.edit:SetText(tostring(math.floor(v + 0.5)))
        end
    end

    UI._suspend = false
end

function UI.Toggle()
    UI:Build()
    if not UI.frame then return end
    if UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.frame:Show()
        UI.RefreshIfOpen()
    end
end
