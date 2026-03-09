-- ============================================================================
-- grid_ui.lua (RobUI GridCore) -- UI LAYOUT / LEFT PLUGINS / CANVAS / RIGHT SSR
-- ============================================================================
local AddonName, ns = ...
local GC = ns and ns.GridCore
if not GC then return end

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local ToggleDropDownMenu = ToggleDropDownMenu

local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth

local tostring = tostring
local tonumber = tonumber
local type = type
local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local pcall = pcall
local table_sort = table.sort
local string_match = string.match
local string_lower = string.lower
local string_format = string.format
local math_floor = math.floor
local math_max = math.max

local function Round(v) return math_floor((tonumber(v) or 0) + 0.5) end

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

-- ============================================================================
-- COMBAT/PROTECTED SAFE ROOT LAYOUT (fixes ADDON_ACTION_BLOCKED on :SetSize)
-- ============================================================================
GC._uiDefer = GC._uiDefer or { pending = false }
local _uiDefer = GC._uiDefer

local function _RootCanMutate(grid)
    if not grid then return false end
    if InCombatLockdown() then return false end
    if grid.IsProtected and grid:IsProtected() then return false end
    return true
end

local function _QueueRootLayout(self, grid, db, reason)
    if not (self and grid and db) then return end
    _uiDefer.pending = true
    _uiDefer.reason = reason or "defer"

    _uiDefer.w = db.w or 1280
    _uiDefer.h = db.h or 680
    _uiDefer.point = db.point or "CENTER"
    _uiDefer.relPoint = db.relPoint or "CENTER"
    _uiDefer.x = db.x or 0
    _uiDefer.y = db.y or 0
end

local function _ApplyQueuedRootLayout(self)
    if not (self and self.ui and self.ui.grid) then return end
    if not _uiDefer.pending then return end

    local grid = self.ui.grid
    if not _RootCanMutate(grid) then return end

    _uiDefer.pending = false

    if grid.SetSize then grid:SetSize(_uiDefer.w, _uiDefer.h) end
    if grid.ClearAllPoints and grid.SetPoint then
        grid:ClearAllPoints()
        grid:SetPoint(_uiDefer.point, UIParent, _uiDefer.relPoint, _uiDefer.x, _uiDefer.y)
    end

    if self.UpdateGridVisuals then self:UpdateGridVisuals() end
    if self.ReflowAll then self:ReflowAll("ui:defer_apply") end
end

GC._uiDeferFrame = GC._uiDeferFrame or CreateFrame("Frame")
GC._uiDeferFrame:UnregisterAllEvents()
GC._uiDeferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
GC._uiDeferFrame:SetScript("OnEvent", function()
    _ApplyQueuedRootLayout(GC)
end)

local function FindSlashKeyForCommand(cmdWithSlash)
    if type(cmdWithSlash) ~= "string" or cmdWithSlash == "" then return nil end
    if cmdWithSlash:sub(1,1) ~= "/" then cmdWithSlash = "/" .. cmdWithSlash end
    local want = string_lower(cmdWithSlash)

    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and string_match(k, "^SLASH_") then
            if string_lower(v) == want then
                local key = string_match(k, "^SLASH_([A-Z0-9_]+)%d+$")
                if key and SlashCmdList and SlashCmdList[key] then
                    return key
                end
            end
        end
    end
    return nil
end

local function RunSlashCommand(cmdWithSlash)
    if InCombatLockdown() then return end
    if type(cmdWithSlash) ~= "string" or cmdWithSlash == "" then return end
    if cmdWithSlash:sub(1,1) ~= "/" then cmdWithSlash = "/" .. cmdWithSlash end

    local key = FindSlashKeyForCommand(cmdWithSlash)
    if key and SlashCmdList and SlashCmdList[key] then
        SlashCmdList[key]("")
        return
    end

    local raw = cmdWithSlash:sub(2)
    local first = raw:match("^([^%s]+)")
    if first and SlashCmdList then
        local up = first:upper()
        if SlashCmdList[up] then
            SlashCmdList[up](raw:match("^%S+%s*(.*)$") or "")
            return
        end
    end

    if ChatFrame_OpenChat then ChatFrame_OpenChat(cmdWithSlash) end
end

local function OpenCombatTools()
    if InCombatLockdown() then return end
    local R = _G.Robui
    if R and R.MasterConfig and R.MasterConfig.Toggle then
        if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
            R.MasterConfig:Toggle()
        end
        if R.MasterConfig.SelectTab then R.MasterConfig:SelectTab("Combat Tools") end
        return
    end
    if type(_G.OpenCombatToolsTab) == "function" then _G.OpenCombatToolsTab(); return end
    if ns and type(ns.OpenCombatToolsTab) == "function" then ns.OpenCombatToolsTab(); return end
end

GC.ui = GC.ui or nil
GC._pluginButtons = GC._pluginButtons or {}
GC._selectedPluginId = GC._selectedPluginId or nil
GC._sel = GC._sel or {}
GC._selectedAnchorId = GC._selectedAnchorId or nil

if type(GC.IsAnchorSelected) ~= "function" then
    function GC:IsAnchorSelected(anchorId)
        return self._sel and self._sel[anchorId] and true or false
    end
end

if type(GC.GetSelectedAnchorIds) ~= "function" then
    function GC:GetSelectedAnchorIds(out)
        out = out or {}
        for k in pairs(out) do out[k] = nil end
        local n = 0
        if self._sel then
            for id, on in pairs(self._sel) do
                if on then
                    n = n + 1
                    out[n] = id
                end
            end
        end
        if n == 0 and self._selectedAnchorId then
            n = 1
            out[1] = self._selectedAnchorId
        end
        return out, n
    end
end

if type(GC.SelectAnchor) ~= "function" then
    function GC:SelectAnchor(anchorId, add)
        if not anchorId then return end
        self._sel = self._sel or {}
        if not add then wipe(self._sel) end
        self._sel[anchorId] = true
        self._selectedAnchorId = anchorId

        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
        if self.UpdateAllAnchorFramesSelected then
            self:UpdateAllAnchorFramesSelected()
        elseif self._anchorFrames then
            for id, af in pairs(self._anchorFrames) do
                if af and af.SetAlpha then af:SetAlpha((self._sel[id] and 1) or 0.65) end
            end
        end
    end
end

if type(GC.ToggleAnchorSelected) ~= "function" then
    function GC:ToggleAnchorSelected(anchorId)
        if not anchorId then return end
        self._sel = self._sel or {}
        local on = self._sel[anchorId]
        if on then
            self._sel[anchorId] = nil
            if self._selectedAnchorId == anchorId then self._selectedAnchorId = nil end
        else
            self._sel[anchorId] = true
            self._selectedAnchorId = anchorId
        end

        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
        if self.UpdateAllAnchorFramesSelected then
            self:UpdateAllAnchorFramesSelected()
        elseif self._anchorFrames then
            for id, af in pairs(self._anchorFrames) do
                if af and af.SetAlpha then af:SetAlpha((self._sel[id] and 1) or 0.65) end
            end
        end
    end
end

if type(GC.UpdateAllAnchorFramesSelected) ~= "function" then
    function GC:UpdateAllAnchorFramesSelected()
        if not self._anchorFrames then return end
        for id, af in pairs(self._anchorFrames) do
            if af and af.SetAlpha then
                af:SetAlpha((self:IsAnchorSelected(id) and 1) or 0.65)
            end
        end
    end
