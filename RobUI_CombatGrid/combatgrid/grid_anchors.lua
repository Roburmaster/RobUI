-- ============================================================================
-- grid_anchors.lua (RobUI GridCore) -- ANCHORS / GROUPS / SNAP / LABELS
-- FIX:
--  - Anchor buttons are MOVABLE (StartMoving works)
-- Added:
--  - Multi-select (Shift-click): _selectedAnchors set + primary _selectedAnchorId
--  - label shows group id [gid] + override indicator (A/C/H) when not inherit
-- ============================================================================
local AddonName, ns = ...
local GC = ns.GridCore

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

local function MakeBackdrop(f, alpha, edgeA)
    if not (f and f.SetBackdrop) then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    f:SetBackdropColor(0,0,0, alpha or 0.25)
    f:SetBackdropBorderColor(0,0,0, edgeA or 1)
end

local function IsAnchorMode(mode)
    return mode == "INHERIT" or mode == "ALWAYS" or mode == "COMBAT" or mode == "HIDDEN"
end

GC._anchorFrames = GC._anchorFrames or {}
GC._selectedAnchorId = GC._selectedAnchorId or nil
GC._selectedAnchors = GC._selectedAnchors or {} -- set: anchorId => true

local function AnchorIdForNew(db)
    local i = 1
    while db.anchors["A"..i] do i = i + 1 end
    return "A"..i
end

function GC:EnsureAnchor(anchorId, defaults, forceCreate)
    self:Init()
    defaults = type(defaults) == "table" and defaults or {}

    if type(anchorId) ~= "string" or anchorId == "" then
        anchorId = AnchorIdForNew(self.db)
        forceCreate = true -- Always create if generated internally (e.g. Add Anchor button)
    end

    if not self.db.anchors[anchorId] then
        if not forceCreate then
            return anchorId -- Prevent background plugins from auto-injecting anchors into empty profiles
        end

        local sm = defaults.showMode
        if type(sm) ~= "string" or not IsAnchorMode(sm) then sm = "INHERIT" end

        self.db.anchors[anchorId] = {
            gx = tonumber(defaults.gx) or 0,
            gy = tonumber(defaults.gy) or 0,
            group = tonumber(defaults.group) or 0,
            scaleWithGrid = defaults.scaleWithGrid and true or false,
            label = (type(defaults.label) == "string" and defaults.label) or anchorId,
            showMode = sm, -- INHERIT/ALWAYS/COMBAT/HIDDEN
        }
    else
        local a = self.db.anchors[anchorId]
        a.gx = tonumber(a.gx) or 0
        a.gy = tonumber(a.gy) or 0
        a.group = tonumber(a.group) or 0
        a.scaleWithGrid = a.scaleWithGrid and true or false
        if type(a.label) ~= "string" then a.label = anchorId end
        if type(a.showMode) ~= "string" or not IsAnchorMode(a.showMode) then
            a.showMode = "INHERIT"
        end
    end

    if self.db.anchors[anchorId] and self.CreateOrUpdateAnchorFrame then
        self:CreateOrUpdateAnchorFrame(anchorId)
        self:PositionAnchorFrame(anchorId)
        self:UpdateAnchorLabel(anchorId)
    end

    return anchorId
end

