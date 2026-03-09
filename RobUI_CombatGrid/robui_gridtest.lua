-- ============================================================================
-- robui_gridtest.lua
-- Mini SmartHub GridCore + Script Runner
--
-- LAYOUT:
--  LEFT  : Plugins list + selected plugin settings + anchor controls
--  MIDDLE: Grid canvas (anchors drag/snap/group)  (only visible in Edit Mode)
--  RIGHT : Script Runner (SSR) integrated into GridCore
--
-- SavedVariables: RobUIGridDB2   (NEW - clean DB)
--
-- Plugin API:
--   ns.GridCore:RegisterPlugin(id, opts)
--     opts = {
--       name = "Player Frame",
--       build = function() return frame end,              -- must return frame to attach
--       settings = function(parent) return frame end,     -- optional plugin UI in left settings box
--       default = { gx=0, gy=0, label="Player" },
--
--       standard = { position=true, size=true, scale=true }, -- what GridCore can control
--       setSize  = function(frame, w, h) end,             -- optional; called by GridCore
--       setScale = function(frame, s) end,                -- optional; called by GridCore
--     }
--
-- Control:
--   /rgrid             toggle edit mode
--   /rgrid edit        show
--   /rgrid hide        hide
-- ============================================================================

local AddonName, ns = ...
ns.GridCore = ns.GridCore or {}
local GC = ns.GridCore

-- ---------------------------------------------------------------------------
-- SavedVariables (NEW, CLEAN)
-- ---------------------------------------------------------------------------
local DB_NAME = "RobUIGridDB2"

local DEFAULT_DB = {
    enabled = true,

    -- root frame pos/size
    point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
    w = 1280, h = 680,

    -- edit mode
    editMode = false,

    -- visuals
    alpha = 0.35,
    borderAlpha = 0.90,
    showCoordLabels = true,

    -- grid
    cell = 8,
    snapPx = 12,
    clampToGrid = true,

    -- groups
    nextGroupId = 1,

    -- scaling
    globalScale = 1.0,         -- global multiplier applied to plugins via setScale
    allowScaleOnResize = false,
    baseW = 900,
    baseH = 520,

    -- anchors[id] = { gx, gy, group, scaleWithGrid, label }
    anchors = {},

    -- attach[pluginId] = anchorId
    attach = {},

    -- ScriptRunner data
    ssr = {
        scripts = {},      -- name -> code
        autorun = {},      -- name -> bool
        last = nil,        -- last opened script name
    },
}

local function ShallowCopy(src)
    if type(_G.CopyTable) == "function" then
        return _G.CopyTable(src)
    end
    local t = {}
    for k,v in pairs(src) do
        if type(v) == "table" then
            local inner = {}
            for k2,v2 in pairs(v) do inner[k2]=v2 end
            t[k]=inner
        else
            t[k]=v
        end
    end
    return t
end

local function EnsureDB()
    _G[DB_NAME] = _G[DB_NAME] or {}
    local db = _G[DB_NAME]

    for k,v in pairs(DEFAULT_DB) do
        if db[k] == nil then
            db[k] = (type(v) == "table") and ShallowCopy(v) or v
        end
    end

    db.anchors = type(db.anchors) == "table" and db.anchors or {}
    db.attach  = type(db.attach)  == "table" and db.attach  or {}
    db.ssr     = type(db.ssr)     == "table" and db.ssr     or ShallowCopy(DEFAULT_DB.ssr)
    db.ssr.scripts = type(db.ssr.scripts) == "table" and db.ssr.scripts or {}
    db.ssr.autorun = type(db.ssr.autorun) == "table" and db.ssr.autorun or {}
    if type(db.nextGroupId) ~= "number" then db.nextGroupId = 1 end
    if type(db.globalScale) ~= "number" then db.globalScale = 1.0 end

    -- keep baseW/baseH stable
    if type(db.baseW) ~= "number" then db.baseW = DEFAULT_DB.baseW end
    if type(db.baseH) ~= "number" then db.baseH = DEFAULT_DB.baseH end

    return db
end

GC.db = GC.db or nil

-- ---------------------------------------------------------------------------
-- Plugin registry
-- ---------------------------------------------------------------------------
GC._plugins      = GC._plugins or {}        -- id -> opts
GC._pluginOrder  = GC._pluginOrder or {}    -- list of ids
GC._pluginFrames = GC._pluginFrames or {}   -- id -> frame

function GC:RegisterPlugin(id, opts)
    if type(id) ~= "string" or id == "" then return end
    if type(opts) ~= "table" then opts = {} end
    opts.name = opts.name or id

    if not self._plugins[id] then
        table.insert(self._pluginOrder, id)
    end
    self._plugins[id] = opts

    -- if already attached in DB, reattach immediately when plugin registers
    local db = self.db or EnsureDB()
    self.db = db
    if db.attach and type(db.attach[id]) == "string" then
        -- delay attach until UI exists OR create anchor frames later
        self:AttachPlugin(id)
    end

    if self.ui and self.ui.pluginList then
        self:RefreshPluginList()
    end
end

function GC:GetPlugin(id)
    return self._plugins and self._plugins[id]
end

-- ---------------------------------------------------------------------------
-- Utils
-- ---------------------------------------------------------------------------
local function Round(v) return math.floor((tonumber(v) or 0) + 0.5) end
local function Clamp(v, a, b)
    v = tonumber(v) or 0
    if v < a then return a end
    if v > b then return b end
    return v
end

local function SnapToCell(v, cell)
    cell = tonumber(cell) or 8
    if cell <= 0 then cell = 8 end
    return Round((tonumber(v) or 0) / cell) * cell
end

local function Distance(a,b) return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) end

local function MakeBackdrop(f, alpha, edgeA)
    if not (f and f.SetBackdrop) then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.35)
    f:SetBackdropBorderColor(0,0,0, edgeA or 1)
end

local function ClearChildren(parent)
    if not parent then return end
    local kids = { parent:GetChildren() }
    for _,c in ipairs(kids) do
        c:Hide()
        c:SetParent(nil)
    end
end

-- ---------------------------------------------------------------------------
-- Public state
-- ---------------------------------------------------------------------------
function GC:IsEditMode()
    local db = self.db or EnsureDB()
    return db.editMode and true or false
