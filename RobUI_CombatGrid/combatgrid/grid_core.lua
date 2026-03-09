-- ============================================================================
-- grid_core.lua (RobUI GridCore)  -- CORE / DB / PLUGINS / ATTACH
--
-- SOURCE OF TRUTH (RobUI profile):
--   Robui.Database.profile.rgrid
--
-- ACCOUNT-WIDE MASTER:
--   RobUIGrid_GlobalDB.master
--
-- Fallback (only if RobUI not loaded):
--   SavedVariables: RobUIGridDB3
-- ============================================================================
local AddonName, ns = ...

ns = _G[AddonName] or ns or {}
_G[AddonName] = ns

ns.GridCore = ns.GridCore or {}
_G.RGridCore = ns.GridCore 

local GC = ns.GridCore

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat
local UnitName = UnitName
local GetRealmName = GetRealmName

local tonumber = tonumber
local type = type
local pairs = pairs
local next = next
local pcall = pcall
local table_insert = table.insert
local table_sort = table.sort
local math_floor = math.floor

local GLOBAL_SV_NAME = "RobUIGrid_GlobalDB"
local SV_NAME = "RobUIGridDB3"

local function GetRobuiProfileRoot()
    local R = _G.Robui
    if not (R and R.Database and R.Database.profile) then return nil end
    return R.Database.profile
end

local DEFAULT_DB = {
    enabled = true,
    editMode = false,
    point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
    w = 1280, h = 680,
    alpha = 0.35,
    borderAlpha = 0.90,
    showCoordLabels = true,
    cell = 8,
    snapPx = 12,
    clampToGrid = true,
    nextGroupId = 1,
    groups = {},
    globalScale = 1.0,
    allowScaleOnResize = false,
    baseW = 900,
    baseH = 520,
    anchors = {},
    attach = {},
    ssr = { scripts = {}, autorun = {}, last = nil },
}

local DEFAULT_META = {
    version = 1,
    autoEnabled = true,       
    manualProfile = nil,      
    activeProfile = "master", 
    lastAutoProfile = nil,  
}

local function NormalizeProfileKey(k)
    if type(k) ~= "string" or k == "" then return nil end
    return k
end

local function GetCharSpecKey()
    local charName = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    realm = realm:gsub("%s+", "")
    
    local specIndex = 1
    if type(_G.GetSpecialization) == "function" then
        specIndex = _G.GetSpecialization() or 1
    end
    
    return charName .. "-" .. realm .. "-Spec" .. specIndex
end

local function ShallowCopy(src)
    local t = {}
    for k,v in pairs(src) do t[k] = v end
    return t
end

local function DeepCopyTable(src)
    if type(_G.CopyTable) == "function" then return _G.CopyTable(src) end
    if type(src) ~= "table" then return src end
    local out = {}
    for k,v in pairs(src) do
        if type(v) == "table" then
            out[k] = DeepCopyTable(v)
        else
            out[k] = v
        end
    end
    return out
end

local function MergeDefaults(dst, defaults)
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = DeepCopyTable(v)
            else
                MergeDefaults(dst[k], v)
            end
        else
            if dst[k] == nil then
                dst[k] = v
            end
        end
    end
end

local function Clamp(v, a, b)
    v = tonumber(v) or 0
    if v < a then return a end
    if v > b then return b end
    return v
end

local function IsGroupMode(mode)
    return mode == "ALWAYS" or mode == "COMBAT" or mode == "HIDDEN"
end

local function IsAnchorMode(mode)
    return mode == "INHERIT" or mode == "ALWAYS" or mode == "COMBAT" or mode == "HIDDEN"
end

local function Round(v)
    return math_floor((tonumber(v) or 0) + 0.5)
end

local function NormalizeOrient(o)
    if o == "V" or o == "VERTICAL" then return "V" end
    return "H"
end

