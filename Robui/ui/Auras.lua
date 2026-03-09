-- ============================================================================
-- auras.lua (RobUI) - Buffs & Debuffs (12.0/Midnight SAFE, DurationObject)
-- Features: DurationObject Cooldowns, Combat Snapshot, Tooltip IDs, BL/WL Filters
-- FIXED: DB Initialization so settings and checkboxes save properly.
-- FIXED: Per-group enabled + shown supported (Enable + Show/Hide).
--
-- SAFE CPU FIX (REAL):
--   1) NO StyleCooldownCountdown() inside UpdateHolder (only on slot create/rebuild)
--   2) Cache auraInstanceID per slot so GetAuraDuration() is not spammed
--   3) Throttle/Coalesce UNIT_AURA + TARGET_CHANGED updates (per unit)
-- ============================================================================

local ADDON, ns = ...
ns.auras = ns.auras or {}
local A = ns.auras

local R = _G.Robui

-- ------------------------------------------------------------
-- CPU sampler hookup (optional)
-- ------------------------------------------------------------
local CPU = _G.RobuiCPU
local Probe = CPU and CPU.Probe or nil
local function Wrap(tag, fn)
    if Probe then return Probe(tag, fn) end
    return fn
end

-- ------------------------------------------------------------
-- API locals
-- ------------------------------------------------------------
local CreateFrame = CreateFrame
local UnitExists  = UnitExists
local UnitAura    = UnitAura
local GameTooltip = GameTooltip
local pcall       = pcall
local floor       = math.floor
local max         = math.max
local tonumber    = tonumber
local type        = type
local select      = select
local ipairs      = ipairs
local pairs       = pairs
local wipe        = table.wipe or wipe
local tostring    = tostring

local CUA = C_UnitAuras
local C_Spell = C_Spell

local GetAuraDataByIndex = CUA and CUA.GetAuraDataByIndex or nil
local GetAuraDuration    = CUA and CUA.GetAuraDuration or nil

local scrubsecretvalues  = _G.scrubsecretvalues

-- ------------------------------------------------------------
-- CONFIG (defaults if DB missing)
-- ------------------------------------------------------------
local DEFAULT_MAX   = 10
local DEFAULT_SIZE  = 18
local DEFAULT_GAP   = 2

local ANCHORS = {
    player = "RobUI_PlayerFrame",
    target = "RobUI_TargetFrame",
}

-- ------------------------------------------------------------
-- Safe font apply
-- ------------------------------------------------------------
local function SafeSetFont(fs, path, size, flags)
    if not (fs and fs.SetFont) then return end
    size  = tonumber(size) or 12
    flags = flags or ""

    local ok = pcall(fs.SetFont, fs, path, size, flags)
    if not ok then
        pcall(fs.SetFont, fs, (_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), size, flags)
    end
end

-- ------------------------------------------------------------
-- Helpers & Security (12.0)
-- ------------------------------------------------------------
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

local function SafeToID(v)
    local n = ScrubNumber(v)
    if type(n) == "number" and n > 0 then return n end
    return nil
end

local function GetAuraInstanceKey(aura)
    if not aura then return nil end
    local ok, v = pcall(function() return aura.auraInstanceID end)
    if not ok then return nil end
    return ScrubNumber(v)
end

local function GetSpellTextureSafe(spellId)
    if not spellId or not (C_Spell and C_Spell.GetSpellTexture) then return nil end
    local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
    if ok then return tex end
    return nil
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

-- ------------------------------------------------------------
-- Combat Snapshot System (Pre-Combat Filter)
-- ------------------------------------------------------------
local PreCombatAuras = { player = {}, target = {} }
local InCombatLockdown = false