end

function GC:SetEditMode(on)
    local db = self.db or EnsureDB()
    self.db = db
    db.editMode = on and true or false
    self:CreateUI() -- safe, builds once
    self:ApplyEditMode()
end

function GC:ToggleEditMode()
    self:SetEditMode(not self:IsEditMode())
end

-- ---------------------------------------------------------------------------
-- Anchor management
-- ---------------------------------------------------------------------------
GC._anchorFrames = GC._anchorFrames or {}    -- anchorId -> visual button
GC._selectedAnchorId = GC._selectedAnchorId or nil

local function AnchorIdForNew(db)
    local i = 1
    while db.anchors["A"..i] do i = i + 1 end
    return "A"..i
end

function GC:EnsureAnchor(anchorId, defaults)
    local db = self.db or EnsureDB()
    self.db = db
    defaults = type(defaults) == "table" and defaults or {}

    if type(anchorId) ~= "string" or anchorId == "" then
        anchorId = AnchorIdForNew(db)
    end

    if not db.anchors[anchorId] then
        db.anchors[anchorId] = {
            gx = tonumber(defaults.gx) or 0,
            gy = tonumber(defaults.gy) or 0,
            group = tonumber(defaults.group) or 0,
            scaleWithGrid = defaults.scaleWithGrid and true or false,
            label = (type(defaults.label) == "string" and defaults.label) or anchorId,
        }
    else
        local a = db.anchors[anchorId]
        if type(a.label) ~= "string" then a.label = anchorId end
        a.gx = tonumber(a.gx) or 0
        a.gy = tonumber(a.gy) or 0
        a.group = tonumber(a.group) or 0
        a.scaleWithGrid = a.scaleWithGrid and true or false
    end

    if self.ui and self.ui.canvas then
        self:CreateOrUpdateAnchorFrame(anchorId)
        self:PositionAnchorFrame(anchorId)
        self:UpdateAnchorLabel(anchorId)
    end

    return anchorId
end

