-- Robui/combattool/buffbars.lua
-- Reskin Blizzard BuffBarCooldownViewer (Blizzard_CooldownViewer) for 12.0+/Midnight
-- PERF FIX:
--  - NO OnUpdate scanning
--  - Style bars ONCE (per-bar cache)
--  - Optional lightweight child-count watcher (ticker) only while viewer shown
--
-- 12.0 / Midnight SAFE RULES USED:
--  - NO string ops on textures/region GetTexture() (can be secret strings)
--  - NO table indexing with secret numbers (spellID from auras can be secret)
--    -> per-spell overrides use pairs() scan + == compare instead
--
-- .toc:
--   ## SavedVariables: RobUIBuffBarsDB

local ADDON, ns = ...
ns = _G[ADDON] or ns
_G[ADDON] = ns

local R = _G.Robui -- RobUI host (optional)

ns.CooldownViewerSkin = ns.CooldownViewerSkin or {}
local M = ns.CooldownViewerSkin

local CreateFrame = CreateFrame
local UIParent = UIParent
local pcall = pcall
local type = type
local tonumber = tonumber
local GetTime = GetTime
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown

-- =========================================================
-- Defaults + SavedVariables
-- =========================================================
local DEFAULTS = {
    enabled = true,

    texture  = "Interface\\Buttons\\WHITE8X8",
    font     = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
    fontFlag = "OUTLINE",

    -- Viewer
    viewerScale = 1.0,
    viewerWidth = 300,

    -- Bars
    barWidth  = 260,
    barHeight = 18,
    fontSize  = 11,

    -- Layout (required for bar height/spacing control)
    forceLayout = false,
    spacing     = 2,

    -- Bottom anchor behavior (only meaningful with forceLayout)
    anchorToBottom = true,

    -- Visuals
    hideBlizzArt = true,
    barBorder    = true,
    borderAlpha  = 0.85,

    -- Default bar color
    barColor = { r=0.20, g=0.70, b=1.00, a=1.00 },

    -- Per-spell overrides: spellID -> {r,g,b,a}
    -- NOTE: spellID read from auras may be secret -> we NEVER index with it directly.
    spellColorOverrides = {},

    -- Mover / anchor
    moverHidden = false,       -- visible until user presses Hide
    moverAlphaShown = 0.65,    -- visible helper frame alpha

    -- New-style position storage
    moverPos = { point="TOPRIGHT", relPoint="TOPRIGHT", x=-420, y=-240 },

    -- Legacy fields (some of your dumps showed these)
    point = nil,
    relPoint = nil,
    x = nil,
    y = nil,
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function Clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function SafeToNumber(x)
    local ok, v = pcall(tonumber, x)
    if ok and type(v) == "number" then return v end
    return nil
end

local function InitDB()
    if type(_G.RobUIBuffBarsDB) ~= "table" then
        _G.RobUIBuffBarsDB = {}
    end
    CopyDefaults(_G.RobUIBuffBarsDB, DEFAULTS)
    M.Config = _G.RobUIBuffBarsDB

    local c = M.Config.barColor or DEFAULTS.barColor
    M.Config.barColor = M.Config.barColor or {}
    M.Config.barColor.r = Clamp01(c.r)
    M.Config.barColor.g = Clamp01(c.g)
    M.Config.barColor.b = Clamp01(c.b)
    M.Config.barColor.a = Clamp01(c.a)

    if type(M.Config.spellColorOverrides) ~= "table" then
        M.Config.spellColorOverrides = {}
    end

    M.Config.spacing      = SafeToNumber(M.Config.spacing) or DEFAULTS.spacing
    M.Config.fontSize     = SafeToNumber(M.Config.fontSize) or DEFAULTS.fontSize
    M.Config.barWidth     = SafeToNumber(M.Config.barWidth) or DEFAULTS.barWidth
    M.Config.barHeight    = SafeToNumber(M.Config.barHeight) or DEFAULTS.barHeight
    M.Config.viewerWidth  = SafeToNumber(M.Config.viewerWidth) or DEFAULTS.viewerWidth
    M.Config.viewerScale  = SafeToNumber(M.Config.viewerScale) or DEFAULTS.viewerScale

    M.Config.anchorToBottom = (M.Config.anchorToBottom == true)

    M.Config.moverAlphaShown = SafeToNumber(M.Config.moverAlphaShown) or DEFAULTS.moverAlphaShown
    M.Config.moverHidden = (M.Config.moverHidden and true) or false

    -- Support both moverPos and legacy point/x/y
    M.Config.moverPos = M.Config.moverPos or {}
    local legacyPoint    = M.Config.point
    local legacyRelPoint = M.Config.relPoint
    local legacyX        = SafeToNumber(M.Config.x)
    local legacyY        = SafeToNumber(M.Config.y)

    if (not M.Config.moverPos.point or not M.Config.moverPos.relPoint) and legacyPoint then
        M.Config.moverPos.point    = legacyPoint
        M.Config.moverPos.relPoint = legacyRelPoint or legacyPoint
        M.Config.moverPos.x        = legacyX or DEFAULTS.moverPos.x
        M.Config.moverPos.y        = legacyY or DEFAULTS.moverPos.y
    end

    M.Config.moverPos.point    = M.Config.moverPos.point    or DEFAULTS.moverPos.point
    M.Config.moverPos.relPoint = M.Config.moverPos.relPoint or DEFAULTS.moverPos.relPoint
    M.Config.moverPos.x        = SafeToNumber(M.Config.moverPos.x) or DEFAULTS.moverPos.x
    M.Config.moverPos.y        = SafeToNumber(M.Config.moverPos.y) or DEFAULTS.moverPos.y
end

local function Cfg()
    if not M.Config then InitDB() end
    return M.Config
end

-- =========================================================
-- SAFE forbidden checks + safe calls
-- =========================================================
local function IsForbiddenSafe(obj)
    if not obj then return true end
    if type(obj) ~= "table" and type(obj) ~= "userdata" then return true end
    if obj.IsForbidden then
        local ok, v = pcall(obj.IsForbidden, obj)
        if ok and v then return true end
    end
    return false
end

local function SafeCall(obj, method, ...)
    if IsForbiddenSafe(obj) then return nil end
    local fn = obj[method]
    if not fn then return nil end
    local ok, ret = pcall(fn, obj, ...)
    if ok then return ret end
    return nil
end

-- =========================================================
-- 12.0 safe addon loaded / load
-- =========================================================
local function IsAddonLoaded(name)
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded then
        local ok, v = pcall(_G.C_AddOns.IsAddOnLoaded, name)
        return ok and v or false
    end
    if _G.IsAddOnLoaded then
        local ok, v = pcall(_G.IsAddOnLoaded, name)
        return ok and v or false
    end
    return false
end

local function LoadAddon(name)
    if _G.C_AddOns and _G.C_AddOns.LoadAddOn then
        pcall(_G.C_AddOns.LoadAddOn, name); return
    end
    if _G.LoadAddOn then
        pcall(_G.LoadAddOn, name); return
    end
end

-- =========================================================
-- Special per-buff coloring (static compares only)
--  - You wanted Warrior Whirlwind / Meat Cleaver red.
--  - (spellIDs vary by build; add more ids as needed)
-- =========================================================
local WW_RED = { r=1.00, g=0.10, b=0.10, a=1.00 }

local function IsWhirlwindLikeSpellID(spellID)
    -- IMPORTANT: spellID may be secret -> ONLY compare, never index tables with it.
    if type(spellID) ~= "number" then return false end
    -- Whirlwind
    if spellID == 1680 then return true end
    -- Meat Cleaver (some builds)
    if spellID == 280392 then return true end
    return false
end

local function TryGetSpellIDFromBar(bar)
    if IsForbiddenSafe(bar) then return nil end

    local id = bar.spellID or bar.spellId or bar.SpellID or bar.SpellId
    if type(id) == "number" then return id end

    local data = bar.data or bar.Data or bar.info or bar.Info or bar.cooldownInfo
    if type(data) == "table" then
        local did = data.spellID or data.spellId or data.SpellID or data.SpellId
        if type(did) == "number" then return did end
    end

    local mid = SafeCall(bar, "GetSpellID")
    if type(mid) == "number" then return mid end

    return nil
end

-- =========================================================
-- Fonts + Borders + Art hiding (ONCE)
-- =========================================================
local function SetFontSafe(fs, size, flags)
    if IsForbiddenSafe(fs) then return end
    if not fs.SetFont then return end
    local cfg = Cfg()

    size = SafeToNumber(size) or 12
    flags = flags or "OUTLINE"
    local fontPath = cfg.font or (_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")

    local ok = pcall(fs.SetFont, fs, fontPath, size, flags)
    if not ok then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags)
    end
    pcall(fs.SetShadowOffset, fs, 0, 0)
end

local function MarkKeep(tex)
    if tex and not IsForbiddenSafe(tex) then
        tex.__robuiKeep = true
    end
end

local function TryHideTexture(tex)
    if IsForbiddenSafe(tex) then return end
    -- Never touch our own helper textures
    if tex.__robuiKeep then return end
    SafeCall(tex, "SetAlpha", 0)
    SafeCall(tex, "Hide")
end

local function EnsureBorder(frame, key, alpha)
    if IsForbiddenSafe(frame) then return nil end
    if not frame.CreateTexture then return nil end

    frame.__robuiBorders = frame.__robuiBorders or {}
    local b = frame.__robuiBorders[key]
    if b and not IsForbiddenSafe(b) then
        SafeCall(b, "SetAlpha", alpha or 1)
        SafeCall(b, "Show")
        return b
    end

    b = frame:CreateTexture(nil, "BORDER")
    if IsForbiddenSafe(b) then return nil end
    b.__robuiKeep = true
    SafeCall(b, "SetTexture", "Interface\\Buttons\\WHITE8X8")
    SafeCall(b, "SetVertexColor", 0, 0, 0, 1)
    SafeCall(b, "SetPoint", "TOPLEFT", frame, "TOPLEFT", -1, 1)
    SafeCall(b, "SetPoint", "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    SafeCall(b, "SetAlpha", alpha or 1)

    frame.__robuiBorders[key] = b
    return b
end

-- Midnight-safe art hide:
-- DO NOT read GetTexture() and do string ops (can be secret strings).
-- We just hide all Texture regions except those marked __robuiKeep.
local function HideBlizzardArtOnce(frame)
    local cfg = Cfg()
    if not cfg.hideBlizzArt then return end
    if IsForbiddenSafe(frame) then return end
    if frame.__robuiArtHidden then return end
    if not frame.GetRegions then return end

    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if not IsForbiddenSafe(r) and r.GetObjectType and r:GetObjectType() == "Texture" then
            -- Avoid texture string calls entirely
            TryHideTexture(r)
        end
    end

    frame.__robuiArtHidden = true
end

-- =========================================================
-- Mover (stable anchor)
-- =========================================================
M.Mover = M.Mover or nil

local function ApplyMoverState()
    local cfg = Cfg()
    local m = M.Mover
    if not m or IsForbiddenSafe(m) then return end

    if cfg.moverHidden then
        SafeCall(m, "SetAlpha", 0)
        SafeCall(m, "EnableMouse", false)
        if m.label then SafeCall(m.label, "Hide") end
        if m.bg then SafeCall(m.bg, "Hide") end
        if m.border then SafeCall(m.border, "Hide") end
    else
        SafeCall(m, "SetAlpha", Clamp01(cfg.moverAlphaShown))
        SafeCall(m, "EnableMouse", true)
        if m.label then SafeCall(m.label, "Show") end
        if m.bg then SafeCall(m.bg, "Show") end
        if m.border then SafeCall(m.border, "Show") end
    end
end

local function SaveMoverPosition()
    local cfg = Cfg()
    local m = M.Mover
    if not m or IsForbiddenSafe(m) or not m.GetPoint then return end

    local p, relTo, rp, x, y
    local ok = pcall(function()
        p, relTo, rp, x, y = m:GetPoint(1)
    end)
    if not ok then return end

    cfg.moverPos = cfg.moverPos or {}
    cfg.moverPos.point = p or cfg.moverPos.point
    cfg.moverPos.relPoint = rp or cfg.moverPos.relPoint
    cfg.moverPos.x = SafeToNumber(x) or 0
    cfg.moverPos.y = SafeToNumber(y) or 0

    -- Legacy mirror (some of your builds stored these)
    cfg.point = cfg.moverPos.point
    cfg.relPoint = cfg.moverPos.relPoint
    cfg.x = cfg.moverPos.x
    cfg.y = cfg.moverPos.y
end

local function PositionMover()
    local cfg = Cfg()
    local m = M.Mover
    if not m or IsForbiddenSafe(m) then return end

    local pos = cfg.moverPos or DEFAULTS.moverPos
    local p = pos.point or cfg.point or "TOPRIGHT"
    local rp = pos.relPoint or cfg.relPoint or p
    local x = SafeToNumber(pos.x) or SafeToNumber(cfg.x) or 0
    local y = SafeToNumber(pos.y) or SafeToNumber(cfg.y) or 0

    SafeCall(m, "ClearAllPoints")
    SafeCall(m, "SetPoint", p, UIParent, rp, x, y)
end

local function EnsureMover()
    if M.Mover and not IsForbiddenSafe(M.Mover) then
        return M.Mover
    end

    local m = CreateFrame("Frame", "RobUI_BuffBarsMover", UIParent, "BackdropTemplate")
    M.Mover = m

    SafeCall(m, "SetFrameStrata", "DIALOG")
    SafeCall(m, "SetSize", 320, 42)
    SafeCall(m, "SetClampedToScreen", true)
    SafeCall(m, "SetMovable", true)
    SafeCall(m, "EnableMouse", true)
    SafeCall(m, "RegisterForDrag", "LeftButton")

    m.bg = m:CreateTexture(nil, "BACKGROUND")
    m.bg.__robuiKeep = true
    SafeCall(m.bg, "SetTexture", "Interface\\Buttons\\WHITE8X8")
    SafeCall(m.bg, "SetAllPoints", m)
    SafeCall(m.bg, "SetVertexColor", 0, 0, 0, 0.55)

    m.border = m:CreateTexture(nil, "BORDER")
    m.border.__robuiKeep = true
    SafeCall(m.border, "SetTexture", "Interface\\Buttons\\WHITE8X8")
    SafeCall(m.border, "SetPoint", "TOPLEFT", m, "TOPLEFT", -1, 1)
    SafeCall(m.border, "SetPoint", "BOTTOMRIGHT", m, "BOTTOMRIGHT", 1, -1)
    SafeCall(m.border, "SetVertexColor", 0, 0, 0, 0.9)

    m.label = m:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(m.label, 12, "OUTLINE")
    SafeCall(m.label, "SetPoint", "CENTER", m, "CENTER", 0, 0)
    SafeCall(m.label, "SetText", "Tracked Bars Anchor (drag me, then click Hide)")

    SafeCall(m, "SetScript", "OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        SafeCall(self, "StartMoving")
    end)

    SafeCall(m, "SetScript", "OnDragStop", function(self)
        SafeCall(self, "StopMovingOrSizing")
        SaveMoverPosition()
    end)

    PositionMover()
    ApplyMoverState()
    return m
end

local function ShowMover()
    local cfg = Cfg()
    cfg.moverHidden = false
    EnsureMover()
    ApplyMoverState()
end

local function HideMover()
    local cfg = Cfg()
    cfg.moverHidden = true
    EnsureMover()
    ApplyMoverState()
end

-- =========================================================
-- Find StatusBar (bars)
-- =========================================================
local function FindStatusBar(bar)
    if IsForbiddenSafe(bar) then return nil end

    if bar.GetObjectType and bar:GetObjectType() == "StatusBar" and bar.GetStatusBarTexture then
        return bar
    end

    local sb = bar.StatusBar or bar.Bar
    if sb and not IsForbiddenSafe(sb) and sb.GetStatusBarTexture then
        return sb
    end

    if bar.GetChildren then
        local kids = { bar:GetChildren() }
        for i = 1, #kids do
            local k = kids[i]
            if not IsForbiddenSafe(k) and k.GetObjectType and k:GetObjectType() == "StatusBar" and k.GetStatusBarTexture then
                return k
            end
        end
    end

    return nil
end

-- =========================================================
-- Apply bar paint + sizing (ONCE + cheap refresh)
-- =========================================================
local function ApplyBarColor(bar, sb)
    local cfg = Cfg()
    if IsForbiddenSafe(sb) then return end
    if not sb.SetStatusBarColor then return end

    local sid = TryGetSpellIDFromBar(bar)

    -- ✅ SECRET-SAFE override lookup:
    -- spellID from auras can be secret -> DO NOT do cfg.spellColorOverrides[sid]
    if sid and type(cfg.spellColorOverrides) == "table" then
        for k, ov in pairs(cfg.spellColorOverrides) do
            if type(k) == "number" and k == sid and type(ov) == "table" then
                SafeCall(sb, "SetStatusBarColor",
                    Clamp01(ov.r),
                    Clamp01(ov.g),
                    Clamp01(ov.b),
                    Clamp01(ov.a == nil and 1 or ov.a)
                )
                return
            end
        end
    end

    -- Special: Whirlwind / Meat Cleaver -> red
    if IsWhirlwindLikeSpellID(sid) then
        local c = WW_RED
        SafeCall(sb, "SetStatusBarColor", c.r, c.g, c.b, c.a)
        return
    end

    local c = cfg.barColor
    SafeCall(sb, "SetStatusBarColor",
        Clamp01(c.r),
        Clamp01(c.g),
        Clamp01(c.b),
        Clamp01(c.a)
    )
end

local function ForceBarSizing(bar, sb)
    local cfg = Cfg()
    if IsForbiddenSafe(bar) or IsForbiddenSafe(sb) then return end

    local bw = SafeToNumber(cfg.barWidth) or DEFAULTS.barWidth
    local bh = SafeToNumber(cfg.barHeight) or DEFAULTS.barHeight

    if bar.SetWidth then SafeCall(bar, "SetWidth", bw) end
    if bar.SetHeight then SafeCall(bar, "SetHeight", bh) end
    if sb.SetWidth then SafeCall(sb, "SetWidth", bw) end
    if sb.SetHeight then SafeCall(sb, "SetHeight", bh) end
end

local function StyleBarOnce(bar)
    local cfg = Cfg()
    if not cfg.enabled then return end
    if IsForbiddenSafe(bar) then return end

    local ot = bar.GetObjectType and bar:GetObjectType()
    if ot ~= "Frame" and ot ~= "StatusBar" then return end

    local sb = FindStatusBar(bar)
    if not sb then return end

    if not bar.__robuiStyled then
        bar.__robuiStyled = true

        if sb.SetStatusBarTexture then
            SafeCall(sb, "SetStatusBarTexture", cfg.texture)
        end
        ApplyBarColor(bar, sb)

        if cfg.barBorder then
            EnsureBorder(sb, "bar", cfg.borderAlpha or 0.85)
        end

        -- Fonts: ONCE
        if bar.GetRegions and not bar.__robuiFontStyled then
            bar.__robuiFontStyled = true
            local regs = { bar:GetRegions() }
            for i = 1, #regs do
                local r = regs[i]
                if not IsForbiddenSafe(r) and r.GetObjectType and r:GetObjectType() == "FontString" then
                    SetFontSafe(r, cfg.fontSize, cfg.fontFlag)
                end
            end
        end

        HideBlizzardArtOnce(bar)
        if sb ~= bar then HideBlizzardArtOnce(sb) end
    end

    -- Cheap refresh
    if sb.SetStatusBarTexture then SafeCall(sb, "SetStatusBarTexture", cfg.texture) end
    ApplyBarColor(bar, sb)
    if cfg.forceLayout then
        ForceBarSizing(bar, sb)
    end
end

-- =========================================================
-- Viewer attach to mover
-- =========================================================
local function AttachViewerToMover(viewer)
    if IsForbiddenSafe(viewer) then return end
    local m = EnsureMover()
    if not m or IsForbiddenSafe(m) then return end

    local cfg = Cfg()

    SafeCall(viewer, "ClearAllPoints")
    if cfg.anchorToBottom then
        SafeCall(viewer, "SetPoint", "BOTTOMLEFT", m, "BOTTOMLEFT", 0, 0)
    else
        SafeCall(viewer, "SetPoint", "TOPLEFT", m, "TOPLEFT", 0, 0)
    end

    local w = SafeToNumber(cfg.viewerWidth) or DEFAULTS.viewerWidth
    SafeCall(m, "SetWidth", w)
end

local function ApplyViewerSizing(viewer)
    local cfg = Cfg()
    if IsForbiddenSafe(viewer) then return end

    if viewer.SetScale then
        SafeCall(viewer, "SetScale", SafeToNumber(cfg.viewerScale) or 1.0)
    end
    if viewer.SetWidth then
        SafeCall(viewer, "SetWidth", SafeToNumber(cfg.viewerWidth) or DEFAULTS.viewerWidth)
    end

    if M.Mover and not IsForbiddenSafe(M.Mover) then
        SafeCall(M.Mover, "SetWidth", SafeToNumber(cfg.viewerWidth) or DEFAULTS.viewerWidth)
    end
end

local function GetPointY(frame)
    if IsForbiddenSafe(frame) or not frame.GetPoint then return 0 end
    local y = 0
    local ok = pcall(function()
        local _, _, _, _, yy = frame:GetPoint(1)
        local n = SafeToNumber(yy)
        if n ~= nil then y = n end
    end)
    if not ok then return 0 end
    return y
end

local function ApplySpacingToChildren(viewer)
    local cfg = Cfg()
    if not cfg.forceLayout then return end
    if IsForbiddenSafe(viewer) then return end
    if not viewer.GetChildren then return end

    local kids = { viewer:GetChildren() }
    local visible = {}

    for i = 1, #kids do
        local k = kids[i]
        if not IsForbiddenSafe(k) and k.IsShown and k:IsShown() then
            visible[#visible+1] = k
        end
    end
    if #visible == 0 then return end

    local gap = SafeToNumber(cfg.spacing) or 0

    if cfg.anchorToBottom then
        local used, ordered = {}, {}

        for _ = 1, #visible do
            local bestIdx, bestY = nil, nil
            for i = 1, #visible do
                if not used[i] then
                    local y = GetPointY(visible[i])
                    if bestY == nil or y < bestY then
                        bestY = y
                        bestIdx = i
                    end
                end
            end
            if bestIdx then
                used[bestIdx] = true
                ordered[#ordered+1] = visible[bestIdx]
            end
        end

        local bottom = ordered[1] or visible[1]
        SafeCall(bottom, "ClearAllPoints")
        SafeCall(bottom, "SetPoint", "BOTTOMLEFT", viewer, "BOTTOMLEFT", 0, 0)

        local prev = bottom
        for i = 2, #ordered do
            local cur = ordered[i]
            SafeCall(cur, "ClearAllPoints")
            SafeCall(cur, "SetPoint", "BOTTOMLEFT", prev, "TOPLEFT", 0, gap)
            prev = cur
        end
    else
        local top = visible[1]
        SafeCall(top, "ClearAllPoints")
        SafeCall(top, "SetPoint", "TOPLEFT", viewer, "TOPLEFT", 0, 0)

        local prev = top
        for i = 2, #visible do
            local cur = visible[i]
            SafeCall(cur, "ClearAllPoints")
            SafeCall(cur, "SetPoint", "TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
            prev = cur
        end
    end
end

-- =========================================================
-- Scan (cheap, no allocations beyond child lists)
-- =========================================================
local function ScanViewer(viewer)
    local cfg = Cfg()
    if not cfg.enabled then return end
    if IsForbiddenSafe(viewer) then return end

    AttachViewerToMover(viewer)
    ApplyViewerSizing(viewer)
    HideBlizzardArtOnce(viewer)

    if viewer.GetChildren then
        local kids = { viewer:GetChildren() }
        for i = 1, #kids do
            local k = kids[i]
            StyleBarOnce(k)
            if k and not IsForbiddenSafe(k) and k.GetChildren then
                local gkids = { k:GetChildren() }
                for j = 1, #gkids do
                    StyleBarOnce(gkids[j])
                end
            end
        end
    end

    ApplySpacingToChildren(viewer)
end

-- =========================================================
-- Child-count watcher (optional, low cost)
-- =========================================================
M._watchTicker = M._watchTicker or nil
M._lastChildCount = M._lastChildCount or 0

local function CountChildren(viewer)
    if IsForbiddenSafe(viewer) or not viewer.GetChildren then return 0 end
    local kids = { viewer:GetChildren() }
    local n = #kids
    for i = 1, #kids do
        local k = kids[i]
        if k and not IsForbiddenSafe(k) and k.GetChildren then
            local g = { k:GetChildren() }
            n = n + #g
        end
    end
    return n
end

local function StartWatch(viewer)
    if M._watchTicker then return end
    M._lastChildCount = 0

    M._watchTicker = C_Timer.NewTicker(0.50, function()
        if not viewer or IsForbiddenSafe(viewer) then
            if M._watchTicker then M._watchTicker:Cancel() end
            M._watchTicker = nil
            return
        end

        local shown = viewer.IsShown and viewer:IsShown() or false
        if not shown then
            if M._watchTicker then M._watchTicker:Cancel() end
            M._watchTicker = nil
            return
        end

        local c = CountChildren(viewer)
        if c ~= M._lastChildCount then
            M._lastChildCount = c
            ScanViewer(viewer)
        end
    end)
end

local function StopWatch()
    if M._watchTicker then
        M._watchTicker:Cancel()
        M._watchTicker = nil
    end
end

-- =========================================================
-- Settings UI + Preview + Mover controls + Spell Overrides
-- =========================================================
M.UI = M.UI or {}

local function ApplyAndRescan()
    local v = _G.BuffBarCooldownViewer
    if v then
        ScanViewer(v)
        StartWatch(v)
    end
    if M.UI and M.UI.UpdatePreview then M.UI:UpdatePreview() end
end

local function MakePanelBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 }
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local sliderIndex = 0
local function MakeNamedSlider(parent, label, x, y, minv, maxv, step, get, set, isFloat, width)
    sliderIndex = sliderIndex + 1
    local name = "RobUIBuffBarsSlider" .. sliderIndex

    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(width or 200)

    local text = _G[name .. "Text"]
    local low  = _G[name .. "Low"]
    local high = _G[name .. "High"]
    if text then text:SetText(label) end
    if low  then low:SetText(tostring(minv)) end
    if high then high:SetText(tostring(maxv)) end

    s:SetScript("OnShow", function(self)
        local v = get()
        if v == nil then v = minv end
        self:SetValue(v)
    end)

    s:SetScript("OnValueChanged", function(self, v)
        v = SafeToNumber(v)
        if not v then return end
        set(v)
        if text then
            if isFloat then
                text:SetText(label .. "  " .. string.format("%.2f", v))
            else
                text:SetText(label .. "  " .. tostring(math.floor(v + 0.5)))
            end
        end
        ApplyAndRescan()
    end)

    return s
end

local function MakeCheckbox(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(fs, 11, "OUTLINE")
    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    fs:SetText(label)

    cb:SetScript("OnShow", function(self)
        self:SetChecked(get() and true or false)
    end)

    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ApplyAndRescan()
    end)

    return cb
end

local function OpenBarColorPicker()
    local cfg = Cfg()
    if not (_G.ColorPickerFrame and _G.ColorPickerFrame.SetupColorPickerAndShow) then return end

    local c = cfg.barColor or DEFAULTS.barColor
    local cr, cg, cb, ca = Clamp01(c.r), Clamp01(c.g), Clamp01(c.b), Clamp01(c.a)

    local function Apply(r,g,b,a)
        cfg.barColor = cfg.barColor or {}
        cfg.barColor.r = Clamp01(r)
        cfg.barColor.g = Clamp01(g)
        cfg.barColor.b = Clamp01(b)
        cfg.barColor.a = Clamp01(a)
        ApplyAndRescan()
    end

    local info = {}
    info.r, info.g, info.b = cr, cg, cb
    info.opacity = 1 - ca
    info.hasOpacity = true

    info.swatchFunc = function()
        local r,g,b = ColorPickerFrame:GetColorRGB()
        local a = 1 - (ColorPickerFrame.opacity or 0)
        Apply(r,g,b,a)
    end
    info.opacityFunc = info.swatchFunc

    info.cancelFunc = function(prev)
        local r = prev and prev.r or cr
        local g = prev and prev.g or cg
        local b = prev and prev.b or cb
        local a = 1 - (prev and prev.opacity or (1 - ca))
        Apply(r,g,b,a)
    end

    pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
end

local function OpenSpellColorPicker(initial, onApply)
    if not (_G.ColorPickerFrame and _G.ColorPickerFrame.SetupColorPickerAndShow) then return end

    local cr, cg, cb, ca = Clamp01(initial.r), Clamp01(initial.g), Clamp01(initial.b), Clamp01(initial.a == nil and 1 or initial.a)

    local info = {}
    info.r, info.g, info.b = cr, cg, cb
    info.opacity = 1 - ca
    info.hasOpacity = true

    info.swatchFunc = function()
        local r,g,b = ColorPickerFrame:GetColorRGB()
        local a = 1 - (ColorPickerFrame.opacity or 0)
        if onApply then onApply(Clamp01(r), Clamp01(g), Clamp01(b), Clamp01(a)) end
    end
    info.opacityFunc = info.swatchFunc

    info.cancelFunc = function(prev)
        local r = prev and prev.r or cr
        local g = prev and prev.g or cg
        local b = prev and prev.b or cb
        local a = 1 - (prev and prev.opacity or (1 - ca))
        if onApply then onApply(Clamp01(r), Clamp01(g), Clamp01(b), Clamp01(a)) end
    end

    pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
end

local function SortedSpellIDs(tbl)
    local arr = {}
    for k in pairs(tbl) do
        if type(k) == "number" then
            arr[#arr+1] = k
        else
            local n = SafeToNumber(k)
            if n then arr[#arr+1] = n end
        end
    end
    table.sort(arr)
    return arr
end

local function SpellName(id)
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(id)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return ("SpellID " .. tostring(id))
end

local function BuildSpellOverrideUI(parent, topY)
    local cfg = Cfg()

    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(header, 12, "OUTLINE")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, topY)
    header:SetText("Per-Spell Color Overrides")

    topY = topY - 24

    local spellLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(spellLabel, 11, "OUTLINE")
    spellLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, topY - 5)
    spellLabel:SetText("SpellID:")

    local idBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    idBox:SetSize(80, 20)
    idBox:SetPoint("LEFT", spellLabel, "RIGHT", 8, 0)
    idBox:SetAutoFocus(false)
    idBox:SetNumeric(true)

    local nameFS = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(nameFS, 11, "OUTLINE")
    nameFS:SetPoint("LEFT", idBox, "RIGHT", 10, 0)
    nameFS:SetText("")

    idBox:SetScript("OnTextChanged", function(self)
        local sid = SafeToNumber(self:GetText())
        if sid then
            nameFS:SetText(SpellName(sid))
        else
            nameFS:SetText("")
        end
    end)

    topY = topY - 30

    local chosen = { r=1, g=0.1, b=0.1, a=1 }
    local sw = parent:CreateTexture(nil, "ARTWORK")
    sw.__robuiKeep = true
    sw:SetSize(16, 16)
    sw:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, topY)
    sw:SetTexture("Interface\\Buttons\\WHITE8X8")
    sw:SetVertexColor(chosen.r, chosen.g, chosen.b, chosen.a)

    local pick = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    pick:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    pick:SetSize(110, 20)
    pick:SetText("Pick Color...")
    pick:SetScript("OnClick", function()
        OpenSpellColorPicker(chosen, function(r,g,b,a)
            chosen.r, chosen.g, chosen.b, chosen.a = r,g,b,a
            sw:SetVertexColor(r,g,b,a)
        end)
    end)

    local add = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    add:SetPoint("LEFT", pick, "RIGHT", 8, 0)
    add:SetSize(100, 20)
    add:SetText("Add/Update")

    local apply = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    apply:SetPoint("LEFT", add, "RIGHT", 8, 0)
    apply:SetSize(80, 20)
    apply:SetText("Apply")

    topY = topY - 34

    local list = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, topY)
    list:SetSize(436, 120)
    list:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    list:SetBackdropColor(0,0,0,0.20)
    list:SetBackdropBorderColor(0,0,0,1)
    list._rows = {}
    list._scroll = 0

    local up = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    up:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -6)
    up:SetSize(52, 18)
    up:SetText("Up")

    local down = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    down:SetPoint("RIGHT", up, "LEFT", -6, 0)
    down:SetSize(52, 18)
    down:SetText("Down")

    local function UpdateList()
        cfg = Cfg()
        cfg.spellColorOverrides = cfg.spellColorOverrides or {}
        local ids = SortedSpellIDs(cfg.spellColorOverrides)

        for i = 1, #list._rows do list._rows[i]:Hide() end

        local maxRows, rowH = 6, 18
        local offset = list._scroll or 0
        if offset < 0 then offset = 0 end
        local maxOff = math.max(0, #ids - maxRows)
        if offset > maxOff then offset = maxOff end
        list._scroll = offset

        for i = 1, maxRows do
            local idx = offset + i
            local sid = ids[idx]
            if not sid then break end

            local row = list._rows[i]
            if not row then
                row = CreateFrame("Frame", nil, list)
                row:SetSize(list:GetWidth() - 10, rowH)
                row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - ((i-1) * rowH))

                row.sw = row:CreateTexture(nil, "ARTWORK")
                row.sw.__robuiKeep = true
                row.sw:SetSize(12, 12)
                row.sw:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.sw:SetTexture("Interface\\Buttons\\WHITE8X8")

                row.txt = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                SetFontSafe(row.txt, 10, "OUTLINE")
                row.txt:SetPoint("LEFT", row.sw, "RIGHT", 8, 0)
                row.txt:SetJustifyH("LEFT")

                row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.del:SetSize(56, 16)
                row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.del:SetText("Remove")

                list._rows[i] = row
            end

            local c = cfg.spellColorOverrides[sid] or {}
            row.sw:SetVertexColor(Clamp01(c.r), Clamp01(c.g), Clamp01(c.b), Clamp01(c.a == nil and 1 or c.a))
            row.txt:SetText(("%d - %s"):format(sid, SpellName(sid)))

            row.del:SetScript("OnClick", function()
                cfg = Cfg()
                cfg.spellColorOverrides = cfg.spellColorOverrides or {}
                cfg.spellColorOverrides[sid] = nil
                UpdateList()
                ApplyAndRescan()
            end)

            row:Show()
        end
    end

    add:SetScript("OnClick", function()
        cfg = Cfg()
        cfg.spellColorOverrides = cfg.spellColorOverrides or {}

        local sid = SafeToNumber(idBox:GetText())
        if not sid then return end

        cfg.spellColorOverrides[sid] = {
            r = Clamp01(chosen.r),
            g = Clamp01(chosen.g),
            b = Clamp01(chosen.b),
            a = Clamp01(chosen.a),
        }
        UpdateList()
        ApplyAndRescan()
    end)

    apply:SetScript("OnClick", ApplyAndRescan)

    up:SetScript("OnClick", function()
        list._scroll = (list._scroll or 0) - 1
        UpdateList()
    end)

    down:SetScript("OnClick", function()
        list._scroll = (list._scroll or 0) + 1
        UpdateList()
    end)

    parent:HookScript("OnShow", function()
        UpdateList()
    end)

    return topY - 150
end

-- Preview (simulated only)
local PREVIEW_ICON = "Interface\\ICONS\\INV_Misc_QuestionMark"

function M.UI:EnsurePreview(parent)
    if self.preview and self.preview:GetParent() == parent then
        return self.preview
    end

    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -44)
    p:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -44)
    p:SetHeight(120)

    p:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    p:SetBackdropColor(0,0,0,0.25)
    p:SetBackdropBorderColor(0,0,0,1)

    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    SetFontSafe(title, 12, "OUTLINE")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -6)
    title:SetText("Preview")

    p.bars = {}
    for i = 1, 3 do
        local wrap = CreateFrame("Frame", nil, p)
        local sb = CreateFrame("StatusBar", nil, wrap)
        sb:SetAllPoints()
        sb:SetMinMaxValues(0, 1)
        sb:SetValue(1)

        local icon = wrap:CreateTexture(nil, "ARTWORK")
        icon.__robuiKeep = true
        icon:SetTexture(PREVIEW_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local nameFS = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local durFS  = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFontSafe(nameFS, 11, "OUTLINE")
        SetFontSafe(durFS,  11, "OUTLINE")
        nameFS:SetPoint("LEFT", sb, "LEFT", 6, 0)
        durFS:SetPoint("RIGHT", sb, "RIGHT", -6, 0)
        nameFS:SetText(i == 1 and "Example Buff" or (i == 2 and "Another Proc" or "Tracked Aura"))
        durFS:SetText(i == 1 and "12s" or (i == 2 and "28s" or "4m"))

        p.bars[i] = { wrap=wrap, sb=sb, icon=icon, nameFS=nameFS, durFS=durFS }
    end

    self.preview = p
    return p
end

function M.UI:UpdatePreview()
    local host = self.hostFrame
    if not host or not host:IsShown() then return end
    local cfg = Cfg()

    local p = self:EnsurePreview(host)

    local bw  = SafeToNumber(cfg.barWidth) or DEFAULTS.barWidth
    local bh  = SafeToNumber(cfg.barHeight) or DEFAULTS.barHeight
    local sp  = SafeToNumber(cfg.spacing) or DEFAULTS.spacing

    local c = cfg.barColor or DEFAULTS.barColor
    local r,g,b,a = Clamp01(c.r), Clamp01(c.g), Clamp01(c.b), Clamp01(c.a)

    local iconSize = bh
    local totalH = (bh * 3) + (sp * 2) + 28
    if totalH < 96 then totalH = 96 end
    p:SetHeight(totalH)

    for i = 1, 3 do
        local it = p.bars[i]
        local yOff = -22 - ((i-1) * (bh + sp))

        it.wrap:ClearAllPoints()
        it.wrap:SetPoint("TOPLEFT", p, "TOPLEFT", 6, yOff)
        it.wrap:SetSize(bw + iconSize + 4, bh)

        it.sb:SetStatusBarTexture(cfg.texture or DEFAULTS.texture)
        it.sb:SetStatusBarColor(r,g,b,a)

        it.icon:ClearAllPoints()
        it.icon:SetPoint("RIGHT", it.sb, "LEFT", -4, 0)
        it.icon:SetSize(iconSize, iconSize)

        SetFontSafe(it.nameFS, cfg.fontSize or DEFAULTS.fontSize, cfg.fontFlag or "OUTLINE")
        SetFontSafe(it.durFS,  cfg.fontSize or DEFAULTS.fontSize, cfg.fontFlag or "OUTLINE")
    end
end

local function BuildSettingsUI(parent, embedded)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(460, 580)

    if embedded then
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        MakePanelBackdrop(f)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    end

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    SetFontSafe(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetText("Buff Bars Settings")

    M.UI.hostFrame = f
    M.UI:EnsurePreview(f)

    local yOffsetBase = -180

    -- Col 1
    local col1X = 12
    MakeCheckbox(f, "Enabled", col1X, yOffsetBase,
        function() return Cfg().enabled end,
        function(v) Cfg().enabled = v end
    )

    MakeCheckbox(f, "Force layout (height/spacing)", col1X, yOffsetBase - 30,
        function() return Cfg().forceLayout end,
        function(v) Cfg().forceLayout = v end
    )

    MakeCheckbox(f, "Anchor to bottom bar", col1X, yOffsetBase - 60,
        function() return Cfg().anchorToBottom end,
        function(v) Cfg().anchorToBottom = v end
    )

    MakeNamedSlider(f, "Viewer Scale", col1X + 12, yOffsetBase - 110, 0.70, 1.60, 0.01,
        function() return Cfg().viewerScale end,
        function(v) Cfg().viewerScale = v end,
        true, 180
    )

    MakeNamedSlider(f, "Viewer Width", col1X + 12, yOffsetBase - 160, 160, 600, 1,
        function() return Cfg().viewerWidth end,
        function(v) Cfg().viewerWidth = v end,
        false, 180
    )

    MakeNamedSlider(f, "Anchor Alpha", col1X + 12, yOffsetBase - 210, 0.15, 1.00, 0.01,
        function() return Cfg().moverAlphaShown end,
        function(v)
            Cfg().moverAlphaShown = v
            ApplyMoverState()
        end,
        true, 180
    )

    -- Col 2
    local col2X = 240
    local showBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    showBtn:SetPoint("TOPLEFT", f, "TOPLEFT", col2X, yOffsetBase)
    showBtn:SetSize(90, 22)
    showBtn:SetText("Show Anchor")
    showBtn:SetScript("OnClick", function()
        ShowMover()
        ApplyAndRescan()
    end)

    local hideBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    hideBtn:SetPoint("LEFT", showBtn, "RIGHT", 4, 0)
    hideBtn:SetSize(90, 22)
    hideBtn:SetText("Hide Anchor")
    hideBtn:SetScript("OnClick", function()
        HideMover()
        ApplyAndRescan()
    end)

    MakeNamedSlider(f, "Bar Width", col2X + 12, yOffsetBase - 60, 120, 520, 1,
        function() return Cfg().barWidth end,
        function(v) Cfg().barWidth = v end,
        false, 180
    )

    MakeNamedSlider(f, "Bar Height", col2X + 12, yOffsetBase - 110, 10, 34, 1,
        function() return Cfg().barHeight end,
        function(v) Cfg().barHeight = v end,
        false, 180
    )

    MakeNamedSlider(f, "Spacing (gap)", col2X + 12, yOffsetBase - 160, 0, 14, 1,
        function() return Cfg().spacing end,
        function(v) Cfg().spacing = v end,
        false, 180
    )

    MakeNamedSlider(f, "Font Size", col2X + 12, yOffsetBase - 210, 8, 18, 1,
        function() return Cfg().fontSize end,
        function(v) Cfg().fontSize = v end,
        false, 180
    )

    -- Spell overrides full width at bottom
    local spellOffsetY = yOffsetBase - 260
    BuildSpellOverrideUI(f, spellOffsetY)

    local colorBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    colorBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    colorBtn:SetSize(140, 22)
    colorBtn:SetText("Base Bar Color...")
    colorBtn:SetScript("OnClick", OpenBarColorPicker)

    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    applyBtn:SetSize(90, 22)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", ApplyAndRescan)

    f:SetScript("OnShow", function()
        EnsureMover()
        ApplyMoverState()
        ApplyAndRescan()
    end)

    return f
end

function M.UI:BuildDialog()
    if self.dialog and self.dialog:IsShown() ~= nil then
        return self.dialog
    end
    self.dialog = BuildSettingsUI(UIParent, false)
    return self.dialog
end

function M.UI:ShowDialog()
    local f = self:BuildDialog()
    f:Show()
end

function M.UI:CreateRobUIPanel()
    if self.robuiPanel then return self.robuiPanel end
    if not (R and R.RegisterModulePanel) then return nil end

    local p = CreateFrame("Frame", nil, UIParent)
    local ui = BuildSettingsUI(p, true)
    ui:SetAllPoints(p)

    self.robuiPanel = p
    R:RegisterModulePanel("Buff Bars", p)
    return p
end

_G.SLASH_ROBUIBUFFBARS1 = "/rbbars"
SlashCmdList.ROBUIBUFFBARS = function()
    M.UI:ShowDialog()
end

-- =========================================================
-- Attach / hook
-- =========================================================
function M:Attach()
    local cfg = Cfg()
    if not cfg.enabled then return end

    EnsureMover()
    ApplyMoverState()

    if not IsAddonLoaded("Blizzard_CooldownViewer") then
        LoadAddon("Blizzard_CooldownViewer")
    end

    local viewer = _G.BuffBarCooldownViewer
    if not viewer then
        C_Timer.After(0.5, function()
            local v = _G.BuffBarCooldownViewer
            if v then M:HookViewer(v) end
        end)
        return
    end

    self:HookViewer(viewer)
end

function M:HookViewer(viewer)
    if not viewer or viewer.__robuiHooked then return end
    viewer.__robuiHooked = true

    ScanViewer(viewer)
    StartWatch(viewer)

    SafeCall(viewer, "HookScript", "OnShow", function()
        ScanViewer(viewer)
        StartWatch(viewer)
        if M.UI and M.UI.UpdatePreview then M.UI:UpdatePreview() end
    end)

    SafeCall(viewer, "HookScript", "OnHide", function()
        StopWatch()
    end)
end

-- =========================================================
-- Events
-- =========================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            InitDB()
            EnsureMover()
            ApplyMoverState()

            C_Timer.After(0.2, function()
                R = _G.Robui
                if R and R.RegisterModulePanel then
                    M.UI:CreateRobUIPanel()
                end
            end)
            return
        end

        if arg1 == "Blizzard_CooldownViewer" then
            Cfg()
            EnsureMover()
            ApplyMoverState()
            M:Attach()
            return
        end
    end

    if event == "PLAYER_LOGIN" then
        Cfg()
        EnsureMover()
        ApplyMoverState()

        C_Timer.After(0.6, function()
            R = _G.Robui
            if R and R.RegisterModulePanel then
                M.UI:CreateRobUIPanel()
            end
        end)

        M:Attach()
        return
    end
end)