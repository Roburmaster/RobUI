-- ============================================================================
-- driver.lua
-- RobUI Combat Grid (CombatTools) - Unified bootstrap + settings panel
--
-- FIX (important):
--  - NEVER swap _G.ctDB to a new table after ptsettings/player/target has cached it.
--  - Keep a stable table reference forever:
--      _G.ctDB = _G.ctDB or {}
--    Then bind RobUI profile storage to that exact table.
--
-- GOALS (total, stable solution):
--  1) Single source of truth for settings = RobUI profile (RobuiDB via R.Database.profile)
--  2) Stable DB wrapper for all modules in this package:
--        ns.DB:RegisterDefaults(pluginId, defaults)
--        ns.DB:GetConfig(pluginId) -> cfg table
--  3) Register ONE settings panel in RobUI MasterConfig (tab)
--  4) No standalone SavedVariables (rbdb/rbardb/RobUITrinketsDB/ctDB) needed.
--     (We keep backwards-compat migration where safe.)
--  5) ClassBar is only active for classes that have a classbar builder.
--
-- NOTE:
--  - You said you handle RobUI.toc/load order.
--  - This file assumes RobUI is loaded before this file.
-- ============================================================================

local ADDON, ns = ...
ns = _G[ADDON] or ns or {}
_G[ADDON] = ns

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitClass = UnitClass
local tonumber = tonumber
local math_floor = math.floor
local wipe = wipe
local pairs = pairs
local type = type
local pcall = pcall

-- RobUI hard dependency (enforced by your toc)
local R = _G.Robui

-- =====================================================================
-- IMPORTANT: Stable ctDB reference (never replace this table)
-- =====================================================================
_G.ctDB = type(_G.ctDB) == "table" and _G.ctDB or {}
ctDB = _G.ctDB -- also keep the global name around for older files

-- =====================================================================
-- DB WRAPPER (stores under active RobUI profile)
-- =====================================================================
ns.DB = ns.DB or {}
local DB = ns.DB

DB._defaults = DB._defaults or {}
DB._cache = DB._cache or {}

local MODULE_ROOT_KEY = "combatgrid" -- R.Database.profile[MODULE_ROOT_KEY][pluginId] = cfg

local function DeepCopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            DeepCopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function GetRobUIProfile()
    if not (R and R.Database and type(R.Database.profile) == "table") then
        return nil
    end
    return R.Database.profile
end

local function EnsureRoot(profile)
    profile[MODULE_ROOT_KEY] = profile[MODULE_ROOT_KEY] or {}
    return profile[MODULE_ROOT_KEY]
end

-- Bind a "stable" table to a pluginId (used for unitframes/ctDB)
local function BindStableTable(pluginId, stableTable)
    if type(pluginId) ~= "string" or pluginId == "" then return end
    if type(stableTable) ~= "table" then return end

    local profile = GetRobUIProfile()
    if not profile then return end

    local root = EnsureRoot(profile)

    -- If profile already has data, merge into stable table (one way) before binding.
    if type(root[pluginId]) == "table" and root[pluginId] ~= stableTable then
        -- merge existing saved values into stable table without overwriting
        for k, v in pairs(root[pluginId]) do
            if stableTable[k] == nil then
                stableTable[k] = v
            elseif type(v) == "table" and type(stableTable[k]) == "table" then
                DeepCopyDefaults(v, stableTable[k])
            end
        end
    end

    -- Now bind profile storage to the stable reference
    root[pluginId] = stableTable

    -- Apply defaults into the stable table
    local defs = DB._defaults[pluginId]
    if type(defs) == "table" then
        DeepCopyDefaults(defs, stableTable)
    end

    DB._cache[pluginId] = stableTable
end