function GC:GetAnchorGridPos(anchorId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return 0,0 end
    local a = db.anchors and db.anchors[anchorId]
    if not a then return 0,0 end
    return tonumber(a.gx) or 0, tonumber(a.gy) or 0
end

function GC:SetAnchorGridPos(anchorId, gx, gy, doSnap, moveGroup)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end
    local a = db.anchors and db.anchors[anchorId]
    if not a then return end

    gx = tonumber(gx) or 0
    gy = tonumber(gy) or 0

    local cell = tonumber(db.cell) or 8
    if doSnap then
        gx = SnapToCell(gx, cell)
        gy = SnapToCell(gy, cell)
    end

    local dx = gx - (tonumber(a.gx) or 0)
    local dy = gy - (tonumber(a.gy) or 0)

    a.gx, a.gy = gx, gy

    if moveGroup then
        local g = tonumber(a.group) or 0
        if g > 0 and (dx ~= 0 or dy ~= 0) then
            for id, info in pairs(db.anchors) do
                if id ~= anchorId and type(id) == "string" and type(info) == "table" and tonumber(info.group) == g then
                    info.gx = (tonumber(info.gx) or 0) + dx
                    info.gy = (tonumber(info.gy) or 0) + dy
                    self:PositionAnchorFrame(id)
                    self:UpdateAnchorLabel(id)
                    self:ReflowAttached(id)
                end
            end
        end
    end

    self:PositionAnchorFrame(anchorId)
    self:UpdateAnchorLabel(anchorId)
    self:ReflowAttached(anchorId)
    self:UpdateSelectedAnchorUI()
end

function GC:DeleteAnchor(anchorId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end
    if not (db.anchors and db.anchors[anchorId]) then return end

    for pid, aid in pairs(db.attach or {}) do
        if aid == anchorId then
            db.attach[pid] = nil
            self._pluginFrames[pid] = nil
        end
    end

    db.anchors[anchorId] = nil

    local af = self._anchorFrames and self._anchorFrames[anchorId]
    if af then af:Hide(); af:SetParent(nil) end
    self._anchorFrames[anchorId] = nil

    if self._selectedAnchorId == anchorId then
        self._selectedAnchorId = nil
        self:UpdateSelectedAnchorUI()
    end
end

-- ---------------------------------------------------------------------------
-- Scale factor / global scale
-- ---------------------------------------------------------------------------
function GC:GetScaleFactor()
    local db = self.db or EnsureDB()
    self.db = db
    local w = tonumber(db.w) or 900
    local h = tonumber(db.h) or 520
    local bw = tonumber(db.baseW) or 900
    local bh = tonumber(db.baseH) or 520
    if bw <= 0 then bw = 900 end
    if bh <= 0 then bh = 520 end
    local sx = w / bw
    local sy = h / bh
    return (sx + sy) * 0.5
end

function GC:GetEffectiveCell()
    local db = self.db or EnsureDB()
    self.db = db
    local cell = tonumber(db.cell) or 8
    if cell < 2 then cell = 2 end
    if db.allowScaleOnResize then
        cell = Clamp(Round(cell * self:GetScaleFactor()), 2, 40)
    end
    return cell
end

function GC:GetEffectiveSnap()
    local db = self.db or EnsureDB()
    self.db = db
    local snap = tonumber(db.snapPx) or 12
    if snap < 1 then snap = 1 end
    if db.allowScaleOnResize then
        snap = Clamp(Round(snap * self:GetScaleFactor()), 1, 80)
    end
    return snap
end

function GC:SetGlobalScale(s)
    local db = self.db or EnsureDB()
    self.db = db
    s = Clamp(tonumber(s) or 1, 0.2, 3.0)
    db.globalScale = s
    self:ApplyGlobalScaleToAll()
    if self.ui and self.ui.scaleValue then
        self.ui.scaleValue:SetText(string.format("Scale: %.2f", s))
    end
end

function GC:ApplyGlobalScaleToAll()
    local db = self.db or EnsureDB()
    self.db = db
    for pid, aid in pairs(db.attach or {}) do
        local f = self._pluginFrames and self._pluginFrames[pid]
        if f then
            self:ApplyFrameScaleForPlugin(pid)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Attach / Detach
-- ---------------------------------------------------------------------------
function GC:IsPluginAttached(pluginId)
    local db = self.db or EnsureDB()
    self.db = db
    return (db.attach and type(db.attach[pluginId]) == "string") and true or false
end

function GC:GetPluginAnchor(pluginId)
    local db = self.db or EnsureDB()
    self.db = db
    return db.attach and db.attach[pluginId]
end

function GC:AttachPlugin(pluginId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(pluginId) ~= "string" then return end
    local p = self:GetPlugin(pluginId)
    if not p then return end

    -- Build frame if needed
    local frame = self._pluginFrames[pluginId]
    if not frame and type(p.build) == "function" then
        local ok, f = pcall(p.build)
        if ok then frame = f end
    end
    if not frame then return end
    self._pluginFrames[pluginId] = frame

    local default = type(p.default) == "table" and p.default or {}
    local anchorId = db.attach[pluginId]
    if type(anchorId) ~= "string" then
        anchorId = "P_" .. pluginId
        anchorId = self:EnsureAnchor(anchorId, {
            gx = default.gx or 0,
            gy = default.gy or 0,
            group = default.group or 0,
            scaleWithGrid = default.scaleWithGrid or false,
            label = default.label or p.name or anchorId,
        })
        db.attach[pluginId] = anchorId
    else
        self:EnsureAnchor(anchorId, default)
    end

    self:CreateUI()
    self:AttachFrameToAnchor(pluginId, frame, anchorId)
    self:RefreshPluginList()

    -- ensure editmode behavior updates movers etc
    if type(p.onGridAttach) == "function" then
        pcall(p.onGridAttach, frame)
    end
end

function GC:DetachPlugin(pluginId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(pluginId) ~= "string" then return end

    local frame = self._pluginFrames[pluginId]
    if frame and frame.ClearAllPoints then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    db.attach[pluginId] = nil
    self._pluginFrames[pluginId] = nil
    self:RefreshPluginList()
end

function GC:AttachFrameToAnchor(pluginId, frame, anchorId)
    if not (frame and frame.SetPoint and frame.ClearAllPoints) then return end
    if type(anchorId) ~= "string" then return end

    local af = self._anchorFrames and self._anchorFrames[anchorId]
    if not af then
        self:EnsureAnchor(anchorId, {})
        af = self._anchorFrames and self._anchorFrames[anchorId]
    end
    if not af then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", af, "CENTER", 0, 0)

    self:ApplyFrameScaleForPlugin(pluginId)
end

function GC:ApplyFrameScaleForPlugin(pluginId)
    local db = self.db or EnsureDB()
    self.db = db
    local p = self:GetPlugin(pluginId)
    local frame = self._pluginFrames and self._pluginFrames[pluginId]
    if not (p and frame) then return end

    -- globalScale is always applied through plugin setScale if available, else SetScale
    local g = Clamp(db.globalScale or 1, 0.2, 3.0)

    if type(p.setScale) == "function" then
        pcall(p.setScale, frame, g)
    else
        if frame.SetScale then
            pcall(frame.SetScale, frame, g)
        end
    end
end

function GC:ReflowAttached(anchorId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end
    for pid, aid in pairs(db.attach or {}) do
        if aid == anchorId then
            local f = self._pluginFrames and self._pluginFrames[pid]
            if f then
                self:AttachFrameToAnchor(pid, f, aid)
            end
        end
    end
end

function GC:ReflowAll()
    local db = self.db or EnsureDB()
    self.db = db
    for pid, aid in pairs(db.attach or {}) do
        local f = self._pluginFrames and self._pluginFrames[pid]
        if f and type(aid) == "string" then
            self:AttachFrameToAnchor(pid, f, aid)
        end
    end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
GC.ui = GC.ui or nil
GC._pluginButtons = GC._pluginButtons or {}
GC._selectedPluginId = GC._selectedPluginId or nil

function GC:CreateUI()
    if self.ui and self.ui.grid then return end

    local db = self.db or EnsureDB()
    self.db = db

    local grid = CreateFrame("Frame", "RobUI_GridCoreRoot", UIParent, "BackdropTemplate")
    self.ui = self.ui or {}
    self.ui.grid = grid
    grid:SetFrameStrata("DIALOG")
    grid:SetFrameLevel(80)
    grid:SetClampedToScreen(true)
    grid:SetMovable(true)
    grid:SetResizable(true)
    grid:EnableMouse(true)

    MakeBackdrop(grid, db.alpha, db.borderAlpha)
    grid:SetSize(db.w, db.h)
    grid:ClearAllPoints()
    grid:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)

    if grid.SetResizeBounds then
        grid:SetResizeBounds(980, 520, 2400, 1400)
    elseif grid.SetMinResize then
        grid:SetMinResize(980, 520)
    end

    -- Header
    local header = CreateFrame("Frame", nil, grid, "BackdropTemplate")
    self.ui.header = header
    header:SetPoint("TOPLEFT", grid, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -1, -1)
    header:SetHeight(30)
    MakeBackdrop(header, 0.55, 0)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        grid:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        grid:StopMovingOrSizing()
        local point, _, relPoint, x, y = grid:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, Round(x), Round(y)
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("RobUI GridCore")

    -- Header buttons
    local function HeaderBtn(text, w)
        local b = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        b:SetHeight(20)
        b:SetWidth(w or 86)
        b:SetText(text)
        return b
    end

    local btnEdit = HeaderBtn("Edit", 70)
    btnEdit:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    self.ui.btnEdit = btnEdit

    local btnAdd = HeaderBtn("Add Anchor", 94)
    btnAdd:SetPoint("RIGHT", btnEdit, "LEFT", -6, 0)
    self.ui.btnAdd = btnAdd

    local btnDel = HeaderBtn("Delete", 78)
    btnDel:SetPoint("RIGHT", btnAdd, "LEFT", -6, 0)
    self.ui.btnDel = btnDel

    local btnLabels = HeaderBtn("Labels", 78)
    btnLabels:SetPoint("RIGHT", btnDel, "LEFT", -6, 0)
    self.ui.btnLabels = btnLabels

    btnEdit:SetScript("OnClick", function() self:ToggleEditMode() end)
    btnAdd:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self:EnsureAnchor(nil, { gx=0, gy=0, label="Anchor" })
        self:SelectAnchor(id)
        self:SetEditMode(true)
    end)
    btnDel:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        self:DeleteAnchor(id)
        self:RefreshPluginList()
        self:UpdateSelectedAnchorUI()
    end)
    btnLabels:SetScript("OnClick", function()
        db.showCoordLabels = not db.showCoordLabels
        self:UpdateAllAnchorLabels()
    end)

    -- Resize handle
    local sizer = CreateFrame("Button", nil, grid)
    self.ui.sizer = sizer
    sizer:SetSize(16,16)
    sizer:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -2, 2)
    sizer:EnableMouse(true)
    sizer:RegisterForDrag("LeftButton")
    sizer:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        grid:StartSizing("BOTTOMRIGHT")
    end)
    sizer:SetScript("OnDragStop", function()
        grid:StopMovingOrSizing()
        local w,h = grid:GetSize()
        db.w, db.h = Round(w), Round(h)
        MakeBackdrop(grid, db.alpha, db.borderAlpha)
        self:UpdateGridVisuals()
        self:ReflowAll()
    end)
    local sTex = sizer:CreateTexture(nil, "OVERLAY")
    sTex:SetAllPoints()
    sTex:SetColorTexture(1,1,1,0.25)

    -- Columns sizes
    local leftW  = 280
    local rightW = 420
    local pad = 6
    local topOff = 38

    -- LEFT: Plugins + Settings + Anchor Controls
    local left = CreateFrame("Frame", nil, grid, "BackdropTemplate")
    self.ui.left = left
    left:SetPoint("TOPLEFT", grid, "TOPLEFT", pad, -topOff)
    left:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", pad, pad)
    left:SetWidth(leftW)
    MakeBackdrop(left, 0.45, 0)

    local leftTitle = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -6)
    leftTitle:SetText("Plugins")

    -- plugin list scroll
    local pScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    pScroll:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -26)
    pScroll:SetPoint("TOPRIGHT", left, "TOPRIGHT", -26, -26)
    pScroll:SetHeight(210)

    local pList = CreateFrame("Frame", nil, pScroll)
    pList:SetSize(1,1)
    pScroll:SetScrollChild(pList)
    self.ui.pluginList = pList

    -- plugin settings box
    local pBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
    self.ui.pluginSettingsBox = pBox
    pBox:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -246)
    pBox:SetPoint("TOPRIGHT", left, "TOPRIGHT", -6, -246)
    pBox:SetHeight(220)
    MakeBackdrop(pBox, 0.30, 0)

    local psTitle = pBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    psTitle:SetPoint("TOPLEFT", pBox, "TOPLEFT", 6, -6)
    psTitle:SetText("Plugin Settings")
    self.ui.pluginSettingsTitle = psTitle

    local psHost = CreateFrame("Frame", nil, pBox)
    psHost:SetPoint("TOPLEFT", pBox, "TOPLEFT", 6, -26)
    psHost:SetPoint("BOTTOMRIGHT", pBox, "BOTTOMRIGHT", -6, 6)
    self.ui.pluginSettingsHost = psHost

    -- Anchor controls box
    local aBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
    self.ui.anchorBox = aBox
    aBox:SetPoint("TOPLEFT", pBox, "BOTTOMLEFT", 0, -8)
    aBox:SetPoint("TOPRIGHT", pBox, "BOTTOMRIGHT", 0, -8)
    aBox:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 6, 6)
    aBox:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -6, 6)
    MakeBackdrop(aBox, 0.30, 0)

    local aTitle = aBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aTitle:SetPoint("TOPLEFT", aBox, "TOPLEFT", 6, -6)
    aTitle:SetText("Anchor Controls")

    -- gx/gy edit boxes
    local function EditLabel(text, y)
        local fs = aBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", aBox, "TOPLEFT", 8, y)
        fs:SetText(text)
        return fs
    end

    local gxLbl = EditLabel("GX:", -28)
    local gxBox = CreateFrame("EditBox", nil, aBox, "InputBoxTemplate")
    gxBox:SetSize(70, 20)
    gxBox:SetPoint("LEFT", gxLbl, "RIGHT", 6, 0)
    gxBox:SetAutoFocus(false)
    self.ui.gxBox = gxBox

    local gyLbl = EditLabel("GY:", -52)
    local gyBox = CreateFrame("EditBox", nil, aBox, "InputBoxTemplate")
    gyBox:SetSize(70, 20)
    gyBox:SetPoint("LEFT", gyLbl, "RIGHT", 6, 0)
    gyBox:SetAutoFocus(false)
    self.ui.gyBox = gyBox

    local applyPos = CreateFrame("Button", nil, aBox, "UIPanelButtonTemplate")
    applyPos:SetSize(80, 20)
    applyPos:SetPoint("TOPRIGHT", aBox, "TOPRIGHT", -8, -30)
    applyPos:SetText("Apply")
    self.ui.applyPos = applyPos

    applyPos:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local gx = tonumber(gxBox:GetText())
        local gy = tonumber(gyBox:GetText())
        if not gx then gx = 0 end
        if not gy then gy = 0 end
        self:SetAnchorGridPos(id, gx, gy, true, true)
    end)

    -- Nudge buttons (better than squares)
    local function NBtn(txt)
        local b = CreateFrame("Button", nil, aBox, "UIPanelButtonTemplate")
        b:SetSize(30, 24)
        b:SetText(txt)
        return b
    end

    local nUp = NBtn("▲")
    local nDn = NBtn("▼")
    local nLf = NBtn("◀")
    local nRt = NBtn("▶")

    nUp:SetPoint("TOPLEFT", aBox, "TOPLEFT", 10, -82)
    nDn:SetPoint("TOPLEFT", nUp, "BOTTOMLEFT", 0, -4)
    nLf:SetPoint("LEFT", nDn, "RIGHT", 6, 0)
    nRt:SetPoint("LEFT", nLf, "RIGHT", 6, 0)

    local nInfo = aBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nInfo:SetPoint("LEFT", nRt, "RIGHT", 8, 0)
    nInfo:SetText("Shift=5")
    self.ui.nInfo = nInfo

    local function Nudge(dx, dy)
        local id = self._selectedAnchorId
        if not id then return end
        if InCombatLockdown() then return end
        local step = IsShiftKeyDown() and 5 or 1
        local gx, gy = self:GetAnchorGridPos(id)
        self:SetAnchorGridPos(id, gx + dx*step, gy + dy*step, false, true)
    end

    nUp:SetScript("OnClick", function() Nudge(0, 1) end)
    nDn:SetScript("OnClick", function() Nudge(0,-1) end)
    nLf:SetScript("OnClick", function() Nudge(-1,0) end)
    nRt:SetScript("OnClick", function() Nudge(1, 0) end)

    -- Group controls
    local gText = aBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gText:SetPoint("TOPLEFT", aBox, "TOPLEFT", 10, -126)
    gText:SetText("Group: none")
    self.ui.groupText = gText

    local gNew = CreateFrame("Button", nil, aBox, "UIPanelButtonTemplate")
    gNew:SetSize(90, 20)
    gNew:SetPoint("TOPLEFT", gText, "BOTTOMLEFT", 0, -6)
    gNew:SetText("New Group")
    self.ui.btnNewGroup = gNew

    local gClr = CreateFrame("Button", nil, aBox, "UIPanelButtonTemplate")
    gClr:SetSize(90, 20)
    gClr:SetPoint("LEFT", gNew, "RIGHT", 6, 0)
    gClr:SetText("Ungroup")
    self.ui.btnClearGroup = gClr

    gNew:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local a = db.anchors[id]; if not a then return end
        local gid = db.nextGroupId or 1
        db.nextGroupId = gid + 1
        a.group = gid
        self:UpdateSelectedAnchorUI()
    end)

    gClr:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local a = db.anchors[id]; if not a then return end
        a.group = 0
        self:UpdateSelectedAnchorUI()
    end)

    -- Global scale slider
    local scaleLbl = aBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLbl:SetPoint("TOPLEFT", gNew, "BOTTOMLEFT", 0, -14)
    scaleLbl:SetText("Global Scale")
    self.ui.scaleLbl = scaleLbl

    local sld = CreateFrame("Slider", nil, aBox, "OptionsSliderTemplate")
    sld:SetPoint("TOPLEFT", scaleLbl, "BOTTOMLEFT", -2, -8)
    sld:SetMinMaxValues(0.2, 3.0)
    sld:SetValueStep(0.01)
    sld:SetObeyStepOnDrag(true)
    sld:SetWidth(240)
    sld:SetValue(db.globalScale or 1.0)
    self.ui.scaleSlider = sld

    local sVal = aBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sVal:SetPoint("TOPLEFT", sld, "BOTTOMLEFT", 4, -6)
    sVal:SetText(string.format("Scale: %.2f", db.globalScale or 1.0))
    self.ui.scaleValue = sVal

    sld:SetScript("OnValueChanged", function(_, v)
        if InCombatLockdown() then return end
        self:SetGlobalScale(v)
    end)

    -- MIDDLE: Canvas
    local canvas = CreateFrame("Frame", nil, grid)
    self.ui.canvas = canvas
    canvas:SetPoint("TOPLEFT", left, "TOPRIGHT", pad, 0)
    canvas:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -(rightW + pad), pad)

    self.ui.lines = {}
    self:UpdateGridVisuals()

    -- RIGHT: Script Runner panel
    local right = CreateFrame("Frame", nil, grid, "BackdropTemplate")
    self.ui.right = right
    right:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -pad, -topOff)
    right:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -pad, pad)
    right:SetWidth(rightW)
    MakeBackdrop(right, 0.45, 0)

    local rTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -6)
    rTitle:SetText("Scripts")
    self.ui.ssrTitle = rTitle

    -- Build SSR UI inside right
    self:BuildSSR(right)

    -- Build anchors from DB
    for anchorId,_ in pairs(db.anchors) do
        if type(anchorId) == "string" then
            self:CreateOrUpdateAnchorFrame(anchorId)
            self:PositionAnchorFrame(anchorId)
            self:UpdateAnchorLabel(anchorId)
        end
    end

    self:RefreshPluginList()
    self:ApplyEditMode()
    self:UpdateSelectedAnchorUI()