local function NormalizeProfileDB(db)
    MergeDefaults(db, DEFAULT_DB)

    if type(db.anchors) ~= "table" then db.anchors = {} end
    if type(db.attach)  ~= "table" then db.attach  = {} end
    if type(db.groups)  ~= "table" then db.groups  = {} end
    if type(db.ssr)     ~= "table" then db.ssr     = DeepCopyTable(DEFAULT_DB.ssr) end
    if type(db.ssr.scripts) ~= "table" then db.ssr.scripts = {} end
    if type(db.ssr.autorun) ~= "table" then db.ssr.autorun = {} end

    db.nextGroupId = tonumber(db.nextGroupId) or 1
    db.globalScale = tonumber(db.globalScale) or 1.0
    db.baseW = tonumber(db.baseW) or DEFAULT_DB.baseW
    db.baseH = tonumber(db.baseH) or DEFAULT_DB.baseH

    if type(db.anchors) == "table" then
        for _,a in pairs(db.anchors) do
            if type(a) == "table" then
                if type(a.showMode) ~= "string" or a.showMode == "" or not IsAnchorMode(a.showMode) then
                    a.showMode = "INHERIT"
                end
                if a.orient ~= nil then
                    a.orient = NormalizeOrient(a.orient)
                end
                if a.fw ~= nil then a.fw = Round(a.fw) end
                if a.fh ~= nil then a.fh = Round(a.fh) end
            end
        end
    end
end

local function IsProfileEmpty(pdb)
    if type(pdb) ~= "table" then return true end
    local hasAnchors = (type(pdb.anchors) == "table") and (next(pdb.anchors) ~= nil)
    local hasAttach  = (type(pdb.attach)  == "table") and (next(pdb.attach)  ~= nil)
    local hasGroups  = (type(pdb.groups)  == "table") and (next(pdb.groups)  ~= nil)
    return (not hasAnchors) and (not hasAttach) and (not hasGroups)
end

local function CopyLayout(src, dst)
    if type(src) ~= "table" or type(dst) ~= "table" then return end

    dst.enabled = src.enabled
    dst.editMode = src.editMode
    dst.point = src.point
    dst.relPoint = src.relPoint
    dst.x = src.x
    dst.y = src.y
    dst.w = src.w
    dst.h = src.h
    dst.alpha = src.alpha
    dst.borderAlpha = src.borderAlpha
    dst.showCoordLabels = src.showCoordLabels
    dst.cell = src.cell
    dst.snapPx = src.snapPx
    dst.clampToGrid = src.clampToGrid
    dst.nextGroupId = src.nextGroupId
    dst.globalScale = src.globalScale
    dst.allowScaleOnResize = src.allowScaleOnResize
    dst.baseW = src.baseW
    dst.baseH = src.baseH

    dst.groups  = DeepCopyTable(src.groups or {})
    dst.anchors = DeepCopyTable(src.anchors or {})
    dst.attach  = DeepCopyTable(src.attach or {})
    dst.ssr     = DeepCopyTable(src.ssr or { scripts = {}, autorun = {}, last = nil })

    NormalizeProfileDB(dst)
end

function GC:CopyProfileToCurrent(srcKey)
    self:Init()
    if self._dbMode ~= "profile" or not self._root then return false end
    
    local activeKey = self._activeProfileKey
    if not activeKey or activeKey == "master" then return false end

    local src
    if srcKey == "master" then
        local globalDB = _G[GLOBAL_SV_NAME]
        src = globalDB and globalDB.master
    else
        src = self._root.profiles[srcKey]
    end

    if type(src) == "table" then
        local dst = self._root.profiles[activeKey]
        CopyLayout(src, dst)
        if self._ApplyProfileChange then self:_ApplyProfileChange("copy_profile") end
        return true
    end
    return false
end

