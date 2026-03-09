-- ============================================================================
-- RobUI Trinkets (On-Use only) - FIX: respects Grid group COMBAT/HIDDEN visibility
-- Shows equipped on-use trinkets (slots 13/14) with cooldown spirals and keybinds.
-- SavedVariables: (none)
--
-- IMPORTANT:
--  - Starts OFF by default (enabled=false)
--  - NO settings panel here (unified panel is in driver.lua)
--
-- rgrid:
--  - PluginId: ct_trinkets
--  - Grid owns POSITION + VISIBILITY when attached (group showMode etc)
--  - Grid controls SIZE + SCALE via callbacks
-- ============================================================================
local ADDON, ns = ...
ns = _G[ADDON] or ns
_G[ADDON] = ns

ns.Trinkets = ns.Trinkets or {}
local T = ns.Trinkets

local CreateFrame = CreateFrame
local UIParent = UIParent
local tonumber = tonumber
local floor = math.floor

local PLUGIN_ID = "ct_trinkets"

-- =========================================================
-- DB
-- =========================================================
local DEFAULTS = {
    enabled = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 0,

    locked = false,
    size = 30,
    gap = 5,
    scale = 1.0,

    showBackground = true,
    bgAlpha = 0.40,
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
        T.db = ns.DB:GetConfig("trinkets")
        CopyDefaults(DEFAULTS, T.db)
        return T.db
    end

    if type(_G.RobUITrinketsDB) ~= "table" then _G.RobUITrinketsDB = {} end
    CopyDefaults(DEFAULTS, _G.RobUITrinketsDB)
    T.db = _G.RobUITrinketsDB
    return T.db
end

function T:GetDB()
    return T.db or EnsureDB()
end

local function DB()
    return T:GetDB()
end

local function IsAttachedToGrid()
    return (ns.GridCore and ns.GridCore.IsPluginAttached and ns.GridCore:IsPluginAttached(PLUGIN_ID)) and true or false
end

local function IsGridDrivingNow()
    if ns.GridCore and ns.GridCore.IsEditMode and ns.GridCore:IsEditMode() then return true end
    if IsAttachedToGrid() then return true end
    return false
end

-- =========================================================
-- Helper: Find Keybind
-- =========================================================
local function GetBindForInventorySlot(invSlot)
    local itemID = GetInventoryItemID("player", invSlot)
    if not itemID then return "" end

    local function GetBindingNameForActionSlot(slot)
        if slot >= 1 and slot <= 12 then return "ACTIONBUTTON" .. slot end
        if slot >= 25 and slot <= 36 then return "MULTIACTIONBAR3BUTTON" .. (slot - 24) end
        if slot >= 37 and slot <= 48 then return "MULTIACTIONBAR4BUTTON" .. (slot - 36) end
        if slot >= 49 and slot <= 60 then return "MULTIACTIONBAR2BUTTON" .. (slot - 48) end
        if slot >= 61 and slot <= 72 then return "MULTIACTIONBAR1BUTTON" .. (slot - 60) end
        return nil
    end

    for i = 1, 72 do
        local actionType, id = GetActionInfo(i)
        if actionType == "item" and id == itemID then
            local bindCommand = GetBindingNameForActionSlot(i)
            if bindCommand then
                local key = GetBindingKey(bindCommand)
                if key then
                    key = key:gsub("SHIFT%-", "S-")
                    key = key:gsub("ALT%-", "A-")
                    key = key:gsub("CTRL%-", "C-")
                    key = key:gsub("MOUSEWHEELUP", "MU")
                    key = key:gsub("MOUSEWHEELDOWN", "MD")
                    key = key:gsub("BUTTON", "M")
                    return key
                end
            end
        end
    end
    return ""
end

-- =========================================================
-- Tooltip helpers (ALWAYS ON)
-- =========================================================
local function HideTrinketTooltip()
    if GameTooltip and GameTooltip:IsShown() then
        GameTooltip:Hide()
    end
end

local function ShowTrinketTooltip(owner, invSlot)
    if not GameTooltip then return end
    if not owner or not invSlot then return end
    if not GetInventoryItemLink("player", invSlot) then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetInventoryItem("player", invSlot)
    GameTooltip:Show()
end

-- =========================================================
-- UI
-- =========================================================
local function CreateTrinketSlot(parent, invSlot)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(30, 30)
    f.invSlot = invSlot

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:EnableMouse(false)

    f.bindText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.bindText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    f.bindText:SetJustifyH("RIGHT")

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        ShowTrinketTooltip(self, self.invSlot)
    end)
    f:SetScript("OnLeave", function()
        HideTrinketTooltip()
    end)

    f:Hide()
    return f
