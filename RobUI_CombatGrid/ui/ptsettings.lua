-- ============================================================================
-- ptsettings.lua
-- SHARED SETTINGS AND HELPER FUNCTIONS (ctDB)
-- + Settings UI
-- + GridCore plugin attach/detach
-- + ROBUI PROFILE BINDING (FIX) + spec/profile resiliency
-- ============================================================================
local AddonName, ns = ...

ns.Player = ns.Player or {}
ns.Target = ns.Target or {}

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown

-- ------------------------------------------------------------
-- BUILT-IN SKINS
-- ------------------------------------------------------------
ns.SKINS = ns.SKINS or {
    [1] = { name = "Classic",      path = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
    [2] = { name = "Flat Solid",   path = "Interface\\Buttons\\WHITE8x8" },
    [3] = { name = "Raid Frame",   path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    [4] = { name = "Skills Bar",   path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    [5] = { name = "Trainer Bar",  path = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-StatusBar" },
}

-- ------------------------------------------------------------
-- DEFAULT DATABASE SHAPE
-- ------------------------------------------------------------
local defaultDB = {
    unlocked  = false,
    linkSizes = false,

    player = {
        point = "CENTER", relPoint = "CENTER", x = -280, y = 120,
        w = 340, hpH = 28, skinIndex = 1,
        useClassColor = true, useCustomHP = false, hpR = 0.2, hpG = 0.8, hpB = 0.2,
        isVertical = false, showHP = true,
        textX = 0, textY = 0, textR = 1, textG = 1, textB = 1,

        showIncomingHeals = true,
        showHealAbsorb    = true,
        showAbsorb        = true,

        scale = 1,
    },

    target = {
        point = "CENTER", relPoint = "CENTER", x = 280, y = 120,
        w = 340, hpH = 28, skinIndex = 1,
        useClassColor = true, useCustomHP = false, hpR = 0.8, hpG = 0.2, hpB = 0.2,
        isVertical = false, showHP = true, showName = true,
        hpTextX = 0, hpTextY = 0, hpTextR = 1, hpTextG = 1, hpTextB = 1,
        nameTextX = 0, nameTextY = 0, nameTextR = 1, nameTextG = 1, nameTextB = 1,

        showIncomingHeals = true,
        showHealAbsorb    = true,
        showAbsorb        = true,

        scale = 1,
    },
}

-- ------------------------------------------------------------
-- Copy helper (shallow copy for nested defaults)
-- ------------------------------------------------------------
local function CopyTableFallback(src)
    if type(_G.CopyTable) == "function" then
        return _G.CopyTable(src)
    end
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do inner[k2] = v2 end
            t[k] = inner
        else
            t[k] = v
        end
    end
    return t
end

local function EnsureDefaults(db, defaults)
    if type(db) ~= "table" then return end
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = (type(v) == "table") and CopyTableFallback(v) or v
        elseif type(v) == "table" and type(db[k]) == "table" then
            for k2, v2 in pairs(v) do
                if db[k][k2] == nil then
                    db[k][k2] = (type(v2) == "table") and CopyTableFallback(v2) or v2
                end
            end
        end
    end
end

-- ------------------------------------------------------------
-- ROBUI PROFILE DB RESOLUTION (CORE FIX)
-- Returns a stable reference to the profile-backed table.
-- Preference order:
--  1) RobUI global R.Database.profile
--  2) Robui.Database.profile
--  3) fallback _G.ctDB
-- The table we use is profile["combatgrid"]["unitframes"] (created if missing).
-- ------------------------------------------------------------
local function ResolveRobUIProfileRoot()
    local R = _G.R
    if R and type(R) == "table" and R.Database and type(R.Database) == "table" and R.Database.profile and type(R.Database.profile) == "table" then
        return R.Database.profile
    end

    local Robui = _G.Robui
    if Robui and type(Robui) == "table" and Robui.Database and type(Robui.Database) == "table" and Robui.Database.profile and type(Robui.Database.profile) == "table" then
        return Robui.Database.profile
    end

    return nil
end

function ns.GetCTDB()
    -- already resolved & stable
    if type(_G.ctDB) == "table" and _G.ctDB.__robui_ctdb_bound then
        return _G.ctDB
    end

    local profile = ResolveRobUIProfileRoot()
    if profile then
        profile.combatgrid = profile.combatgrid or {}
        profile.combatgrid.unitframes = profile.combatgrid.unitframes or {}

        local pdb = profile.combatgrid.unitframes
        pdb.__robui_ctdb_bound = true

        -- migrate whatever we had in _G.ctDB into profile table ONCE
        if type(_G.ctDB) == "table" and _G.ctDB ~= pdb then
            for k, v in pairs(_G.ctDB) do
                if k ~= "__robui_ctdb_bound" and pdb[k] == nil then
                    if type(v) == "table" then
                        pdb[k] = CopyTableFallback(v)
                    else
                        pdb[k] = v
                    end
                end
            end
        end

        -- enforce defaults
        EnsureDefaults(pdb, defaultDB)

        -- bind global ref to profile ref (CRITICAL)
        _G.ctDB = pdb
        ctDB = pdb
        return pdb
    end

    -- fallback (no RobUI profile available)
    if type(_G.ctDB) ~= "table" then _G.ctDB = {} end
    EnsureDefaults(_G.ctDB, defaultDB)
    _G.ctDB.__robui_ctdb_bound = true
    ctDB = _G.ctDB
    return _G.ctDB
end

-- ------------------------------------------------------------
-- SECRET SAFE helpers etc (kept from your file)
-- ------------------------------------------------------------
function ns.issecret(v)
    if type(_G.issecretvalue) == "function" then
        local ok, r = pcall(_G.issecretvalue, v)
        if ok and r then return true end
    end
    return false
end

function ns.CreateSafeSliderLabels(slider, lowText, highText, valueText)
    if not slider or slider._robuiLabels then return end
    slider._robuiLabels = true

    slider._low = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider._low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    slider._low:SetText(lowText or "")

    slider._high = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider._high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    slider._high:SetText(highText or "")

    slider._text = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider._text:SetPoint("BOTTOM", slider, "TOP", 0, 2)
    slider._text:SetText(valueText or "")
end

function ns.SafeSetSliderText(slider, txt)
    if not slider then return end
    if slider._text and slider._text.SetText then
        slider._text:SetText(txt or "")
    end
end

function ns.SafeSetText(self, key, fs, txt)
    if not fs or not fs.SetText then return end
    if txt == nil then txt = "" end

    if ns.issecret(txt) then
        self[key] = nil
        pcall(fs.SetText, fs, txt)
        return
    end

    local prev = self[key]
    if prev ~= nil and ns.issecret(prev) then
        self[key] = nil
        pcall(fs.SetText, fs, txt)
        return
    end

    if prev ~= txt then
        self[key] = txt
        pcall(fs.SetText, fs, txt)
    end
end

function ns.Clamp01(v)
    local ok, res = pcall(function() return tonumber(v) or 0 end)
    if not ok then return 0 end
    if res < 0 then return 0 end
    if res > 1 then return 1 end
    return res
end

function ns.GetClassColorRGB(unit)
    local _, class = UnitClass(unit or "player")
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

function ns.EnsureBackdrop(f, alpha)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.25)
    f:SetBackdropBorderColor(0,0,0,1)
