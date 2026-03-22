local ADDON_NAME, ns = ...
local CB = ns.CB
local R = ns.R

local CreateFrame = CreateFrame
local UIParent = UIParent
local tonumber = tonumber
local floor = math.floor
local ipairs = ipairs

local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = UIDropDownMenu_SetText

local _sliderId = 0
local function NextSliderName()
    _sliderId = _sliderId + 1
    return "RobUICastbarSlider_" .. _sliderId
end

local function PrettyKey(k)
    if k == "player" then return "Player" end
    if k == "player_mini" then return "Player Mini" end
    if k == "player_extra" then return "Player Extra" end
    if k == "target" then return "Target" end
    if k == "target_mini" then return "Target Mini" end
    if k == "target_extra" then return "Target Extra" end
    return k
end

local SETTINGS_KEYS = {
    "player", "player_mini", "player_extra",
    "target", "target_mini", "target_extra",
}

-- Slider Ranges
local RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX = 80, 520
local RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX = 8, 160
local RANGE_V_THICK_MIN, RANGE_V_THICK_MAX = 2, 120
local RANGE_V_LEN_MIN, RANGE_V_LEN_MAX = 80, 900
local RANGE_TEXT_MIN, RANGE_TEXT_MAX = 6, 32
local RANGE_ICON_MIN, RANGE_ICON_MAX = 0, 128
local RANGE_BOX_W_MIN, RANGE_BOX_W_MAX = 20, 600
local RANGE_BOX_H_MIN, RANGE_BOX_H_MAX = 8, 120

-- UI Element Generators
local function CreateCheckbox(parent, label, onClick)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b.Text:SetText(label)
    b:SetScript("OnClick", function(self)
        if parent and parent._refreshing then return end
        if onClick then onClick(self, self:GetChecked() and true or false) end
    end)
    return b
end

-- MODERN FLAT BUTTON GENERATOR (WITH DYNAMIC COLORS)
local function CreateButton(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 140, h or 22)

    -- Black border background
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    -- Inner background (Default Dark grey)
    local bg = b:CreateTexture(nil, "ARTWORK")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bg = bg
    
    -- Store base colors so OnMouseUp restores correctly
    b.baseR, b.baseG, b.baseB = 0.15, 0.15, 0.15
    b.bg:SetColorTexture(b.baseR, b.baseG, b.baseB, 1)

    -- Highlight effect on hover
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 1, 1, 0.1)

    -- Button Text
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label)
    b.text = text

    -- Click Animation (darkens the current base color)
    b:SetScript("OnMouseDown", function(self)
        self.bg:SetColorTexture(self.baseR * 0.5, self.baseG * 0.5, self.baseB * 0.5, 1)
        self.text:SetPoint("CENTER", 1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.bg:SetColorTexture(self.baseR, self.baseG, self.baseB, 1)
        self.text:SetPoint("CENTER", 0, 0)
    end)
    
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)

    -- Method to dynamically update the button color
    function b:SetButtonColor(r, g, b)
        self.baseR, self.baseG, self.baseB = r, g, b
        self.bg:SetColorTexture(r, g, b, 1)
    end

    return b
end

local function CreateHeader(parent, text)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetText(text)
    return t
end

local function CreateSlider(parent, label, minV, maxV, step, onValueChanged)
    local name = NextSliderName()
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(240)

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
        if parent and parent._refreshing then return end
        if onValueChanged then onValueChanged(self, v) end
    end)

    s._labelFS = textFS
    return s
end

local function SetSliderRange(slider, minV, maxV)
    if not slider then return end
    slider:SetMinMaxValues(minV, maxV)
    local cur = tonumber(slider:GetValue()) or minV
    if cur < minV then cur = minV end
    if cur > maxV then cur = maxV end
    slider:SetValue(cur)
    slider:SetExactValueText(cur)
end

local function CreateGroupPanel(parent, titleText, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width, height)
    if type(CB.CreateSafeBorder) == "function" then
        CB:CreateSafeBorder(panel, 0, 1, {0.05, 0.05, 0.05, 0.7}, {0, 0, 0, 1})
    end
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 4, 4)
    title:SetText(titleText)
    
    return panel
end