end

local function SavePosition()
    if not T.frame then return end
    local db = DB()
    local p, _, rp, x, y = T.frame:GetPoint()
    db.point = p
    db.relPoint = rp
    db.x = x
    db.y = y
end

local function IsOnUse(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end
    local spellName = C_Item.GetItemSpell(link)
    return spellName and true or false
end

local function ApplyLayout(t1Active, t2Active)
    local db = DB()
    local s = tonumber(db.size) or 30
    local g = tonumber(db.gap) or 5

    T.t1:SetSize(s, s)
    T.t2:SetSize(s, s)

    T.t1:ClearAllPoints()
    T.t2:ClearAllPoints()

    if db.showBackground then
        T.frame.bg:SetColorTexture(0, 0, 0, tonumber(db.bgAlpha) or 0.4)
    else
        T.frame.bg:SetColorTexture(0, 0, 0, 0)
    end

    -- drag only when standalone (Grid owns position when attached)
    if IsGridDrivingNow() then
        T.frame:EnableMouse(false)
    else
        T.frame:EnableMouse(not db.locked)
    end

    -- TOOLTIP: ALWAYS ON (even when attached/edit)
    T.t1:EnableMouse(true)
    T.t2:EnableMouse(true)

    if t1Active and t2Active then
        T.frame:SetSize((s * 2) + g, s)
        T.t1:SetPoint("LEFT", T.frame, "LEFT", 0, 0)
        T.t2:SetPoint("RIGHT", T.frame, "RIGHT", 0, 0)
        T.t1:Show()
        T.t2:Show()
    elseif t1Active then
        T.frame:SetSize(s, s)
        T.t1:SetPoint("CENTER", T.frame, "CENTER", 0, 0)
        T.t1:Show()
        T.t2:Hide()
        HideTrinketTooltip()
    elseif t2Active then
        T.frame:SetSize(s, s)
        T.t2:SetPoint("CENTER", T.frame, "CENTER", 0, 0)
        T.t2:Show()
        T.t1:Hide()
        HideTrinketTooltip()
    else
        T.frame:SetSize(s, s)
        T.t1:Hide()
        T.t2:Hide()
        HideTrinketTooltip()
    end
end

local function UpdateVisibilityAndIcons()
    local db = DB()

    -- disabled ALWAYS wins
    if not db.enabled then
        if T.frame then T.frame:Hide() end
        HideTrinketTooltip()
        return
    end
    if not T.frame then return end

    local t1Active = IsOnUse(13)
    local t2Active = IsOnUse(14)

    if t1Active then
        T.t1.icon:SetTexture(GetInventoryItemTexture("player", 13))
        T.t1.bindText:SetText(GetBindForInventorySlot(13))
    end
    if t2Active then
        T.t2.icon:SetTexture(GetInventoryItemTexture("player", 14))
        T.t2.bindText:SetText(GetBindForInventorySlot(14))
    end

    ApplyLayout(t1Active, t2Active)

    -- VISIBILITY FIX:
    -- If attached to Grid, DO NOT force Show() (Grid controls COMBAT/HIDDEN via group/anchor mode).
    -- We only force Hide() if there are no on-use trinkets (no content).
    if IsAttachedToGrid() then
        if not (t1Active or t2Active) then
            T.frame:Hide()
            HideTrinketTooltip()
        end
        return
    end

    -- Standalone behavior (not attached): we own show/hide.
    if t1Active or t2Active then
        T.frame:Show()
    else
        T.frame:Hide()
        HideTrinketTooltip()
    end
end

local function UpdateCooldowns()
    local db = DB()
    if not db.enabled then return end
    if not T.frame or not T.frame:IsShown() then return end

    if T.t1:IsShown() then
        local start, duration, enable = GetInventoryItemCooldown("player", 13)
        if start and duration and duration > 0 and enable == 1 then
            T.t1.cooldown:SetCooldown(start, duration)
        else
            T.t1.cooldown:Clear()
        end
    end

    if T.t2:IsShown() then
        local start, duration, enable = GetInventoryItemCooldown("player", 14)
        if start and duration and duration > 0 and enable == 1 then
            T.t2.cooldown:SetCooldown(start, duration)
        else
            T.t2.cooldown:Clear()
        end
    end
end

function T:Create()
    if self.frame then return end

    local db = DB()

    local f = CreateFrame("Frame", "RobUI_Trinkets", UIParent)
    self.frame = f
    f:SetFrameStrata("MEDIUM")

    f:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x, db.y)
    f:SetSize(65, 30)
    f:SetScale(tonumber(db.scale) or 1.0)

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
        SavePosition()
    end)

    f:SetScript("OnHide", function()
        HideTrinketTooltip()
    end)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(true)

    self.t1 = CreateTrinketSlot(f, 13)
    self.t2 = CreateTrinketSlot(f, 14)

    f:Hide()
