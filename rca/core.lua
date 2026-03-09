-- ============================================================================
-- Core.lua (RCA) - RobUI Integrated + rgrid (RobUI GridCore) + RobUI Profile DB
-- The main conductor that links the UI, settings, and the new RCA modules.
--
-- FIX (THIS EDIT):
--  - Intelligent per-CLASS + per-SPEC storage:
--      R.Database.profile.rca[pluginId][CLASS][SPEC_ID] = cfg
--  - Auto-swap cfg on spec change
--  - Combat-safe refresh (defer while in combat)
-- ============================================================================

local AddonName, ns = ...
ns = _G[AddonName] or ns or {}
_G[AddonName] = ns

-- WoW locals
local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitClass = UnitClass
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local tonumber = tonumber
local floor = math.floor
local max = math.max
local wipe = wipe
local pairs = pairs
local type = type
local pcall = pcall
local ipairs = ipairs
local tinsert = table.insert
local tremove = table.remove
local GetItemSpell = GetItemSpell
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetSpecialization = GetSpecialization
local ClearCursor = ClearCursor
local GetCursorInfo = GetCursorInfo
local IsAltKeyDown = IsAltKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local PickupSpell = PickupSpell
local GetMacroSpell = GetMacroSpell
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local table_sort = table.sort
local select = select

-- RobUI (hard dependency)
local R = _G.Robui or _G.RobUI or _G["Robui"] or _G["RobUI"]

-- Shared Modules
local SpellDB = ns.SpellDB

-- ============================================================================
-- DB WRAPPER (stores under active RobUI profile)  [PER CLASS + SPEC]
-- ============================================================================
ns.DB = ns.DB or {}
local DB = ns.DB

DB._defaults = DB._defaults or {}
DB._cache = DB._cache or {}

local MODULE_ROOT_KEY = "rca"

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

local function GetClassToken()
    return select(2, UnitClass("player")) or "UNKNOWN"
end

local function GetSpecID()
    -- Spec changes happen in-combat sometimes. Still safe to read.
    local s = 0
    if GetSpecialization then
        s = GetSpecialization() or 0
    end
    return s
end

local function CacheKey(pluginId, classToken, specId)
    return pluginId .. ":" .. (classToken or "UNKNOWN") .. ":" .. tostring(specId or 0)
end

local function EnsurePluginRoot(root, pluginId)
    root[pluginId] = root[pluginId] or {}
    return root[pluginId]
end

local function EnsureScopedConfig(pluginRoot, classToken, specId)
    classToken = classToken or "UNKNOWN"
    specId = specId or 0

    pluginRoot[classToken] = pluginRoot[classToken] or {}
    pluginRoot[classToken][specId] = pluginRoot[classToken][specId] or {}
    return pluginRoot[classToken][specId]
end

local function MigrateLegacyIfNeeded(pluginRoot, classToken, specId)
    -- If old versions stored keys directly under pluginRoot (offCount, etc),
    -- move them into current scope once.
    if pluginRoot and type(pluginRoot) == "table" and pluginRoot._migratedLegacy ~= true then
        -- Heuristic: if pluginRoot.offCount exists and pluginRoot[classToken] isn't a table yet.
        if pluginRoot.offCount ~= nil or pluginRoot.cdCount ~= nil or pluginRoot.mainSize ~= nil then
            local scoped = EnsureScopedConfig(pluginRoot, classToken, specId)
            for k, v in pairs(pluginRoot) do
                if k ~= "_migratedLegacy" and k ~= classToken then
                    -- Only move "primitive settings + tables", ignore any future class buckets.
                    if type(k) == "string" and k ~= "UNKNOWN" then
                        if scoped[k] == nil then
                            scoped[k] = v
                        end
                    end
                end
            end
            -- Clean legacy keys (optional, but keeps DB clean)
            for k, _ in pairs(scoped) do
                -- nothing
            end
            -- Mark migrated (do not repeatedly move)
            pluginRoot._migratedLegacy = true
        else
            pluginRoot._migratedLegacy = true
        end
    end
end

function DB:RegisterDefaults(pluginId, defaults)
    if type(pluginId) ~= "string" or pluginId == "" then return end
    defaults = (type(defaults) == "table") and defaults or {}
    DB._defaults[pluginId] = defaults

    local profile = GetRobUIProfile()
    if not profile then return end

    local root = EnsureRoot(profile)
    local pluginRoot = EnsurePluginRoot(root, pluginId)

    local classToken = GetClassToken()
    local specId = GetSpecID()

    MigrateLegacyIfNeeded(pluginRoot, classToken, specId)

    local cfg = EnsureScopedConfig(pluginRoot, classToken, specId)
    DeepCopyDefaults(defaults, cfg)

    DB._cache[CacheKey(pluginId, classToken, specId)] = cfg
end

function DB:GetConfig(pluginId)
    if type(pluginId) ~= "string" or pluginId == "" then return {} end

    local classToken = GetClassToken()
    local specId = GetSpecID()
    local key = CacheKey(pluginId, classToken, specId)

    local cached = DB._cache[key]
    if type(cached) == "table" then return cached end

    local profile = GetRobUIProfile()
    if not profile then return {} end

    local root = EnsureRoot(profile)
    local pluginRoot = EnsurePluginRoot(root, pluginId)

    MigrateLegacyIfNeeded(pluginRoot, classToken, specId)

    local cfg = EnsureScopedConfig(pluginRoot, classToken, specId)

    local defs = DB._defaults[pluginId]
    if type(defs) == "table" then
        DeepCopyDefaults(defs, cfg)
    end

    DB._cache[key] = cfg
    return cfg
end

function DB:ResetCache()
    wipe(DB._cache)
end

-- ============================================================================
-- DEFAULTS
-- ============================================================================
local DEFAULTS = {
    offCount  = 4,
    cdCount   = 2,
    defCount  = 2,
    healCount = 2,

    mainSize  = 50,
    queueSize = 36,
    cdSize    = 40,
    defSize   = 40,
    healSize  = 40,

    offDir    = "RIGHT",
    cdDir     = "RIGHT",
    defDir    = "RIGHT",
    healDir   = "RIGHT",

    -- Visibility toggles
    showOff   = true,
    showCd    = true,
    showDef   = true,
    showHeal  = true,

    spacing   = 4,
    locked    = false,

    offPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = -150 },
    cdPos   = { point = "CENTER", relPoint = "CENTER", x = 0, y = -210 },
    defPos  = { point = "CENTER", relPoint = "CENTER", x = 0, y = -80  },
    healPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -10  },

    blacklist    = {},
    whitelist    = {},
    offPriority  = {},
    cdPriority   = {},
    defPriority  = {},
    healPriority = {},

    customBinds = {},
}

