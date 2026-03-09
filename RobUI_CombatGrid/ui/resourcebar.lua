-- ============================================================================
-- RobUI Resource Bar (12.0+)
-- Auto power swap (Mana/Rage/Energy/etc)
-- Movable + Lock
-- SavedVariables: (none)
--
-- IMPORTANT:
--  - Starts OFF by default
--  - NO settings panel here (unified panel is in driver.lua)
--  - GridCore plugin support (rgrid):
--      * PluginId: ct_resourcebar
--      * build() ALWAYS returns a frame
--      * Grid owns position/size/scale via standard + setSize/setScale
--      * Standalone drag/save still works when not in Grid edit/attached
-- ============================================================================

local AddonName, ns = ...
ns = _G[AddonName] or ns
_G[AddonName] = ns

ns.ResourceBar = ns.ResourceBar or {}
local RB = ns.ResourceBar

local CreateFrame = CreateFrame
local UIParent = UIParent
local tonumber = tonumber

local PLUGIN_ID = "ct_resourcebar"

-- =========================================================
-- Defaults + DB
-- =========================================================
local DEFAULTS = {
    enabled  = false,

    width    = 260,
    height   = 18,
    scale    = 1.0,

    point    = "CENTER",
    relPoint = "CENTER",
    x        = 0,
    y        = -200,

    locked   = false,
    showText = true,

    texture  = "Interface\\Buttons\\WHITE8X8",
    backdrop = 0.60,
}

local POWER_COLORS = {
    [Enum.PowerType.Mana]         = {0.0, 0.4, 1.0},
    [Enum.PowerType.Rage]         = {1.0, 0.1, 0.1},
    [Enum.PowerType.Energy]       = {1.0, 1.0, 0.0},
    [Enum.PowerType.Focus]        = {1.0, 0.5, 0.0},
    [Enum.PowerType.RunicPower]   = {0.0, 0.8, 1.0},
    [Enum.PowerType.Insanity]     = {0.6, 0.0, 1.0},
    [Enum.PowerType.Fury]         = {0.8, 0.0, 0.8},
    [Enum.PowerType.LunarPower]   = {0.3, 0.3, 1.0},
    [Enum.PowerType.Maelstrom]    = {0.0, 0.6, 1.0},
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function EnsureDB()
    if ns.DB and ns.DB.GetConfig then
        RB.db = ns.DB:GetConfig("resourcebar")
        CopyDefaults(DEFAULTS, RB.db)
        return RB.db
    end

    if type(_G.rbardb) ~= "table" then _G.rbardb = {} end
    CopyDefaults(DEFAULTS, _G.rbardb)
    RB.db = _G.rbardb
    return RB.db
end

function RB:GetDB()
    return RB.db or EnsureDB()
end

local function DB()
    return RB:GetDB()
end

-- =========================================================
-- Grid/Standalone coordination
-- =========================================================
local function IsAttachedToGrid()
    return (ns.GridCore and ns.GridCore.IsPluginAttached and ns.GridCore:IsPluginAttached(PLUGIN_ID)) and true or false
end

local function IsGridDrivingNow()
    if ns.GridCore and ns.GridCore.IsEditMode and ns.GridCore:IsEditMode() then return true end
    if IsAttachedToGrid() then return true end
    return false
end

-- =========================================================
-- Frame helpers
-- =========================================================
local function SavePosition(f)
    local db = DB()
    local p, _, rp, x, y = f:GetPoint()
    db.point = p
    db.relPoint = rp
    db.x = x
    db.y = y
end

local function UpdateBar()
    local db = DB()
    if not RB.bar then return end

    if not db.enabled then
        if RB.text then RB.text:SetText("") end
        return
    end

    local powerType = UnitPowerType("player")
    local cur = UnitPower("player", powerType)
    local maxv = UnitPowerMax("player", powerType)

    if not maxv or maxv == 0 then
        RB.bar:SetMinMaxValues(0, 1)
        RB.bar:SetValue(0)
        if RB.text then RB.text:SetText("") end
        return
    end

    RB.bar:SetMinMaxValues(0, maxv)
    RB.bar:SetValue(cur or 0)

    local c = POWER_COLORS[powerType] or {1, 1, 1}
    RB.bar:SetStatusBarColor(c[1], c[2], c[3])

    if RB.text then
        if db.showText then
            RB.text:SetText((cur or 0) .. " / " .. maxv)
        else
            RB.text:SetText("")
        end
    end
end

local function CreateBar()
    local db = DB()
    if RB.frame then return end

    local f = CreateFrame("Frame", "RobUI_ResourceBar", UIParent, "BackdropTemplate")
    RB.frame = f

    f:SetSize(db.width, db.height)
    f:SetScale(tonumber(db.scale) or 1.0)
    f:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x, db.y)

    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f:SetBackdropColor(0, 0, 0, tonumber(db.backdrop) or 0.6)

    local bar = CreateFrame("StatusBar", nil, f)
    RB.bar = bar
    bar:SetAllPoints()
    bar:SetStatusBarTexture(db.texture)

    local txt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    RB.text = txt
    txt:SetPoint("CENTER")

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if IsGridDrivingNow() then return end
        if not DB().locked then self:StartMoving() end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if IsGridDrivingNow() then return end
        SavePosition(self)
    end)

    UpdateBar()