function DB:RegisterDefaults(pluginId, defaults)
    if type(pluginId) ~= "string" or pluginId == "" then return end
    defaults = (type(defaults) == "table") and defaults or {}
    DB._defaults[pluginId] = defaults

    local profile = GetRobUIProfile()
    if not profile then return end

    local root = EnsureRoot(profile)

    -- Special case: if this pluginId is already bound to a stable table, just apply defaults
    if type(root[pluginId]) == "table" and DB._cache[pluginId] == root[pluginId] then
        DeepCopyDefaults(defaults, root[pluginId])
        return
    end

    root[pluginId] = root[pluginId] or {}
    DeepCopyDefaults(defaults, root[pluginId])
    DB._cache[pluginId] = root[pluginId]
end

function DB:GetConfig(pluginId)
    if type(pluginId) ~= "string" or pluginId == "" then return {} end

    local cached = DB._cache[pluginId]
    if type(cached) == "table" then return cached end

    local profile = GetRobUIProfile()
    if not profile then return {} end

    local root = EnsureRoot(profile)

    -- If the profile points at a table already, use it
    if type(root[pluginId]) ~= "table" then
        root[pluginId] = {}
    end

    local defs = DB._defaults[pluginId]
    if type(defs) == "table" then
        DeepCopyDefaults(defs, root[pluginId])
    end

    DB._cache[pluginId] = root[pluginId]
    return root[pluginId]
end

function DB:ResetCache()
    wipe(DB._cache)
end

-- =====================================================================
-- Shared: classbar builders live in separate files
-- =====================================================================
ns.standaloneBars = ns.standaloneBars or {}
ns.ClassBarDriver = ns.ClassBarDriver or {}
local D = ns.ClassBarDriver

local PLUGIN_ID = "ct_classbar"

local function GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function HasClassBarForPlayer()
    local class = GetPlayerClass()
    return class and type(ns.standaloneBars[class]) == "function"
end

-- =====================================================================
-- Module defaults (RobUI profile)
-- =====================================================================
DB:RegisterDefaults("core", {
    enabled = true,
    debug = false,
})

DB:RegisterDefaults("classbar", {
    enabled  = false,

    point    = "CENTER",
    x        = 0,
    y        = -150,

    width    = 220,
    height   = 24,

    isLocked = true,
    showText = true,
    scale    = 1.0,
})

DB:RegisterDefaults("resourcebar", {
    enabled = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -200,

    width = 260,
    height = 18,

    scale = 1.0,
    locked = true,
    showText = true,

    showBackground = true,
    bgAlpha = 0.40,
})

DB:RegisterDefaults("trinkets", {
    enabled = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 0,

    locked = false,
    size = 30,
    gap = 5,

    showBackground = true,
    bgAlpha = 0.40,
})

-- Unitframes (ctDB replacement) – used by ptsettings/player/target
DB:RegisterDefaults("unitframes", {
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
    }
})

-- =====================================================================
-- Backwards compat migration (one-time, best-effort)
-- =====================================================================
local function MigrateLegacyOnce()
    local profile = GetRobUIProfile()
    if not profile then return end
    local root = EnsureRoot(profile)
    root._migrated = root._migrated or {}

    -- ClassBar: rbdb.ClassBar -> combatgrid.classbar
    if not root._migrated.classbar and type(_G.rbdb) == "table" and type(_G.rbdb.ClassBar) == "table" then
        local legacy = _G.rbdb.ClassBar
        local cfg = DB:GetConfig("classbar")
        for k, v in pairs(legacy) do
            if cfg[k] == nil then cfg[k] = v end
        end
        root._migrated.classbar = true
    end

    -- ResourceBar: rbardb -> combatgrid.resourcebar
    if not root._migrated.resourcebar and type(_G.rbardb) == "table" then
        local legacy = _G.rbardb
        local cfg = DB:GetConfig("resourcebar")
        for k, v in pairs(legacy) do
            if cfg[k] == nil then cfg[k] = v end
        end
        root._migrated.resourcebar = true
    end

    -- Trinkets: RobUITrinketsDB -> combatgrid.trinkets
    if not root._migrated.trinkets and type(_G.RobUITrinketsDB) == "table" then
        local legacy = _G.RobUITrinketsDB
        local cfg = DB:GetConfig("trinkets")
        for k, v in pairs(legacy) do
            if cfg[k] == nil then cfg[k] = v end
        end
        root._migrated.trinkets = true
    end

    -- Unitframes: ctDB -> combatgrid.unitframes
    -- NOTE: We DO NOT copy the whole table blindly because ctDB is now stable and profile-bound.
    if not root._migrated.unitframes and type(_G.ctDB) == "table" and _G.ctDB ~= ctDB then
        -- normally shouldn't happen, but keep safe
        root._migrated.unitframes = true
    elseif not root._migrated.unitframes and type(_G.ctDB) == "table" then
        -- If there was legacy data already inside ctDB, it will be merged during BindStableTable()
        root._migrated.unitframes = true
    end