local PLUGIN_ROOT = "rca"
DB:RegisterDefaults(PLUGIN_ROOT, DEFAULTS)

local CONFIG = DB:GetConfig(PLUGIN_ROOT)
ns.CONFIG = CONFIG

-- ============================================================================
-- GRIDCORE DISCOVERY
-- ============================================================================
local function GetGridCore()
    if _G.RGridCore and type(_G.RGridCore.RegisterPlugin) == "function" then
        return _G.RGridCore
    end
    local cg = _G["RobUI_CombatGrid"]
    if cg and cg.GridCore and type(cg.GridCore.RegisterPlugin) == "function" then
        return cg.GridCore
    end
    if R then
        if R.GridCore and type(R.GridCore.RegisterPlugin) == "function" then return R.GridCore end
        if R.rgrid and R.rgrid.GridCore and type(R.rgrid.GridCore.RegisterPlugin) == "function" then return R.rgrid.GridCore end
    end
    return nil
end

local function IsAttachedToGrid(pluginId)
    local GC = GetGridCore()
    return (GC and GC.IsPluginAttached and GC:IsPluginAttached(pluginId)) and true or false
end

-- ============================================================================
-- CLASS DATA & FALLBACKS
-- ============================================================================
local DEFAULT_OFFENSIVE_BUFFS = {
    WARRIOR     = {107574, 1719, 167105, 262161},
    PALADIN     = {31884, 231895, 327193},
    DEATHKNIGHT = {51271, 152279, 275699},
    HUNTER      = {19574, 288613, 266779},
    MAGE        = {190319, 12042, 12472},
    ROGUE       = {13750, 51690, 121471},
    WARLOCK     = {113858, 205180, 113860},
    SHAMAN      = {114050, 114051, 114052},
    MONK        = {137639, 123904},
    DEMONHUNTER = {191427, 200146},
    DRUID       = {102560, 102543, 194223},
    PRIEST      = {10060, 34433},
    EVOKER      = {375087, 368847},
}

local function GetClassLists()
    local playerClass = GetClassToken()
    local selfHeals, majorCDs, majorBuffs = {}, {}, {}

    if SpellDB then
        selfHeals  = (SpellDB.CLASS_SELFHEAL_DEFAULTS and SpellDB.CLASS_SELFHEAL_DEFAULTS[playerClass]) or {}
        majorCDs   = (SpellDB.CLASS_COOLDOWN_DEFAULTS and SpellDB.CLASS_COOLDOWN_DEFAULTS[playerClass]) or {}
        majorBuffs = (SpellDB.CLASS_OFFENSIVE_BUFF_DEFAULTS and SpellDB.CLASS_OFFENSIVE_BUFF_DEFAULTS[playerClass]) or DEFAULT_OFFENSIVE_BUFFS[playerClass] or {}
    else
        majorBuffs = DEFAULT_OFFENSIVE_BUFFS[playerClass] or {}
    end
    return selfHeals, majorCDs, majorBuffs
end

-- ============================================================================
-- ARRAY HELPERS & FILTERING
-- ============================================================================
local function IsInArray(arr, val)
    if type(arr) ~= "table" then return false end
    for _, v in ipairs(arr) do
        if v == val then return true end
    end
    return false
end

local function IsBlacklisted(spellID) return IsInArray(CONFIG.blacklist, spellID) end
local function IsWhitelisted(spellID) return IsInArray(CONFIG.whitelist, spellID) end

local function IsOffensiveAllowed(spellID)
    if not spellID or spellID <= 0 then return false end
    if IsBlacklisted(spellID) then return false end
    if IsWhitelisted(spellID) then return true end
    if SpellDB and SpellDB.IsOffensive then
        return SpellDB.IsOffensive(spellID)
    end
    return true
end

local function ClearCooldown(cd)
    if not cd then return end
    if cd.Clear then cd:Clear()
    elseif cd.ClearCooldown then cd:ClearCooldown()
    else cd:SetCooldown(0, 0) end
end

