-- ============================================================================
-- Auras_v2.lua (RobUI) - Buffs & Debuffs (12.0/Midnight SAFE)
-- Features: Dynamic growth, Filtering, Tooltip IDs, GridCore (rgrid) Integration
-- FIXED: Added "Pre-Combat Snapshot" filter. Hides pre-combat buffs during encounters.
-- FIXED: Scrubs secret values BEFORE using as table keys (prevents "table index is secret").
-- NOTE: This is an interim solution until Blizzard provides official aura filtering.
-- ============================================================================
local ADDON, ns = ...
ns.auras_v2 = ns.auras_v2 or {}
local A = ns.auras_v2
local R = _G.Robui

local pcall       = pcall
local floor       = math.floor
local max         = math.max
local tonumber    = tonumber
local type        = type
local select      = select
local ipairs      = ipairs
local next        = next
local pairs       = pairs

local CreateFrame = CreateFrame
local UnitExists  = UnitExists
local UnitAura    = UnitAura
local GameTooltip = GameTooltip
local UIParent    = UIParent

local CUA = C_UnitAuras
local C_Spell = C_Spell
local GetAuraDataByIndex = CUA and CUA.GetAuraDataByIndex or nil
local GetAuraDuration    = CUA and CUA.GetAuraDuration or nil

local wipe = table.wipe or wipe
local scrubsecretvalues  = _G.scrubsecretvalues

local DEFAULT_MAX   = 10
local DEFAULT_SIZE  = 24
local DEFAULT_GAP   = 2

-- =========================================================
-- Combat Snapshot System (The Genius Filter)
-- =========================================================
local PreCombatAuras = { player = {}, target = {} }
local InCombatLockdown = false

-- Scrub secret number -> normal number (or nil)
local function ScrubNumber(v)
    if v == nil then return nil end
    if scrubsecretvalues then
        local sv = select(1, scrubsecretvalues(v))
        if type(sv) == "number" then return sv end
        return nil
    end
    if type(v) == "number" then return v end
    return nil
end

-- Safely get a scrubbed auraInstanceID from aura table
local function GetAuraInstanceKey(aura)
    if not aura then return nil end
    local ok, v = pcall(function() return aura.auraInstanceID end)
    if not ok then return nil end
    return ScrubNumber(v)
end

-- Safely get a scrubbed spellId from aura table
local function GetAuraSpellKey(aura)
    if not aura then return nil end
    local ok, v = pcall(function() return aura.spellId end)
    if not ok then return nil end
    return ScrubNumber(v)
end