end

function T:ApplyConfig()
    EnsureDB()
    self:Create()

    local db = DB()
    if not self.frame then return end

    self.frame:SetScale(tonumber(db.scale) or 1.0)

    -- POSITION: Grid owns position when attached
    if not IsAttachedToGrid() then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x, db.y)
    end

    UpdateVisibilityAndIcons()
    UpdateCooldowns()
end

function T:ForceUpdate()
    self:ApplyConfig()
end

-- =========================================================
-- GridCore plugin registration
-- =========================================================
local function RegisterGridPlugin()
    if T._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
        name = "Trinkets",
        default = { gx = 0, gy = 0, scaleWithGrid = false, label = "Trinkets" },

        build = function()
            EnsureDB()
            T:ApplyConfig()
            return T.frame
        end,

        standard = { position = true, size = true, scale = true },

        setSize = function(frame, w, h)
            local db = DB()
            w = tonumber(w) or db.size or 30
            h = tonumber(h) or db.size or 30
            local s = floor(((w + h) * 0.5) + 0.5)
            if s < 16 then s = 16 end
            if s > 80 then s = 80 end
            db.size = s
            T:ApplyConfig()
        end,

        setScale = function(frame, s)
            local db = DB()
            s = tonumber(s) or db.scale or 1.0
            if s < 0.25 then s = 0.25 end
            if s > 3.00 then s = 3.00 end
            db.scale = s
            T:ApplyConfig()
        end,

        settings = function(parent)
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints()
            local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", 0, 0)
            t:SetJustifyH("LEFT")
            t:SetText("Trinkets\n\n- Grid owns POSITION + VISIBILITY when attached.\n- Size maps to icon size.\n- Scale affects the whole widget.\n\nTooltip is ALWAYS enabled on hover.")
            return f
        end,
    })

    T._gridRegistered = true
end

-- =========================================================
-- Events
-- =========================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("UPDATE_BINDINGS")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        T:ApplyConfig()
        RegisterGridPlugin()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        RegisterGridPlugin()
        UpdateVisibilityAndIcons()
        UpdateCooldowns()
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UPDATE_BINDINGS" then
        UpdateVisibilityAndIcons()
        UpdateCooldowns()
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        UpdateCooldowns()
        return
    end
end)