local function IsKnownSafe(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    return (IsPlayerSpell and IsPlayerSpell(spellID)) or true
end

-- ============================================================================
-- CURSOR / DRAG HELPER
-- ============================================================================
local function GetCursorSpellID()
    local infoType, d1, _, d3 = GetCursorInfo()
    if infoType == "spell" then
        return d3
    elseif infoType == "macro" then
        return GetMacroSpell(d1)
    elseif infoType == "item" then
        local _, spellID = GetItemSpell(d1)
        return spellID
    elseif infoType == "inventory" then
        local itemID = GetInventoryItemID("player", d1)
        if itemID then
            local _, spellID = GetItemSpell(itemID)
            return spellID
        end
    end
    return nil
end

-- ============================================================================
-- ICON FRAMES
-- ============================================================================
local function CreateIconFrame(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", -1, 1)
    f.bg:SetPoint("BOTTOMRIGHT", 1, -1)
    f.bg:SetColorTexture(0, 0, 0, 1)

    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints()
    f.cd:SetDrawEdge(false)
    if f.cd.SetDrawBling then f.cd:SetDrawBling(false) end
    if f.cd.SetDrawSwipe then f.cd:SetDrawSwipe(true) end
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(false) end

    f.hotkey = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.hotkey:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if self._spellID and self._spellID > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self._spellID)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    return f
end

local offParent  = CreateFrame("Frame", "RCA_Offensive", UIParent)
local cdParent   = CreateFrame("Frame", "RCA_Cooldowns", UIParent)
local defParent  = CreateFrame("Frame", "RCA_Defensive", UIParent)
local healParent = CreateFrame("Frame", "RCA_Healing", UIParent)

local offIcons, cdIcons, defIcons, healIcons = {}, {}, {}, {}

local PLUGIN_OFF  = "rca_off"
local PLUGIN_CD   = "rca_cd"
local PLUGIN_DEF  = "rca_def"
local PLUGIN_HEAL = "rca_heal"

local function ApplyVisibility()
    offParent:SetShown(CONFIG.showOff)
    cdParent:SetShown(CONFIG.showCd)
    defParent:SetShown(CONFIG.showDef)
    healParent:SetShown(CONFIG.showHeal)
end
ns.ApplyVisibility = ApplyVisibility

local function ApplyPositions()
    if not IsAttachedToGrid(PLUGIN_OFF) then
        offParent:ClearAllPoints()
        offParent:SetPoint(CONFIG.offPos.point, UIParent, CONFIG.offPos.relPoint, CONFIG.offPos.x, CONFIG.offPos.y)
    end
    if not IsAttachedToGrid(PLUGIN_CD) then
        cdParent:ClearAllPoints()
        cdParent:SetPoint(CONFIG.cdPos.point, UIParent, CONFIG.cdPos.relPoint, CONFIG.cdPos.x, CONFIG.cdPos.y)
    end
    if not IsAttachedToGrid(PLUGIN_DEF) then
        defParent:ClearAllPoints()
        defParent:SetPoint(CONFIG.defPos.point, UIParent, CONFIG.defPos.relPoint, CONFIG.defPos.x, CONFIG.defPos.y)
    end
    if not IsAttachedToGrid(PLUGIN_HEAL) then
        healParent:ClearAllPoints()
        healParent:SetPoint(CONFIG.healPos.point, UIParent, CONFIG.healPos.relPoint, CONFIG.healPos.x, CONFIG.healPos.y)
    end
end

local function UpdateParentSize(parent, count, firstSize, otherSize, spacing, direction)
    if count <= 0 then parent:SetSize(1, 1) return end
    local primaryDim = firstSize + (count > 1 and (count - 1) * (otherSize + spacing) or 0)
    local secondaryDim = max(firstSize, otherSize)

    if direction == "DOWN" or direction == "UP" then
        parent:SetSize(secondaryDim, primaryDim)
    else
        parent:SetSize(primaryDim, secondaryDim)
    end
end

local function UpdateLayout()
    local function ConfigureRow(icons, parent, count, firstSize, restSize, spacing, direction)
        UpdateParentSize(parent, count, firstSize, restSize, spacing, direction)

        -- NOTE: Your old code hard-limited to 4 icons. Keep it as-is.
        for i = 1, 4 do
            local size = (i == 1) and firstSize or restSize
            if not icons[i] then icons[i] = CreateIconFrame(parent, size) end
            local icon = icons[i]
            icon:SetSize(size, size)

            if i <= count then
                icon:Show()
                icon:ClearAllPoints()
                if i == 1 then
                    if direction == "DOWN" then
                        icon:SetPoint("TOP", parent, "TOP", 0, 0)
                    elseif direction == "UP" then
                        icon:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
                    elseif direction == "LEFT" then
                        icon:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
                    else -- "RIGHT"
                        icon:SetPoint("LEFT", parent, "LEFT", 0, 0)
                    end
                else
                    local prev = icons[i - 1]
                    if direction == "DOWN" then
                        icon:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
                    elseif direction == "UP" then
                        icon:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
                    elseif direction == "LEFT" then
                        icon:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
                    else -- "RIGHT"
                        icon:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
                    end
                end
            else
                icon:Hide()
            end
        end
    end

    ConfigureRow(offIcons,  offParent,  CONFIG.offCount,  CONFIG.mainSize, CONFIG.queueSize, CONFIG.spacing, CONFIG.offDir)
    ConfigureRow(cdIcons,   cdParent,   CONFIG.cdCount,   CONFIG.cdSize,   CONFIG.cdSize,    CONFIG.spacing, CONFIG.cdDir)
    ConfigureRow(defIcons,  defParent,  CONFIG.defCount,  CONFIG.defSize,  CONFIG.defSize,   CONFIG.spacing, CONFIG.defDir)
    ConfigureRow(healIcons, healParent, CONFIG.healCount, CONFIG.healSize, CONFIG.healSize,  CONFIG.spacing, CONFIG.healDir)
end

local function SaveParentPos(parent, key)
    local point, _, relPoint, x, y = parent:GetPoint(1)
    if not point then return end
    CONFIG[key] = {
        point = point,
        relPoint = relPoint or "CENTER",
        x = floor((x or 0) + 0.5),
        y = floor((y or 0) + 0.5),
    }
end

local function ApplyLock()
    local unlocked = not CONFIG.locked
    local GC = GetGridCore()
    local gridEdit = (GC and GC.IsEditMode and GC:IsEditMode()) and true or false

    for _, p in ipairs({ offParent, cdParent, defParent, healParent }) do
        local attached = false
        if p == offParent then attached = IsAttachedToGrid(PLUGIN_OFF)
        elseif p == cdParent then attached = IsAttachedToGrid(PLUGIN_CD)
        elseif p == defParent then attached = IsAttachedToGrid(PLUGIN_DEF)
        else attached = IsAttachedToGrid(PLUGIN_HEAL) end

        local allowMove = unlocked and (not attached) and (not gridEdit)
        p:SetMovable(allowMove)
        p:EnableMouse(allowMove)

        if allowMove then
            p:RegisterForDrag("LeftButton")
            p:SetScript("OnDragStart", p.StartMoving)
            p:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                if self == offParent then SaveParentPos(self, "offPos")
                elseif self == cdParent then SaveParentPos(self, "cdPos")
                elseif self == defParent then SaveParentPos(self, "defPos")
                else SaveParentPos(self, "healPos") end
            end)

            p.dragBg = p.dragBg or p:CreateTexture(nil, "BACKGROUND")
            p.dragBg:SetAllPoints()
            p.dragBg:SetColorTexture(0, 1, 0, 0.25)
        else
            p:SetScript("OnDragStart", nil)
            p:SetScript("OnDragStop", nil)
            if p.dragBg then p.dragBg:SetColorTexture(0, 0, 0, 0) end
        end
    end
end

-- ============================================================================
-- SETTINGS UI (RobUI panel + /rca fallback)
-- ============================================================================
local DropZones = {}

local function UpdateAllVisuals()
    for _, fn in ipairs(DropZones) do fn() end
end
ns.UpdateAllVisuals = UpdateAllVisuals