end

function GC:UpdateGridVisuals()
    if not (self.ui and self.ui.canvas) then return end
    local db = self.db or EnsureDB()
    self.db = db
    local canvas = self.ui.canvas

    local w,h = canvas:GetSize()
    w,h = Round(w), Round(h)

    local cell = self:GetEffectiveCell()

    -- wipe old lines
    for _,t in ipairs(self.ui.lines or {}) do
        if t and t.Hide then t:Hide() end
    end
    self.ui.lines = {}

    local maxLines = 260
    local count = 0

    local function NewLine()
        local l = canvas:CreateTexture(nil, "BACKGROUND")
        l:SetColorTexture(1,1,1,0.08)
        self.ui.lines[#self.ui.lines+1] = l
        return l
    end

    for x = cell, w, cell do
        count = count + 1
        if count > maxLines then break end
        local l = NewLine()
        l:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, 0)
        l:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", x, 0)
        l:SetWidth(1)
    end

    for y = cell, h, cell do
        count = count + 1
        if count > maxLines then break end
        local l = NewLine()
        l:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -y)
        l:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -y)
        l:SetHeight(1)
    end

    self.ui.centerX = self.ui.centerX or canvas:CreateTexture(nil, "ARTWORK")
    self.ui.centerY = self.ui.centerY or canvas:CreateTexture(nil, "ARTWORK")

    self.ui.centerX:SetColorTexture(1,0,0,0.55)
    self.ui.centerY:SetColorTexture(1,0,0,0.55)

    local cx = Round(w/2)
    local cy = Round(h/2)

    self.ui.centerX:ClearAllPoints()
    self.ui.centerX:SetPoint("TOPLEFT", canvas, "TOPLEFT", cx, 0)
    self.ui.centerX:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx, 0)
    self.ui.centerX:SetWidth(2)

    self.ui.centerY:ClearAllPoints()
    self.ui.centerY:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -cy)
    self.ui.centerY:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -cy)
    self.ui.centerY:SetHeight(2)

    for anchorId,_ in pairs(db.anchors) do
        if type(anchorId) == "string" then
            self:PositionAnchorFrame(anchorId)
            self:UpdateAnchorLabel(anchorId)
        end
    end