end

function ns.GetFontPath(fs)
    if not fs or not fs.GetFont then return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
    local path = select(1, fs:GetFont())
    return path or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function ns.AbbrevAny(n)
    if n == nil then return nil end
    if _G.AbbreviateLargeNumbers then
        local ok, s = pcall(_G.AbbreviateLargeNumbers, n)
        if ok and type(s) == "string" then return s end
    end
    if type(n) == "number" and not ns.issecret(n) then
        if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
        if n >= 1000 then return string.format("%.1fk", n / 1000) end
        return tostring(math.floor(n + 0.5))
    end
    local ok, s = pcall(string.format, "%s", n)
    if ok and type(s) == "string" then return s end
    return nil
end

function ns.FormatCurMax(cur, maxv)
    local a = ns.AbbrevAny(cur)
    local b = ns.AbbrevAny(maxv)
    if a == nil or b == nil then return nil end
    return a .. " / " .. b
end

function ns.ApplyHPStyle(hpBar, db, unit)
    local skinIdx = db.skinIndex or 1
    local texPath = ns.SKINS[skinIdx] and ns.SKINS[skinIdx].path or ns.SKINS[1].path
    pcall(hpBar.SetStatusBarTexture, hpBar, texPath)

    local r,g,b = 0.2, 0.8, 0.2
    if db.useCustomHP then
        r,g,b = ns.Clamp01(db.hpR), ns.Clamp01(db.hpG), ns.Clamp01(db.hpB)
    elseif db.useClassColor then
        r,g,b = ns.GetClassColorRGB(unit)
    end

    pcall(hpBar.SetStatusBarColor, hpBar, r,g,b)
    local tex = hpBar:GetStatusBarTexture()
    if tex and tex.SetVertexColor then tex:SetVertexColor(r,g,b) end