StaticPopupDialogs["RCA_ADD_SPELL_BY_ID"] = {
    text = "Enter Spell ID:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 10,
    OnAccept = function(self, dbKey)
        local text = self.editBox:GetText()
        local id = tonumber(text)
        if id and id > 0 and dbKey then
            tinsert(CONFIG[dbKey], id)
            if ns.UpdateAllVisuals then ns.UpdateAllVisuals() end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local button = self:GetParent().button1
        if button and button:IsEnabled() then
            button:Click()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateModernSlider(parent, name, label, y, minV, maxV, key)
    local frameName = "RCA_ModernSlider_" .. name
    local s = CreateFrame("Slider", frameName, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 20, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(260)

    local low  = _G[frameName .. "Low"]
    local high = _G[frameName .. "High"]
    local text = _G[frameName .. "Text"]

    if low  then low:SetText(tostring(minV)) end
    if high then high:SetText(tostring(maxV)) end

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 6)
    title:SetText(label)

    local initial = CONFIG[key] or minV
    s:SetValue(initial)
    if text then text:SetText(tostring(initial)) end

    s:SetScript("OnValueChanged", function(_, val)
        local v = floor((val or 0) + 0.5)
        CONFIG[key] = v
        if text then text:SetText(tostring(v)) end
        UpdateLayout()
    end)

    return s
end

local function CreateVisualDropZone(parent, label, x, y, dbKey)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)

    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", x, y - 22)
    box:SetSize(280, 40)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.15, 0.15, 0.15, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)

    local instruction = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instruction:SetPoint("CENTER")
    instruction:SetText("Drop Spell Here\n|cffaaaaaa(Alt+Shift+Click to add ID)|r")
    instruction:SetTextColor(0.5, 0.5, 0.5)

    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    box.icons = {}

    box.UpdateVisuals = function()
        local arr = CONFIG[dbKey]
        if type(arr) ~= "table" then return end

        if #arr == 0 then instruction:Show() else instruction:Hide() end

        for i = 1, 10 do
            local icon = box.icons[i]
            if i <= #arr then
                if not icon then
                    icon = CreateFrame("Button", nil, box)
                    icon:SetSize(30, 30)
                    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    icon:RegisterForDrag("LeftButton")

                    icon.tex = icon:CreateTexture(nil, "ARTWORK")
                    icon.tex:SetAllPoints()
                    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                    icon:SetScript("OnEnter", function(self)
                        if GetCursorInfo() then return end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetSpellByID(self.spellID)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("|cFF00FF00Drag|r to Move/Reorder", 1, 1, 1)
                        GameTooltip:AddLine("|cFFFF0000Right-Click|r to Remove", 1, 1, 1)
                        GameTooltip:Show()
                    end)

                    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    icon:SetScript("OnDragStart", function(self)
                        if self.spellID then
                            if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(self.spellID)
                            else PickupSpell(self.spellID) end
                            tremove(CONFIG[dbKey], self.index)
                            UpdateAllVisuals()
                            GameTooltip:Hide()
                        end
                    end)

                    icon:SetScript("OnReceiveDrag", function(self)
                        local newID = GetCursorSpellID()
                        if newID and newID > 0 then
                            for k, v in ipairs(CONFIG[dbKey]) do
                                if v == newID then tremove(CONFIG[dbKey], k) break end
                            end
                            tinsert(CONFIG[dbKey], self.index, newID)
                            ClearCursor()
                            UpdateAllVisuals()
                        end
                    end)

                    icon:SetScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            tremove(CONFIG[dbKey], self.index)
                            UpdateAllVisuals()
                            GameTooltip:Hide()
                        elseif button == "LeftButton" and GetCursorInfo() then
                            self:GetScript("OnReceiveDrag")(self)
                        end
                    end)

                    box.icons[i] = icon
                end

                icon.spellID = arr[i]
                icon.index = i

                local spellInfo = C_Spell.GetSpellInfo(arr[i])
                icon.tex:SetTexture(spellInfo and spellInfo.iconID or 134400)

                icon:ClearAllPoints()
                icon:SetPoint("LEFT", box, "LEFT", 5 + ((i - 1) * 34), 0)
                icon:Show()
            else
                if icon then icon:Hide() end
            end
        end
    end

    tinsert(DropZones, box.UpdateVisuals)

    local function HandleBoxDrop()
        local newID = GetCursorSpellID()
        if newID and newID > 0 then
            for k, v in ipairs(CONFIG[dbKey]) do
                if v == newID then tremove(CONFIG[dbKey], k) break end
            end
            tinsert(CONFIG[dbKey], newID)
            ClearCursor()
            UpdateAllVisuals()
        end
    end

    box:SetScript("OnReceiveDrag", HandleBoxDrop)
    box:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if IsAltKeyDown() and IsShiftKeyDown() then
                local popup = StaticPopup_Show("RCA_ADD_SPELL_BY_ID")
                if popup then popup.data = dbKey end
            elseif GetCursorInfo() then
                HandleBoxDrop()
            end
        end
    end)

    return box
end

local function CreateDirectionToggle(parent, label, x, y, key)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetSize(85, 22)

    local function GetDirText(dir)
        if dir == "DOWN" then return "Down"
        elseif dir == "UP" then return "Up"
        elseif dir == "LEFT" then return "Left"
        else return "Right" end
    end

    btn:SetText(GetDirText(CONFIG[key]))

    btn:SetScript("OnClick", function(self)
        local current = CONFIG[key]
        if current == "RIGHT" then CONFIG[key] = "LEFT"
        elseif current == "LEFT" then CONFIG[key] = "DOWN"
        elseif current == "DOWN" then CONFIG[key] = "UP"
        else CONFIG[key] = "RIGHT" end

        self:SetText(GetDirText(CONFIG[key]))
        UpdateLayout()
    end)

    local txt = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
    txt:SetText(label)

    return btn
end

local function CreateVisibilityToggle(parent, label, x, y, key)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(26, 26)

    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)

    cb:SetChecked(CONFIG[key])
    cb:SetScript("OnClick", function(self)
        CONFIG[key] = self:GetChecked()
        if ns.ApplyVisibility then ns.ApplyVisibility() end
    end)

    return cb
end