function GC:CopyProfileToMaster(srcKey)
    self:Init()
    if not srcKey or srcKey == "master" then return false end
    if self._dbMode ~= "profile" or not self._root then return false end

    local globalDB = _G[GLOBAL_SV_NAME]
    if not (globalDB and globalDB.master) then return false end

    local src = self._root.profiles[srcKey]
    if type(src) == "table" then
        CopyLayout(src, globalDB.master)
        return true
    end
    return false
end

local function EnsureDB_ProfileFirst()
    -- Initialize Global DB for Account-wide Master
    _G[GLOBAL_SV_NAME] = _G[GLOBAL_SV_NAME] or {}
    local globalDB = _G[GLOBAL_SV_NAME]
    globalDB.master = globalDB.master or {}
    NormalizeProfileDB(globalDB.master)

    local prof = GetRobuiProfileRoot()
    if prof then
        prof.rgrid = prof.rgrid or {}
        local root = prof.rgrid

        root.meta = root.meta or {}
        MergeDefaults(root.meta, DEFAULT_META)
        if type(root.profiles) ~= "table" then root.profiles = {} end

        -- Link the profile's master to the Account-Wide Global Master
        root.profiles.master = globalDB.master

        -- Ensure current Char/Spec profile exists (Empty by default)
        local desiredKey = GetCharSpecKey()
        root.profiles[desiredKey] = root.profiles[desiredKey] or {}
        NormalizeProfileDB(root.profiles[desiredKey])

        local m = root.meta
        m.version = tonumber(m.version) or 1
        m.autoEnabled = (m.autoEnabled ~= false)
        if m.manualProfile ~= nil and m.manualProfile ~= "master" then
            m.manualProfile = nil
        end
        m.activeProfile = NormalizeProfileKey(m.activeProfile) or "master"
        m.lastAutoProfile = NormalizeProfileKey(m.lastAutoProfile) or desiredKey
        if m.lastAutoProfile == "master" then m.lastAutoProfile = desiredKey end

        local activeKey
        if m.manualProfile == "master" then
            activeKey = "master"
        elseif m.autoEnabled then
            activeKey = desiredKey
            m.lastAutoProfile = activeKey
        else
            activeKey = (m.activeProfile ~= "master") and m.activeProfile or desiredKey
            if activeKey == "master" then activeKey = desiredKey end
        end

        m.activeProfile = activeKey
        return root.profiles[activeKey], "profile", root
    end

    -- Fallback
    _G[SV_NAME] = _G[SV_NAME] or {}
    local db = _G[SV_NAME]
    NormalizeProfileDB(db)
    return db, "sv", nil
end

GC.db = GC.db or nil
GC._dbMode = GC._dbMode or nil
GC._root = GC._root or nil
GC._activeProfileKey = GC._activeProfileKey or nil
GC._pendingAutoApply = GC._pendingAutoApply or false
GC._plugins      = GC._plugins or {}      
GC._pluginOrder  = GC._pluginOrder or {}  
GC._pluginFrames = GC._pluginFrames or {} 
GC._attaching    = GC._attaching or {}    

function GC:HasRoleProfiles()
    self:Init()
    return (self._dbMode == "profile" and self._root and type(self._root.profiles) == "table") and true or false
end

function GC:GetActiveProfileKey()
    self:Init()
    return self._activeProfileKey or "master"
end

function GC:IsManualMaster()
    self:Init()
    return (self._root and self._root.meta and self._root.meta.manualProfile == "master") and true or false
end

function GC:SetManualMaster(on)
    self:Init()
    if not (self._root and self._root.meta) then return false end

    if on then
        self._root.meta.manualProfile = "master"
        return self:SwitchProfile("master", "manual_master")
    else
        self._root.meta.manualProfile = nil
        return self:ApplyAutoProfile("manual_off")
    end
end

function GC:GetDesiredAutoProfileKey()
    return GetCharSpecKey()
end