end

local function GetSelectedIds(self) return self:GetSelectedAnchorIds() end

local function GetCommonGroup(self, ids, n)
    local db = self.db
    if n <= 0 then return nil end
    local cg = nil
    for i=1,n do
        local a = db.anchors[ids[i]]
        local g = a and (tonumber(a.group) or 0) or 0
        if cg == nil then cg = g
        elseif cg ~= g then return -1 end
    end
    return cg or 0
end

local function GetCommonAnchorMode(self, ids, n)
    local db = self.db
    if n <= 0 then return nil end
    local cm = nil
    for i=1,n do
        local a = db.anchors[ids[i]]
        local m = a and a.showMode or "INHERIT"
        if type(m) ~= "string" or m == "" then m = "INHERIT" end
        if cm == nil then cm = m
        elseif cm ~= m then return "MIXED" end
    end
    return cm or "INHERIT"
end

local function NormalizeOrient(v)
    if v == "V" or v == "VERTICAL" then return "V" end
    return "H"
end

function GC:_FindPluginIdOnAnchor(anchorId)
    if type(anchorId) ~= "string" then return nil end
    local db = self.db or {}
    local maps = { db.attach, db.attached, db.pluginToAnchor, db.pluginAnchor, db.pluginsToAnchor, (db.plugins and db.plugins.attach) }
    for _,m in ipairs(maps) do
        if type(m) == "table" then
            for pid, aid in pairs(m) do
                if aid == anchorId and type(pid) == "string" then return pid end
            end
        end
    end
    if type(self.GetPluginAnchor) == "function" then
        for pid,_ in pairs(self._plugins or {}) do
            local ok, aid = pcall(self.GetPluginAnchor, self, pid)
            if ok and aid == anchorId then return pid end
        end
    end
    for pid,_ in pairs(self._plugins or {}) do
        if type(pid) == "string" then
            local aid = (type(db.attach) == "table" and db.attach[pid]) or (type(db.attached) == "table" and db.attached[pid])
            if aid == anchorId then return pid end
        end
    end
    return nil
end

function GC:_FindPluginFrame(pluginId)
    if type(pluginId) ~= "string" then return nil end
    local p = self.GetPlugin and self:GetPlugin(pluginId) or (self._plugins and self._plugins[pluginId])
    if type(p) == "table" then
        if p.frame and p.frame.SetSize then return p.frame end
        if p._frame and p._frame.SetSize then return p._frame end
        if p.instance and p.instance.SetSize then return p.instance end
    end
    local caches = { self._pluginFrames, self._frames, self._instances, self.instances, self.frames }
    for _,c in ipairs(caches) do
        if type(c) == "table" then
            local f = c[pluginId]
            if f and f.SetSize then return f end
        end
    end
    return nil
end

function GC:_ApplyAnchorAttachedFrameLayout(anchorId, w, h, orient)
    if InCombatLockdown() then return end
    if type(anchorId) ~= "string" then return end
    local db = self.db
    local a = db and db.anchors and db.anchors[anchorId]
    if not a then return end

    w = Round(tonumber(w) or a.fw or a.w or 0)
    h = Round(tonumber(h) or a.fh or a.h or 0)
    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    orient = NormalizeOrient(orient or a.orient or a.dir or a.orientation)

    a.fw = w
    a.fh = h
    a.orient = orient

    local pid = self:_FindPluginIdOnAnchor(anchorId)
    local frame = pid and self:_FindPluginFrame(pid) or nil
    if frame and frame.SetSize then
        frame:SetSize(w, h)
        if frame.SetOrientation then pcall(frame.SetOrientation, frame, orient == "V" and "VERTICAL" or "HORIZONTAL")
        elseif frame.SetVertical then pcall(frame.SetVertical, frame, orient == "V") end
        if pid and type(self.ApplyLayoutForPlugin) == "function" then pcall(self.ApplyLayoutForPlugin, self, pid) end
    end
end

local function GetPrettyProfileText()
    if not GC or not GC.HasRoleProfiles or not GC:HasRoleProfiles() then return "Profile: (legacy)" end
    local manualMaster = (GC.IsManualMaster and GC:IsManualMaster()) and true or false

    if manualMaster then return "MASTER" end

    local specName = "No Spec"
    if type(_G.GetSpecialization) == "function" then
        local specIndex = _G.GetSpecialization()
        if specIndex then
            local _, name = _G.GetSpecializationInfo(specIndex)
            if name then specName = name end
        end
    end

    return "AUTO (" .. specName:upper() .. ")"
end

function GC:_SyncUIFromDB(reason)
    if not (self.ui and self.ui.grid) then return end
    local db = self.db or {}
    local grid = self.ui.grid

    db.anchors = db.anchors or {}

    -- ROOT SIZE/POS MUST BE COMBAT+PROTECTED SAFE
    if not _RootCanMutate(grid) then
        _QueueRootLayout(self, grid, db, reason or "ui:sync")
    else
        if grid.SetSize then grid:SetSize(db.w or 1280, db.h or 680) end
        if grid.ClearAllPoints and grid.SetPoint then
            grid:ClearAllPoints()
            grid:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
        end
    end

    MakeBackdrop(grid, db.alpha, db.borderAlpha)

    self._anchorFrames = self._anchorFrames or {}
    for aid, af in pairs(self._anchorFrames) do
        if af then
            if not db.anchors[aid] then af:Hide() else af:SetShown(db.editMode and true or false) end
        end
    end

    for aid,_ in pairs(db.anchors) do
        if type(aid) == "string" then
            if self.CreateOrUpdateAnchorFrame then self:CreateOrUpdateAnchorFrame(aid) end
            if self.PositionAnchorFrame then self:PositionAnchorFrame(aid) end
            if self.UpdateAnchorLabel then self:UpdateAnchorLabel(aid) end
        end
    end

    if self.UpdateGridVisuals then self:UpdateGridVisuals() end
    if self.RefreshPluginList then self:RefreshPluginList() end
    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    if self.ApplyEditMode then self:ApplyEditMode() end
    if self.UpdateScaleUI then self:UpdateScaleUI() end
    if self._RefreshProfileUI then self:_RefreshProfileUI() end

    -- If we deferred root changes, try applying now (safe out of combat)
    _ApplyQueuedRootLayout(self)
end

function GC:_ApplyProfileChange(reason)
    if InCombatLockdown() then return end
    if self.Init then self:Init(true) end
    if self.OnProfileChanged then self:OnProfileChanged() end
    self:_SyncUIFromDB(reason or "ui:profile")
end