-- ============================================================================
-- IMPORT / EXPORT LOGIC
-- ============================================================================
local function ExportSettings()
    local s = ""
    local lists = {"offPriority", "cdPriority", "defPriority", "healPriority", "whitelist", "blacklist"}

    for _, listName in ipairs(lists) do
        if CONFIG[listName] and #CONFIG[listName] > 0 then
            s = s .. listName .. "=" .. table.concat(CONFIG[listName], ",") .. ";"
        end
    end

    local binds = {}
    if CONFIG.customBinds then
        for id, bind in pairs(CONFIG.customBinds) do
            if bind and bind ~= "" then
                tinsert(binds, id .. ":" .. bind)
            end
        end
    end

    if #binds > 0 then
        s = s .. "customBinds=" .. table.concat(binds, ",") .. ";"
    end

    return s
end

local function ImportSettings(str)
    if type(str) ~= "string" or str == "" then return false end
    local foundAnything = false

    for k, v in str:gmatch("(%w+)=([^;]*);") do
        if k == "customBinds" then
            CONFIG.customBinds = {}
            for idStr, bind in v:gmatch("(%d+):([^,]+)") do
                local id = tonumber(idStr)
                if id then
                    CONFIG.customBinds[id] = bind
                    foundAnything = true
                end
            end
        elseif CONFIG[k] ~= nil then
            CONFIG[k] = {}
            for idStr in v:gmatch("(%d+)") do
                local id = tonumber(idStr)
                if id then
                    tinsert(CONFIG[k], id)
                    foundAnything = true
                end
            end
        end
    end

    if foundAnything then
        ns.UpdateAllVisuals()
        if ns.Scanner and ns.Scanner.UpdateActionBarCache then
            ns.Scanner.UpdateActionBarCache()
        end
    end
    return foundAnything
end

-- ============================================================================
-- UI BUILDER
-- ============================================================================
local function BuildEmbeddedPanel(parent)
    local p = CreateFrame("Frame", nil, parent or UIParent)
    p:Hide()
    if parent then p:SetAllPoints(parent) end

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -15)
    title:SetText("Combat Assistant")

    -- Left Column (Counts)
    CreateModernSlider(p, "OffCount",  "Rotation Amount",  -50, 1, 4, "offCount")
    CreateModernSlider(p, "CdCount",   "Cooldown Amount",  -100, 1, 4, "cdCount")
    CreateModernSlider(p, "DefCount",  "Defensive Amount", -150, 1, 4, "defCount")
    CreateModernSlider(p, "HealCount", "Healing Amount",   -200, 1, 4, "healCount")

    -- Left Column (Sizes)
    CreateModernSlider(p, "MainSize",  "Main Attack Size", -250, 20, 100, "mainSize")
    CreateModernSlider(p, "QueueSize", "Next Attack Size", -300, 20, 100, "queueSize")
    CreateModernSlider(p, "CdSize",    "Cooldown Size",    -350, 20, 100, "cdSize")
    CreateModernSlider(p, "DefSize",   "Defensive Size",   -400, 20, 100, "defSize")
    CreateModernSlider(p, "HealSize",  "Healing Size",     -450, 20, 100, "healSize")

    -- Direction Toggles
    CreateDirectionToggle(p, "Offensive", 20,  -500, "offDir")
    CreateDirectionToggle(p, "Cooldowns", 120, -500, "cdDir")
    CreateDirectionToggle(p, "Defensive", 20,  -550, "defDir")
    CreateDirectionToggle(p, "Healing",   120, -550, "healDir")

    -- Visibility Toggles
    CreateVisibilityToggle(p, "Show Offensive", 20, -600, "showOff")
    CreateVisibilityToggle(p, "Show Cooldowns", 140, -600, "showCd")
    CreateVisibilityToggle(p, "Show Defensive", 20, -630, "showDef")
    CreateVisibilityToggle(p, "Show Healing",   140, -630, "showHeal")

    -- Right Column (DropZones)
    CreateVisualDropZone(p, "Offensive Priority (Not working as intended)", 340, -50,  "offPriority")
    CreateVisualDropZone(p, "Cooldown Priority",  340, -120, "cdPriority")
    CreateVisualDropZone(p, "Defensive Priority", 340, -190, "defPriority")
    CreateVisualDropZone(p, "Healing Priority",   340, -260, "healPriority")
    CreateVisualDropZone(p, "Whitelist",          340, -330, "whitelist")
    CreateVisualDropZone(p, "Blacklist",          340, -400, "blacklist")

    local lockBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    lockBtn:SetPoint("BOTTOMLEFT", 20, 15)
    lockBtn:SetSize(140, 25)
    lockBtn:SetText("Lock / Unlock")
    lockBtn:SetScript("OnClick", function()
        CONFIG.locked = not CONFIG.locked
        ApplyLock()
    end)

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", lockBtn, "RIGHT", 10, 0)
    resetBtn:SetSize(100, 25)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        local prof = GetRobUIProfile()
        if prof then
            prof[MODULE_ROOT_KEY] = prof[MODULE_ROOT_KEY] or {}
            prof[MODULE_ROOT_KEY][PLUGIN_ROOT] = prof[MODULE_ROOT_KEY][PLUGIN_ROOT] or {}

            local classToken = GetClassToken()
            local specId = GetSpecID()
            prof[MODULE_ROOT_KEY][PLUGIN_ROOT][classToken] = prof[MODULE_ROOT_KEY][PLUGIN_ROOT][classToken] or {}
            prof[MODULE_ROOT_KEY][PLUGIN_ROOT][classToken][specId] = {} -- wipe ONLY current spec bucket

            DB:ResetCache()
            CONFIG = DB:GetConfig(PLUGIN_ROOT)
            ns.CONFIG = CONFIG
            UpdateLayout()
            ApplyPositions()
            ApplyLock()
            if ns.ApplyVisibility then ns.ApplyVisibility() end
            UpdateAllVisuals()
        end
    end)

    local ieBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    ieBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    ieBtn:SetSize(120, 25)
    ieBtn:SetText("Import / Export")

    -- ========================================================================
    -- CUSTOM KEYBINDS TOGGLE
    -- ========================================================================
    local kbBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    kbBtn:SetPoint("LEFT", ieBtn, "RIGHT", 10, 0)
    kbBtn:SetSize(120, 25)
    kbBtn:SetText("Custom Binds")
    kbBtn:SetScript("OnClick", function()
    if ns.Keybinds and ns.Keybinds.Toggle then
        ns.Keybinds.Toggle()
    else
        print("|cffff0000RCA:|r KeyBinds.lua is not loaded. Check .toc filename/case.")
    end
end)

    -- Import / Export UI setup
    local ieFrame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    ieFrame:SetAllPoints()
    ieFrame:SetFrameLevel(p:GetFrameLevel() + 50)
    ieFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ieFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    ieFrame:Hide()

    local ieTitle = ieFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ieTitle:SetPoint("TOPLEFT", 20, -15)
    ieTitle:SetText("Import / Export Spells")

    local ieInfo = ieFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ieInfo:SetPoint("TOPLEFT", ieTitle, "BOTTOMLEFT", 0, -5)
    ieInfo:SetText("Copy the text below to backup your spell lists, or paste a string and click Import.")

    local ieScroll = CreateFrame("ScrollFrame", nil, ieFrame, "UIPanelScrollFrameTemplate")
    ieScroll:SetPoint("TOPLEFT", 20, -50)
    ieScroll:SetPoint("BOTTOMRIGHT", -40, 50)

    local ieEdit = CreateFrame("EditBox", nil, ieScroll)
    ieEdit:SetMultiLine(true)
    ieEdit:SetFontObject("ChatFontNormal")
    ieEdit:SetWidth(550)
    ieEdit:SetAutoFocus(false)
    ieScroll:SetScrollChild(ieEdit)

    local importExecuteBtn = CreateFrame("Button", nil, ieFrame, "UIPanelButtonTemplate")
    importExecuteBtn:SetPoint("BOTTOMLEFT", 20, 15)
    importExecuteBtn:SetSize(120, 25)
    importExecuteBtn:SetText("Import")
    importExecuteBtn:SetScript("OnClick", function()
        local success = ImportSettings(ieEdit:GetText())
        if success then
            print("|cff00ff00RCA:|r Settings imported successfully!")
            UpdateLayout()
            ns.UpdateAllVisuals()
            ieFrame:Hide()
        else
            print("|cffff0000RCA:|r Failed to import. Invalid format or empty string.")
        end
    end)

    local closeIEBtn = CreateFrame("Button", nil, ieFrame, "UIPanelButtonTemplate")
    closeIEBtn:SetPoint("LEFT", importExecuteBtn, "RIGHT", 10, 0)
    closeIEBtn:SetSize(120, 25)
    closeIEBtn:SetText("Close")
    closeIEBtn:SetScript("OnClick", function() ieFrame:Hide() end)

    ieBtn:SetScript("OnClick", function()
        ieEdit:SetText(ExportSettings())
        ieEdit:HighlightText()
        ieFrame:Show()
    end)

    p:SetScript("OnShow", function()
        CONFIG = DB:GetConfig(PLUGIN_ROOT)
        ns.CONFIG = CONFIG
        UpdateLayout()
        ApplyPositions()
        ApplyLock()
        if ns.ApplyVisibility then ns.ApplyVisibility() end
        UpdateAllVisuals()
    end)

    return p