local function SnapshotUnitAuras(unit)
    if InCombatLockdown or not unit or not UnitExists(unit) then return end
    PreCombatAuras[unit] = PreCombatAuras[unit] or {}
    wipe(PreCombatAuras[unit])

    if GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not aura then break end
            local aid = GetAuraInstanceKey(aura)
            if aid then PreCombatAuras[unit][aid] = true end
        end
        for i = 1, 40 do
            local ok, aura = pcall(GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not aura then break end
            local aid = GetAuraInstanceKey(aura)
            if aid then PreCombatAuras[unit][aid] = true end
        end
    end
end
SnapshotUnitAuras = Wrap("Auras:SnapshotUnitAuras", SnapshotUnitAuras)

-- ------------------------------------------------------------
-- Slot UI
-- ------------------------------------------------------------
local function CreateAuraSlot(parent, index, size, gap)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f:SetPoint("LEFT", (index - 1) * (size + gap), 0)
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

    -- IMPORTANT: style ONCE (not every update)
    StyleCooldownCountdown(cd, size)

    local count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 2, 0)
    count:Hide()

    do
        local font = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local fs = max(9, floor(size * 0.55))
        SafeSetFont(count, font, fs, "OUTLINE")
    end

    count:SetText("")

    f.icon  = tex
    f.cd    = cd
    f.count = count

    f._unit           = nil
    f._auraIndex      = nil
    f._spellId        = nil
    f._filter         = nil
    f._auraInstanceID = nil

    -- NEW: cooldown cache (so GetAuraDuration isn't spammed)
    f._lastAuraInstanceID = nil

    f:SetScript("OnEnter", function(self)
        if not self or not SafeShown(self) then return end
        if not self._unit or not self._auraIndex or not self._filter then return end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", -2, -2)

        local ok = pcall(function()
            GameTooltip:SetUnitAura(self._unit, self._auraIndex, self._filter)
        end)

        local okSpell, sId = pcall(function() return self._spellId end)
        if (not ok or GameTooltip:NumLines() == 0) and okSpell and sId then
            pcall(function() GameTooltip:SetSpellByID(sId) end)
        end

        if okSpell and sId then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Spell ID:", tostring(sId), 1, 0.82, 0, 1, 1, 1)
        end

        if GameTooltip:NumLines() > 0 then
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    end)

    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return f
end

-- ------------------------------------------------------------
-- BL/WL Map Builder
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- Collect
-- ------------------------------------------------------------
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

            if pass and InCombatLockdown then
                local aid = GetAuraInstanceKey(aura)
                if aid and PreCombatAuras[unit] and PreCombatAuras[unit][aid] then
                    pass = false
                end
            end

            if pass then
                local sid = SafeToID(aura.spellId)
                if sid then
                    local k = tostring(sid)

                    if blMap and blMap[k] then
                        pass = false
                    end

                    if pass and hasWL then
                        if not (wlMap and wlMap[k]) then
                            pass = false
                        end
                    end
                else
                    if hasWL then pass = true end
                end
            end

            if pass then
                list[#list + 1] = {
                    auraIndex      = i,
                    auraInstanceID = aura.auraInstanceID,
                    icon           = aura.icon,
                    count          = aura.applications,
                    spellId        = aura.spellId,
                }
                if #list >= maxN then break end
            end
        end
        if #list > 0 then return list end
    end

    if UnitAura then
        for i = 1, 40 do
            local name, texture, count, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
            if not name then break end

            local pass = true
            local sid = SafeToID(spellId)

            if sid then
                local k = tostring(sid)
                if blMap and blMap[k] then pass = false end
                if pass and hasWL and not (wlMap and wlMap[k]) then pass = false end
            end

            if pass then
                list[#list + 1] = {
                    auraIndex      = i,
                    auraInstanceID = nil,
                    icon           = texture,
                    count          = count,
                    spellId        = spellId,
                }
                if #list >= maxN then break end
            end
        end
    end

    if #list == 0 then return nil end
    return list
end
Collect = Wrap("Auras:Collect", Collect)

-- ------------------------------------------------------------
-- Holder creation
-- ------------------------------------------------------------
local function EnsureHolder(key, unit, filter)
    A._holders = A._holders or {}
    if A._holders[key] then return A._holders[key] end

    local h = CreateFrame("Frame", "RobUI_AurasHolder_" .. key, UIParent)
    h:SetFrameStrata("TOOLTIP")
    h:SetFrameLevel(9000)
    h:SetIgnoreParentAlpha(true)
    h:Show()

    h._unit   = unit
    h._filter = filter
    h._slots  = {}
    h._max    = DEFAULT_MAX
    h._size   = DEFAULT_SIZE
    h._gap    = DEFAULT_GAP

    h:SetSize(h._max * h._size + (h._max - 1) * h._gap, h._size)

    for i = 1, h._max do
        h._slots[i] = CreateAuraSlot(h, i, h._size, h._gap)
    end

    A._holders[key] = h
    return h
end

local function RebuildSlots(holder, maxN, size, gap)
    local safeMaxN = tonumber(maxN) or 1
    safeMaxN = max(1, safeMaxN)

    local safeSize = tonumber(size) or 8
    safeSize = max(8, safeSize)

    local safeGap = tonumber(gap) or 0
    safeGap = max(0, safeGap)

    if holder._max == safeMaxN and holder._size == safeSize and holder._gap == safeGap then
        holder:SetSize(safeMaxN * safeSize + (safeMaxN - 1) * safeGap, safeSize)
        return
    end

    for i = 1, #holder._slots do
        local b = holder._slots[i]
        if b then b:Hide() b:SetParent(nil) end
    end
    holder._slots = {}

    holder._max  = safeMaxN
    holder._size = safeSize
    holder._gap  = safeGap

    holder:SetSize(safeMaxN * safeSize + (safeMaxN - 1) * safeGap, safeSize)

    for i = 1, safeMaxN do
        holder._slots[i] = CreateAuraSlot(holder, i, safeSize, safeGap)
    end
end

-- ------------------------------------------------------------
-- Update holder (FAST)
-- ------------------------------------------------------------
local function UpdateHolder(holder, unit, filter, cfg)
    if not holder then return end
    cfg = cfg or {}

    if cfg.enabled == false or cfg.shown == false then
        holder:Hide()
        return
    end

    if unit == "target" and not UnitExists("target") then
        holder:Hide()
        return
    end

    local maxN = cfg.max or holder._max or DEFAULT_MAX
    local size = cfg.size or holder._size or DEFAULT_SIZE
    local gap  = cfg.gap or holder._gap or DEFAULT_GAP
    RebuildSlots(holder, maxN, size, gap)

    holder:Show()

    local activeFilter = filter
    if cfg.onlyMine then activeFilter = activeFilter .. "|PLAYER" end

    local list = Collect(unit, activeFilter, maxN, cfg)
    local slots = holder._slots

    for slot = 1, (tonumber(maxN) or DEFAULT_MAX) do
        local b = slots[slot]
        local a = list and list[slot] or nil

        if a then
            b._unit           = unit
            b._filter         = activeFilter
            b._auraIndex      = a.auraIndex
            b._spellId        = a.spellId
            b._auraInstanceID = a.auraInstanceID

            local okSet = pcall(function() b.icon:SetTexture(a.icon) end)
            if (not okSet) or (not b.icon:GetTexture()) then
                local tex = GetSpellTextureSafe(a.spellId)
                if tex then pcall(function() b.icon:SetTexture(tex) end) end
            end

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

            -- IMPORTANT: no countdown styling here (only on slot create/rebuild)
            -- IMPORTANT: cache auraInstanceID so GetAuraDuration isn't spammed
            if GetAuraDuration and b._auraInstanceID and b.cd.SetCooldownFromDurationObject then
                if b._lastAuraInstanceID == b._auraInstanceID and b.cd:IsShown() then
                    -- no-op; cooldown continues ticking
                else
                    b._lastAuraInstanceID = b._auraInstanceID

                    local durObj
                    local okDur = pcall(function()
                        durObj = GetAuraDuration(unit, b._auraInstanceID)
                    end)

                    if okDur and durObj then
                        pcall(b.cd.SetCooldownFromDurationObject, b.cd, durObj, true)
                        b.cd:Show()
                    else
                        b.cd:Hide()
                    end
                end
            else
                b._lastAuraInstanceID = nil
                b.cd:Hide()
            end

            b:Show()
        else
            b._unit, b._filter, b._auraIndex, b._spellId, b._auraInstanceID = nil, nil, nil, nil, nil
            b._lastAuraInstanceID = nil
            b.icon:SetTexture(nil)
            b.count:SetText("")
            b.count:Hide()
            b.cd:Hide()
            b:Hide()
        end
    end
end
UpdateHolder = Wrap("Auras:UpdateHolder", UpdateHolder)

-- ------------------------------------------------------------
-- Anchor to RobUI frames
-- ------------------------------------------------------------
local function AnchorHolder(holder, unitKey, where, pad)
    local anchorName = ANCHORS[unitKey]
    local parent = anchorName and _G[anchorName]

    pad = tonumber(pad) or 0

    holder:ClearAllPoints()

    if parent then
        if where == "TOP" then
            holder:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, pad)
        else
            holder:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -pad)
        end
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ------------------------------------------------------------
-- Bulletproof DB Initialization
-- ------------------------------------------------------------
function A:GetDB()
    if not (R and R.Database and R.Database.profile) then return nil end
    local p = R.Database.profile

    if type(p.auras) ~= "table" then p.auras = {} end
    local db = p.auras

    if db.enabled == nil then db.enabled = true end
    if db.attachTopPad == nil then db.attachTopPad = 6 end
    if db.attachBottomPad == nil then db.attachBottomPad = 6 end
    if db.attachBottomPadTarget == nil then db.attachBottomPadTarget = 6 end

    local groups = {"playerDebuffs", "playerBuffs", "targetDebuffs", "targetBuffs"}
    for _, k in ipairs(groups) do
        if type(db[k]) ~= "table" then db[k] = {} end
        local g = db[k]

        if g.enabled == nil then g.enabled = true end
        if g.shown == nil then g.shown = true end
        if g.locked == nil then g.locked = false end
        if g.onlyMine == nil then g.onlyMine = false end

        if g.size == nil then g.size = 24 end
        if g.max == nil then g.max = 10 end
        if g.gap == nil then g.gap = 2 end

        if type(g.blacklist) ~= "table" then g.blacklist = {} end
        if type(g.whitelist) ~= "table" then g.whitelist = {} end
    end

    return db