end

function ns.SafeSetMinMaxAndValue(bar, maxv, curv)
    if not bar then return end
    pcall(bar.SetMinMaxValues, bar, 0, maxv or 1)
    pcall(bar.SetValue, bar, curv or 0)
end

function ns.DisableMouseOn(frame)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
    if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
end

-- Heal prediction shared
local healCalc = nil
function ns.EnsureHealCalc()
    if healCalc then return healCalc end
    if type(CreateUnitHealPredictionCalculator) == "function" then
        healCalc = CreateUnitHealPredictionCalculator()
    end
    return healCalc
end

function ns.ShouldShowNumber(v)
    if v == nil then return false end
    if ns.issecret(v) then return true end
    if type(v) == "number" then return v > 0 end
    return false
end

-- ------------------------------------------------------------
-- SETTINGS UI (unchanged layout, but now uses ns.GetCTDB())
-- ------------------------------------------------------------
local function OpenColorPicker(db, rKey, gKey, bKey, swatchTex, callback)
    local function ColorCallback(previousValues)
        local r, g, b
        if previousValues then
            r, g, b = previousValues.r, previousValues.g, previousValues.b
        else
            r, g, b = ColorPickerFrame:GetColorRGB()
        end
        db[rKey], db[gKey], db[bKey] = r, g, b
        if swatchTex then swatchTex:SetColorTexture(r, g, b) end
        if callback and not InCombatLockdown() then callback() end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = ColorCallback,
            cancelFunc = ColorCallback,
            r = db[rKey], g = db[gKey], b = db[bKey],
        })
    else
        ColorPickerFrame.func = ColorCallback
        ColorPickerFrame.cancelFunc = ColorCallback
        ColorPickerFrame:SetColorRGB(db[rKey], db[gKey], db[bKey])
        ColorPickerFrame.previousValues = {r = db[rKey], g = db[gKey], b = db[bKey]}
        ColorPickerFrame:Show()
    end
end

local function CreateColorSwatch(parent, labelText, db, rKey, gKey, bKey, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(165, 20)

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(labelText)

    local btn = CreateFrame("Button", nil, container)
    btn:SetSize(18, 18)
    btn:SetPoint("LEFT", label, "RIGHT", 10, 0)

    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetColorTexture(db[rKey], db[gKey], db[bKey])
    tex:SetAllPoints()

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(1, 1, 1)
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)

    btn:SetScript("OnClick", function()
        OpenColorPicker(db, rKey, gKey, bKey, tex, callback)
    end)

    return container, btn
end

local _linkGuard = false