function GC:ApplyAutoProfile(reason)
    self:Init()
    if not (self._root and self._root.meta) then return false end
    local m = self._root.meta

    if m.manualProfile == "master" then return true end
    if m.autoEnabled == false then return true end

    local desired = self:GetDesiredAutoProfileKey()
    if desired ~= (self._activeProfileKey or m.activeProfile) then
        return self:SwitchProfile(desired, reason or "auto")
    end
    return true
end

local function SoftDetachAllFrames(self)
    for _, frame in pairs(self._pluginFrames or {}) do
        if frame and frame.ClearAllPoints then
            pcall(frame.ClearAllPoints, frame)
        end
        if frame and frame.Hide then
            pcall(frame.Hide, frame)
        end
    end
end

function GC:SwitchProfile(key, reason)
    self:Init()
    key = NormalizeProfileKey(key) or GetCharSpecKey()

    if self._dbMode ~= "profile" or not (self._root and self._root.profiles) then
        return false
    end

    if UnitAffectingCombat and UnitAffectingCombat("player") then
        self._pendingAutoApply = true
        return false
    end

    -- Ensure profile exists before assigning it
    if type(self._root.profiles[key]) ~= "table" then
        self._root.profiles[key] = {}
        NormalizeProfileDB(self._root.profiles[key])
    end

    local m = self._root.meta
    if not m then return false end

    if key ~= "master" then
        m.lastAutoProfile = key
        if m.manualProfile == "master" then
            m.manualProfile = nil
        end
    end

    m.activeProfile = key
    self._activeProfileKey = key
    self.db = self._root.profiles[key]

    SoftDetachAllFrames(self)

    if self.ui and self.ui.grid and self.CreateUI then
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
        if self.RefreshPluginList then self:RefreshPluginList() end
        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
        if self.ApplyEditMode then self:ApplyEditMode() end
    end

    if type(self.db.attach) == "table" then
        for pid,_ in pairs(self.db.attach) do
            self:AttachPlugin(pid) 
        end
    end

    if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    if self.ReflowAll then self:ReflowAll() end
    return true
end

function GC:Init(forceReinit)
    if self.db and not forceReinit then return end
    self.db, self._dbMode, self._root = EnsureDB_ProfileFirst()

    if self._root and self._root.meta then
        self._activeProfileKey = NormalizeProfileKey(self._root.meta.activeProfile) or "master"
    else
        self._activeProfileKey = nil
    end

    if type(self.db.groups) ~= "table" then self.db.groups = {} end

    if type(self.db.anchors) == "table" then
        for _,a in pairs(self.db.anchors) do
            if type(a) == "table" then
                if type(a.showMode) ~= "string" or a.showMode == "" or not IsAnchorMode(a.showMode) then
                    a.showMode = "INHERIT"
                end
                if a.orient ~= nil then
                    a.orient = NormalizeOrient(a.orient)
                end
                if a.fw ~= nil then a.fw = Round(a.fw) end
                if a.fh ~= nil then a.fh = Round(a.fh) end
            end
        end
    end
end

function GC:OnProfileChanged()
    self:Init(true)
    if self._dbMode == "profile" and self._root and self._root.meta then
        self:ApplyAutoProfile("RobUIProfileChanged")
        self:Init(true)
    end

    if self.ui and self.ui.grid and self.CreateUI then
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
        if self.RefreshPluginList then self:RefreshPluginList() end
        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
        if self.ApplyEditMode then self:ApplyEditMode() end
    end

    SoftDetachAllFrames(self)
    if type(self.db.attach) == "table" then
        for pid,_ in pairs(self.db.attach) do
            self:AttachPlugin(pid) 
        end
    end
    if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
end

function GC:IsEditMode()
    self:Init()
    return self.db.editMode and true or false
end

function GC:SetEditMode(on)
    self:Init()
    self.db.editMode = on and true or false
    if self.CreateUI then self:CreateUI() end
    if self.ApplyEditMode then self:ApplyEditMode() end
    if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
end