end

function GC:ApplyEditMode()
    if not (self.ui and self.ui.grid) then return end
    local db = self.db or EnsureDB()
    self.db = db

    if db.editMode then
        self.ui.grid:Show()
        self.ui.btnEdit:SetText("Done")
        for _,af in pairs(self._anchorFrames or {}) do
            if af then af:SetShown(true) end
        end
    else
        self.ui.grid:Hide()
        self.ui.btnEdit:SetText("Edit")
    end

    self:UpdateSelectedAnchorUI()
end

-- ---------------------------------------------------------------------------
-- Anchor visuals + dragging
-- ---------------------------------------------------------------------------
function GC:CreateOrUpdateAnchorFrame(anchorId)
    if not (self.ui and self.ui.canvas) then return end
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end

    local canvas = self.ui.canvas
    local af = self._anchorFrames[anchorId]

    if not af then
        af = CreateFrame("Button", nil, canvas, "BackdropTemplate")
        self._anchorFrames[anchorId] = af
        af._id = anchorId
        af:SetSize(18,18)
        MakeBackdrop(af, 0.25, 1.0)
        af:SetBackdropBorderColor(1,1,1,0.85)
        af:EnableMouse(true)
        af:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        af:RegisterForDrag("LeftButton")
        af:SetMovable(true)

        local tex = af:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetColorTexture(0.2, 0.7, 1.0, 0.35)
        af._fill = tex

        local lbl = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOP", af, "BOTTOM", 0, -2)
        lbl:SetText("")
        af._label = lbl

        af:SetScript("OnClick", function(_, mouse)
            if mouse == "LeftButton" then
                self:SelectAnchor(anchorId)
            elseif mouse == "RightButton" then
                self:SelectAnchor(anchorId)
                local a = db.anchors[anchorId]
                if a then
                    if (tonumber(a.group) or 0) > 0 then
                        a.group = 0
                    else
                        local gid = db.nextGroupId or 1
                        db.nextGroupId = gid + 1
                        a.group = gid
                    end
                    self:UpdateSelectedAnchorUI()
                end
            end
        end)

        af:SetScript("OnDragStart", function()
            if InCombatLockdown() then return end
            if not db.editMode then return end
            self:SelectAnchor(anchorId)
            af:StartMoving()
        end)

        af:SetScript("OnDragStop", function()
            af:StopMovingOrSizing()
            if not db.editMode then return end
            if InCombatLockdown() then return end

            local cx = canvas:GetWidth()/2
            local cy = canvas:GetHeight()/2

            local left = af:GetLeft()
            local bottom = af:GetBottom()
            local cLeft = canvas:GetLeft()
            local cBottom = canvas:GetBottom()

            if not (left and bottom and cLeft and cBottom) then
                self:PositionAnchorFrame(anchorId)
                return
            end

            local x = (left - cLeft) + (af:GetWidth()/2)
            local y = (bottom - cBottom) + (af:GetHeight()/2)

            local gx = Round(x - cx)
            local gy = Round(y - cy)

            local cell = self:GetEffectiveCell()
            local snapTol = self:GetEffectiveSnap()

            local sx = SnapToCell(gx, cell)
            local sy = SnapToCell(gy, cell)

            if Distance(gx, sx) <= snapTol then gx = sx end
            if Distance(gy, sy) <= snapTol then gy = sy end

            if db.clampToGrid then
                local maxX = Round(cx - 10)
                local maxY = Round(cy - 10)
                gx = Clamp(gx, -maxX, maxX)
                gy = Clamp(gy, -maxY, maxY)
            end

            self:SetAnchorGridPos(anchorId, gx, gy, false, true)
        end)
    end

    af:SetShown(db.editMode and true or false)