end

function A:ApplyAll()
    local db = self:GetDB()
    if not db then return end

    if db.enabled == false then
        if self.playerDebuffs then self.playerDebuffs:Hide() end
        if self.playerBuffs then self.playerBuffs:Hide() end
        if self.targetDebuffs then self.targetDebuffs:Hide() end
        if self.targetBuffs then self.targetBuffs:Hide() end
        return
    end

    self.playerDebuffs = self.playerDebuffs or EnsureHolder("playerDebuffs", "player", "HARMFUL")
    self.playerBuffs   = self.playerBuffs   or EnsureHolder("playerBuffs",   "player", "HELPFUL")
    self.targetDebuffs = self.targetDebuffs or EnsureHolder("targetDebuffs", "target", "HARMFUL")
    self.targetBuffs   = self.targetBuffs   or EnsureHolder("targetBuffs",   "target", "HELPFUL")

    AnchorHolder(self.playerDebuffs, "player", "TOP",    db.attachTopPad)
    AnchorHolder(self.playerBuffs,   "player", "BOTTOM", db.attachBottomPad)
    AnchorHolder(self.targetDebuffs, "target", "TOP",    db.attachTopPad)
    AnchorHolder(self.targetBuffs,   "target", "BOTTOM", db.attachBottomPadTarget)

    UpdateHolder(self.playerDebuffs, "player", "HARMFUL", db.playerDebuffs)
    UpdateHolder(self.playerBuffs,   "player", "HELPFUL", db.playerBuffs)
    UpdateHolder(self.targetDebuffs, "target", "HARMFUL", db.targetDebuffs)
    UpdateHolder(self.targetBuffs,   "target", "HELPFUL", db.targetBuffs)