end

-- =====================================================================
-- Class Bar frames
-- =====================================================================
local Anchor = CreateFrame("Frame", "RBAnchor", UIParent)
Anchor:SetSize(220, 24)
Anchor:SetFrameStrata("HIGH")
Anchor:SetMovable(true)
Anchor:SetClampedToScreen(true)
Anchor:Hide()

local MainBar = CreateFrame("Frame", "RBMainBar", Anchor, "BackdropTemplate")
MainBar:SetSize(220, 24)
MainBar:SetPoint("CENTER", Anchor, "CENTER", 0, 0)
MainBar:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
MainBar:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
MainBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
MainBar:SetClipsChildren(true) -- overflow safety

MainBar.unlockOverlay = MainBar:CreateTexture(nil, "OVERLAY", nil, 7)
MainBar.unlockOverlay:SetAllPoints()
MainBar.unlockOverlay:SetColorTexture(0, 1, 0, 0.3)
MainBar.unlockOverlay:Hide()

ns.Anchor = Anchor
ns.MainBar = MainBar

ns.Text = MainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ns.Text:SetPoint("CENTER", MainBar, "CENTER", 0, 0)
ns.Text:SetText("")

D._activeClass = nil
D._built = false
D._gridRegistered = D._gridRegistered or false

local function IsAttachedToGrid()
    return (ns.GridCore and ns.GridCore.IsPluginAttached and ns.GridCore:IsPluginAttached(PLUGIN_ID)) and true or false
end

local function IsGridDrivingNow()
    if ns.GridCore and ns.GridCore.IsEditMode and ns.GridCore:IsEditMode() then return true end
    if IsAttachedToGrid() then return true end
    return false
end

local function SavePositionFromAnchor(cfg)
    local cx, cy = Anchor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux then
        cfg.point = "CENTER"
        cfg.x = cx - ux
        cfg.y = cy - uy
        Anchor:ClearAllPoints()
        Anchor:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    end
end

local function AttachClassModuleIfEnabled(forceRebuild)
    local cfg = DB:GetConfig("classbar")
    if not cfg.enabled then return end

    local class = GetPlayerClass()
    if not class then return end

    local builder = ns.standaloneBars[class]
    if type(builder) ~= "function" then
        D._activeClass = nil
        D._built = false
        return
    end

    if not forceRebuild and D._activeClass == class and D._built then
        return
    end

    D._activeClass = class
    D._built = false

    local ok = pcall(builder, MainBar)
    if ok then
        D._built = true
    else
        D._built = false
    end
end

function D:Apply()
    local cfg = DB:GetConfig("classbar")

    if not cfg.enabled then
        Anchor:Hide()
        MainBar:EnableMouse(false)
        MainBar.unlockOverlay:Hide()
        return
    end

    -- HARD RULE: no classbar for this class => nothing
    if not HasClassBarForPlayer() then
        Anchor:Hide()
        return
    end

    -- Position: Grid owns position when attached
    if not IsAttachedToGrid() then
        Anchor:ClearAllPoints()
        Anchor:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
    end

    local w = tonumber(cfg.width) or 220
    local h = tonumber(cfg.height) or 24
    if w < 120 then w = 120 end
    if h < 12 then h = 12 end

    Anchor:SetSize(w, h)
    MainBar:SetSize(w, h)

    local s = tonumber(cfg.scale) or 1.0
    if s < 0.25 then s = 0.25 end
    if s > 3.00 then s = 3.00 end
    Anchor:SetScale(s)

    if IsGridDrivingNow() then
        MainBar:EnableMouse(false)
        MainBar.unlockOverlay:Hide()
    else
        if cfg.isLocked then
            MainBar:EnableMouse(false)
            MainBar.unlockOverlay:Hide()
        else
            MainBar:EnableMouse(true)
            MainBar.unlockOverlay:Show()
        end
    end

    ns.Text:SetShown(cfg.showText and true or false)
    Anchor:Show()

    AttachClassModuleIfEnabled(false)