function GC:GetAnchorGridPos(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return 0,0 end
    local a = self.db.anchors[anchorId]
    if not a then return 0,0 end
    return tonumber(a.gx) or 0, tonumber(a.gy) or 0
end

function GC:SetAnchorGridPos(anchorId, gx, gy, snap, moveGroup)
    self:Init()
    if type(anchorId) ~= "string" then return end
    local a = self.db.anchors[anchorId]
    if not a then return end

    gx = tonumber(gx) or 0
    gy = tonumber(gy) or 0

    if snap then
        gx = SnapToCell(gx, self.db.cell)
        gy = SnapToCell(gy, self.db.cell)
    end

    local dx = gx - (tonumber(a.gx) or 0)
    local dy = gy - (tonumber(a.gy) or 0)

    a.gx, a.gy = gx, gy

    if moveGroup then
        local g = tonumber(a.group) or 0
        if g > 0 and (dx ~= 0 or dy ~= 0) then
            for id, info in pairs(self.db.anchors) do
                if id ~= anchorId and type(info) == "table" and tonumber(info.group) == g then
                    info.gx = (tonumber(info.gx) or 0) + dx
                    info.gy = (tonumber(info.gy) or 0) + dy
                    if self.PositionAnchorFrame then self:PositionAnchorFrame(id) end
                    if self.UpdateAnchorLabel then self:UpdateAnchorLabel(id) end
                    if self.ReflowAttached then self:ReflowAttached(id) end
                end
            end
        end
    end

    if self.PositionAnchorFrame then self:PositionAnchorFrame(anchorId) end
    if self.UpdateAnchorLabel then self:UpdateAnchorLabel(anchorId) end
    if self.ReflowAttached then self:ReflowAttached(anchorId) end
    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
end

function GC:DeleteAnchor(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return end
    if not self.db.anchors[anchorId] then return end

    for pid, aid in pairs(self.db.attach or {}) do
        if aid == anchorId then
            self.db.attach[pid] = nil
        end
    end

    self.db.anchors[anchorId] = nil

    local af = self._anchorFrames[anchorId]
    if af then
        af:Hide()
        af:SetParent(nil)
    end
    self._anchorFrames[anchorId] = nil

    if self._selectedAnchorId == anchorId then
        self._selectedAnchorId = nil
    end
    if self._selectedAnchors then
        self._selectedAnchors[anchorId] = nil
    end

    if self.RefreshPluginList then self:RefreshPluginList() end
    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    if self.UpdateAllAnchorFramesSelected then self:UpdateAllAnchorFramesSelected() end
end

-- ============================================================================
-- Selection helpers (multi)
-- ============================================================================
function GC:ClearSelection()
    self._selectedAnchors = self._selectedAnchors or {}
    for k in pairs(self._selectedAnchors) do
        self._selectedAnchors[k] = nil
    end
end

function GC:IsAnchorSelected(anchorId)
    self._selectedAnchors = self._selectedAnchors or {}
    return self._selectedAnchors[anchorId] and true or false
end

function GC:SelectAnchor(anchorId, additive)
    self:Init()
    if type(anchorId) ~= "string" then return end
    if not self.db.anchors[anchorId] then return end

    self._selectedAnchors = self._selectedAnchors or {}

    if not additive then
        self:ClearSelection()
    end
    self._selectedAnchors[anchorId] = true
    self._selectedAnchorId = anchorId

    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    if self.UpdateAllAnchorFramesSelected then self:UpdateAllAnchorFramesSelected() end
end

function GC:ToggleAnchorSelected(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return end
    if not self.db.anchors[anchorId] then return end

    self._selectedAnchors = self._selectedAnchors or {}

    if self._selectedAnchors[anchorId] then
        self._selectedAnchors[anchorId] = nil
        if self._selectedAnchorId == anchorId then
            self._selectedAnchorId = nil
        end
    else
        self._selectedAnchors[anchorId] = true
        self._selectedAnchorId = anchorId
    end

    if self.UpdateSelectedAnchorUI then self:UpdateSelectedAnchorUI() end
    if self.UpdateAllAnchorFramesSelected then self:UpdateAllAnchorFramesSelected() end
end

function GC:GetSelectedAnchorIds(out)
    self:Init()
    self._selectedAnchors = self._selectedAnchors or {}

    out = out or {}
    for k in pairs(out) do out[k] = nil end

    local n = 0
    for id in pairs(self._selectedAnchors) do
        if self.db.anchors[id] then
            n = n + 1
            out[n] = id
        end
    end

    if n == 0 and self._selectedAnchorId and self.db.anchors[self._selectedAnchorId] then
        n = 1
        out[1] = self._selectedAnchorId
    end

    return out, n
end

function GC:UpdateAllAnchorFramesSelected()
    self:Init()
    for id,_ in pairs(self.db.anchors) do
        if self.PositionAnchorFrame then self:PositionAnchorFrame(id) end
        if self.UpdateAnchorLabel then self:UpdateAnchorLabel(id) end
    end
end

function GC:ReflowAttached(anchorId)
    self:Init()
    if type(anchorId) ~= "string" then return end
    for pid, aid in pairs(self.db.attach or {}) do
        if aid == anchorId then
            local frame = self._pluginFrames[pid]
            if frame and self.AttachFrameToAnchor then
                self:AttachFrameToAnchor(pid, frame, aid)
                self:ApplyFrameScaleForPlugin(pid)
            end
        end
    end
end

-- ============================================================================
-- Anchor visuals
-- ============================================================================
function GC:CreateAnchorButton(parent, anchorId)
    local af = CreateFrame("Button", nil, parent, "BackdropTemplate")
    af._id = anchorId
    af:SetSize(18,18)
    MakeBackdrop(af, 0.25, 1.0)
    af:SetBackdropBorderColor(1,1,1,0.85)

    local fill = af:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    fill:SetColorTexture(0.2, 0.7, 1.0, 0.35)
    af._fill = fill

    local lbl = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOP", af, "BOTTOM", 0, -2)
    lbl:SetText("")
    af._label = lbl

    af:EnableMouse(true)
    af:SetMovable(true)
    af:RegisterForDrag("LeftButton")
    if af.SetClampedToScreen then af:SetClampedToScreen(true) end

    return af
end

function GC:UpdateAnchorLabel(anchorId)
    self:Init()
    local af = self._anchorFrames and self._anchorFrames[anchorId]
    if not (af and af._label) then return end

    if not self.db.showCoordLabels then
        af._label:SetText("")
        return
    end

    local a = self.db.anchors[anchorId]
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

    local gid = tonumber(a.group) or 0
    local gtxt = (gid > 0) and (" ["..gid.."]") or ""

    local sm = a.showMode
    if type(sm) ~= "string" or not IsAnchorMode(sm) then
        sm = "INHERIT"
        a.showMode = "INHERIT"
    end

    local mtxt = ""
    if sm ~= "INHERIT" then
        local c = (sm == "ALWAYS") and "A" or (sm == "COMBAT") and "C" or (sm == "HIDDEN") and "H" or ""
        if c ~= "" then mtxt = " "..c end
    end

    af._label:SetText(label .. gtxt .. mtxt .. " (" .. gx .. "," .. gy .. ")")
end

function GC:PositionAnchorFrame(anchorId)
    if not (self.ui and self.ui.canvas) then return end
    self:Init()

    local canvas = self.ui.canvas
    local af = self._anchorFrames[anchorId]
    local a = self.db.anchors[anchorId]
    if not (af and a) then return end

    local gx = tonumber(a.gx) or 0
    local gy = tonumber(a.gy) or 0

    local cx = canvas:GetWidth()/2
    local cy = canvas:GetHeight()/2

    local x = Round(cx + gx)
    local y = Round(cy + gy)

    af:ClearAllPoints()
    af:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)

    local isPrimary = (self._selectedAnchorId == anchorId)
    local isSelected = isPrimary or (self._selectedAnchors and self._selectedAnchors[anchorId])

    if isPrimary then
        af:SetBackdropBorderColor(1, 0.9, 0.2, 1)
        af._fill:SetColorTexture(1, 0.9, 0.2, 0.25)
    elseif isSelected then
        af:SetBackdropBorderColor(0.2, 1.0, 0.4, 1)
        af._fill:SetColorTexture(0.2, 1.0, 0.4, 0.18)
    else
        af:SetBackdropBorderColor(1,1,1,0.85)
        af._fill:SetColorTexture(0.2, 0.7, 1.0, 0.35)
    end
end

function GC:AnchorDragStop(anchorId)
    if not (self.ui and self.ui.canvas) then return end
    self:Init()

    local canvas = self.ui.canvas
    local af = self._anchorFrames[anchorId]
    if not af then return end

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

    local cx = canvas:GetWidth()/2
    local cy = canvas:GetHeight()/2

    local gx = Round(x - cx)
    local gy = Round(y - cy)

    local cell = tonumber(self.db.cell) or 8
    local snapTol = tonumber(self.db.snapPx) or 12

    local sx = SnapToCell(gx, cell)
    local sy = SnapToCell(gy, cell)

    if math.abs(gx - sx) <= snapTol then gx = sx end
    if math.abs(gy - sy) <= snapTol then gy = sy end

    if self.db.clampToGrid then
        local maxX = Round(cx - 10)
        local maxY = Round(cy - 10)
        gx = Clamp(gx, -maxX, maxX)
        gy = Clamp(gy, -maxY, maxY)
    end

    self:SetAnchorGridPos(anchorId, gx, gy, false, true)
end