end

ns.RCA_BuildSettingsPanel = BuildEmbeddedPanel

local settingsFrame = CreateFrame("Frame", "RCASettings", UIParent, "BackdropTemplate")
settingsFrame:SetSize(680, 680)
settingsFrame:SetPoint("CENTER")
settingsFrame:Hide()
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
settingsFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
settingsFrame:SetBackdropBorderColor(0, 0, 0, 1)

local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() settingsFrame:Hide() end)

local embedHolder = CreateFrame("Frame", nil, settingsFrame)
embedHolder:SetPoint("TOPLEFT", 0, 0)
embedHolder:SetPoint("BOTTOMRIGHT", 0, 0)

local embedPanel = BuildEmbeddedPanel(embedHolder)
embedPanel:Show()

SLASH_RCA1 = "/rca"
SlashCmdList["RCA"] = function()
    if settingsFrame:IsShown() then settingsFrame:Hide() else settingsFrame:Show() end
end

local didRegisterMenu = false
local function RegisterToRobUI()
    if didRegisterMenu then return end
    if not (R and type(R.RegisterModulePanel) == "function") then return end

    local holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()

    local p = BuildEmbeddedPanel(holder)
    p:Hide()

    R:RegisterModulePanel("Combat Assistant", p)
    didRegisterMenu = true
end

-- ============================================================================
-- GRIDCORE PLUGIN REGISTRATION
-- ============================================================================
local GRID_REGISTERED = false

local function RegisterGridPlugins()
    if GRID_REGISTERED then return true end

    local GC = GetGridCore()
    if not (GC and type(GC.RegisterPlugin) == "function") then
        return false
    end

    GC:RegisterPlugin(PLUGIN_OFF, {
        name = "Combat Assistant - Offensive",
        default = { gx = -240, gy = -120, scaleWithGrid = false, label = "CA Off" },
        build = function() return offParent end,
        standard = { position = true, size = false, scale = true },
        setScale = function(frame, s)
            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end
            frame:SetScale(s)
        end,
    })

    GC:RegisterPlugin(PLUGIN_CD, {
        name = "Combat Assistant - Cooldowns",
        default = { gx = -240, gy = -180, scaleWithGrid = false, label = "CA CD" },
        build = function() return cdParent end,
        standard = { position = true, size = false, scale = true },
        setScale = function(frame, s)
            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end
            frame:SetScale(s)
        end,
    })

    GC:RegisterPlugin(PLUGIN_DEF, {
        name = "Combat Assistant - Defensive",
        default = { gx = -240, gy = -60, scaleWithGrid = false, label = "CA Def" },
        build = function() return defParent end,
        standard = { position = true, size = false, scale = true },
        setScale = function(frame, s)
            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end
            frame:SetScale(s)
        end,
    })

    GC:RegisterPlugin(PLUGIN_HEAL, {
        name = "Combat Assistant - Healing",
        default = { gx = -240, gy = 0, scaleWithGrid = false, label = "CA Heal" },
        build = function() return healParent end,
        standard = { position = true, size = false, scale = true },
        setScale = function(frame, s)
            s = tonumber(s) or 1
            if s < 0.2 then s = 0.2 end
            if s > 3.0 then s = 3.0 end
            frame:SetScale(s)
        end,
    })

    GRID_REGISTERED = true
    return true