end

local function EnsureFrame()
    EnsureDB()
    if not RB.frame then CreateBar() end
    return RB.frame
end

-- =========================================================
-- Public API used by unified settings panel
-- =========================================================
function RB:ApplyConfig()
    local db = DB()
    EnsureFrame()

    if RB.frame then
        RB.frame:SetScale(tonumber(db.scale) or 1.0)

        -- Only apply saved point when NOT attached (Grid owns position when attached)
        if not IsAttachedToGrid() then
            RB.frame:ClearAllPoints()
            RB.frame:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x, db.y)
        end

        RB.frame:SetSize(db.width, db.height)
        RB.frame:SetBackdropColor(0, 0, 0, tonumber(db.backdrop) or 0.6)

        -- mouse: only when standalone
        if IsGridDrivingNow() then
            RB.frame:EnableMouse(false)
        else
            RB.frame:EnableMouse(not db.locked)
        end

        -- VISIBILITY:
        -- - disabled => ALWAYS hide
        -- - enabled + attached => DO NOT force Show() (Grid controls group/combat visibility)
        -- - enabled + standalone => Show()
        if not db.enabled then
            RB.frame:Hide()
        else
            if not IsAttachedToGrid() then
                RB.frame:Show()
            end
        end
    end

    if RB.bar then
        RB.bar:SetStatusBarTexture(db.texture)
    end

    UpdateBar()
end

function RB:ForceUpdate()
    EnsureDB()
    EnsureFrame()
    self:ApplyConfig()
end

function RB:Update()
    UpdateBar()
end

-- =========================================================
-- Event driver
-- =========================================================
RB.driver = RB.driver or CreateFrame("Frame")
RB.driver:RegisterEvent("PLAYER_LOGIN")
RB.driver:RegisterEvent("UNIT_POWER_UPDATE")
RB.driver:RegisterEvent("UNIT_DISPLAYPOWER")
RB.driver:RegisterEvent("PLAYER_ENTERING_WORLD")

RB.driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        EnsureFrame()
        RB:ApplyConfig()
        return
    end

    if event == "UNIT_POWER_UPDATE" and arg1 ~= "player" then
        return
    end

    RB:Update()
end)

-- =========================================================
-- GridCore plugin registration (robust like player.lua)
-- =========================================================
local function RegisterGridPlugin()
    if RB._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
        name = "Resource Bar",
        default = { gx = 0, gy = -200, scaleWithGrid = false, label = "Resource" },

        build = function()
            RB:ForceUpdate()
            return RB.frame
        end,

        standard = { position = true, size = true, scale = true },

        setSize = function(frame, w, h)
            local db = DB()
            w = tonumber(w) or db.width or DEFAULTS.width
            h = tonumber(h) or db.height or DEFAULTS.height
            if w < 20 then w = 20 end
            if h < 6  then h = 6  end
            db.width = w
            db.height = h
            RB:ApplyConfig()
        end,

        setScale = function(frame, s)
            local db = DB()
            s = tonumber(s) or db.scale or 1.0
            if s < 0.25 then s = 0.25 end
            if s > 3.0  then s = 3.0  end
            db.scale = s
            RB:ApplyConfig()
        end,

        settings = function(parent)
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints()
            local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", 0, 0)
            t:SetJustifyH("LEFT")
            t:SetText("Resource Bar\n\n- Grid owns POSITION + VISIBILITY when attached.\n- Grid controls size/scale via callbacks.\n- Standalone drag works when not in Grid edit/attached.\n")
            return f
        end,
    })

    RB._gridRegistered = true
end

local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterEvent("ADDON_LOADED")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        EnsureDB()
        EnsureFrame()
        RB:ApplyConfig()
        RegisterGridPlugin()
        return
    end
end)

_G.RobUI_ResourceBar = RB