end

function GC:PositionAnchorFrame(anchorId)
    if not (self.ui and self.ui.canvas) then return end
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end

    local canvas = self.ui.canvas
    local af = self._anchorFrames[anchorId]
    if not af then return end

    local a = db.anchors and db.anchors[anchorId]
    if not a then return end

    local gx = tonumber(a.gx) or 0
    local gy = tonumber(a.gy) or 0

    local cx = canvas:GetWidth()/2
    local cy = canvas:GetHeight()/2

    local x = Round(cx + gx)
    local y = Round(cy + gy)

    af:ClearAllPoints()
    af:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)

    if self._selectedAnchorId == anchorId then
        af:SetBackdropBorderColor(1, 0.9, 0.2, 1)
        af._fill:SetColorTexture(1, 0.9, 0.2, 0.25)
    else
        af:SetBackdropBorderColor(1,1,1,0.85)
        af._fill:SetColorTexture(0.2, 0.7, 1.0, 0.35)
    end
end

function GC:UpdateAnchorLabel(anchorId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end
    local af = self._anchorFrames and self._anchorFrames[anchorId]
    if not (af and af._label) then return end

    if not db.showCoordLabels then
        af._label:SetText("")
        return
    end

    local a = db.anchors and db.anchors[anchorId]
    if not a then
        af._label:SetText("")
        return
    end

    local label = a.label
    if type(label) ~= "string" then
        label = anchorId
        a.label = label
    end

    local gx = tonumber(a.gx) or 0
    local gy = tonumber(a.gy) or 0
    af._label:SetText(label .. " (" .. gx .. "," .. gy .. ")")
end

function GC:UpdateAllAnchorLabels()
    local db = self.db or EnsureDB()
    self.db = db
    for anchorId,_ in pairs(db.anchors or {}) do
        if type(anchorId) == "string" then
            self:UpdateAnchorLabel(anchorId)
        end
    end
end

function GC:SelectAnchor(anchorId)
    local db = self.db or EnsureDB()
    self.db = db
    if type(anchorId) ~= "string" then return end
    if not (db.anchors and db.anchors[anchorId]) then return end

    self._selectedAnchorId = anchorId

    for id,_ in pairs(db.anchors) do
        if type(id) == "string" then
            self:PositionAnchorFrame(id)
        end
    end

    self:UpdateSelectedAnchorUI()
end

function GC:UpdateSelectedAnchorUI()
    if not self.ui then return end
    local db = self.db or EnsureDB()
    self.db = db

    local id = self._selectedAnchorId
    if not id or type(id) ~= "string" or not (db.anchors and db.anchors[id]) then
        if self.ui.gxBox then self.ui.gxBox:SetText("") end
        if self.ui.gyBox then self.ui.gyBox:SetText("") end
        if self.ui.groupText then self.ui.groupText:SetText("Group: none") end
        return
    end

    local a = db.anchors[id]
    local gx = tonumber(a.gx) or 0
    local gy = tonumber(a.gy) or 0
    if self.ui.gxBox then self.ui.gxBox:SetText(tostring(gx)) end
    if self.ui.gyBox then self.ui.gyBox:SetText(tostring(gy)) end

    local g = tonumber(a.group) or 0
    if self.ui.groupText then
        self.ui.groupText:SetText((g > 0) and ("Group: "..g) or "Group: none")
    end
end

-- ---------------------------------------------------------------------------
-- Left panel plugin list + plugin settings
-- ---------------------------------------------------------------------------
function GC:OpenPluginSettings(pluginId)
    if not (self.ui and self.ui.pluginSettingsHost) then return end
    if type(pluginId) ~= "string" then return end
    local p = self:GetPlugin(pluginId)
    if not p then return end

    self._selectedPluginId = pluginId
    self.ui.pluginSettingsTitle:SetText("Plugin Settings: " .. (p.name or pluginId))

    ClearChildren(self.ui.pluginSettingsHost)

    local row = CreateFrame("Frame", nil, self.ui.pluginSettingsHost)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", self.ui.pluginSettingsHost, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", self.ui.pluginSettingsHost, "TOPRIGHT", 0, 0)

    local addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    addBtn:SetSize(92, 20)
    addBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
    addBtn:SetText(self:IsPluginAttached(pluginId) and "Reattach" or "Add")

    local remBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remBtn:SetSize(92, 20)
    remBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
    remBtn:SetText("Remove")

    addBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        self:SetEditMode(true)
        self:AttachPlugin(pluginId)
        self:RefreshPluginList()
        self:OpenPluginSettings(pluginId)
    end)

    remBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        self:DetachPlugin(pluginId)
        self:RefreshPluginList()
        self:OpenPluginSettings(pluginId)
    end)

    -- standard controls (size/scale) if plugin supports
    local std = type(p.standard) == "table" and p.standard or {}

    local host = CreateFrame("Frame", nil, self.ui.pluginSettingsHost)
    host:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -8)
    host:SetPoint("BOTTOMRIGHT", self.ui.pluginSettingsHost, "BOTTOMRIGHT", 0, 0)

    local topY = -2

    local function AddLine(text)
        local fs = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", host, "TOPLEFT", 0, topY)
        fs:SetText(text)
        topY = topY - 18
        return fs
    end

    if std.size and type(p.setSize) == "function" then
        AddLine("Size (w/h):")
        local wBox = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
        wBox:SetSize(60, 20)
        wBox:SetPoint("TOPLEFT", host, "TOPLEFT", 0, topY)
        wBox:SetAutoFocus(false)
        wBox:SetText("340")

        local hBox = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
        hBox:SetSize(60, 20)
        hBox:SetPoint("LEFT", wBox, "RIGHT", 8, 0)
        hBox:SetAutoFocus(false)
        hBox:SetText("28")

        local btn = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
        btn:SetSize(70, 20)
        btn:SetPoint("LEFT", hBox, "RIGHT", 8, 0)
        btn:SetText("Apply")

        btn:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local frame = self._pluginFrames and self._pluginFrames[pluginId]
            if not frame then return end
            local w = tonumber(wBox:GetText())
            local h = tonumber(hBox:GetText())
            if not w or not h then return end
            pcall(p.setSize, frame, w, h)
            self:ReflowAll()
        end)

        topY = topY - 30
    end

    if std.scale and type(p.setScale) == "function" then
        AddLine("Plugin Scale is driven by Global Scale slider.")
    end

    -- plugin custom settings UI
    if type(p.settings) == "function" then
        local uiHost = CreateFrame("Frame", nil, host)
        uiHost:SetPoint("TOPLEFT", host, "TOPLEFT", 0, topY - 8)
        uiHost:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

        local ok, ui = pcall(p.settings, uiHost)
        if ok and ui then
            ui:SetParent(uiHost)
            ui:ClearAllPoints()
            ui:SetAllPoints(uiHost)
            ui:Show()
        else
            local msg = uiHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            msg:SetPoint("TOPLEFT", uiHost, "TOPLEFT", 0, 0)
            msg:SetText("Plugin settings returned nothing.")
        end
    end