function GC:ToggleEditMode()
    self:SetEditMode(not self:IsEditMode())
end

function GC:GetGroup(gid, create)
    self:Init()
    gid = tonumber(gid) or 0
    if gid <= 0 then return nil end

    self.db.groups = self.db.groups or {}
    local g = self.db.groups[gid]

    if not g and create then
        g = { name = "Group " .. gid, showMode = "ALWAYS" }
        self.db.groups[gid] = g
    end

    if g then
        if type(g.name) ~= "string" or g.name == "" then
            g.name = "Group " .. gid
        end
        if type(g.showMode) ~= "string" or not IsGroupMode(g.showMode) then
            g.showMode = "ALWAYS"
        end
    end

    return g
end

function GC:EnsureGroup(gid) return self:GetGroup(gid, true) end

function GC:NewGroup(name)
    self:Init()
    local gid = tonumber(self.db.nextGroupId) or 1
    self.db.nextGroupId = gid + 1

    local g = self:GetGroup(gid, true)
    if type(name) == "string" and name ~= "" then g.name = name end
    return gid
end

function GC:SetGroupName(gid, name)
    self:Init()
    gid = tonumber(gid) or 0
    if gid <= 0 then return false end
    if type(name) ~= "string" or name == "" then return false end
    local g = self:GetGroup(gid, true)
    g.name = name
    return true
end

function GC:SetGroupShowMode(gid, mode)
    self:Init()
    gid = tonumber(gid) or 0
    if gid <= 0 then return false end
    if type(mode) ~= "string" or not IsGroupMode(mode) then return false end

    local g = self:GetGroup(gid, true)
    g.showMode = mode
    if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    return true
end

function GC:DeleteGroup(gid)
    self:Init()
    gid = tonumber(gid) or 0
    if gid <= 0 then return false end

    if type(self.db.groups) ~= "table" then self.db.groups = {} end
    self.db.groups[gid] = nil

    if type(self.db.anchors) == "table" then
        for anchorId, a in pairs(self.db.anchors) do
            if type(a) == "table" then
                local ag = tonumber(a.group) or 0
                if ag == gid then
                    a.group = 0
                    if self.ApplyVisibilityForAnchor then
                        self:ApplyVisibilityForAnchor(anchorId)
                    end
                end
            end
        end
    end

    if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    if self.ReflowAll then self:ReflowAll() end

    if self.ui and self.ui.grid then
        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
        if self.UpdateAllAnchorFramesSelected then self:UpdateAllAnchorFramesSelected() end
        if self.RefreshPluginList then self:RefreshPluginList() end
    end
    return true
end

function GC:GetAllGroupIds(out)
    self:Init()
    out = out or {}
    for k in pairs(out) do out[k] = nil end

    local seen, n = {}, 0
    for gid,_ in pairs(self.db.groups or {}) do
        gid = tonumber(gid)
        if gid and gid > 0 and not seen[gid] then
            seen[gid] = true
            n = n + 1
            out[n] = gid
        end
    end

    for _,a in pairs(self.db.anchors or {}) do
        if type(a) == "table" then
            local gid = tonumber(a.group) or 0
            if gid > 0 and not seen[gid] then
                seen[gid] = true
                n = n + 1
                out[n] = gid
            end
        end
    end

    table_sort(out)
    return out, n
end

function GC:IsInCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

function GC:GetAnchorEffectiveShowMode(anchorId)
    self:Init()
    local a = self.db.anchors and self.db.anchors[anchorId]
    if not a then return "ALWAYS" end

    local am = a.showMode
    if type(am) ~= "string" or am == "" or not IsAnchorMode(am) then
        am = "INHERIT"
        a.showMode = "INHERIT"
    end

    if am ~= "INHERIT" then
        return am
    end

    local gid = tonumber(a.group) or 0
    if gid > 0 then
        local g = self:GetGroup(gid, false)
        if g and IsGroupMode(g.showMode) then
            return g.showMode
        end
    end

    return "ALWAYS"