end

local function RegisterGridPluginsRetry(attempt)
    attempt = attempt or 1

    if RegisterGridPlugins() then
        ApplyPositions()
        ApplyLock()
        return
    end

    if attempt >= 60 then return end
    C_Timer.After(0.5, function()
        RegisterGridPluginsRetry(attempt + 1)
    end)
end

-- ============================================================================
-- QUEUE LOGIC & RENDERING
-- ============================================================================
local GCD_SPELL_ID = 61304

local function ApplyCooldownWithGCD(frame, spellID)
    local st, dur = 0, 0
    local cdInfo = C_Spell.GetSpellCooldown(spellID)

    if cdInfo then
        st, dur = cdInfo.startTime, cdInfo.duration
    end

    local isSecDur = ns.API.IsSecret(dur)

    if not isSecDur and (not dur or dur <= 0) then
        for slot = 1, 19 do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                local _, itemSpellID = GetItemSpell(itemID)
                if itemSpellID == spellID then
                    local ist, idur = GetInventoryItemCooldown("player", slot)
                    if ist and idur then
                        st, dur = ist, idur
                        isSecDur = ns.API.IsSecret(dur)
                        break
                    end
                end
            end
        end
    end

    if st and dur then
        pcall(function() frame.cd:SetCooldown(st, dur) end)
    else
        ClearCooldown(frame.cd)
        st, dur = 0, 0
    end

    local applyGcd = false
    if not isSecDur and type(dur) == "number" then
        if dur <= 0 then applyGcd = true end
    end

    if applyGcd then
        local gcd = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if gcd then
            local gst, gdur = gcd.startTime, gcd.duration
            if not ns.API.IsSecret(gdur) and type(gdur) == "number" and gdur > 0 then
                pcall(function() frame.cd:SetCooldown(gst, gdur) end)
                st, dur = gst, gdur
            end
        end
    end
end

local function Render(frame, baseSpellID)
    local spellID = ns.API.GetActualSpellID(baseSpellID)
    frame._spellID = spellID

    if spellID and spellID > 0 then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then
            frame.tex:SetTexture(info.iconID)

            -- Priority: Check Custom Binds first
            local bindText = ""
            if ns.CONFIG.customBinds and ns.CONFIG.customBinds[spellID] then
                bindText = ns.CONFIG.customBinds[spellID]
            else
                bindText = ns.Scanner.GetCachedHotkey(spellID)
            end
            frame.hotkey:SetText(bindText)

            ApplyCooldownWithGCD(frame, spellID)

            local usable, noMana = ns.API.IsSpellUsableSafe(spellID)
            local onRealCooldown = not ns.API.IsSpellReadySafe(spellID)

            if (not usable and noMana) or onRealCooldown then
                frame.tex:SetDesaturated(true)
                frame.tex:SetVertexColor(0.45, 0.45, 0.45)
                frame:SetAlpha(0.85)
            else
                frame.tex:SetDesaturated(false)
                frame.tex:SetVertexColor(1, 1, 1)
                frame:SetAlpha(1.0)
            end

            if GameTooltip:IsOwned(frame) then
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end
            return
        end
    end

    frame._spellID = nil
    frame.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.tex:SetDesaturated(true)
    frame.tex:SetVertexColor(1, 1, 1)
    frame.hotkey:SetText("")
    ClearCooldown(frame.cd)
    frame:SetAlpha(0.2)
    if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
end

local function AddUnique(queue, spellID, limit, forceKnown)
    if not spellID or spellID <= 0 then return end
    if IsBlacklisted(spellID) then return end
    if limit and #queue >= limit then return end
    if IsInArray(queue, spellID) then return end
    if not forceKnown and not IsKnownSafe(spellID) then return end
    queue[#queue + 1] = spellID
end

local function SmartFill(queue, priorityList, defaultList, limit)
    -- Pass 1: Ready spells
    if priorityList then
        for _, id in ipairs(priorityList) do
            if #queue >= limit then return end
            if not IsBlacklisted(id) and ns.API.IsSpellReadySafe(id) and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, limit, true)
            end
        end
    end

    if defaultList then
        for _, id in ipairs(defaultList) do
            if #queue >= limit then return end
            if not IsBlacklisted(id) and IsKnownSafe(id) and ns.API.IsSpellReadySafe(id) and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, limit, false)
            end
        end
    end

    -- Pass 2: Spells on cooldown
    if priorityList then
        for _, id in ipairs(priorityList) do
            if #queue >= limit then return end
            if not IsBlacklisted(id) and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, limit, true)
            end
        end
    end

    if defaultList then
        for _, id in ipairs(defaultList) do
            if #queue >= limit then return end
            if not IsBlacklisted(id) and IsKnownSafe(id) and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, limit, false)
            end
        end
    end
end

local function BuildOffQueue()
    local queue = {}
    local blizzSpells = ns.Queue.GetRawOffensiveSpells()

    if CONFIG.offPriority and #CONFIG.offPriority > 0 then
        local reordered = {}
        local used = {}

        for _, prioID in ipairs(CONFIG.offPriority) do
            for _, bID in ipairs(blizzSpells) do
                local actualB = ns.API.GetActualSpellID(bID)
                if (bID == prioID or actualB == prioID) and not used[bID] then
                    local isReady = ns.API.IsSpellReadySafe(bID)
                    local isUsable, noMana = ns.API.IsSpellUsableSafe(bID)

                    if isReady and isUsable and not noMana then
                        tinsert(reordered, bID)
                        used[bID] = true
                    end
                end
            end
        end

        for _, bID in ipairs(blizzSpells) do
            if not used[bID] then
                tinsert(reordered, bID)
            end
        end
        blizzSpells = reordered
    end

    for _, id in ipairs(blizzSpells) do
        if #queue >= CONFIG.offCount then break end
        if not IsBlacklisted(id) and not ns.Filter.PlayerHasBuff(id) then
            AddUnique(queue, id, CONFIG.offCount, true)
        end
    end

    return queue
end

local function BuildCDQueue()
    local queue = {}
    local selfHeals, majorCDs, majorBuffs = GetClassLists()
    SmartFill(queue, CONFIG.cdPriority, majorBuffs, CONFIG.cdCount)
    return queue