function GC:CreateUI()
    -- Do not build this UI in combat; it can taint and trigger protected calls.
    if InCombatLockdown() then
        print("|cffff0000[RobUI Grid]|r Cannot open Grid UI in combat.")
        return
    end

    if self.Init then self:Init() end
    if self.ui and self.ui.grid then
        self:_SyncUIFromDB("ui:create_refresh")
        return
    end

    self._plugins = self._plugins or {}
    self._pluginOrder = self._pluginOrder or {}
    self._anchorFrames = self._anchorFrames or {}

    local db = self.db or {}
    db.anchors = db.anchors or {}

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

    -- ROOT SIZE/POS MUST BE COMBAT+PROTECTED SAFE
    if not _RootCanMutate(grid) then
        _QueueRootLayout(self, grid, db, "ui:create")
    else
        grid:SetSize(db.w or 1280, db.h or 680)
        grid:ClearAllPoints()
        grid:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
    end

    if grid.SetResizeBounds then grid:SetResizeBounds(980, 600, 2400, 1400)
    elseif grid.SetMinResize then grid:SetMinResize(980, 600) end

    local header = CreateFrame("Frame", nil, grid, "BackdropTemplate")
    self.ui.header = header
    header:SetPoint("TOPLEFT", grid, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -1, -1)
    header:SetHeight(30)
    MakeBackdrop(header, 0.55, 0)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not InCombatLockdown() then grid:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        grid:StopMovingOrSizing()
        local point, _, relPoint, x, y = grid:GetPoint()
        self.db.point, self.db.relPoint, self.db.x, self.db.y = point, relPoint, Round(x), Round(y)
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("Grid")

    local function HeaderBtn(text, w)
        local b = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        b:SetHeight(20)
        b:SetWidth(w or 86)
        b:SetText(text)
        return b
    end

    -- Compact Launch Buttons
    local btnCT = HeaderBtn("CT", 36)
    btnCT:SetPoint("LEFT", title, "RIGHT", 10, 0)
    btnCT:SetScript("OnClick", function() RunSlashCommand("/ctframes") end)

    local btnA2 = HeaderBtn("A2", 36)
    btnA2:SetPoint("LEFT", btnCT, "RIGHT", 4, 0)
    btnA2:SetScript("OnClick", function() RunSlashCommand("/aurasv2") end)

    local btnRCA = HeaderBtn("RCA", 46)
    btnRCA:SetPoint("LEFT", btnA2, "RIGHT", 4, 0)
    btnRCA:SetScript("OnClick", function() RunSlashCommand("/rca") end)

    local btnCTTools = HeaderBtn("Tools", 56)
    btnCTTools:SetPoint("LEFT", btnRCA, "RIGHT", 4, 0)
    btnCTTools:SetScript("OnClick", function() OpenCombatTools() end)

    local btnCE = HeaderBtn("Info", 50)
    btnCE:SetPoint("LEFT", btnCTTools, "RIGHT", 4, 0)
    btnCE:SetScript("OnClick", function() RunSlashCommand("/ce") end)

    local btnIncCast = HeaderBtn("inc cast", 70)
    btnIncCast:SetPoint("LEFT", btnCE, "RIGHT", 4, 0)
    btnIncCast:SetScript("OnClick", function() RunSlashCommand("/pic") end)

    -- Profile Section
    local profText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profText:SetPoint("LEFT", btnIncCast, "RIGHT", 12, 0)
    profText:SetText(GetPrettyProfileText())
    self.ui.profileText = profText

    local profDD = CreateFrame("Frame", "RobUIGrid_ProfileDD", header, "UIDropDownMenuTemplate")
    profDD:SetPoint("LEFT", profText, "RIGHT", -10, -3)
    UIDropDownMenu_SetWidth(profDD, 120)
    self.ui.profileDD = profDD

    -- New Copy Dropdown Menu
    local copyBtn = HeaderBtn("Copy...", 65)
    copyBtn:SetPoint("LEFT", profDD, "RIGHT", -12, 3)
    self.ui.btnCopyProfile = copyBtn

    local copyMenu = CreateFrame("Frame", "RobUIGrid_CopyMenu", copyBtn, "UIDropDownMenuTemplate")
    copyBtn:SetScript("OnClick", function(selfBtn)
        if InCombatLockdown() then return end
        ToggleDropDownMenu(1, nil, copyMenu, selfBtn, 0, 0)
    end)

    UIDropDownMenu_Initialize(copyMenu, function(_, level)
        level = level or 1
        if level ~= 1 then return end

        local activeKey = self:GetActiveProfileKey()
        if activeKey == "master" then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Cannot copy into MASTER"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local function addCopyOption(text, srcKey)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.notCheckable = true
            info.func = function()
                if InCombatLockdown() then return end
                local ok = self:CopyProfileToCurrent(srcKey)
                if ok then
                    print("|cff00ccff[RobUI Grid]|r Successfully copied '" .. text .. "' to current profile.")
                else
                    print("|cffff0000[RobUI Grid]|r Failed to copy profile.")
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end

        addCopyOption("Global MASTER", "master")

        if self._root and self._root.profiles then
            for k, _ in pairs(self._root.profiles) do
                if k ~= "master" and k ~= activeKey then
                    addCopyOption(k, k)
                end
            end
        end
    end)

    local pushBtn = HeaderBtn("Push", 50)
    pushBtn:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)
    self.ui.btnPushMaster = pushBtn

    local function RefreshProfileUI()
        if not self.ui then return end
        if self.ui.profileText then self.ui.profileText:SetText(GetPrettyProfileText()) end
        if self.ui.profileDD then
            if self.HasRoleProfiles and self:HasRoleProfiles() then
                local manual = (self.IsManualMaster and self:IsManualMaster()) and true or false
                if manual then UIDropDownMenu_SetText(self.ui.profileDD, "MASTER (manual)")
                else
                    local activeSpecText = GetPrettyProfileText():match("AUTO %((.-)%)") or "SPEC"
                    UIDropDownMenu_SetText(self.ui.profileDD, "AUTO ("..activeSpecText..")")
                end
            else
                UIDropDownMenu_SetText(self.ui.profileDD, "(legacy)")
            end
        end
    end
    self._RefreshProfileUI = RefreshProfileUI

    UIDropDownMenu_Initialize(profDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end

        local function add(text, func, checked)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = func
            info.checked = checked and true or false
            UIDropDownMenu_AddButton(info, level)
        end

        if not (self.HasRoleProfiles and self:HasRoleProfiles()) then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Role profiles not available"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local manual = (self.IsManualMaster and self:IsManualMaster()) and true or false
        local wantAuto = not manual

        add("AUTO (spec)", function()
            if InCombatLockdown() then return end
            if self.SetManualMaster then self:SetManualMaster(false)
            elseif self.ApplyAutoProfile then self:ApplyAutoProfile("ui:auto") end
            self:_ApplyProfileChange("ui:auto")
            RefreshProfileUI()
        end, wantAuto)

        add("MASTER (manual)", function()
            if InCombatLockdown() then return end
            if self.SetManualMaster then self:SetManualMaster(true)
            elseif self.SwitchProfile then self:SwitchProfile("master", "ui:master") end
            self:_ApplyProfileChange("ui:master")
            RefreshProfileUI()
        end, manual)
    end)

    pushBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not (self.HasRoleProfiles and self:HasRoleProfiles()) then return end
        local active = self:GetActiveProfileKey()
        if active == "master" then
            print("|cff00ccff[RobUI Grid]|r You are already modifying the MASTER profile.")
            return
        end
        local ok = self:CopyProfileToMaster(active)
        if ok then
            print("|cff00ccff[RobUI Grid]|r Successfully saved " .. active:upper() .. " layout to Global MASTER.")
        else
            print("|cffff0000[RobUI Grid]|r Failed to push to MASTER profile.")
        end
    end)

    local btnEdit = HeaderBtn("Done", 70)
    btnEdit:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    self.ui.btnEdit = btnEdit

    local btnAdd = HeaderBtn("Add Anchor", 90)
    btnAdd:SetPoint("RIGHT", btnEdit, "LEFT", -6, 0)
    self.ui.btnAdd = btnAdd

    local btnDel = HeaderBtn("Delete", 64)
    btnDel:SetPoint("RIGHT", btnAdd, "LEFT", -6, 0)
    self.ui.btnDel = btnDel

    local btnLabels = HeaderBtn("Labels", 64)
    btnLabels:SetPoint("RIGHT", btnDel, "LEFT", -6, 0)
    self.ui.btnLabels = btnLabels

    btnEdit:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local wasEdit = self.db and self.db.editMode and true or false
        if self.ToggleEditMode then self:ToggleEditMode() end
        if wasEdit and self.db and not self.db.editMode then
            if ReloadUI then ReloadUI() end
        end
    end)

    btnAdd:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not self.EnsureAnchor then return end
        local id = self:EnsureAnchor(nil, { gx=0, gy=0, label="Anchor", showMode="INHERIT" }, true)
        self:SelectAnchor(id, false)
        if self.SetEditMode then self:SetEditMode(true) end
    end)

    btnDel:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if id and self.DeleteAnchor then self:DeleteAnchor(id) end
    end)

    btnLabels:SetScript("OnClick", function()
        self.db.showCoordLabels = not self.db.showCoordLabels
        self:UpdateAllAnchorFramesSelected()
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
    end)

    local sizer = CreateFrame("Button", nil, grid)
    self.ui.sizer = sizer
    sizer:SetSize(16,16)
    sizer:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -2, 2)
    sizer:EnableMouse(true)
    sizer:RegisterForDrag("LeftButton")
    sizer:SetScript("OnDragStart", function() if not InCombatLockdown() then grid:StartSizing("BOTTOMRIGHT") end end)
    sizer:SetScript("OnDragStop", function()
        grid:StopMovingOrSizing()
        local w,h = grid:GetSize()
        self.db.w, self.db.h = Round(w), Round(h)
        MakeBackdrop(grid, self.db.alpha, self.db.borderAlpha)
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
        if self.ReflowAll then self:ReflowAll("ui:resize") end
    end)
    local sTex = sizer:CreateTexture(nil, "OVERLAY")
    sTex:SetAllPoints()
    sTex:SetColorTexture(1,1,1,0.25)

    local leftW  = 300
    local rightW = 420
    local pad = 6
    local topOff = 38

    local left = CreateFrame("Frame", nil, grid, "BackdropTemplate")
    self.ui.left = left
    left:SetPoint("TOPLEFT", grid, "TOPLEFT", pad, -topOff)
    left:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", pad, pad)
    left:SetWidth(leftW)
    MakeBackdrop(left, 0.45, 0)

    local leftTitle = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -6)
    leftTitle:SetText("Plugins")

    local pScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    pScroll:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -26)
    pScroll:SetPoint("TOPRIGHT", left, "TOPRIGHT", -26, -26)
    pScroll:SetHeight(200)
    self.ui.pScroll = pScroll

    local pList = CreateFrame("Frame", nil, pScroll)
    pList:SetSize(1,1)
    pScroll:SetScrollChild(pList)
    self.ui.pluginList = pList

    local pBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
    self.ui.pluginSettingsBox = pBox
    MakeBackdrop(pBox, 0.30, 0)

    local psTitle = pBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    psTitle:SetPoint("TOPLEFT", pBox, "TOPLEFT", 6, -6)
    psTitle:SetText("Plugin Settings")
    self.ui.pluginSettingsTitle = psTitle

    local psHost = CreateFrame("Frame", nil, pBox)
    psHost:SetPoint("TOPLEFT", pBox, "TOPLEFT", 6, -26)
    psHost:SetPoint("BOTTOMRIGHT", pBox, "BOTTOMRIGHT", -6, 6)
    self.ui.pluginSettingsHost = psHost

    local aBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
    self.ui.anchorBox = aBox
    MakeBackdrop(aBox, 0.30, 0)

    local aTitle = aBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aTitle:SetPoint("TOPLEFT", aBox, "TOPLEFT", 6, -6)
    aTitle:SetText("Anchor Controls")

    local aScroll = CreateFrame("ScrollFrame", nil, aBox, "UIPanelScrollFrameTemplate")
    aScroll:SetPoint("TOPLEFT", aBox, "TOPLEFT", 6, -26)
    aScroll:SetPoint("BOTTOMRIGHT", aBox, "BOTTOMRIGHT", -26, 6)
    self.ui.aScroll = aScroll

    local aCont = CreateFrame("Frame", nil, aScroll)
    aCont:SetSize(1,1)
    aScroll:SetScrollChild(aCont)
    self.ui.aCont = aCont

    local function Label(text, y)
        local fs = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", aCont, "TOPLEFT", 8, y)
        fs:SetText(text)
        return fs
    end

    local gxLbl = Label("GX:", -6)
    local gxBox = CreateFrame("EditBox", nil, aCont, "InputBoxTemplate")
    gxBox:SetSize(70, 20)
    gxBox:SetPoint("LEFT", gxLbl, "RIGHT", 6, 0)
    gxBox:SetAutoFocus(false)
    self.ui.gxBox = gxBox

    local gyLbl = Label("GY:", -30)
    local gyBox = CreateFrame("EditBox", nil, aCont, "InputBoxTemplate")
    gyBox:SetSize(70, 20)
    gyBox:SetPoint("LEFT", gyLbl, "RIGHT", 6, 0)
    gyBox:SetAutoFocus(false)
    self.ui.gyBox = gyBox

    local applyPos = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    applyPos:SetSize(80, 20)
    applyPos:SetPoint("TOPRIGHT", aCont, "TOPRIGHT", -8, -14)
    applyPos:SetText("Apply")
    self.ui.applyPos = applyPos

    applyPos:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local gx = tonumber(gxBox:GetText()) or 0
        local gy = tonumber(gyBox:GetText()) or 0
        if self.SetAnchorGridPos then self:SetAnchorGridPos(id, gx, gy, true, true) end
    end)

    local function NBtn(txt)
        local b = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
        b:SetSize(30, 24)
        b:SetText(txt)
        return b
    end
    local nUp = NBtn("U")
    local nDn = NBtn("D")
    local nLf = NBtn("L")
    local nRt = NBtn("R")

    nUp:SetPoint("TOPLEFT", aCont, "TOPLEFT", 10, -56)
    nDn:SetPoint("TOPLEFT", nUp, "BOTTOMLEFT", 0, -4)
    nLf:SetPoint("LEFT", nDn, "RIGHT", 6, 0)
    nRt:SetPoint("LEFT", nLf, "RIGHT", 6, 0)

    local nInfo = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nInfo:SetPoint("LEFT", nRt, "RIGHT", 8, 0)
    nInfo:SetText("Shift=5")
    self.ui.nInfo = nInfo

    local function Nudge(dx, dy)
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local step = IsShiftKeyDown() and 5 or 1
        if self.GetAnchorGridPos and self.SetAnchorGridPos then
            local gx, gy = self:GetAnchorGridPos(id)
            self:SetAnchorGridPos(id, (gx or 0) + dx*step, (gy or 0) + dy*step, false, true)
        end
    end
    nUp:SetScript("OnClick", function() Nudge(0, 1) end)
    nDn:SetScript("OnClick", function() Nudge(0,-1) end)
    nLf:SetScript("OnClick", function() Nudge(-1,0) end)
    nRt:SetScript("OnClick", function() Nudge(1, 0) end)

    local fLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fLbl:SetPoint("TOPLEFT", aCont, "TOPLEFT", 10, -104)
    fLbl:SetText("Attached Frame")
    self.ui.frameLbl = fLbl

    local fwLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fwLbl:SetPoint("TOPLEFT", fLbl, "BOTTOMLEFT", 0, -6)
    fwLbl:SetText("Width")
    self.ui.fwLbl = fwLbl

    local fwBox = CreateFrame("EditBox", nil, aCont, "InputBoxTemplate")
    fwBox:SetSize(62, 20)
    fwBox:SetPoint("LEFT", fwLbl, "RIGHT", 6, 0)
    fwBox:SetAutoFocus(false)
    self.ui.fwBox = fwBox

    local fhLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fhLbl:SetPoint("LEFT", fwBox, "RIGHT", 10, 0)
    fhLbl:SetText("Height")
    self.ui.fhLbl = fhLbl

    local fhBox = CreateFrame("EditBox", nil, aCont, "InputBoxTemplate")
    fhBox:SetSize(62, 20)
    fhBox:SetPoint("LEFT", fhLbl, "RIGHT", 6, 0)
    fhBox:SetAutoFocus(false)
    self.ui.fhBox = fhBox

    local fApply = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    fApply:SetSize(62, 20)
    fApply:SetPoint("TOPRIGHT", aCont, "TOPRIGHT", -8, -128)
    fApply:SetText("Apply")
    self.ui.fApply = fApply

    local fSwap = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    fSwap:SetSize(62, 20)
    fSwap:SetPoint("RIGHT", fApply, "LEFT", -6, 0)
    fSwap:SetText("Swap")
    self.ui.fSwap = fSwap

    local oLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    oLbl:SetPoint("TOPLEFT", fwLbl, "BOTTOMLEFT", 0, -10)
    oLbl:SetText("Orientation")
    self.ui.orientLbl = oLbl

    local oDD = CreateFrame("Frame", "RobUIGrid_AnchorOrientDD", aCont, "UIDropDownMenuTemplate")
    oDD:SetPoint("TOPLEFT", oLbl, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(oDD, 120)
    self.ui.orientDD = oDD

    local function RefreshOrientText()
        local id = self._selectedAnchorId
        if not id or not self.db.anchors[id] then
            UIDropDownMenu_SetText(oDD, "Horizontal")
            return
        end
        local a = self.db.anchors[id]
        local o = NormalizeOrient(a.orient or a.dir or a.orientation)
        UIDropDownMenu_SetText(oDD, (o == "V") and "Vertical" or "Horizontal")
    end

    UIDropDownMenu_Initialize(oDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        local function add(text, val)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                if InCombatLockdown() then return end
                local id = self._selectedAnchorId
                if not id or not self.db.anchors[id] then return end
                self.db.anchors[id].orient = NormalizeOrient(val)
                local w = tonumber(fwBox:GetText())
                local h = tonumber(fhBox:GetText())
                self:_ApplyAnchorAttachedFrameLayout(id, w, h, self.db.anchors[id].orient)
                RefreshOrientText()
            end
            UIDropDownMenu_AddButton(info, level)
        end
        add("Horizontal", "H")
        add("Vertical", "V")
    end)

    fApply:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id then return end
        local w = tonumber(fwBox:GetText())
        local h = tonumber(fhBox:GetText())
        local a = self.db.anchors[id]
        local o = a and NormalizeOrient(a.orient) or "H"
        self:_ApplyAnchorAttachedFrameLayout(id, w, h, o)
        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    end)

    fSwap:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local id = self._selectedAnchorId
        if not id or not self.db.anchors[id] then return end
        local w = tonumber(fwBox:GetText()) or 0
        local h = tonumber(fhBox:GetText()) or 0
        fwBox:SetText(tostring(h))
        fhBox:SetText(tostring(w))
        local a = self.db.anchors[id]
        a.orient = (NormalizeOrient(a.orient) == "V") and "H" or "V"
        self:_ApplyAnchorAttachedFrameLayout(id, h, w, a.orient)
        RefreshOrientText()
        if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    end)

    local gText = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gText:SetPoint("TOPLEFT", aCont, "TOPLEFT", 10, -198)
    gText:SetText("Group: none")
    self.ui.groupText = gText

    local gNew = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    gNew:SetSize(78, 20)
    gNew:SetPoint("TOPLEFT", gText, "BOTTOMLEFT", 0, -6)
    gNew:SetText("New")
    self.ui.btnNewGroup = gNew

    local gClr = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    gClr:SetSize(78, 20)
    gClr:SetPoint("LEFT", gNew, "RIGHT", 6, 0)
    gClr:SetText("Ungroup")
    self.ui.btnClearGroup = gClr

    local gDel = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    gDel:SetSize(78, 20)
    gDel:SetPoint("LEFT", gClr, "RIGHT", 6, 0)
    gDel:SetText("Delete")
    self.ui.btnDeleteGroup = gDel

    local grpLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    grpLbl:SetPoint("TOPLEFT", gNew, "BOTTOMLEFT", 0, -10)
    grpLbl:SetText("Set Group")
    self.ui.grpLbl = grpLbl

    local grpDD = CreateFrame("Frame", "RobUIGrid_GroupDD", aCont, "UIDropDownMenuTemplate")
    grpDD:SetPoint("TOPLEFT", grpLbl, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(grpDD, 120)
    self.ui.grpDD = grpDD

    local rnLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rnLbl:SetPoint("TOPLEFT", grpDD, "BOTTOMLEFT", 16, -6)
    rnLbl:SetText("Group Name")
    self.ui.rnLbl = rnLbl

    local rnBox = CreateFrame("EditBox", nil, aCont, "InputBoxTemplate")
    rnBox:SetSize(140, 20)
    rnBox:SetPoint("TOPLEFT", rnLbl, "BOTTOMLEFT", 0, -4)
    rnBox:SetAutoFocus(false)
    self.ui.rnBox = rnBox

    local rnBtn = CreateFrame("Button", nil, aCont, "UIPanelButtonTemplate")
    rnBtn:SetSize(70, 20)
    rnBtn:SetPoint("LEFT", rnBox, "RIGHT", 6, 0)
    rnBtn:SetText("Rename")
    self.ui.rnBtn = rnBtn

    local aVisLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    aVisLbl:SetPoint("TOPLEFT", rnBox, "BOTTOMLEFT", 0, -10)
    aVisLbl:SetText("Element Visibility")
    self.ui.aVisLbl = aVisLbl

    local aVisDD = CreateFrame("Frame", "RobUIGrid_AnchorVisDD", aCont, "UIDropDownMenuTemplate")
    aVisDD:SetPoint("TOPLEFT", aVisLbl, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(aVisDD, 120)
    self.ui.aVisDD = aVisDD

    local gVisLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gVisLbl:SetPoint("TOPLEFT", aVisDD, "BOTTOMLEFT", 16, -6)
    gVisLbl:SetText("Group Visibility")
    self.ui.gVisLbl = gVisLbl

    local gVisDD = CreateFrame("Frame", "RobUIGrid_GroupVisDD", aCont, "UIDropDownMenuTemplate")
    gVisDD:SetPoint("TOPLEFT", gVisLbl, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(gVisDD, 120)
    self.ui.gVisDD = gVisDD

    local scaleLbl = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLbl:SetPoint("TOPLEFT", gVisDD, "BOTTOMLEFT", 16, -8)
    scaleLbl:SetText("Global Scale")
    self.ui.scaleLbl = scaleLbl

    local sld = CreateFrame("Slider", nil, aCont, "OptionsSliderTemplate")
    sld:SetPoint("TOPLEFT", scaleLbl, "BOTTOMLEFT", -2, -8)
    sld:SetMinMaxValues(0.2, 3.0)
    sld:SetValueStep(0.01)
    sld:SetObeyStepOnDrag(true)
    sld:SetWidth(240)
    sld:SetValue(self.db.globalScale or 1.0)
    self.ui.scaleSlider = sld

    local sVal = aCont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sVal:SetPoint("TOPLEFT", sld, "BOTTOMLEFT", 4, -6)
    sVal:SetText(string_format("Scale: %.2f", self.db.globalScale or 1.0))
    self.ui.scaleValue = sVal

    sld:SetScript("OnValueChanged", function(_, v)
        if InCombatLockdown() then return end
        if self.SetGlobalScale then self:SetGlobalScale(v) end
    end)

    gNew:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local ids, n = GetSelectedIds(self)
        if n <= 0 then
            print("|cffff0000[RobUI Grid]|r You must select an anchor first!")
            return
        end
        if not self.NewGroup then return end
        local gid = self:NewGroup(nil)
        for i=1,n do
            local a = self.db.anchors[ids[i]]
            if a then a.group = gid end
        end
        self:UpdateSelectedAnchorUI()
        self:UpdateAllAnchorFramesSelected()
        if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    end)

    gClr:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local ids, n = GetSelectedIds(self)
        if n <= 0 then
            print("|cffff0000[RobUI Grid]|r You must select an anchor first!")
            return
        end
        for i=1,n do
            local a = self.db.anchors[ids[i]]
            if a then a.group = 0 end
        end
        self:UpdateSelectedAnchorUI()
        self:UpdateAllAnchorFramesSelected()
        if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    end)

    gDel:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local ids, n = GetSelectedIds(self)
        if n <= 0 then
            print("|cffff0000[RobUI Grid]|r You must select an anchor first!")
            return
        end
        local cg = GetCommonGroup(self, ids, n)
        if not cg or cg <= 0 or cg == -1 then return end
        if self.DeleteGroup then self:DeleteGroup(cg) end
        self:UpdateSelectedAnchorUI()
        self:UpdateAllAnchorFramesSelected()
        if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    end)

    rnBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local ids, n = GetSelectedIds(self)
        if n <= 0 then
            print("|cffff0000[RobUI Grid]|r You must select an anchor first!")
            return
        end
        local cg = GetCommonGroup(self, ids, n)
        if not cg or cg <= 0 or cg == -1 then return end
        local name = rnBox:GetText()
        if type(name) ~= "string" or name == "" then return end
        if self.SetGroupName then self:SetGroupName(cg, name) end
        self:UpdateSelectedAnchorUI()
        self:UpdateAllAnchorFramesSelected()
    end)

    local function RefreshGroupDDText()
        local ids, n = GetSelectedIds(self)
        if n <= 0 then
            UIDropDownMenu_SetText(grpDD, "none")
            return
        end
        local cg = GetCommonGroup(self, ids, n)
        if cg == -1 then UIDropDownMenu_SetText(grpDD, "mixed")
        elseif (cg or 0) <= 0 then UIDropDownMenu_SetText(grpDD, "none")
        else
            local g = self.GetGroup and self:GetGroup(cg, true) or nil
            local nm = (g and g.name) or ("Group "..cg)
            UIDropDownMenu_SetText(grpDD, cg.." - "..nm)
        end
    end

    UIDropDownMenu_Initialize(grpDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        local function addItem(text, gid)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                if InCombatLockdown() then return end
                local ids, n = GetSelectedIds(self)
                if n <= 0 then return end
                for i=1,n do
                    local a = self.db.anchors[ids[i]]
                    if a then a.group = gid end
                end
                if gid > 0 and self.EnsureGroup then self:EnsureGroup(gid) end
                self:UpdateSelectedAnchorUI()
                self:UpdateAllAnchorFramesSelected()
                if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
        addItem("none", 0)
        if self.GetAllGroupIds then
            local gids, gn = self:GetAllGroupIds()
            for i=1,gn do
                local gid = gids[i]
                local g = self:GetGroup(gid, true)
                local nm = (g and g.name) or ("Group "..gid)
                addItem(gid.." - "..nm, gid)
            end
        end
    end)

    local function RefreshAnchorVisText()
        local ids, n = GetSelectedIds(self)
        if n <= 0 then UIDropDownMenu_SetText(aVisDD, "inherit"); return end
        local cm = GetCommonAnchorMode(self, ids, n)
        if cm == "MIXED" then UIDropDownMenu_SetText(aVisDD, "mixed")
        elseif cm == "INHERIT" then UIDropDownMenu_SetText(aVisDD, "inherit")
        else UIDropDownMenu_SetText(aVisDD, cm) end
    end

    UIDropDownMenu_Initialize(aVisDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        local function setMode(mode)
            if InCombatLockdown() then return end
            local ids, n = GetSelectedIds(self)
            if n <= 0 then return end
            for i=1,n do
                local id = ids[i]
                local a = self.db.anchors[id]
                if a then a.showMode = mode end
                if self.ApplyVisibilityForAnchor then self:ApplyVisibilityForAnchor(id) end
            end
            self:UpdateSelectedAnchorUI()
            self:UpdateAllAnchorFramesSelected()
            if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
        end
        local function add(text, mode)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function() setMode(mode) end
            UIDropDownMenu_AddButton(info, level)
        end
        add("INHERIT (group)", "INHERIT")
        add("ALWAYS", "ALWAYS")
        add("COMBAT", "COMBAT")
        add("HIDDEN", "HIDDEN")
    end)

    local function RefreshGroupVisText()
        local ids, n = GetSelectedIds(self)
        if n <= 0 then UIDropDownMenu_SetText(gVisDD, "(select group)"); return end
        local cg = GetCommonGroup(self, ids, n)
        if not cg or cg <= 0 or cg == -1 then UIDropDownMenu_SetText(gVisDD, "(select group)"); return end
        local g = self.GetGroup and self:GetGroup(cg, true) or nil
        UIDropDownMenu_SetText(gVisDD, (g and g.showMode) or "ALWAYS")
    end

    UIDropDownMenu_Initialize(gVisDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        local ids, n = GetSelectedIds(self)
        if n <= 0 then return end
        local cg = GetCommonGroup(self, ids, n)
        if not cg or cg <= 0 or cg == -1 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Select anchors with same group"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        local function add(text, mode)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                if InCombatLockdown() then return end
                if self.SetGroupShowMode then self:SetGroupShowMode(cg, mode) end
                self:UpdateSelectedAnchorUI()
                self:UpdateAllAnchorFramesSelected()
                if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
        add("ALWAYS", "ALWAYS")
        add("COMBAT", "COMBAT")
        add("HIDDEN", "HIDDEN")
    end)

    local canvas = CreateFrame("Frame", nil, grid)
    self.ui.canvas = canvas
    canvas:SetPoint("TOPLEFT", left, "TOPRIGHT", pad, 0)
    canvas:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -(rightW + pad), pad)
    canvas:SetScript("OnSizeChanged", function()
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
    end)

    self.ui.lines = {}
    if self.UpdateGridVisuals then self:UpdateGridVisuals() end

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

    if self.BuildSSR then self:BuildSSR(right) end

    local function LayoutLeft()
        if not (self.ui and self.ui.left and self.ui.pScroll and self.ui.pluginSettingsBox and self.ui.anchorBox) then return end
        local lh = left:GetHeight() or 700
        local topPad = 26 + 6
        local bottomPad = 6
        local listH = math_max(160, math_floor(lh * 0.28))
        local pBoxH = math_max(110, math_floor(lh * 0.18))
        local gap = 8

        self.ui.pScroll:SetHeight(listH)

        pBox:ClearAllPoints()
        pBox:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -(topPad + listH + gap))
        pBox:SetPoint("TOPRIGHT", left, "TOPRIGHT", -6, -(topPad + listH + gap))
        pBox:SetHeight(pBoxH)

        aBox:ClearAllPoints()
        aBox:SetPoint("TOPLEFT", pBox, "BOTTOMLEFT", 0, -gap)
        aBox:SetPoint("TOPRIGHT", pBox, "BOTTOMRIGHT", 0, -gap)
        aBox:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 6, bottomPad)
        aBox:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -6, bottomPad)

        aCont:SetHeight(720)
    end

    left:SetScript("OnSizeChanged", LayoutLeft)
    grid:SetScript("OnSizeChanged", function()
        LayoutLeft()
        if self.UpdateGridVisuals then self:UpdateGridVisuals() end
    end)
    LayoutLeft()

    for anchorId,_ in pairs(self.db.anchors) do
        if type(anchorId) == "string" then
            self:CreateOrUpdateAnchorFrame(anchorId)
            if self.PositionAnchorFrame then self:PositionAnchorFrame(anchorId) end
            if self.UpdateAnchorLabel then self:UpdateAnchorLabel(anchorId) end
        end
    end

    self:RefreshPluginList()
    if self.ApplyEditMode then self:ApplyEditMode() end
    self:UpdateSelectedAnchorUI()

    self._RefreshGroupDDText = RefreshGroupDDText
    self._RefreshAnchorVisText = RefreshAnchorVisText
    self._RefreshGroupVisText = RefreshGroupVisText
    self._RefreshOrientText = RefreshOrientText

    RefreshGroupDDText()
    RefreshAnchorVisText()
    RefreshGroupVisText()
    RefreshOrientText()
    RefreshProfileUI()

    -- If we deferred root changes, try applying now (safe out of combat)
    _ApplyQueuedRootLayout(self)