local function CreateColumn(parent, titleText, dbKey, xOffset, yTop)
    local ctDB = ns.GetCTDB()
    local db = ctDB[dbKey]
    local isTarget = (dbKey == "target")

    local colTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yTop)
    colTitle:SetText(titleText)

    local function refresh()
        if ns.Player and ns.Player.ApplyLayout then ns.Player:ApplyLayout() end
        if ns.Target and ns.Target.ApplyLayout then ns.Target:ApplyLayout() end
        if ns.Player and ns.Player.UpdateValues then ns.Player:UpdateValues() end
        if ns.Target and ns.Target.UpdateValues then ns.Target:UpdateValues() end
        if ns.Target and ns.Target.ApplySecureVisibility then ns.Target:ApplySecureVisibility() end
        if ns.Player and ns.Player.UpdateLockState then ns.Player:UpdateLockState() end
        if ns.Target and ns.Target.UpdateLockState then ns.Target:UpdateLockState() end
    end

    parent.__wSliders = parent.__wSliders or {}
    parent.__hSliders = parent.__hSliders or {}

    local function SetSizeBoth(which, val)
        if _linkGuard then return end
        if not ctDB.linkSizes then return end
        _linkGuard = true

        if which == "w" then
            ctDB.player.w = val
            ctDB.target.w = val
            if parent.__wSliders.player then parent.__wSliders.player:SetValue(val) end
            if parent.__wSliders.target then parent.__wSliders.target:SetValue(val) end
        elseif which == "h" then
            ctDB.player.hpH = val
            ctDB.target.hpH = val
            if parent.__hSliders.player then parent.__hSliders.player:SetValue(val) end
            if parent.__hSliders.target then parent.__hSliders.target:SetValue(val) end
        end

        _linkGuard = false
        if not InCombatLockdown() then refresh() end
    end

    local function NewSlider(parentFrame, minV, maxV, step, initial, label)
        local s = CreateFrame("Slider", nil, parentFrame, "OptionsSliderTemplate")
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:SetValue(initial)

        ns.CreateSafeSliderLabels(s, tostring(minV), tostring(maxV), label or "")
        return s
    end

    -- Width
    local wSlider = NewSlider(parent, 100, 600, 1, db.w, "Length")
    wSlider:SetPoint("TOPLEFT", colTitle, "BOTTOMLEFT", 0, -18)
    ns.SafeSetSliderText(wSlider, "Length")
    parent.__wSliders[dbKey] = wSlider
    wSlider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(tonumber(val) or db.w or 100)
        db.w = val
        if ctDB.linkSizes then SetSizeBoth("w", val) else if not InCombatLockdown() then refresh() end end
    end)

    -- Height
    local hSlider = NewSlider(parent, 10, 100, 1, db.hpH, "Thickness")
    hSlider:SetPoint("TOPLEFT", wSlider, "BOTTOMLEFT", 0, -28)
    ns.SafeSetSliderText(hSlider, "Thickness")
    parent.__hSliders[dbKey] = hSlider
    hSlider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(tonumber(val) or db.hpH or 10)
        db.hpH = val
        if ctDB.linkSizes then SetSizeBoth("h", val) else if not InCombatLockdown() then refresh() end end
    end)

    -- Skin
    local skinSlider = NewSlider(parent, 1, #ns.SKINS, 1, db.skinIndex, "")
    skinSlider:SetPoint("TOPLEFT", hSlider, "BOTTOMLEFT", 0, -28)
    ns.SafeSetSliderText(skinSlider, "Skin: " .. (ns.SKINS[db.skinIndex] and ns.SKINS[db.skinIndex].name or ns.SKINS[1].name))
    skinSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(tonumber(val) or 1)
        db.skinIndex = val
        ns.SafeSetSliderText(self, "Skin: " .. (ns.SKINS[val] and ns.SKINS[val].name or ns.SKINS[1].name))
        if not InCombatLockdown() then refresh() end
    end)

    -- Bar Colors
    local classColorBtn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    classColorBtn:SetPoint("TOPLEFT", skinSlider, "BOTTOMLEFT", -15, -14)
    classColorBtn.text = classColorBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    classColorBtn.text:SetPoint("LEFT", classColorBtn, "RIGHT", 2, 1)
    classColorBtn.text:SetText("Use Class Colors")
    classColorBtn:SetChecked(db.useClassColor)

    local barColorCont = CreateColorSwatch(parent, "Custom Bar Color", db, "hpR", "hpG", "hpB", refresh)
    barColorCont:SetPoint("TOPLEFT", classColorBtn, "BOTTOMLEFT", 6, -6)

    local function UpdateBarColors()
        db.useClassColor = classColorBtn:GetChecked() and true or false
        if db.useClassColor then
            db.useCustomHP = false
            barColorCont:Hide()
        else
            db.useCustomHP = true
            barColorCont:Show()
        end
        if not InCombatLockdown() then refresh() end
    end
    classColorBtn:SetScript("OnClick", UpdateBarColors)
    UpdateBarColors()

    -- Vertical Layout
    local verticalBtn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    verticalBtn:SetPoint("TOPLEFT", barColorCont, "BOTTOMLEFT", -6, -10)
    verticalBtn.text = verticalBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    verticalBtn.text:SetPoint("LEFT", verticalBtn, "RIGHT", 2, 1)
    verticalBtn.text:SetText("Vertical Layout")
    verticalBtn:SetChecked(db.isVertical)
    verticalBtn:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        db.isVertical = v

        if ctDB.linkSizes then
            ctDB.player.isVertical = v
            ctDB.target.isVertical = v
        end
        if not InCombatLockdown() then refresh() end
    end)

    -- Reset Button
    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 22)
    resetBtn:SetPoint("TOPLEFT", verticalBtn, "BOTTOMLEFT", 18, -10)
    resetBtn:SetText("Reset "..titleText)
    resetBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local def = defaultDB[dbKey]
        if not def then return end

        local copied = CopyTableFallback(def)
        for k, v in pairs(copied) do db[k] = v end

        if parent.__wSliders[dbKey] then parent.__wSliders[dbKey]:SetValue(db.w) end
        if parent.__hSliders[dbKey] then parent.__hSliders[dbKey]:SetValue(db.hpH) end
        verticalBtn:SetChecked(db.isVertical)

        if ctDB.linkSizes then
            ctDB.target.w = ctDB.player.w
            ctDB.target.hpH = ctDB.player.hpH
            ctDB.target.isVertical = ctDB.player.isVertical
            if parent.__wSliders.target then parent.__wSliders.target:SetValue(ctDB.target.w) end
            if parent.__hSliders.target then parent.__hSliders.target:SetValue(ctDB.target.hpH) end
        end

        refresh()
    end)

    -- -----------------------------
    -- GRID CONTROLS
    -- -----------------------------
    local gridHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    gridHeader:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -12, -14)
    gridHeader:SetText("--- Grid ---")

    local addGridBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addGridBtn:SetSize(150, 22)
    addGridBtn:SetPoint("TOPLEFT", gridHeader, "BOTTOMLEFT", 12, -8)
    addGridBtn:SetText("Add to Grid")

    local remGridBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    remGridBtn:SetSize(150, 22)
    remGridBtn:SetPoint("TOPLEFT", addGridBtn, "BOTTOMLEFT", 0, -6)
    remGridBtn:SetText("Remove from Grid")

    local function PluginId()
        return (dbKey == "player") and "ct_player" or "ct_target"
    end

    addGridBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not (ns and ns.GridCore and type(ns.GridCore.AttachPlugin) == "function") then return end

        -- Ensure DB is profile-backed right now
        ns.GetCTDB()

        -- Ensure plugin exists (register happens inside modules)
        if dbKey == "player" and ns.Player and ns.Player.Initialize then ns.Player:Initialize() end
        if dbKey == "target" and ns.Target and ns.Target.Initialize then ns.Target:Initialize() end

        ns.GridCore:SetEditMode(true)
        ns.GridCore:AttachPlugin(PluginId())

        if ns.Player and ns.Player.UpdateLockState then ns.Player:UpdateLockState() end
        if ns.Target and ns.Target.UpdateLockState then ns.Target:UpdateLockState() end
        if ns.Target and ns.Target.ApplySecureVisibility then ns.Target:ApplySecureVisibility() end
    end)

    remGridBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not (ns and ns.GridCore and type(ns.GridCore.DetachPlugin) == "function") then return end
        ns.GridCore:DetachPlugin(PluginId())
        if ns.Player and ns.Player.UpdateLockState then ns.Player:UpdateLockState() end
        if ns.Target and ns.Target.UpdateLockState then ns.Target:UpdateLockState() end
        if ns.Target and ns.Target.ApplySecureVisibility then ns.Target:ApplySecureVisibility() end
    end)

    -- ------------------------------------------------------------
    -- Overlays
    -- ------------------------------------------------------------
    local ovHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ovHeader:SetPoint("TOPLEFT", remGridBtn, "BOTTOMLEFT", -12, -16)
    ovHeader:SetText("--- Overlays ---")

    local function NewCheck(parentFrame, label, anchorTo, x, y, initial)
        local b = CreateFrame("CheckButton", nil, parentFrame, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or 0)
        b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "RIGHT", 2, 1)
        b.text:SetText(label)
        b:SetChecked(initial and true or false)
        return b
    end

    local incBtn = NewCheck(parent, "Incoming Heals", ovHeader, -6, 0, db.showIncomingHeals)
    incBtn:SetScript("OnClick", function(self)
        db.showIncomingHeals = self:GetChecked() and true or false
        if not InCombatLockdown() then refresh() end
    end)

    local habBtn = NewCheck(parent, "Heal Absorb", incBtn, 0, 0, db.showHealAbsorb)
    habBtn:SetScript("OnClick", function(self)
        db.showHealAbsorb = self:GetChecked() and true or false
        if not InCombatLockdown() then refresh() end
    end)

    local absBtn = NewCheck(parent, "Shields (Absorb)", habBtn, 0, 0, db.showAbsorb)
    absBtn:SetScript("OnClick", function(self)
        db.showAbsorb = self:GetChecked() and true or false
        if not InCombatLockdown() then refresh() end
    end)

    -- HP Text
    local hpHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hpHeader:SetPoint("TOPLEFT", absBtn, "BOTTOMLEFT", 6, -10)
    hpHeader:SetText("--- HP Text ---")

    local showHPBtn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    showHPBtn:SetPoint("TOPLEFT", hpHeader, "BOTTOMLEFT", -6, 0)
    showHPBtn.text = showHPBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    showHPBtn.text:SetPoint("LEFT", showHPBtn, "RIGHT", 2, 1)
    showHPBtn.text:SetText("Show HP Text")
    showHPBtn:SetChecked(db.showHP)
    showHPBtn:SetScript("OnClick", function(self)
        db.showHP = self:GetChecked() and true or false
        if not InCombatLockdown() then refresh() end
    end)

    local hpX = dbKey == "player" and "textX" or "hpTextX"
    local hpY = dbKey == "player" and "textY" or "hpTextY"
    local hpR = dbKey == "player" and "textR" or "hpTextR"
    local hpG = dbKey == "player" and "textG" or "hpTextG"
    local hpB = dbKey == "player" and "textB" or "hpTextB"

    local function NewSlider(parentFrame, minV, maxV, step, initial, label)
        local s = CreateFrame("Slider", nil, parentFrame, "OptionsSliderTemplate")
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:SetValue(initial)
        ns.CreateSafeSliderLabels(s, tostring(minV), tostring(maxV), label or "")
        return s
    end

    local hpXSlider = NewSlider(parent, -100, 100, 1, db[hpX], "X Offset")
    hpXSlider:SetPoint("TOPLEFT", showHPBtn, "BOTTOMLEFT", 6, -15)
    ns.SafeSetSliderText(hpXSlider, "X Offset")
    hpXSlider:SetScript("OnValueChanged", function(_, val)
        db[hpX] = val
        if not InCombatLockdown() then refresh() end
    end)

    local hpYSlider = NewSlider(parent, -100, 100, 1, db[hpY], "Y Offset")
    hpYSlider:SetPoint("TOPLEFT", hpXSlider, "BOTTOMLEFT", 0, -25)
    ns.SafeSetSliderText(hpYSlider, "Y Offset")
    hpYSlider:SetScript("OnValueChanged", function(_, val)
        db[hpY] = val
        if not InCombatLockdown() then refresh() end
    end)

    local hpColorCont = CreateColorSwatch(parent, "HP Text Color", db, hpR, hpG, hpB, refresh)
    hpColorCont:SetPoint("TOPLEFT", hpYSlider, "BOTTOMLEFT", 0, -10)

    if isTarget then
        local nameHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        nameHeader:SetPoint("TOPLEFT", hpColorCont, "BOTTOMLEFT", 0, -15)
        nameHeader:SetText("--- Name Text ---")

        local showNameBtn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        showNameBtn:SetPoint("TOPLEFT", nameHeader, "BOTTOMLEFT", -6, 0)
        showNameBtn.text = showNameBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        showNameBtn.text:SetPoint("LEFT", showNameBtn, "RIGHT", 2, 1)
        showNameBtn.text:SetText("Show Name Text")
        showNameBtn:SetChecked(db.showName)
        showNameBtn:SetScript("OnClick", function(self)
            db.showName = self:GetChecked() and true or false
            if not InCombatLockdown() then refresh() end
        end)

        local nameXSlider = NewSlider(parent, -100, 100, 1, db.nameTextX, "X Offset")
        nameXSlider:SetPoint("TOPLEFT", showNameBtn, "BOTTOMLEFT", 6, -15)
        ns.SafeSetSliderText(nameXSlider, "X Offset")
        nameXSlider:SetScript("OnValueChanged", function(_, val)
            db.nameTextX = val
            if not InCombatLockdown() then refresh() end
        end)

        local nameYSlider = NewSlider(parent, -100, 100, 1, db.nameTextY, "Y Offset")
        nameYSlider:SetPoint("TOPLEFT", nameXSlider, "BOTTOMLEFT", 0, -25)
        ns.SafeSetSliderText(nameYSlider, "Y Offset")
        nameYSlider:SetScript("OnValueChanged", function(_, val)
            db.nameTextY = val
            if not InCombatLockdown() then refresh() end
        end)

        local nameColorCont = CreateColorSwatch(parent, "Name Text Color", db, "nameTextR", "nameTextG", "nameTextB", refresh)
        nameColorCont:SetPoint("TOPLEFT", nameYSlider, "BOTTOMLEFT", 0, -10)
    end