end

function D:ForceUpdate()
    self:Apply()
end

-- Drag (standalone only)
MainBar:RegisterForDrag("LeftButton")
MainBar:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    if IsGridDrivingNow() then return end
    local cfg = DB:GetConfig("classbar")
    if not cfg.isLocked then
        Anchor:StartMoving()
    end
end)
MainBar:SetScript("OnDragStop", function()
    Anchor:StopMovingOrSizing()
    if IsGridDrivingNow() then return end
    local cfg = DB:GetConfig("classbar")
    SavePositionFromAnchor(cfg)
end)

-- =====================================================================
-- Unified Settings Panel (RobUI MasterConfig tab)
-- =====================================================================
ns.CombatToolsSettings = ns.CombatToolsSettings or {}
local S = ns.CombatToolsSettings

local function MakeHeader(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function MakeRule(parent, x, y, w)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.10)
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(w or 560, 1)
    return t
end

local function BuildPanel(parent)
    local p = CreateFrame("Frame", nil, parent or UIParent)
    p:Hide()

    -- --- CLASS BAR -----------------------------------------------------------
    MakeHeader(p, "Class Bar", 20, -20)
    MakeRule(p, 20, -42, 560)

    local cbEnabled = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cbEnabled:SetPoint("TOPLEFT", 20, -60)
    cbEnabled.text:SetText("Enable Class Bar")

    local cbLock = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cbLock:SetPoint("TOPLEFT", 20, -90)
    cbLock.text:SetText("Lock")

    local cbText = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cbText:SetPoint("TOPLEFT", 20, -120)
    cbText.text:SetText("Show Text")

    local cbScale = CreateFrame("Slider", "RobUI_CT_ClassBarScale", p, "OptionsSliderTemplate")
    cbScale:SetPoint("TOPLEFT", 20, -175)
    cbScale:SetMinMaxValues(0.5, 2.0)
    cbScale:SetValueStep(0.05)
    cbScale:SetObeyStepOnDrag(true)
    cbScale:SetWidth(240)
    _G[cbScale:GetName() .. "Low"]:SetText("50%")
    _G[cbScale:GetName() .. "High"]:SetText("200%")
    _G[cbScale:GetName() .. "Text"]:SetText("Scale")

    local cbW = CreateFrame("Slider", "RobUI_CT_ClassBarWidth", p, "OptionsSliderTemplate")
    cbW:SetPoint("TOPLEFT", 20, -235)
    cbW:SetMinMaxValues(120, 600)
    cbW:SetValueStep(10)
    cbW:SetObeyStepOnDrag(true)
    cbW:SetWidth(240)
    _G[cbW:GetName() .. "Low"]:SetText("120")
    _G[cbW:GetName() .. "High"]:SetText("600")
    _G[cbW:GetName() .. "Text"]:SetText("Width")

    local cbH = CreateFrame("Slider", "RobUI_CT_ClassBarHeight", p, "OptionsSliderTemplate")
    cbH:SetPoint("TOPLEFT", 20, -285)
    cbH:SetMinMaxValues(12, 60)
    cbH:SetValueStep(1)
    cbH:SetObeyStepOnDrag(true)
    cbH:SetWidth(240)
    _G[cbH:GetName() .. "Low"]:SetText("12")
    _G[cbH:GetName() .. "High"]:SetText("60")
    _G[cbH:GetName() .. "Text"]:SetText("Height")

    local cbReset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    cbReset:SetSize(220, 24)
    cbReset:SetPoint("TOPLEFT", 20, -345)
    cbReset:SetText("Reset Class Bar Position")

    -- --- RESOURCE BAR --------------------------------------------------------
    MakeHeader(p, "Resource Bar", 320, -20)
    MakeRule(p, 320, -42, 260)

    local RB = ns.ResourceBar

    local rbEnabled = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    rbEnabled:SetPoint("TOPLEFT", 320, -60)
    rbEnabled.text:SetText("Enable Resource Bar")

    local rbLock = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    rbLock:SetPoint("TOPLEFT", 320, -90)
    rbLock.text:SetText("Lock")

    local rbText = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    rbText:SetPoint("TOPLEFT", 320, -120)
    rbText.text:SetText("Show Text")

    local rbW = CreateFrame("Slider", "RobUI_CT_RBarWidth", p, "OptionsSliderTemplate")
    rbW:SetPoint("TOPLEFT", 320, -175)
    rbW:SetMinMaxValues(100, 600)
    rbW:SetValueStep(10)
    rbW:SetObeyStepOnDrag(true)
    rbW:SetWidth(240)
    _G[rbW:GetName() .. "Low"]:SetText("100")
    _G[rbW:GetName() .. "High"]:SetText("600")
    _G[rbW:GetName() .. "Text"]:SetText("Width")

    local rbH = CreateFrame("Slider", "RobUI_CT_RBarHeight", p, "OptionsSliderTemplate")
    rbH:SetPoint("TOPLEFT", 320, -225)
    rbH:SetMinMaxValues(10, 48)
    rbH:SetValueStep(1)
    rbH:SetObeyStepOnDrag(true)
    rbH:SetWidth(240)
    _G[rbH:GetName() .. "Low"]:SetText("10")
    _G[rbH:GetName() .. "High"]:SetText("48")
    _G[rbH:GetName() .. "Text"]:SetText("Height")

    local rbReset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    rbReset:SetSize(180, 24)
    rbReset:SetPoint("TOPLEFT", 320, -285)
    rbReset:SetText("Reset Resource Bar Position")

    -- --- TRINKETS ------------------------------------------------------------
    MakeHeader(p, "Trinkets", 20, -400)
    MakeRule(p, 20, -422, 560)

    local T = ns.Trinkets

    local tEnabled = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    tEnabled:SetPoint("TOPLEFT", 20, -440)
    tEnabled.text:SetText("Enable Trinkets")

    local tLock = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    tLock:SetPoint("TOPLEFT", 20, -470)
    tLock.text:SetText("Lock")

    local tBG = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    tBG:SetPoint("TOPLEFT", 20, -500)
    tBG.text:SetText("Background")

    local tSize = CreateFrame("Slider", "RobUI_CT_TrinketsSize", p, "OptionsSliderTemplate")
    tSize:SetPoint("TOPLEFT", 20, -555)
    tSize:SetMinMaxValues(20, 48)
    tSize:SetValueStep(1)
    tSize:SetObeyStepOnDrag(true)
    tSize:SetWidth(240)
    _G[tSize:GetName() .. "Low"]:SetText("20")
    _G[tSize:GetName() .. "High"]:SetText("48")
    _G[tSize:GetName() .. "Text"]:SetText("Icon Size")

    local tGap = CreateFrame("Slider", "RobUI_CT_TrinketsGap", p, "OptionsSliderTemplate")
    tGap:SetPoint("TOPLEFT", 20, -605)
    tGap:SetMinMaxValues(0, 20)
    tGap:SetValueStep(1)
    tGap:SetObeyStepOnDrag(true)
    tGap:SetWidth(240)
    _G[tGap:GetName() .. "Low"]:SetText("0")
    _G[tGap:GetName() .. "High"]:SetText("20")
    _G[tGap:GetName() .. "Text"]:SetText("Gap")

    local tReset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    tReset:SetSize(180, 24)
    tReset:SetPoint("TOPLEFT", 20, -665)
    tReset:SetText("Reset Trinkets Position")

    -- Handlers: Class Bar
    cbEnabled:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("classbar")
        cfg.enabled = btn:GetChecked() and true or false
        D._built = false
        D:Apply()
    end)

    cbLock:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("classbar")
        cfg.isLocked = btn:GetChecked() and true or false
        D:Apply()
    end)

    cbText:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("classbar")
        cfg.showText = btn:GetChecked() and true or false
        D:Apply()
    end)

    cbScale:SetScript("OnValueChanged", function(_, val)
        local cfg = DB:GetConfig("classbar")
        cfg.scale = tonumber(val) or 1.0
        D:Apply()
    end)

    cbW:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("classbar")
        cfg.width = math_floor((tonumber(v) or 220) + 0.5)
        D:Apply()
    end)

    cbH:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("classbar")
        cfg.height = math_floor((tonumber(v) or 24) + 0.5)
        D:Apply()
    end)

    cbReset:SetScript("OnClick", function()
        local cfg = DB:GetConfig("classbar")
        cfg.point = "CENTER"
        cfg.x = 0
        cfg.y = -150
        D:Apply()
    end)

    -- Handlers: Resource Bar
    local function ApplyRB()
        if RB and RB.ApplyConfig then RB:ApplyConfig() end
    end

    rbEnabled:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("resourcebar")
        cfg.enabled = btn:GetChecked() and true or false
        ApplyRB()
    end)

    rbLock:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("resourcebar")
        cfg.locked = btn:GetChecked() and true or false
        ApplyRB()
    end)

    rbText:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("resourcebar")
        cfg.showText = btn:GetChecked() and true or false
        ApplyRB()
    end)

    rbW:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("resourcebar")
        cfg.width = math_floor((tonumber(v) or 260) + 0.5)
        ApplyRB()
    end)

    rbH:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("resourcebar")
        cfg.height = math_floor((tonumber(v) or 18) + 0.5)
        ApplyRB()
    end)

    rbReset:SetScript("OnClick", function()
        local cfg = DB:GetConfig("resourcebar")
        cfg.point = "CENTER"
        cfg.relPoint = "CENTER"
        cfg.x = 0
        cfg.y = -200
        ApplyRB()
    end)

    -- Handlers: Trinkets
    local function ApplyT()
        if T and T.ApplyConfig then T:ApplyConfig() end
    end

    tEnabled:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("trinkets")
        cfg.enabled = btn:GetChecked() and true or false
        ApplyT()
    end)

    tLock:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("trinkets")
        cfg.locked = btn:GetChecked() and true or false
        ApplyT()
    end)

    tBG:SetScript("OnClick", function(btn)
        local cfg = DB:GetConfig("trinkets")
        cfg.showBackground = btn:GetChecked() and true or false
        ApplyT()
    end)

    tSize:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("trinkets")
        cfg.size = math_floor((tonumber(v) or 30) + 0.5)
        ApplyT()
    end)

    tGap:SetScript("OnValueChanged", function(_, v)
        local cfg = DB:GetConfig("trinkets")
        cfg.gap = math_floor((tonumber(v) or 5) + 0.5)
        ApplyT()
    end)

    tReset:SetScript("OnClick", function()
        local cfg = DB:GetConfig("trinkets")
        cfg.point = "CENTER"
        cfg.relPoint = "CENTER"
        cfg.x = 0
        cfg.y = 0
        ApplyT()
    end)

    -- Refresh controls when panel is shown
    p:SetScript("OnShow", function()
        local c = DB:GetConfig("classbar")
        cbEnabled:SetChecked(c.enabled and true or false)
        cbLock:SetChecked(c.isLocked and true or false)
        cbText:SetChecked(c.showText and true or false)
        cbScale:SetValue(tonumber(c.scale) or 1.0)
        cbW:SetValue(tonumber(c.width) or 220)
        cbH:SetValue(tonumber(c.height) or 24)

        local rbc = DB:GetConfig("resourcebar")
        rbEnabled:SetChecked(rbc.enabled and true or false)
        rbLock:SetChecked(rbc.locked and true or false)
        rbText:SetChecked(rbc.showText and true or false)
        rbW:SetValue(tonumber(rbc.width) or 260)
        rbH:SetValue(tonumber(rbc.height) or 18)

        local tc = DB:GetConfig("trinkets")
        tEnabled:SetChecked(tc.enabled and true or false)
        tLock:SetChecked(tc.locked and true or false)
        tBG:SetChecked(tc.showBackground and true or false)
        tSize:SetValue(tonumber(tc.size) or 30)
        tGap:SetValue(tonumber(tc.gap) or 5)
    end)

    return p