end

function GC:RefreshPluginList()
    if not (self.ui and self.ui.pluginList) then return end

    for _,b in pairs(self._pluginButtons) do
        if b then b:Hide(); b:SetParent(nil) end
    end
    wipe(self._pluginButtons)

    local list = self.ui.pluginList
    local y = -2

    for _,pid in ipairs(self._pluginOrder or {}) do
        local p = self._plugins[pid]
        if p then
            local b = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
            b:SetSize(230, 20)
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 2, y)
            y = y - 22

            local attached = self:IsPluginAttached(pid)
            b:SetText((attached and "● " or "○ ") .. (p.name or pid))

            b:SetScript("OnClick", function()
                self:OpenPluginSettings(pid)
            end)

            self._pluginButtons[pid] = b
        end
    end

    list:SetHeight(-y + 10)
end

-- ---------------------------------------------------------------------------
-- SSR (Script Runner) on right panel
-- ---------------------------------------------------------------------------
GC._ssr = GC._ssr or { current = nil, listButtons = {} }

local function SSR_Ensure(db)
    db.ssr = type(db.ssr) == "table" and db.ssr or ShallowCopy(DEFAULT_DB.ssr)
    db.ssr.scripts = type(db.ssr.scripts) == "table" and db.ssr.scripts or {}
    db.ssr.autorun = type(db.ssr.autorun) == "table" and db.ssr.autorun or {}
end