end

-- ============================================================================
-- THE MISSING FUNCTIONS HAVE BEEN RESTORED BELOW
-- ============================================================================

function GC:UpdateScaleUI()
    if not (self.ui and self.ui.scaleValue and self.ui.scaleSlider) then return end
    self.ui.scaleSlider:SetValue(self.db.globalScale or 1.0)
    self.ui.scaleValue:SetText(string_format("Scale: %.2f", self.db.globalScale or 1.0))
end

function GC:ApplyEditMode()
    if not (self.ui and self.ui.grid) then return end
    if self.db.editMode then
        self.ui.grid:Show()
        if self.ui.btnEdit then self.ui.btnEdit:SetText("Done") end
        for _,af in pairs(self._anchorFrames or {}) do
            if af then af:Show() end
        end
    else
        self.ui.grid:Hide()
        if self.ui.btnEdit then self.ui.btnEdit:SetText("Edit") end
    end
    self:UpdateSelectedAnchorUI()
    if self._RefreshProfileUI then self:_RefreshProfileUI() end
end

function GC:UpdateGridVisuals()
    if not (self.ui and self.ui.canvas) then return end
    local canvas = self.ui.canvas
    local db = self.db

    if not db then return end

    local w,h = canvas:GetSize()
    w,h = Round(w), Round(h)
    if w <= 0 or h <= 0 then return end

    for _,t in ipairs(self.ui.lines or {}) do
        if t and t.Hide then t:Hide() end
    end
    self.ui.lines = {}

    local cell = tonumber(db.cell) or 8
    if cell < 2 then cell = 2 end

    local function NewLine()
        local l = canvas:CreateTexture(nil, "BACKGROUND")
        l:SetColorTexture(1,1,1,0.08)
        self.ui.lines[#self.ui.lines+1] = l
        return l
    end

    local maxLines = 520
    local count = 0

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
            if self.PositionAnchorFrame then self:PositionAnchorFrame(anchorId) end
            if self.UpdateAnchorLabel then self:UpdateAnchorLabel(anchorId) end
        end
    end
end

function GC:CreateOrUpdateAnchorFrame(anchorId)
    if not (self.ui and self.ui.canvas) then return end
    local canvas = self.ui.canvas
    local db = self.db
    local a = db.anchors[anchorId]
    if not a then return end

    self._anchorFrames = self._anchorFrames or {}
    local af = self._anchorFrames[anchorId]
    if not af then
        if not self.CreateAnchorButton then return end
        af = self:CreateAnchorButton(canvas, anchorId)
        self._anchorFrames[anchorId] = af

        af:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        af:SetScript("OnClick", function(_, mouse)
            if mouse ~= "LeftButton" then
                self:SelectAnchor(anchorId, false)
                return
            end

            if IsShiftKeyDown() then
                self:ToggleAnchorSelected(anchorId)
            else
                self:SelectAnchor(anchorId, false)
            end
        end)

        af:SetScript("OnDragStart", function()
            if InCombatLockdown() then return end
            if not db.editMode then return end

            if IsShiftKeyDown() then
            else
                if not self:IsAnchorSelected(anchorId) then
                    self:SelectAnchor(anchorId, false)
                else
                    self._selectedAnchorId = anchorId
                    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
                    if self.UpdateAllAnchorFramesSelected then self:UpdateAllAnchorFramesSelected() end
                end
            end

            if af.StartMoving then af:StartMoving() end
        end)

        af:SetScript("OnDragStop", function()
            if af.StopMovingOrSizing then af:StopMovingOrSizing() end
            if InCombatLockdown() then return end
            if not db.editMode then return end
            if self.AnchorDragStop then self:AnchorDragStop(anchorId) end
        end)
    end

    af:SetShown(db.editMode and true or false)
end

function GC:UpdateSelectedAnchorUI()
    if not self.ui then return end
    local db = self.db

    local ids, n = GetSelectedIds(self)

    if n <= 0 then
        if self.ui.gxBox then self.ui.gxBox:SetText("") end
        if self.ui.gyBox then self.ui.gyBox:SetText("") end
        if self.ui.groupText then self.ui.groupText:SetText("Group: none") end
        if self.ui.rnBox then self.ui.rnBox:SetText("") end

        if self.ui.fwBox then self.ui.fwBox:SetText("") end
        if self.ui.fhBox then self.ui.fhBox:SetText("") end
        if self._RefreshOrientText then self:_RefreshOrientText() end

        if self._RefreshGroupDDText then self:_RefreshGroupDDText() end
        if self._RefreshAnchorVisText then self:_RefreshAnchorVisText() end
        if self._RefreshGroupVisText then self:_RefreshGroupVisText() end
        if self._RefreshProfileUI then self:_RefreshProfileUI() end
        return
    end

    local aid = self._selectedAnchorId
    if not aid or not db.anchors[aid] then aid = ids[1] end
    local a = db.anchors[aid]

    local gx = tonumber(a.gx) or 0
    local gy = tonumber(a.gy) or 0
    if self.ui.gxBox then self.ui.gxBox:SetText(tostring(gx)) end
    if self.ui.gyBox then self.ui.gyBox:SetText(tostring(gy)) end

    if self.ui.fwBox and self.ui.fhBox then
        local w = tonumber(a.fw)
        local h = tonumber(a.fh)

        if (not w or not h) then
            local apid = self:_FindPluginIdOnAnchor(aid)
            local frame = apid and self:_FindPluginFrame(apid) or nil
            if frame and frame.GetSize then
                local fw, fh = frame:GetSize()
                if not w then w = Round(fw) end
                if not h then h = Round(fh) end
            end
        end

        if w then self.ui.fwBox:SetText(tostring(Round(w))) else self.ui.fwBox:SetText("") end
        if h then self.ui.fhBox:SetText(tostring(Round(h))) else self.ui.fhBox:SetText("") end
    end

    if self._RefreshOrientText then self:_RefreshOrientText() end

    local cg = GetCommonGroup(self, ids, n)
    if self.ui.groupText then
        if cg == -1 then
            self.ui.groupText:SetText("Group: mixed  ["..n.."]")
        elseif (cg or 0) <= 0 then
            self.ui.groupText:SetText("Group: none  ["..n.."]")
        else
            local g = self.GetGroup and self:GetGroup(cg, true) or nil
            local nm = (g and g.name) or ("Group "..cg)
            self.ui.groupText:SetText("Group: "..cg.." ("..nm..")  ["..n.."]")
        end
    end

    if self.ui.rnBox then
        if cg and cg > 0 and cg ~= -1 then
            local g = self:GetGroup(cg, true)
            self.ui.rnBox:SetText((g and g.name) or ("Group "..cg))
        else
            self.ui.rnBox:SetText("")
        end
    end

    if self._RefreshGroupDDText then self:_RefreshGroupDDText() end
    if self._RefreshAnchorVisText then self:_RefreshAnchorVisText() end
    if self._RefreshGroupVisText then self:_RefreshGroupVisText() end
    if self._RefreshProfileUI then self:_RefreshProfileUI() end
end

function GC:AttachFrameToAnchor(pluginId, frame, anchorId)
    if not (frame and frame.SetPoint and frame.ClearAllPoints) then return end
    if type(anchorId) ~= "string" then return end

    local af = self._anchorFrames and self._anchorFrames[anchorId]
    if not af then
        if self.EnsureAnchor then self:EnsureAnchor(anchorId, {}, true) end
        af = self._anchorFrames and self._anchorFrames[anchorId]
    end
    if not af then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", af, "CENTER", 0, 0)
end

function GC:RefreshPluginList()
    if not (self.ui and self.ui.pluginList) then return end
    for _,b in pairs(self._pluginButtons) do if b then b:Hide(); b:SetParent(nil) end end
    wipe(self._pluginButtons)
    local list = self.ui.pluginList
    local y = -2
    self._plugins = self._plugins or {}
    self._pluginOrder = self._pluginOrder or {}
    local order = {}

    if type(self._pluginOrder) == "table" and #self._pluginOrder > 0 then
        for i=1,#self._pluginOrder do order[#order+1] = self._pluginOrder[i] end
    else
        for pid,_ in pairs(self._plugins) do order[#order+1] = pid end
        table_sort(order)
    end

    for _,pid in ipairs(order) do
        local p = self._plugins[pid]
        if p then
            local b = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
            b:SetSize(248, 20)
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 2, y)
            y = y - 22
            local attached = (self.IsPluginAttached and self:IsPluginAttached(pid)) and true or false
            b:SetText((attached and "● " or "○ ") .. (p.name or pid))
            b:SetScript("OnClick", function() self:OpenPluginSettings(pid) end)
            self._pluginButtons[pid] = b
        end
    end
    list:SetHeight(-y + 10)
    if self._RefreshProfileUI then self:_RefreshProfileUI() end
end

function GC:OpenPluginSettings(pluginId)
    if not (self.ui and self.ui.pluginSettingsHost) then return end
    if type(pluginId) ~= "string" then return end
    if not self.GetPlugin then return end
    local p = self:GetPlugin(pluginId)
    if not p then return end

    self._selectedPluginId = pluginId
    if self.ui.pluginSettingsTitle then self.ui.pluginSettingsTitle:SetText("Plugin Settings: " .. (p.name or pluginId)) end
    ClearChildren(self.ui.pluginSettingsHost)

    local row = CreateFrame("Frame", nil, self.ui.pluginSettingsHost)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", self.ui.pluginSettingsHost, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", self.ui.pluginSettingsHost, "TOPRIGHT", 0, 0)

    local attached = (self.IsPluginAttached and self:IsPluginAttached(pluginId)) and true or false
    local addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    addBtn:SetSize(92, 20)
    addBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
    addBtn:SetText(attached and "Reattach" or "Add")

    local remBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remBtn:SetSize(92, 20)
    remBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
    remBtn:SetText("Remove")

    addBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if self.SetEditMode then self:SetEditMode(true) end
        if not self.AttachPlugin then return end
        if self:IsPluginAttached(pluginId) then self:AttachPlugin(pluginId)
        else self:AttachPlugin(pluginId, true) end
        self:RefreshPluginList()
        self:OpenPluginSettings(pluginId)
        if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    end)

    remBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not self.DetachPlugin then return end
        self:DetachPlugin(pluginId)
        self:RefreshPluginList()
        self:OpenPluginSettings(pluginId)
        if self.ApplyVisibilityAll then self:ApplyVisibilityAll() end
    end)

    local host = CreateFrame("Frame", nil, self.ui.pluginSettingsHost)
    host:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -8)
    host:SetPoint("BOTTOMRIGHT", self.ui.pluginSettingsHost, "BOTTOMRIGHT", 0, 0)

    if type(p.settings) == "function" then
        local ok, ui = pcall(p.settings, host)
        if ok and ui then
            ui:SetParent(host)
            ui:ClearAllPoints()
            ui:SetAllPoints(host)
            ui:Show()
        else
            local t = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            t:SetText("Settings UI error.")
        end
    else
        local t = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        t:SetText("No custom settings UI.")
    end
end

function GC:ShowUI()
    if not (self.ui and self.ui.grid) then self:CreateUI() end
    if not (self.ui and self.ui.grid) then return end
    self.db.editMode = true
    if self.ApplyEditMode then self:ApplyEditMode() end
end

function GC:HideUI()
    if not (self.ui and self.ui.grid) then return end
    self.db.editMode = false
    if self.ApplyEditMode then self:ApplyEditMode() end
end

function GC:ToggleUI()
    if not (self.ui and self.ui.grid) then
        self:CreateUI()
        if not (self.ui and self.ui.grid) then return end
        self.db.editMode = true
        if self.ApplyEditMode then self:ApplyEditMode() end
        return
    end
    if self.db.editMode then self:HideUI() else self:ShowUI() end
end