end

function ns.CreateOptionsPanel()
    local panel = CreateFrame("Frame", "CTFramesOptions", UIParent, "BackdropTemplate")
    panel:SetSize(560, 760)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    tinsert(UISpecialFrames, "CTFramesOptions")
    ns.EnsureBackdrop(panel, 0.95)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Shared Frames (ctDB)")

    local ctDB = ns.GetCTDB()

    local unlockBtn = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    unlockBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
    unlockBtn.text = unlockBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    unlockBtn.text:SetPoint("LEFT", unlockBtn, "RIGHT", 2, 1)
    unlockBtn.text:SetText("Unlock All to Move")
    unlockBtn:SetChecked(ctDB.unlocked)
    unlockBtn:SetScript("OnClick", function(self)
        ctDB.unlocked = self:GetChecked() and true or false
        if ns.Player and ns.Player.UpdateLockState then ns.Player:UpdateLockState() end
        if ns.Target and ns.Target.UpdateLockState then ns.Target:UpdateLockState() end
        if ns.Target and ns.Target.ApplySecureVisibility then ns.Target:ApplySecureVisibility() end
    end)

    local linkBtn = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    linkBtn:SetPoint("TOPLEFT", unlockBtn, "BOTTOMLEFT", 0, -6)
    linkBtn.text = linkBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    linkBtn.text:SetPoint("LEFT", linkBtn, "RIGHT", 2, 1)
    linkBtn.text:SetText("Link Player + Target Size")
    linkBtn:SetChecked(ctDB.linkSizes)
    linkBtn:SetScript("OnClick", function(self)
        ctDB.linkSizes = self:GetChecked() and true or false
        if ctDB.linkSizes then
            ctDB.target.w = ctDB.player.w
            ctDB.target.hpH = ctDB.player.hpH
            ctDB.target.isVertical = ctDB.player.isVertical
        end
        if ns.Player and ns.Player.ApplyLayout then ns.Player:ApplyLayout() end
        if ns.Target and ns.Target.ApplyLayout then ns.Target:ApplyLayout() end
        if ns.Player and ns.Player.UpdateValues then ns.Player:UpdateValues() end
        if ns.Target and ns.Target.UpdateValues then ns.Target:UpdateValues() end
    end)

    local scroll = CreateFrame("ScrollFrame", "CTFramesOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -92)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1400)
    scroll:SetScrollChild(content)

    CreateColumn(content, "Player Settings", "player", 12, 10)
    CreateColumn(content, "Target Settings", "target", 290, 10)
end

-- ------------------------------------------------------------
-- SLASH
-- ------------------------------------------------------------
SLASH_CTFRAMES1 = "/ctframes"
SlashCmdList["CTFRAMES"] = function()
    if CTFramesOptions then
        CTFramesOptions:SetShown(not CTFramesOptions:IsShown())
    end
end

-- ------------------------------------------------------------
-- DB INIT + REBIND ON SPEC CHANGE (FIX)
-- ------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
initFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
initFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= AddonName then return end

    -- Always bind ctDB to RobUI profile table if available
    ns.GetCTDB()

    if not CTFramesOptions then
        ns.CreateOptionsPanel()
    end

    -- If spec/profile changed, re-apply layout so vertical etc reflects correct profile
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if ns.Player and ns.Player.ApplyLayout then ns.Player:ApplyLayout() end
        if ns.Target and ns.Target.ApplyLayout then ns.Target:ApplyLayout() end
        if ns.Target and ns.Target.ApplySecureVisibility then ns.Target:ApplySecureVisibility() end
        if ns.Player and ns.Player.UpdateLockState then ns.Player:UpdateLockState() end
        if ns.Target and ns.Target.UpdateLockState then ns.Target:UpdateLockState() end
    end
end)