local function SnapshotUnitAuras(unit)
    if InCombatLockdown or not unit or not UnitExists(unit) then return end
    PreCombatAuras[unit] = PreCombatAuras[unit] or {}
    wipe(PreCombatAuras[unit])

    if GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not aura then break end
            local aid = GetAuraInstanceKey(aura)
            if aid then
                PreCombatAuras[unit][aid] = true
            end
        end
        for i = 1, 40 do
            local ok, aura = pcall(GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not aura then break end
            local aid = GetAuraInstanceKey(aura)
            if aid then
                PreCombatAuras[unit][aid] = true
            end
        end
    end
end

-- =========================================================
-- GridCore Helpers
-- =========================================================
local function GC_IsEditMode()
    local GC = ns and ns.GridCore
    if not GC then return false end
    if type(GC.IsEditMode) == "function" then
        local ok, r = pcall(GC.IsEditMode, GC)
        if ok and r then return true end
    end
    return false
end

-- =========================================================
-- Helpers
-- =========================================================
local function SafeSetFont(fs, path, size, flags)
    if not (fs and fs.SetFont) then return end
    size  = tonumber(size) or 12
    flags = flags or ""
    local ok = pcall(fs.SetFont, fs, path, size, flags)
    if not ok then
        pcall(fs.SetFont, fs, (_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), size, flags)
    end
end

local function GetSpellTextureSafe(spellId)
    if not spellId or not (C_Spell and C_Spell.GetSpellTexture) then return nil end
    local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
    return ok and tex or nil
end

local function SafeShown(obj)
    if not obj then return false end
    local ok, v = pcall(function() return obj:IsShown() end)
    return ok and v or false
end

local function StyleCooldownCountdown(cd, iconSize)
    if not (cd and cd.GetCountdownFontString) then return end
    local fs = cd:GetCountdownFontString()
    if not fs then return end
    local font = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local fsz  = max(9, floor((tonumber(iconSize) or 18) * 0.62))
    SafeSetFont(fs, font, fsz, "OUTLINE")
    fs:SetShadowOffset(0, 0)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", cd, "CENTER", 0, 0)
    fs:SetDrawLayer("OVERLAY", 7)
    fs:Show()
end

-- =========================================================
-- Slot Creation & Collection
-- =========================================================
local function CreateAuraSlot(parent, index, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f:Hide()
    f:EnableMouse(true)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(tex)
    cd:SetDrawEdge(false)
    cd:SetDrawSwipe(true)
    cd:SetHideCountdownNumbers(false)
    cd:Hide()
    StyleCooldownCountdown(cd, size)

    local count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 2, 0)
    count:Hide()
    SafeSetFont(count, _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", max(9, floor(size * 0.55)), "OUTLINE")
    count:SetText("")

    f.icon = tex; f.cd = cd; f.count = count

    f:SetScript("OnEnter", function(self)
        if not self or not SafeShown(self) then return end
        if not self._unit or not self._auraIndex or not self._filter then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", -2, -2)
        local ok = pcall(function() GameTooltip:SetUnitAura(self._unit, self._auraIndex, self._filter) end)

        local okSpell, sId = pcall(function() return self._spellId end)
        if (not ok or GameTooltip:NumLines() == 0) and okSpell and sId then
            pcall(function() GameTooltip:SetSpellByID(sId) end)
        end
        if okSpell and sId then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Spell ID:", tostring(sId), 1, 0.82, 0, 1, 1, 1)
        end
        if GameTooltip:NumLines() > 0 then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return f
end

-- Build safe string-key maps for BL/WL (numbers stored as strings)
local function BuildKeyMap(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for sid, active in pairs(src) do
        if active then
            out[tostring(sid)] = true
        end
    end
    return out
end

local function Collect(unit, filter, maxN, cfg)
    if not unit or not UnitExists(unit) then return nil end

    local list = {}

    cfg = cfg or {}
    local blMap = cfg._blMap
    local wlMap = cfg._wlMap
    if not blMap or not wlMap or cfg._mapsDirty then
        cfg._blMap = BuildKeyMap(cfg.blacklist)
        cfg._wlMap = BuildKeyMap(cfg.whitelist)
        cfg._mapsDirty = false
        blMap = cfg._blMap
        wlMap = cfg._wlMap
    end

    local hasWL = false
    for _ in pairs(wlMap) do hasWL = true break end

    if GetAuraDataByIndex then
        for i = 1, 40 do
            local aura
            local ok = pcall(function() aura = GetAuraDataByIndex(unit, i, filter) end)
            if (not ok) or (not aura) or (not aura.icon) then break end

            local pass = true

            -- Pre-combat snapshot filter (uses scrubbed auraInstanceID)
            if pass and InCombatLockdown then
                local aid = GetAuraInstanceKey(aura)
                if aid and PreCombatAuras[unit] and PreCombatAuras[unit][aid] then
                    pass = false
                end
            end

            -- SpellID BL/WL filter (uses scrubbed spellId)
            if pass then
                local sid = GetAuraSpellKey(aura)
                if sid then
                    local k = tostring(sid)

                    -- blacklist
                    if blMap and blMap[k] then
                        pass = false
                    end

                    -- whitelist mode
                    if pass and hasWL then
                        if not (wlMap and wlMap[k]) then
                            pass = false
                        end
                    end
                else
                    -- If whitelist is active and we can't resolve a safe spellId -> block (fail closed)
                    if hasWL then
                        pass = false
                    end
                end
            end

            if pass then
                list[#list + 1] = {
                    auraIndex = i,
                    auraInstanceID = aura.auraInstanceID,
                    icon = aura.icon,
                    count = aura.applications,
                    spellId = aura.spellId
                }
                if #list >= maxN then break end
            end
        end
        if #list > 0 then return list end
    end

    return #list > 0 and list or nil
end

-- =========================================================
-- Layout & Holder Management
-- =========================================================
local function LayoutSlots(holder, maxN, size, gap, growth)
    local width, height = size, size
    for i = 1, maxN do
        local f = holder._slots[i]
        f:ClearAllPoints()

        if growth == "LEFT" then
            f:SetPoint("RIGHT", holder, "RIGHT", -(i - 1) * (size + gap), 0)
            width = maxN * size + (maxN - 1) * gap
        elseif growth == "UP" then
            f:SetPoint("BOTTOM", holder, "BOTTOM", 0, (i - 1) * (size + gap))
            height = maxN * size + (maxN - 1) * gap
        elseif growth == "DOWN" then
            f:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (size + gap))
            height = maxN * size + (maxN - 1) * gap
        else -- RIGHT
            f:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + gap), 0)
            width = maxN * size + (maxN - 1) * gap
        end
    end
    holder:SetSize(max(1, width), max(1, height))
end

local function RebuildSlots(holder, maxN, size, gap, growth)
    maxN = max(1, tonumber(maxN) or 1)
    size = max(8, tonumber(size) or 8)
    gap  = max(0, tonumber(gap) or 0)
    growth = growth or "RIGHT"

    if holder._max == maxN and holder._size == size and holder._gap == gap and holder._growth == growth then
        LayoutSlots(holder, maxN, size, gap, growth)
        return
    end

    for i = 1, #holder._slots do
        local b = holder._slots[i]
        if b then b:Hide() b:SetParent(nil) end
    end
    holder._slots = {}
    holder._max = maxN; holder._size = size; holder._gap = gap; holder._growth = growth

    for i = 1, maxN do
        holder._slots[i] = CreateAuraSlot(holder, i, size)
    end
    LayoutSlots(holder, maxN, size, gap, growth)
end

local function EnsureHolder(key, unit, filter)
    A._holders = A._holders or {}
    if A._holders[key] then return A._holders[key] end

    local h = CreateFrame("Frame", "RobUI_AurasV2Holder_" .. key, UIParent)
    h:SetFrameStrata("LOW")
    h:Show()
    h._unit = unit; h._filter = filter; h._slots = {}

    A._holders[key] = h
    return h
end

local function UpdateHolder(holder, key, unit, filter, cfg, previewEnabled)
    if not holder then return end
    cfg = cfg or {}

    if cfg.enabled == false or cfg.shown == false then
        holder:Hide()
        return
    end

    local maxN   = cfg.max or DEFAULT_MAX
    local size   = cfg.size or DEFAULT_SIZE
    local gap    = cfg.gap or DEFAULT_GAP
    local growth = cfg.growth or "RIGHT"

    RebuildSlots(holder, maxN, size, gap, growth)

    local isEditMode = GC_IsEditMode()
    local showDummy = (isEditMode or previewEnabled) == true

    if unit == "target" and (not UnitExists("target")) and (not showDummy) then
        holder:Hide()
        return
    end

    holder:Show()

    local activeFilter = filter
    if cfg.onlyMine then activeFilter = activeFilter .. "|PLAYER" end

    local list = Collect(unit, activeFilter, maxN, cfg)

    for slot = 1, maxN do
        local b = holder._slots[slot]
        local a = list and list[slot] or nil

        if a then
            b._unit = unit; b._filter = activeFilter; b._auraIndex = a.auraIndex; b._spellId = a.spellId; b._auraInstanceID = a.auraInstanceID

            local okSet = pcall(function() b.icon:SetTexture(a.icon) end)
            if (not okSet) or (not b.icon:GetTexture()) then
                local tex = GetSpellTextureSafe(a.spellId)
                if tex then pcall(function() b.icon:SetTexture(tex) end) end
            end

            -- Safely parse count
            local c = 0
            pcall(function()
                local val = tonumber(a.count)
                if val and val > 1 then c = val end
            end)

            if c > 1 then
                b.count:SetText(c)
                b.count:Show()
            else
                b.count:SetText("")
                b.count:Hide()
            end

            if GetAuraDuration and b._auraInstanceID and b.cd.SetCooldownFromDurationObject then
                local durObj
                local okDur = pcall(function() durObj = GetAuraDuration(unit, b._auraInstanceID) end)
                if okDur and durObj then
                    pcall(b.cd.SetCooldownFromDurationObject, b.cd, durObj, true)
                    b.cd:Show()
                    StyleCooldownCountdown(b.cd, size)
                else
                    b.cd:Hide()
                end
            else
                b.cd:Hide()
            end

            b:Show()

        elseif showDummy then
            b._unit, b._filter, b._auraIndex, b._spellId, b._auraInstanceID = nil, nil, nil, nil, nil
            b.icon:SetTexture(134400)
            b.count:SetText(""); b.count:Hide()
            b.cd:Hide()
            b:Show()

        else
            b._unit, b._filter, b._auraIndex, b._spellId, b._auraInstanceID = nil, nil, nil, nil, nil
            b.icon:SetTexture(nil)
            b.count:SetText(""); b.count:Hide()
            b.cd:Hide()
            b:Hide()
        end
    end
end

-- =========================================================
-- DB
-- =========================================================
function A:GetDB()
    if R and R.Database and R.Database.profile then
        R.Database.profile.auras_v2 = R.Database.profile.auras_v2 or {
            enabled = true,
            preview = false,

            playerDebuffs = { shown = true, onlyMine = false, size = 24, max = 10, gap = 2, growth = "RIGHT", blacklist = {}, whitelist = {} },
            playerBuffs   = { shown = true, onlyMine = false, size = 24, max = 10, gap = 2, growth = "RIGHT", blacklist = {}, whitelist = {} },
            targetDebuffs = { shown = true, onlyMine = false, size = 24, max = 10, gap = 2, growth = "RIGHT", blacklist = {}, whitelist = {} },
            targetBuffs   = { shown = true, onlyMine = false, size = 24, max = 10, gap = 2, growth = "RIGHT", blacklist = {}, whitelist = {} }
        }
        return R.Database.profile.auras_v2
    end
    return nil
end

-- =========================================================
-- GridCore Plugin Registration
-- =========================================================
local function RegisterGridPlugins()
    if A._gridRegistered then return end
    if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

    local plugins = {
        { id = "ct_auras_p_debuffs", title = "Player Debuffs", key = "playerDebuffs", unit = "player", filter = "HARMFUL", defGX = -240, defGY = 80 },
        { id = "ct_auras_p_buffs",   title = "Player Buffs",   key = "playerBuffs",   unit = "player", filter = "HELPFUL", defGX = -240, defGY = 90 },
        { id = "ct_auras_t_debuffs", title = "Target Debuffs", key = "targetDebuffs", unit = "target", filter = "HARMFUL", defGX = 240,  defGY = 80 },
        { id = "ct_auras_t_buffs",   title = "Target Buffs",   key = "targetBuffs",   unit = "target", filter = "HELPFUL", defGX = 240,  defGY = 90 },
    }

    for _, p in ipairs(plugins) do
        ns.GridCore:RegisterPlugin(p.id, {
            name = "Auras: " .. p.title,
            default = { gx = p.defGX, gy = p.defGY, scaleWithGrid = false, label = p.title },

            build = function()
                return EnsureHolder(p.key, p.unit, p.filter)
            end,

            standard = { position = true, size = false, scale = true },

            setScale = function(frame, s)
                if not frame then return end
                s = tonumber(s) or 1
                pcall(frame.SetScale, frame, s)
            end,
        })
    end

    A._gridRegistered = true
end

function A:ApplyAll()
    local db = self:GetDB()
    if not db then return end

    self.playerDebuffs = self.playerDebuffs or EnsureHolder("playerDebuffs", "player", "HARMFUL")
    self.playerBuffs   = self.playerBuffs   or EnsureHolder("playerBuffs",   "player", "HELPFUL")
    self.targetDebuffs = self.targetDebuffs or EnsureHolder("targetDebuffs", "target", "HARMFUL")
    self.targetBuffs   = self.targetBuffs   or EnsureHolder("targetBuffs",   "target", "HELPFUL")

    if db.enabled == false then
        self.playerDebuffs:Hide(); self.playerBuffs:Hide()
        self.targetDebuffs:Hide(); self.targetBuffs:Hide()
        return
    end

    local preview = (db.preview == true)

    UpdateHolder(self.playerDebuffs, "playerDebuffs", "player", "HARMFUL", db.playerDebuffs, preview)
    UpdateHolder(self.playerBuffs,   "playerBuffs",   "player", "HELPFUL", db.playerBuffs,   preview)
    UpdateHolder(self.targetDebuffs, "targetDebuffs", "target", "HARMFUL", db.targetDebuffs, preview)
    UpdateHolder(self.targetBuffs,   "targetBuffs",   "target", "HELPFUL", db.targetBuffs,   preview)
end

-- =========================================================
-- Events
-- =========================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        InCombatLockdown = true
        A:ApplyAll()

    elseif event == "PLAYER_REGEN_ENABLED" then
        InCombatLockdown = false
        SnapshotUnitAuras("player")
        SnapshotUnitAuras("target")
        A:ApplyAll()

    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function()
            RegisterGridPlugins()
            SnapshotUnitAuras("player")
            SnapshotUnitAuras("target")
            A:ApplyAll()
        end)

    elseif event == "UNIT_AURA" then
        if not InCombatLockdown and (unit == "player" or unit == "target") then
            SnapshotUnitAuras(unit)
        end

        local db = A:GetDB(); if not db or db.enabled == false then return end
        local preview = (db.preview == true)

        if unit == "player" then
            if A.playerDebuffs then UpdateHolder(A.playerDebuffs, "playerDebuffs", "player", "HARMFUL", db.playerDebuffs, preview) end
            if A.playerBuffs   then UpdateHolder(A.playerBuffs,   "playerBuffs",   "player", "HELPFUL", db.playerBuffs,   preview) end
        elseif unit == "target" then
            if A.targetDebuffs then UpdateHolder(A.targetDebuffs, "targetDebuffs", "target", "HARMFUL", db.targetDebuffs, preview) end
            if A.targetBuffs   then UpdateHolder(A.targetBuffs,   "targetBuffs",   "target", "HELPFUL", db.targetBuffs,   preview) end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if not InCombatLockdown then
            SnapshotUnitAuras("target")
        end

        local db = A:GetDB(); if not db or db.enabled == false then return end
        local preview = (db.preview == true)

        if A.targetDebuffs then UpdateHolder(A.targetDebuffs, "targetDebuffs", "target", "HARMFUL", db.targetDebuffs, preview) end
        if A.targetBuffs   then UpdateHolder(A.targetBuffs,   "targetBuffs",   "target", "HELPFUL", db.targetBuffs,   preview) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InCombatLockdown = false
        SnapshotUnitAuras("player")
        SnapshotUnitAuras("target")
        A:ApplyAll()
    end
end)