end

function GC:ShouldShowByMode(mode)
    mode = (type(mode) == "string" and mode) or "ALWAYS"
    if mode == "HIDDEN" then return false end
    if mode == "COMBAT" then return self:IsInCombat() end
    return true
end

function GC:ApplyVisibilityForAnchor(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return end

    if self.db.editMode then
        for pid, aid in pairs(self.db.attach or {}) do
            if aid == anchorId then
                local f = self._pluginFrames and self._pluginFrames[pid]
                if f and f.Show then pcall(f.Show, f) end
            end
        end
        return
    end

    local mode = self:GetAnchorEffectiveShowMode(anchorId)
    local show = self:ShouldShowByMode(mode)

    for pid, aid in pairs(self.db.attach or {}) do
        if aid == anchorId then
            local f = self._pluginFrames and self._pluginFrames[pid]
            if f then
                if show then
                    if f.Show then pcall(f.Show, f) end
                else
                    if f.Hide then pcall(f.Hide, f) end
                end
            end
        end
    end
end

function GC:ApplyVisibilityAll()
    self:Init()
    for _, aid in pairs(self.db.attach or {}) do
        if type(aid) == "string" then
            self:ApplyVisibilityForAnchor(aid)
        end
    end
end

function GC:SetAnchorShowMode(anchorId, mode)
    self:Init()
    if type(anchorId) ~= "string" then return false end
    if type(mode) ~= "string" or not IsAnchorMode(mode) then return false end
    local a = self.db.anchors and self.db.anchors[anchorId]
    if not a then return false end
    a.showMode = mode
    self:ApplyVisibilityForAnchor(anchorId)
    return true
end

function GC:GetPlugin(id)
    return self._plugins and self._plugins[id]
end

function GC:RegisterPlugin(id, opts)
    self:Init()
    if type(id) ~= "string" or id == "" then return end
    if type(opts) ~= "table" then opts = {} end
    opts.name = opts.name or id

    if not self._plugins[id] then
        table_insert(self._pluginOrder, id)
    end
    self._plugins[id] = opts

    if self.RefreshPluginList then self:RefreshPluginList() end
    if self.db.attach and type(self.db.attach[id]) == "string" then
        self:AttachPlugin(id)
    end
end

function GC:IsPluginAttached(pluginId)
    self:Init()
    return (self.db.attach and type(self.db.attach[pluginId]) == "string") and true or false
end

function GC:GetPluginAnchor(pluginId)
    self:Init()
    return self.db.attach and self.db.attach[pluginId]
end

function GC:GetPluginIdForAnchor(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return nil end
    for pid, aid in pairs(self.db.attach or {}) do
        if aid == anchorId then return pid end
    end
    return nil
end

function GC:GetPluginFrame(pluginId)
    self:Init()
    if type(pluginId) ~= "string" then return nil end
    return self._pluginFrames and self._pluginFrames[pluginId] or nil
end

function GC:GetGlobalScale()
    self:Init()
    return Clamp(self.db.globalScale or 1.0, 0.2, 3.0)
end

function GC:SetGlobalScale(s)
    self:Init()
    self.db.globalScale = Clamp(s, 0.2, 3.0)
    if self.ApplyGlobalScaleToAll then self:ApplyGlobalScaleToAll() end
    if self.UpdateScaleUI then self:UpdateScaleUI() end
end

function GC:ApplyFrameScaleForPlugin(pluginId)
    self:Init()
    local p = self:GetPlugin(pluginId)
    local frame = self._pluginFrames[pluginId]
    if not (p and frame) then return end
    local g = self:GetGlobalScale()
    if type(p.setScale) == "function" then
        pcall(p.setScale, frame, g)
    elseif frame.SetScale then
        pcall(frame.SetScale, frame, g)
    end
end

function GC:ApplyGlobalScaleToAll()
    self:Init()
    for pid,_ in pairs(self.db.attach or {}) do
        self:ApplyFrameScaleForPlugin(pid)
    end
end

function GC:SetAnchorFrameLayout(anchorId, w, h, orient)
    self:Init()
    if type(anchorId) ~= "string" then return false end
    local a = self.db.anchors and self.db.anchors[anchorId]
    if type(a) ~= "table" then return false end

    w = Round(tonumber(w) or a.fw or 0)
    h = Round(tonumber(h) or a.fh or 0)
    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    orient = NormalizeOrient(orient or a.orient)

    a.fw = w
    a.fh = h
    a.orient = orient

    local pid = self:GetPluginIdForAnchor(anchorId)
    if pid then
        local frame = self:GetPluginFrame(pid)
        if frame and frame.SetSize then
            pcall(frame.SetSize, frame, w, h)
        end

        local p = self:GetPlugin(pid)
        if p then
            if type(p.setOrientation) == "function" then
                pcall(p.setOrientation, frame, orient)
            elseif frame and frame.SetOrientation then
                pcall(frame.SetOrientation, frame, (orient == "V") and "VERTICAL" or "HORIZONTAL")
            elseif frame and frame.SetVertical then
                pcall(frame.SetVertical, frame, orient == "V")
            end
        end
    end
    return true
end

local function ApplyAnchorFrameLayoutIfAny(self, pluginId, anchorId)
    if type(anchorId) ~= "string" then return end
    local a = self.db.anchors and self.db.anchors[anchorId]
    if type(a) ~= "table" then return end

    local w = tonumber(a.fw)
    local h = tonumber(a.fh)
    local o = a.orient

    if not w and not h and not o then return end

    local frame = self._pluginFrames and self._pluginFrames[pluginId]
    if frame and frame.SetSize and (w or h) then
        local cw, ch
        if frame.GetSize then cw, ch = frame:GetSize() end
        w = Round(w or cw or 0)
        h = Round(h or ch or 0)
        if w < 1 then w = 1 end
        if h < 1 then h = 1 end
        pcall(frame.SetSize, frame, w, h)
    end

    o = NormalizeOrient(o)
    a.orient = o

    local p = self:GetPlugin(pluginId)
    if p then
        if type(p.setOrientation) == "function" then
            pcall(p.setOrientation, frame, o)
        elseif frame and frame.SetOrientation then
            pcall(frame.SetOrientation, frame, (o == "V") and "VERTICAL" or "HORIZONTAL")
        elseif frame and frame.SetVertical then
            pcall(frame.SetVertical, frame, o == "V")
        end
    end
end

function GC:AttachPlugin(pluginId, forceCreate)
    self:Init()
    if type(pluginId) ~= "string" then return false end
    if self._attaching[pluginId] then return false end

    local p = self:GetPlugin(pluginId)
    if not p then return false end

    local existingAnchorId = self.db.attach and self.db.attach[pluginId]
    if type(existingAnchorId) ~= "string" and not forceCreate then
        return false
    end

    if self.CreateUI then self:CreateUI() end
    self._attaching[pluginId] = true

    local frame = self._pluginFrames[pluginId]
    if not frame then
        if type(p.build) == "function" then
            local ok, f = pcall(p.build)
            if ok then frame = f end
        end
        if frame then
            self._pluginFrames[pluginId] = frame
        end
    end

    if not frame then
        self._attaching[pluginId] = nil
        return false
    end

    local anchorId = existingAnchorId
    local def = type(p.default) == "table" and p.default or {}

    if type(anchorId) ~= "string" then
        anchorId = "P_" .. pluginId
        -- Added the required `true` flag to EnsureAnchor to permit creation
        anchorId = self:EnsureAnchor(anchorId, {
            gx = def.gx or 0,
            gy = def.gy or 0,
            group = def.group or 0,
            scaleWithGrid = def.scaleWithGrid or false,
            label = def.label or p.name or anchorId,
            showMode = def.showMode or "INHERIT",
        }, true)
        self.db.attach[pluginId] = anchorId
    else
        self:EnsureAnchor(anchorId, def, true)
    end

    if self.AttachFrameToAnchor then
        self:AttachFrameToAnchor(pluginId, frame, anchorId)
    end

    ApplyAnchorFrameLayoutIfAny(self, pluginId, anchorId)

    self:ApplyFrameScaleForPlugin(pluginId)
    if self.RefreshPluginList then self:RefreshPluginList() end
    self:ApplyVisibilityForAnchor(anchorId)

    self._attaching[pluginId] = nil
    return true
end

function GC:DetachPlugin(pluginId)
    self:Init()
    if type(pluginId) ~= "string" then return end

    local frame = self._pluginFrames[pluginId]
    if frame and frame.ClearAllPoints then
        pcall(frame.ClearAllPoints, frame)
        if frame.SetPoint then
            pcall(frame.SetPoint, frame, "CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    if self.db.attach then
        self.db.attach[pluginId] = nil
    end
    if self.RefreshPluginList then self:RefreshPluginList() end
end

function GC:ReflowAll()
    self:Init()
    if not self.AttachFrameToAnchor then return end
    for pid, anchorId in pairs(self.db.attach or {}) do
        local frame = self._pluginFrames[pid]
        if frame and type(anchorId) == "string" then
            self:AttachFrameToAnchor(pid, frame, anchorId)
            ApplyAnchorFrameLayoutIfAny(self, pid, anchorId)
            self:ApplyFrameScaleForPlugin(pid)
            self:ApplyVisibilityForAnchor(anchorId)
        end
    end
end

SLASH_ROBUIGRID1 = "/rgrid"
SlashCmdList["ROBUIGRID"] = function(msg)
    msg = (msg or ""):lower()
    GC:Init()
    if GC.CreateUI then GC:CreateUI() end

    if msg == "edit" then
        GC:SetEditMode(true)
    elseif msg == "hide" then
        GC:SetEditMode(false)
    elseif msg == "master" then
        GC:SetManualMaster(true)
    elseif msg == "auto" then
        GC:SetManualMaster(false)
    else
        GC:ToggleEditMode()
    end
end

local E = CreateFrame("Frame")
E:RegisterEvent("ADDON_LOADED")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_REGEN_DISABLED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")
E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
E:RegisterEvent("PLAYER_ROLES_ASSIGNED")
E:RegisterEvent("GROUP_ROSTER_UPDATE")

E:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= AddonName then return end

    GC:Init()

    if event == "PLAYER_REGEN_DISABLED" then
        if GC.ApplyVisibilityAll then GC:ApplyVisibilityAll() end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if GC.ApplyVisibilityAll then GC:ApplyVisibilityAll() end
        if GC._pendingAutoApply then
            GC._pendingAutoApply = false
            GC:ApplyAutoProfile("after_combat")
            GC:Init(true)
        end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
        if GC._dbMode == "profile" and GC._root and GC._root.meta then
            if UnitAffectingCombat and UnitAffectingCombat("player") then
                GC._pendingAutoApply = true
            else
                GC:ApplyAutoProfile(event)
                GC:Init(true)
            end
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if GC._dbMode == "profile" and GC._root and GC._root.meta then
            GC:ApplyAutoProfile("login")
            GC:Init(true)
        end

        if GC.SSR_Autorun then GC:SSR_Autorun() end

        if GC.db.editMode and GC.CreateUI then
            GC:CreateUI()
            GC:SetEditMode(true)
        end

        for pid,_ in pairs(GC.db.attach or {}) do
            GC:AttachPlugin(pid) 
        end

        if GC.ApplyVisibilityAll then GC:ApplyVisibilityAll() end
    end
end)