function CB:OpenColorPickerForKey(selectedKey, colorField, onChange)
    local dbAll = self:GetDB()
    if not dbAll or not dbAll[selectedKey] then return end

    local sdb = dbAll[selectedKey]
    sdb[colorField] = sdb[colorField] or {1, 1, 1, 1}

    local r = tonumber(sdb[colorField][1]) or 1
    local g = tonumber(sdb[colorField][2]) or 1
    local b = tonumber(sdb[colorField][3]) or 1
    local a = tonumber(sdb[colorField][4]); if type(a) ~= "number" then a = 1 end

    local function Apply(cr, cg, cb, ca)
        sdb[colorField][1] = cr
        sdb[colorField][2] = cg
        sdb[colorField][3] = cb
        sdb[colorField][4] = ca
        self:UpdateBarLayout(selectedKey)
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
        info.opacityFunc = info.swatchFunc
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
end

function CB:EnsureSettingsPanel()
    if self.SettingsPanel and self.SettingsPanel.RefreshSection then
        return self.SettingsPanel
    end

    local f = CreateFrame("Frame", "RobUICastbarSettings", UIParent)
    f:SetSize(780, 680)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()
    f._refreshing = false
    f.testModeActive = false -- Tracker statusen på Test Mode

    self:CreateSafeBorder(f, 0, 1, {0.08, 0.08, 0.08, 0.98}, {0, 0, 0, 1})

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RobUI - Castbars")

    local closeBtn = CreateButton(f, "Close", 80, 22, function() f:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -16)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -46)
    desc:SetWidth(740)
    desc:SetJustifyH("LEFT")
    desc:SetText("Extra bars: Text sizing, position, and box sizing are independent of bar thickness/length. Vertical mode uses Width=Thickness and Height=Length.")

    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -80)
    sf:SetPoint("BOTTOMRIGHT", -36, 16)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(720, 850)
    content._refreshing = false
    sf:SetScrollChild(content)

    local selectedKey = "player"
    local function GetSelectedDB()
        local db = CB:GetDB()
        return db and db[selectedKey] or nil
    end

    ---------------------------------------------------------
    -- PANEL: General Settings (Top)
    ---------------------------------------------------------
    local pnlGeneral = CreateGroupPanel(content, "General & Selection", 720, 80)
    pnlGeneral:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -20)

    local globalEnabled = CreateCheckbox(pnlGeneral, "Enable Castbars (disables Blizzard castbar)", function(_, v)
        local db = CB:GetDB()
        if db then
            db.global.enabled = v and true or false
            CB:Refresh()
        end
    end)
    globalEnabled:SetPoint("TOPLEFT", 12, -12)

    local dropdown = CreateFrame("Frame", "RobUICastbarDrop", pnlGeneral, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", globalEnabled, "BOTTOMLEFT", -18, -4)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, 200) end

    f.testModeBtn = CreateButton(pnlGeneral, "Toggle Test Mode", 140, 22, function()
        CB:ToggleTestMode()
        f.testModeActive = not f.testModeActive
        if f.RefreshSection then f:RefreshSection() end
    end)
    f.testModeBtn:SetPoint("LEFT", dropdown, "RIGHT", 10, 2)

    local resetBtn = CreateButton(pnlGeneral, "Reset Selected Position", 160, 22, function()
        local db, defaults = CB:GetDB(), CB:GetDefaults()
        if not db or not db[selectedKey] then return end
        db[selectedKey].x = defaults[selectedKey] and defaults[selectedKey].x or 0
        db[selectedKey].y = defaults[selectedKey] and defaults[selectedKey].y or 0
        CB:UpdateBarLayout(selectedKey)
        if f.RefreshSection then f:RefreshSection() end
    end)
    resetBtn:SetPoint("LEFT", f.testModeBtn, "RIGHT", 10, 0)

    ---------------------------------------------------------
    -- LEFT COLUMN
    ---------------------------------------------------------
    -- PANEL: Bar Preferences
    local pnlBar = CreateGroupPanel(content, "Bar Preferences", 340, 160)
    pnlBar:SetPoint("TOPLEFT", pnlGeneral, "BOTTOMLEFT", 0, -30)

    f.cbEnabled = CreateCheckbox(pnlBar, "Enabled (this bar)", function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].enabled = v and true or false; CB:UpdateBarLayout(selectedKey) end
    end)
    f.cbEnabled:SetPoint("TOPLEFT", 12, -12)

    f.cbIcon = CreateCheckbox(pnlBar, "Show Icon", function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].showIcon = v and true or false; CB:UpdateBarLayout(selectedKey) end
    end)
    f.cbIcon:SetPoint("TOPLEFT", f.cbEnabled, "BOTTOMLEFT", 0, -4)

    f.cbLatency = CreateCheckbox(pnlBar, "Show Latency (Player only)", function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].showLatency = v and true or false; CB:UpdateBarLayout(selectedKey) end
    end)
    f.cbLatency:SetPoint("TOPLEFT", f.cbIcon, "BOTTOMLEFT", 0, -4)

    f.btnColor = CreateButton(pnlBar, "Pick Bar Color", 140, 22, function()
        CB:OpenColorPickerForKey(selectedKey, "color", function() if f.RefreshSection then f:RefreshSection() end end)
    end)
    f.btnColor:SetPoint("TOPLEFT", f.cbLatency, "BOTTOMLEFT", 4, -16)

    local btnShieldColor = CreateButton(pnlBar, "Pick Shield Color", 140, 22, function()
        CB:OpenColorPickerForKey(selectedKey, "shieldColor", function() if f.RefreshSection then f:RefreshSection() end end)
    end)
    btnShieldColor:SetPoint("LEFT", f.btnColor, "RIGHT", 10, 0)

    -- PANEL: Size
    local pnlSize = CreateGroupPanel(content, "Size Settings", 340, 180)
    pnlSize:SetPoint("TOPLEFT", pnlBar, "BOTTOMLEFT", 0, -30)

    f.slW = CreateSlider(pnlSize, "Width", RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].width = floor(tonumber(v) or 200); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slW:SetPoint("TOPLEFT", 16, -26)

    f.slH = CreateSlider(pnlSize, "Height", RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].height = floor(tonumber(v) or 14); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slH:SetPoint("TOPLEFT", f.slW, "BOTTOMLEFT", 0, -28)

    f.slIcon = CreateSlider(pnlSize, "Icon Size (0=Auto)", RANGE_ICON_MIN, RANGE_ICON_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].iconSize = floor(tonumber(v) or 0); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slIcon:SetPoint("TOPLEFT", f.slH, "BOTTOMLEFT", 0, -28)

    ---------------------------------------------------------
    -- RIGHT COLUMN
    ---------------------------------------------------------
    -- PANEL: Text
    local pnlText = CreateGroupPanel(content, "Standard Text Settings", 360, 130)
    pnlText:SetPoint("TOPLEFT", pnlGeneral, "BOTTOMLEFT", 360, -30)

    f.slTextSize = CreateSlider(pnlText, "Cast Text Size", RANGE_TEXT_MIN, RANGE_TEXT_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].textSize = floor(tonumber(v) or 11); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTextSize:SetPoint("TOPLEFT", 16, -26)

    f.slTimeSize = CreateSlider(pnlText, "Time Text Size", RANGE_TEXT_MIN, RANGE_TEXT_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].timeSize = floor(tonumber(v) or 11); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTimeSize:SetPoint("TOPLEFT", f.slTextSize, "BOTTOMLEFT", 0, -28)

    -- PANEL: Extra Bars
    local pnlExtra = CreateGroupPanel(content, "Extra Bars (Positioning)", 360, 290)
    pnlExtra:SetPoint("TOPLEFT", pnlText, "BOTTOMLEFT", 0, -30)
    f.pnlExtra = pnlExtra

    f.cbVertical = CreateCheckbox(pnlExtra, "Vertical Mode", function(_, v)
        if not CB:IsExtraKey(selectedKey) then
            if f.cbVertical then f.cbVertical:SetChecked(false) end; return
        end
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].vertical = v and true or false; CB:UpdateBarLayout(selectedKey); if f.RefreshSection then f:RefreshSection() end end
    end)
    f.cbVertical:SetPoint("TOPLEFT", 12, -12)

    f.slTextX = CreateSlider(pnlExtra, "Cast Text X Offset", -300, 300, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].textX = floor(tonumber(v) or 0); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTextX:SetPoint("TOPLEFT", 16, -60)

    f.slTextY = CreateSlider(pnlExtra, "Cast Text Y Offset", -300, 300, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].textY = floor(tonumber(v) or 0); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTextY:SetPoint("TOPLEFT", f.slTextX, "BOTTOMLEFT", 0, -28)

    f.slTimeX = CreateSlider(pnlExtra, "Time Text X Offset", -300, 300, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].timeX = floor(tonumber(v) or 0); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTimeX:SetPoint("TOPLEFT", f.slTextY, "BOTTOMLEFT", 0, -28)

    f.slTimeY = CreateSlider(pnlExtra, "Time Text Y Offset", -300, 300, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].timeY = floor(tonumber(v) or 0); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTimeY:SetPoint("TOPLEFT", f.slTimeX, "BOTTOMLEFT", 0, -28)

    -- PANEL: Extra Text Boxes
    local pnlExtraBox = CreateGroupPanel(content, "Extra Text Boxes (Dimensions)", 360, 240)
    pnlExtraBox:SetPoint("TOPLEFT", pnlExtra, "BOTTOMLEFT", 0, -30)
    f.pnlExtraBox = pnlExtraBox

    f.slTextBoxW = CreateSlider(pnlExtraBox, "Cast Text Box Width", RANGE_BOX_W_MIN, RANGE_BOX_W_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].textBoxW = floor(tonumber(v) or 160); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTextBoxW:SetPoint("TOPLEFT", 16, -26)

    f.slTextBoxH = CreateSlider(pnlExtraBox, "Cast Text Box Height", RANGE_BOX_H_MIN, RANGE_BOX_H_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].textBoxH = floor(tonumber(v) or 18); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTextBoxH:SetPoint("TOPLEFT", f.slTextBoxW, "BOTTOMLEFT", 0, -28)

    f.slTimeBoxW = CreateSlider(pnlExtraBox, "Time Text Box Width", RANGE_BOX_W_MIN, RANGE_BOX_W_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].timeBoxW = floor(tonumber(v) or 60); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTimeBoxW:SetPoint("TOPLEFT", f.slTextBoxH, "BOTTOMLEFT", 0, -28)

    f.slTimeBoxH = CreateSlider(pnlExtraBox, "Time Text Box Height", RANGE_BOX_H_MIN, RANGE_BOX_H_MAX, 1, function(_, v)
        local db = CB:GetDB()
        if db and db[selectedKey] then db[selectedKey].timeBoxH = floor(tonumber(v) or 18); CB:UpdateBarLayout(selectedKey) end
    end)
    f.slTimeBoxH:SetPoint("TOPLEFT", f.slTimeBoxW, "BOTTOMLEFT", 0, -28)

    ---------------------------------------------------------
    -- LOGIC
    ---------------------------------------------------------
    local function UpdateSizeSliderLabelsAndRanges(isExtra, isVertical)
        if f.slW and f.slW._labelFS then f.slW._labelFS:SetText((isExtra and isVertical) and "Thickness (Width)" or "Width") end
        if f.slH and f.slH._labelFS then f.slH._labelFS:SetText((isExtra and isVertical) and "Length (Height)" or "Height") end

        if isExtra and isVertical then
            SetSliderRange(f.slW, RANGE_V_THICK_MIN, RANGE_V_THICK_MAX)
            SetSliderRange(f.slH, RANGE_V_LEN_MIN, RANGE_V_LEN_MAX)
        else
            SetSliderRange(f.slW, RANGE_H_WIDTH_MIN, RANGE_H_WIDTH_MAX)
            SetSliderRange(f.slH, RANGE_H_HEIGHT_MIN, RANGE_H_HEIGHT_MAX)
        end
    end

    local function RefreshAllControls()
        local db = CB:GetDB()
        if not db then return end

        f._refreshing = true
        content._refreshing = true

        globalEnabled:SetChecked(db.global.enabled and true or false)

        -- Oppdater farge på Test Mode-knappen basert på status
        if f.testModeActive then
            f.testModeBtn:SetButtonColor(0.6, 0.1, 0.1) -- Mørk rød farge når aktiv
        else
            f.testModeBtn:SetButtonColor(0.15, 0.15, 0.15) -- Standard mørkegrå når av
        end

        local sdb = GetSelectedDB()
        if not sdb then
            content._refreshing = false
            f._refreshing = false
            return
        end

        local isPlayer = (selectedKey:find("player") ~= nil)
        if f.cbLatency then
            f.cbLatency:SetEnabled(isPlayer and true or false)
            f.cbLatency:SetChecked((isPlayer and sdb.showLatency) and true or false)
        end

        if f.cbEnabled then f.cbEnabled:SetChecked(sdb.enabled and true or false) end
        if f.cbIcon then f.cbIcon:SetChecked(sdb.showIcon and true or false) end

        local isExtra = CB:IsExtraKey(selectedKey)
        local isVertical = (isExtra and sdb.vertical) and true or false

        if isExtra then
            f.pnlExtra:Show()
            f.pnlExtraBox:Show()
            if f.cbVertical then f.cbVertical:SetChecked(isVertical and true or false) end
        else
            f.pnlExtra:Hide()
            f.pnlExtraBox:Hide()
        end

        UpdateSizeSliderLabelsAndRanges(isExtra, isVertical)

        local function SyncSlider(slider, val, fallback)
            if slider then slider:SetValue(tonumber(val) or fallback); slider:SetExactValueText(tonumber(val) or fallback) end
        end

        SyncSlider(f.slW, sdb.width, 200)
        SyncSlider(f.slH, sdb.height, 14)
        SyncSlider(f.slIcon, sdb.iconSize, 0)
        SyncSlider(f.slTextSize, sdb.textSize, 11)
        SyncSlider(f.slTimeSize, sdb.timeSize, 11)

        if isExtra then
            SyncSlider(f.slTextX, sdb.textX, 0)
            SyncSlider(f.slTextY, sdb.textY, 0)
            SyncSlider(f.slTimeX, sdb.timeX, 0)
            SyncSlider(f.slTimeY, sdb.timeY, 0)
            SyncSlider(f.slTextBoxW, sdb.textBoxW, 160)
            SyncSlider(f.slTextBoxH, sdb.textBoxH, 18)
            SyncSlider(f.slTimeBoxW, sdb.timeBoxW, 60)
            SyncSlider(f.slTimeBoxH, sdb.timeBoxH, 18)
        end

        content._refreshing = false
        f._refreshing = false
    end

    local function OnSelectKey(key)
        selectedKey = key
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dropdown, "Edit: " .. PrettyKey(key)) end
        RefreshAllControls()
    end

    local function InitDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.isTitle = true
        info.text = "Select Castbar"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        for _, k in ipairs(SETTINGS_KEYS) do
            local i = UIDropDownMenu_CreateInfo()
            i.text = PrettyKey(k)
            i.notCheckable = true
            i.func = function() OnSelectKey(k) end
            UIDropDownMenu_AddButton(i, level)
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dropdown, InitDropdown)
    end

    function f:RefreshSection()
        RefreshAllControls()
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dropdown, "Edit: " .. PrettyKey(selectedKey)) end
    end

    f:SetScript("OnShow", function() OnSelectKey(selectedKey) end)

    self.SettingsPanel = f
    return f
end

function CB:RegisterWithRobUIMenu()
    local panel = self:EnsureSettingsPanel()
    self.SettingsPanel = panel

    if type(R.RegisterModulePanel) == "function" then
        pcall(R.RegisterModulePanel, R, "castbars", panel)
        return
    end
    if R.MasterConfig and type(R.MasterConfig.RegisterTab) == "function" then
        pcall(R.MasterConfig.RegisterTab, R.MasterConfig, "castbars", panel)
        return
    end
    if R.MasterConfig and type(R.MasterConfig.AddPanel) == "function" then
        pcall(R.MasterConfig.AddPanel, R.MasterConfig, "castbars", panel)
        return
    end
end

function CB:OpenSettings()
    local panel = self:EnsureSettingsPanel()

    if R.MasterConfig and type(R.MasterConfig.Toggle) == "function" then
        if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
            R.MasterConfig:Toggle()
        end
        if type(R.MasterConfig.SelectTab) == "function" then
            pcall(R.MasterConfig.SelectTab, R.MasterConfig, "castbars")
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