end

function S:BuildRobUI(parent)
    if self.panel and self.panel.GetParent and parent and self.panel:GetParent() ~= parent then
        self.panel:SetParent(parent)
        self.panel:ClearAllPoints()
        self.panel:SetAllPoints(parent)
        self.panel:Hide()
        return self.panel
    end

    if self.panel then
        self.panel:Hide()
        return self.panel
    end

    local p = BuildPanel(parent)
    self.panel = p
    if parent then p:SetAllPoints(parent) end
    p:Hide()
    return p
end

local function RegisterToRobUI()
    if not (R and type(R.RegisterModulePanel) == "function") then return end

    local holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()

    local p = S:BuildRobUI(holder)
    p:Hide()

    R:RegisterModulePanel("Combat Tools", p)
end

-- =====================================================================
-- GridCore plugin registration for ClassBar
-- =====================================================================
local function RegisterGridPlugin()
    if not HasClassBarForPlayer() then
        D._gridRegistered = false
        return
    end

    if D._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
        name = "Class Bar",
        default = { gx = 0, gy = -150, scaleWithGrid = false, label = "Class Bar" },

        build = function()
            D:Apply()
            return Anchor
        end,

        standard = { position = true, size = true, scale = true },

        setSize = function(_, w, h)
            local cfg = DB:GetConfig("classbar")
            w = tonumber(w) or cfg.width or 220
            h = tonumber(h) or cfg.height or 24
            if w < 120 then w = 120 end
            if h < 12  then h = 12  end
            cfg.width = w
            cfg.height = h
            D:Apply()
        end,

        setScale = function(_, s)
            local cfg = DB:GetConfig("classbar")
            s = tonumber(s) or cfg.scale or 1.0
            if s < 0.25 then s = 0.25 end
            if s > 3.00 then s = 3.00 end
            cfg.scale = s
            D:Apply()
        end,

        settings = function(parent)
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints()
            local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", 0, 0)
            t:SetJustifyH("LEFT")
            t:SetText("Class Bar\n\n- Only registers for classes that have a classbar.\n- MainBar clips children to prevent divider overflow.\n")
            return f
        end,
    })

    D._gridRegistered = true