local function SSR_Run(name, code)
    local func, err = loadstring(code or "")
    if func then
        local ok, runErr = pcall(func)
        if not ok then
            print("|cffff0000[Grid SSR] Runtime Error in " .. (name or "Unsaved") .. ":|r", runErr)
        end
    else
        print("|cffff0000[Grid SSR] Syntax Error in " .. (name or "Unsaved") .. ":|r", err)
    end
end

function GC:BuildSSR(parent)
    local db = self.db or EnsureDB()
    self.db = db
    SSR_Ensure(db)

    local s = self._ssr
    s.current = db.ssr.last

    -- Left: list
    local listScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -28)
    listScroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 54)
    listScroll:SetWidth(150)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(150, 10)
    listScroll:SetScrollChild(listContent)
    s.listContent = listContent

    -- Right: editor scroll
    local editScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 18, 0)
    editScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 54)

    local editBox = CreateFrame("EditBox", nil, editScroll)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(999999)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(parent:GetWidth() - 230)
    editBox:SetAutoFocus(false)
    editScroll:SetScrollChild(editBox)

    local bg = editBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    s.editBox = editBox

    -- AutoRun checkbox
    local autoRunCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    autoRunCheck:SetSize(26, 26)
    autoRunCheck.text = autoRunCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoRunCheck.text:SetPoint("LEFT", autoRunCheck, "RIGHT", 0, 1)
    autoRunCheck.text:SetText("Auto-Run on Login")
    autoRunCheck:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 22)
    s.autoRun = autoRunCheck

    autoRunCheck:SetScript("OnClick", function(selfBtn)
        if not s.current then
            selfBtn:SetChecked(false)
            return
        end
        db.ssr.autorun[s.current] = selfBtn:GetChecked() and true or false
    end)

    local function UpdateList()
        -- clear old
        for _, btn in pairs(s.listButtons) do btn:Hide() end

        local y = 0
        local idx = 1

        for name,_ in pairs(db.ssr.scripts) do
            local btn = s.listButtons[idx]
            if not btn then
                btn = CreateFrame("Button", nil, listContent, "GameMenuButtonTemplate")
                btn:SetSize(140, 20)
                s.listButtons[idx] = btn
            end

            btn:SetPoint("TOPLEFT", 0, -y)
            btn:SetText(name)
            btn:Show()

            btn:SetScript("OnClick", function()
                s.current = name
                db.ssr.last = name
                editBox:SetText(db.ssr.scripts[name] or "")
                autoRunCheck:SetChecked(db.ssr.autorun[name] or false)
            end)

            y = y + 25
            idx = idx + 1
        end

        listContent:SetHeight(math.max(y, 10))

        -- restore last
        if s.current and db.ssr.scripts[s.current] then
            editBox:SetText(db.ssr.scripts[s.current])
            autoRunCheck:SetChecked(db.ssr.autorun[s.current] or false)
        else
            autoRunCheck:SetChecked(false)
        end
    end

    s.UpdateList = UpdateList
    UpdateList()

    -- Bottom buttons
    local btnNew = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnNew:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    btnNew:SetSize(60, 25)
    btnNew:SetText("New")
    btnNew:SetScript("OnClick", function()
        s.current = nil
        db.ssr.last = nil
        editBox:SetText("")
        autoRunCheck:SetChecked(false)
    end)

    StaticPopupDialogs["GRID_SSR_SAVE"] = {
        text = "Enter name for the new script:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(selfPopup)
            local name = selfPopup.EditBox:GetText()
            if name and name ~= "" then
                s.current = name
                db.ssr.last = name
                db.ssr.scripts[name] = editBox:GetText()
                if db.ssr.autorun[name] == nil then db.ssr.autorun[name] = false end
                autoRunCheck:SetChecked(db.ssr.autorun[name])
                UpdateList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local btnSave = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnSave:SetPoint("LEFT", btnNew, "RIGHT", 5, 0)
    btnSave:SetSize(60, 25)
    btnSave:SetText("Save")
    btnSave:SetScript("OnClick", function()
        if s.current then
            db.ssr.scripts[s.current] = editBox:GetText()
        else
            StaticPopup_Show("GRID_SSR_SAVE")
        end
        UpdateList()
    end)

    local btnDelete = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnDelete:SetPoint("LEFT", btnSave, "RIGHT", 5, 0)
    btnDelete:SetSize(60, 25)
    btnDelete:SetText("Delete")
    btnDelete:SetScript("OnClick", function()
        if s.current and db.ssr.scripts[s.current] then
            db.ssr.scripts[s.current] = nil
            db.ssr.autorun[s.current] = nil
            if db.ssr.last == s.current then db.ssr.last = nil end
            s.current = nil
            editBox:SetText("")
            autoRunCheck:SetChecked(false)
            UpdateList()
        end
    end)

    local btnRun = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnRun:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    btnRun:SetSize(90, 25)
    btnRun:SetText("Run Code")
    btnRun:SetScript("OnClick", function()
        local name = s.current or "Unsaved"
        local code = editBox:GetText()
        SSR_Run(name, code)
    end)
end

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_ROBUIGRID1 = "/rgrid"
SlashCmdList["ROBUIGRID"] = function(msg)
    msg = (msg or ""):lower()
    GC.db = GC.db or EnsureDB()
    GC:CreateUI()

    if msg == "edit" then
        GC:SetEditMode(true)
    elseif msg == "hide" then
        GC:SetEditMode(false)
    else
        GC:ToggleEditMode()
    end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= AddonName then return end

    GC.db = EnsureDB()

    if event == "PLAYER_LOGIN" then
        -- Auto-run SSR scripts
        local db = GC.db
        if db and db.ssr and db.ssr.autorun and db.ssr.scripts then
            for name, enabled in pairs(db.ssr.autorun) do
                if enabled and db.ssr.scripts[name] then
                    SSR_Run(name, db.ssr.scripts[name])
                end
            end
        end

        -- If editMode saved on, show UI
        if GC.db.editMode then
            GC:CreateUI()
            GC:SetEditMode(true)
        end

        -- Reattach plugins already saved (works even if plugin registers later too)
        for pid, aid in pairs(GC.db.attach or {}) do
            if type(pid) == "string" and type(aid) == "string" then
                GC:AttachPlugin(pid)
            end
        end
    end
end)