end
A.ApplyAll = Wrap("Auras:ApplyAll", A.ApplyAll)

-- ------------------------------------------------------------
-- Events (THROTTLED/COALESCED)
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

local THROTTLE = 0.06 -- 60ms (0.05 - 0.10)

local pending   = { player = false, target = false }
local scheduled = false

local function DoUnitUpdate(unit)
    local db = A:GetDB()
    if not db or db.enabled == false then return end

    if not InCombatLockdown then
        SnapshotUnitAuras(unit)
    end

    if unit == "player" then
        if A.playerDebuffs then UpdateHolder(A.playerDebuffs, "player", "HARMFUL", db.playerDebuffs) end
        if A.playerBuffs   then UpdateHolder(A.playerBuffs,   "player", "HELPFUL", db.playerBuffs) end
    elseif unit == "target" then
        if A.targetDebuffs then UpdateHolder(A.targetDebuffs, "target", "HARMFUL", db.targetDebuffs) end
        if A.targetBuffs   then UpdateHolder(A.targetBuffs,   "target", "HELPFUL", db.targetBuffs) end
    end
end

local function Flush()
    scheduled = false

    if pending.player then
        pending.player = false
        DoUnitUpdate("player")
    end

    if pending.target then
        pending.target = false
        DoUnitUpdate("target")
    end
end
Flush = Wrap("Auras:Flush", Flush)

local function Schedule()
    if scheduled then return end
    scheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(THROTTLE, Flush)
    else
        Flush()
    end
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        InCombatLockdown = true
        A:ApplyAll()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        InCombatLockdown = false
        SnapshotUnitAuras("player")
        SnapshotUnitAuras("target")
        A:ApplyAll()
        return
    end

    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                SnapshotUnitAuras("player")
                SnapshotUnitAuras("target")
                A:ApplyAll()
            end)
        else
            SnapshotUnitAuras("player")
            SnapshotUnitAuras("target")
            A:ApplyAll()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        InCombatLockdown = false
        SnapshotUnitAuras("player")
        SnapshotUnitAuras("target")
        A:ApplyAll()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        pending.target = true
        Schedule()
        return
    end

    if event == "UNIT_AURA" then
        if unit == "player" then
            pending.player = true
            Schedule()
        elseif unit == "target" then
            pending.target = true
            Schedule()
        end
        return
    end
end

ev:SetScript("OnEvent", Wrap("Auras:OnEvent", OnEvent))