end

-- =====================================================================
-- Init (PLAYER_LOGIN)
-- =====================================================================
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00b3ffRobUI CombatGrid|r: " .. msg)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    R = _G.Robui
    if not (R and R.Database and type(R.Database.profile) == "table") then
        Print("RobUI not ready. Check toc/load order.")
        return
    end

    -- reset caches (profile might have changed since load)
    DB:ResetCache()

    -- one-time legacy migration
    MigrateLegacyOnce()

    -- CRITICAL FIX:
    -- Bind the RobUI profile "unitframes" storage to the SAME stable ctDB table
    BindStableTable("unitframes", _G.ctDB)
    ctDB = _G.ctDB

    -- (Optional) you can also bind other stable tables if you ever need it.
    -- For now only unitframes must be stable to fix vertical/horizontal.

    RegisterToRobUI()

    -- Classbar lifecycle
    if HasClassBarForPlayer() then
        RegisterGridPlugin()
        D:Apply()
    else
        Anchor:Hide()
    end

    -- other modules apply using profile configs
    if ns.ResourceBar and ns.ResourceBar.ApplyConfig then
        ns.ResourceBar:ApplyConfig()
    end
    if ns.Trinkets and ns.Trinkets.ApplyConfig then
        ns.Trinkets:ApplyConfig()
    end

    -- optional: if grid needs a boot hook
    if type(ns.Boot) == "function" then
        ns.Boot()
    end
end)