end

local function BuildDefQueue()
    local queue = {}
    if UnitIsDeadOrGhost("player") then return queue end

    local activeProcs = ns.Scanner.GetActiveProcs()
    if SpellDB and SpellDB.DEFENSIVE_SPELLS then
        for id in pairs(SpellDB.DEFENSIVE_SPELLS) do
            if not IsBlacklisted(id) and activeProcs[id] and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, CONFIG.defCount, false)
            end
        end
    end

    local selfHeals, majorCDs = GetClassLists()

    local defDefaults = {}
    local healthPct = ns.API.GetHealthPctSafe()
    if healthPct <= 0.60 then
        for _, v in ipairs(majorCDs) do tinsert(defDefaults, v) end
    end

    if #queue < CONFIG.defCount and SpellDB and SpellDB.DEFENSIVE_SPELLS then
        local tmp = {}
        for id in pairs(SpellDB.DEFENSIVE_SPELLS) do tinsert(tmp, id) end
        table_sort(tmp)
        for _, v in ipairs(tmp) do tinsert(defDefaults, v) end
    end

    SmartFill(queue, CONFIG.defPriority, defDefaults, CONFIG.defCount)
    return queue
end

local function BuildHealQueue()
    local queue = {}
    if UnitIsDeadOrGhost("player") then return queue end

    local activeProcs = ns.Scanner.GetActiveProcs()
    if SpellDB and SpellDB.HEALING_SPELLS then
        for id in pairs(SpellDB.HEALING_SPELLS) do
            if not IsBlacklisted(id) and activeProcs[id] and not ns.Filter.PlayerHasBuff(id) then
                AddUnique(queue, id, CONFIG.healCount, false)
            end
        end
    end

    local selfHeals = GetClassLists()

    local healDefaults = {}
    local healthPct = ns.API.GetHealthPctSafe()

    if healthPct <= 0.80 then
        for _, v in ipairs(selfHeals) do tinsert(healDefaults, v) end
    end

    SmartFill(queue, CONFIG.healPriority, healDefaults, CONFIG.healCount)
    return queue
end

local function UpdateAll()
    CONFIG = DB:GetConfig(PLUGIN_ROOT)
    ns.CONFIG = CONFIG

    -- Only process and render if the parent frame is set to visible in the config
    if CONFIG.showOff then
        local offQueue = BuildOffQueue()
        for i = 1, CONFIG.offCount do Render(offIcons[i], offQueue[i]) end
    end

    if CONFIG.showCd then
        local cdQueue = BuildCDQueue()
        for i = 1, CONFIG.cdCount do Render(cdIcons[i], cdQueue[i]) end
    end

    if CONFIG.showDef then
        local defQueue = BuildDefQueue()
        for i = 1, CONFIG.defCount do Render(defIcons[i], defQueue[i]) end
    end

    if CONFIG.showHeal then
        local healQueue = BuildHealQueue()
        for i = 1, CONFIG.healCount do Render(healIcons[i], healQueue[i]) end
    end
end

-- ============================================================================
-- HIGH-PERFORMANCE DRIVER (OnUpdate)
-- ============================================================================
local driver = CreateFrame("Frame")
local updateTimer = 0

local COMBAT_UPDATE_RATE = 0.15  -- Balanced, responsive in combat (150ms)
local IDLE_UPDATE_RATE = 0.5     -- Slowed down when idle (500ms)

driver:SetScript("OnUpdate", function(_, elapsed)
    updateTimer = updateTimer + (elapsed or 0)

    local inCombat = UnitAffectingCombat("player")
    local isHidden = (not offParent:IsShown() and not cdParent:IsShown() and not defParent:IsShown() and not healParent:IsShown())

    local rate = COMBAT_UPDATE_RATE
    if isHidden or not inCombat then
        rate = IDLE_UPDATE_RATE
    end

    -- INSTANT EXIT Throttle. Kills CPU usage 99% of frames.
    if updateTimer < rate then return end

    if not isHidden then
        UpdateAll()
    end

    updateTimer = 0
end)

-- ============================================================================
-- SPEC/CLASS INTELLIGENT SWAP (combat-safe)
-- ============================================================================
local pendingSwapRefresh = false
local lastSpec = -1
local lastClass = ""

local function ApplySwapRefresh()
    DB:ResetCache()
    CONFIG = DB:GetConfig(PLUGIN_ROOT)
    ns.CONFIG = CONFIG

    UpdateLayout()
    ApplyPositions()
    ApplyLock()
    if ns.ApplyVisibility then ns.ApplyVisibility() end
    UpdateAllVisuals()

    -- also refresh scanner hotkey cache if exists
    if ns.Scanner and ns.Scanner.UpdateActionBarCache then
        ns.Scanner.UpdateActionBarCache()
    end
end

local function RequestSwapRefresh()
    if InCombatLockdown() then
        pendingSwapRefresh = true
        return
    end
    pendingSwapRefresh = false
    ApplySwapRefresh()
end

local SwapEvents = CreateFrame("Frame")
SwapEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
SwapEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
SwapEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
SwapEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

SwapEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingSwapRefresh then
            RequestSwapRefresh()
        end
        return
    end

    -- Spec/Class change detection
    local c = GetClassToken()
    local s = GetSpecID()

    if c ~= lastClass or s ~= lastSpec then
        lastClass = c
        lastSpec = s
        RequestSwapRefresh()
    end
end)

-- ============================================================================
-- INIT
-- ============================================================================
local didInit = false

local function InitOnce()
    if didInit then return end
    didInit = true

    lastClass = GetClassToken()
    lastSpec = GetSpecID()

    CONFIG = DB:GetConfig(PLUGIN_ROOT)
    ns.CONFIG = CONFIG

    UpdateLayout()
    ApplyPositions()
    ApplyLock()
    if ns.ApplyVisibility then ns.ApplyVisibility() end
    UpdateAllVisuals()

    RegisterToRobUI()
    RegisterGridPluginsRetry(1)
end

local E = CreateFrame("Frame")
E:RegisterEvent("PLAYER_LOGIN")
E:SetScript("OnEvent", function()
    if GetRobUIProfile() then
        InitOnce()
    else
        C_Timer.After(0.5, function()
            if GetRobUIProfile() then InitOnce() end
        end)
    end
end)