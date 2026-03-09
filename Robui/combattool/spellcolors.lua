-- ============================================================================
-- Robui/combattool/buffbars_spellcolors.lua
-- BuffBars: Per-spell color overrides UI + live repaint
--
-- Saves to: RobUIBuffBarsDB.spellColorOverrides[spellID] = {r,g,b,a}
-- Slash:
--   /rbbcolors   (open UI)
--
-- Works without modifying buffbars.lua by repainting the BuffBarCooldownViewer
-- bars after your skin runs. Low cost: repaints only on show + child changes.
-- ============================================================================

local ADDON, ns = ...
ns = _G[ADDON] or ns
_G[ADDON] = ns

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer
local pcall = pcall
local tonumber = tonumber
local type = type
local InCombatLockdown = InCombatLockdown

-- ------------------------------------------------------------
-- DB
-- ------------------------------------------------------------
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

local function EnsureDB()
    _G.RobUIBuffBarsDB = _G.RobUIBuffBarsDB or {}
    local db = _G.RobUIBuffBarsDB

    db.spellColorOverrides = db.spellColorOverrides or {}

    db.colorUIPos = db.colorUIPos or {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0,
    }

    return db
end

local function GetOverrides()
    local db = EnsureDB()
    return db.spellColorOverrides
end

-- ------------------------------------------------------------
-- Safe helpers (avoid forbidden)
-- ------------------------------------------------------------
local function IsForbiddenSafe(obj)
    if not obj then return true end
    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then return true end
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

-- ------------------------------------------------------------
-- Try identify bar spellID (best effort)
-- ------------------------------------------------------------
local function TryGetSpellIDFromBar(bar)
    if IsForbiddenSafe(bar) then return nil end

    local id = bar.spellID or bar.spellId or bar.SpellID or bar.SpellId
    if type(id) == "number" then return id end

    local data = bar.data or bar.Data or bar.info or bar.Info
    if type(data) == "table" then
        local did = data.spellID or data.spellId or data.SpellID or data.SpellId
        if type(did) == "number" then return did end
    end

    local mid = SafeCall(bar, "GetSpellID")
    if type(mid) == "number" then return mid end

    return nil
end

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
            if k and not IsForbiddenSafe(k) and k.GetObjectType and k:GetObjectType() == "StatusBar" and k.GetStatusBarTexture then
                return k
            end
        end
    end

    return nil
end

-- ------------------------------------------------------------
-- Repaint viewer using overrides
-- ------------------------------------------------------------
local function ApplyOverrideToBar(bar)
    if IsForbiddenSafe(bar) then return end

    local sid = TryGetSpellIDFromBar(bar)
    if not sid then return end

    local ov = GetOverrides()[sid]
    if type(ov) ~= "table" then return end

    local sb = FindStatusBar(bar)
    if not sb or IsForbiddenSafe(sb) or not sb.SetStatusBarColor then return end

    local r = Clamp01(ov.r)
    local g = Clamp01(ov.g)
    local b = Clamp01(ov.b)
    local a = Clamp01(ov.a == nil and 1 or ov.a)

    SafeCall(sb, "SetStatusBarColor", r, g, b, a)
end

local function RepaintViewer()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer or IsForbiddenSafe(viewer) then return end
    if viewer.IsShown and not viewer:IsShown() then return end
    if not viewer.GetChildren then return end

    local kids = { viewer:GetChildren() }
    for i = 1, #kids do
        local k = kids[i]
        ApplyOverrideToBar(k)
        if k and not IsForbiddenSafe(k) and k.GetChildren then
            local gkids = { k:GetChildren() }
            for j = 1, #gkids do
                ApplyOverrideToBar(gkids[j])
            end
        end
    end
end

-- watcher (same style as your other files)
local Watch = { ticker=nil, last=0 }

local function CountChildrenDeep(viewer)
    if not viewer or IsForbiddenSafe(viewer) or not viewer.GetChildren then return 0 end
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

local function StartWatch()
    if Watch.ticker then return end
    Watch.last = 0

    Watch.ticker = C_Timer.NewTicker(0.50, function()
        local viewer = _G.BuffBarCooldownViewer
        if not viewer or IsForbiddenSafe(viewer) then
            if Watch.ticker then Watch.ticker:Cancel() end
            Watch.ticker = nil
            return
        end

        if viewer.IsShown and not viewer:IsShown() then
            if Watch.ticker then Watch.ticker:Cancel() end
            Watch.ticker = nil
            return
        end

        local c = CountChildrenDeep(viewer)
        if c ~= Watch.last then
            Watch.last = c
            RepaintViewer()
        end
    end)
end

local function StopWatch()
    if Watch.ticker then
        Watch.ticker:Cancel()
        Watch.ticker = nil
    end
end

local function HookViewerIfPossible()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer or IsForbiddenSafe(viewer) then return end
    if viewer.__robuiSpellColorHooked then return end
    viewer.__robuiSpellColorHooked = true

    SafeCall(viewer, "HookScript", "OnShow", function()
        RepaintViewer()
        StartWatch()
    end)

    SafeCall(viewer, "HookScript", "OnHide", function()
        StopWatch()
    end)

    -- If already shown
    if viewer.IsShown and viewer:IsShown() then
        RepaintViewer()
        StartWatch()
    end
end

-- ------------------------------------------------------------
-- UI
-- ------------------------------------------------------------
local UI = { frame=nil }

local function SaveUIPos(f)
    local db = EnsureDB()
    if not f or IsForbiddenSafe(f) or not f.GetPoint then return end

    local p, _, rp, x, y
    local ok = pcall(function()
        p, _, rp, x, y = f:GetPoint(1)
    end)
    if not ok then return end

    db.colorUIPos.point = p or db.colorUIPos.point
    db.colorUIPos.relPoint = rp or db.colorUIPos.relPoint
    db.colorUIPos.x = SafeToNumber(x) or 0
    db.colorUIPos.y = SafeToNumber(y) or 0
end

local function RestoreUIPos(f)
    local db = EnsureDB()
    local pos = db.colorUIPos or {}
    local p = pos.point or "CENTER"
    local rp = pos.relPoint or p
    local x = SafeToNumber(pos.x) or 0
    local y = SafeToNumber(pos.y) or 0
    f:ClearAllPoints()
    f:SetPoint(p, UIParent, rp, x, y)
end

local function SortSpellIDs(tbl)
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

local function PrettySpellName(id)
    if not _G.GetSpellInfo then return ("SpellID " .. tostring(id)) end
    local name = _G.GetSpellInfo(id)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return ("SpellID " .. tostring(id))
end

local function MakeBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 }
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local function EnsureFont(fs, size)
    if not fs or IsForbiddenSafe(fs) then return end
    size = SafeToNumber(size) or 12
    local font = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(fs.SetFont, fs, font, size, "OUTLINE")
    pcall(fs.SetShadowOffset, fs, 0, 0)
end

local function MakeRow(parent, y, leftText)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    EnsureFont(fs, 11)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    fs:SetText(leftText)
    return fs
end

local function UpdateList(listFrame)
    if not listFrame or IsForbiddenSafe(listFrame) then return end

    local overrides = GetOverrides()
    local ids = SortSpellIDs(overrides)

    listFrame._rows = listFrame._rows or {}
    for i = 1, #listFrame._rows do
        listFrame._rows[i]:Hide()
    end

    local visibleRows = 12
    local rowH = 18
    local offset = listFrame._scrollOffset or 0
    if offset < 0 then offset = 0 end
    if offset > math.max(0, #ids - visibleRows) then
        offset = math.max(0, #ids - visibleRows)
    end
    listFrame._scrollOffset = offset

    for i = 1, visibleRows do
        local idx = offset + i
        local sid = ids[idx]
        if not sid then break end

        local row = listFrame._rows[i]
        if not row then
            row = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
            row:SetSize(listFrame:GetWidth() - 24, rowH)
            row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 12, -10 - ((i-1) * rowH))
            row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8" })
            row:SetBackdropColor(0,0,0,0.15)

            row.swatch = row:CreateTexture(nil, "ARTWORK")
            row.swatch:SetSize(14, 14)
            row.swatch:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.swatch:SetTexture("Interface\\Buttons\\WHITE8X8")

            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            EnsureFont(row.text, 11)
            row.text:SetPoint("LEFT", row.swatch, "RIGHT", 8, 0)
            row.text:SetJustifyH("LEFT")

            row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.del:SetSize(56, 16)
            row.del:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.del:SetText("Remove")

            listFrame._rows[i] = row
        end

        local c = overrides[sid]
        local r = Clamp01(c and c.r or 1)
        local g = Clamp01(c and c.g or 1)
        local b = Clamp01(c and c.b or 1)
        local a = Clamp01(c and (c.a == nil and 1 or c.a) or 1)

        row.swatch:SetVertexColor(r,g,b,a)
        row.text:SetText(("%d  -  %s"):format(sid, PrettySpellName(sid)))

        row.del:SetScript("OnClick", function()
            overrides[sid] = nil
            UpdateList(listFrame)
            RepaintViewer()
        end)

        row:Show()
    end

    if listFrame._scrollText then
        listFrame._scrollText:SetText(("Showing %d / %d"):format(math.min(visibleRows, #ids - offset), #ids))
    end
end

local function OpenColorPicker(initial, onApply, onCancel)
    if not (_G.ColorPickerFrame and _G.ColorPickerFrame.SetupColorPickerAndShow) then return end

    local cr = Clamp01(initial.r)
    local cg = Clamp01(initial.g)
    local cb = Clamp01(initial.b)
    local ca = Clamp01(initial.a == nil and 1 or initial.a)

    local function Apply(r,g,b,a)
        if onApply then onApply(Clamp01(r), Clamp01(g), Clamp01(b), Clamp01(a)) end
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
        if onCancel then
            onCancel()
            return
        end
        local r = prev and prev.r or cr
        local g = prev and prev.g or cg
        local b = prev and prev.b or cb
        local a = 1 - (prev and prev.opacity or (1 - ca))
        Apply(r,g,b,a)
    end

    pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
end

function UI:Show()
    EnsureDB()

    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    if not self.frame then
        local f = CreateFrame("Frame", "RobUI_BuffBarsSpellColors", UIParent, "BackdropTemplate")
        f:SetSize(460, 380)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetClampedToScreen(true)
        MakeBackdrop(f)

        f:SetScript("OnDragStart", function(self)
            if InCombatLockdown and InCombatLockdown() then return end
            self:StartMoving()
        end)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveUIPos(self)
        end)

        RestoreUIPos(f)

        local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        EnsureFont(title, 14)
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
        title:SetText("BuffBars - Spell Color Overrides")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

        -- SpellID input
        MakeRow(f, -44, "SpellID:")

        local idBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        idBox:SetSize(110, 20)
        idBox:SetPoint("TOPLEFT", f, "TOPLEFT", 72, -40)
        idBox:SetAutoFocus(false)
        idBox:SetNumeric(true)

        local nameFS = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        EnsureFont(nameFS, 11)
        nameFS:SetPoint("LEFT", idBox, "RIGHT", 10, 0)
        nameFS:SetText("")

        idBox:SetScript("OnTextChanged", function(self)
            local sid = SafeToNumber(self:GetText())
            if sid then
                nameFS:SetText(PrettySpellName(sid))
            else
                nameFS:SetText("")
            end
        end)

        -- Swatch button (uses last chosen color)
        local chosen = { r=1, g=0, b=0, a=1 } -- default red
        local swatch = f:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(18, 18)
        swatch:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70)
        swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
        swatch:SetVertexColor(chosen.r, chosen.g, chosen.b, chosen.a)

        local pickBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        pickBtn:SetSize(120, 20)
        pickBtn:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
        pickBtn:SetText("Pick Color...")

        pickBtn:SetScript("OnClick", function()
            OpenColorPicker(chosen, function(r,g,b,a)
                chosen.r, chosen.g, chosen.b, chosen.a = r,g,b,a
                swatch:SetVertexColor(r,g,b,a)
            end)
        end)

        -- Add/Update
        local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        addBtn:SetSize(120, 20)
        addBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -98)
        addBtn:SetText("Add / Update")

        local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        applyBtn:SetSize(120, 20)
        applyBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        applyBtn:SetText("Apply now")

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(120, 20)
        clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 8, 0)
        clearBtn:SetText("Clear input")

        -- List box
        local list = CreateFrame("Frame", nil, f, "BackdropTemplate")
        list:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -132)
        list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 44)
        list:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
        list:SetBackdropColor(0,0,0,0.20)
        list:SetBackdropBorderColor(0,0,0,1)

        list._scrollText = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        EnsureFont(list._scrollText, 10)
        list._scrollText:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 10, 6)
        list._scrollText:SetText("")

        local up = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        up:SetSize(60, 18)
        up:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, 6)
        up:SetText("Up")

        local down = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        down:SetSize(60, 18)
        down:SetPoint("RIGHT", up, "LEFT", -6, 0)
        down:SetText("Down")

        up:SetScript("OnClick", function()
            list._scrollOffset = (list._scrollOffset or 0) - 1
            UpdateList(list)
        end)
        down:SetScript("OnClick", function()
            list._scrollOffset = (list._scrollOffset or 0) + 1
            UpdateList(list)
        end)

        addBtn:SetScript("OnClick", function()
            local sid = SafeToNumber(idBox:GetText())
            if not sid then return end

            local overrides = GetOverrides()
            overrides[sid] = {
                r = Clamp01(chosen.r),
                g = Clamp01(chosen.g),
                b = Clamp01(chosen.b),
                a = Clamp01(chosen.a),
            }
            UpdateList(list)
            RepaintViewer()
        end)

        applyBtn:SetScript("OnClick", function()
            RepaintViewer()
        end)

        clearBtn:SetScript("OnClick", function()
            idBox:SetText("")
            nameFS:SetText("")
        end)

        -- Footer note
        local note = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        EnsureFont(note, 10)
        note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
        note:SetText("Note: Colors apply when viewer is shown and when bars change.")

        f:SetScript("OnShow", function()
            HookViewerIfPossible()
            UpdateList(list)
            RepaintViewer()
        end)

        self.frame = f
        self.list = list
        self.idBox = idBox
        self.swatch = swatch
    end

    self.frame:Show()
    HookViewerIfPossible()
    UpdateList(self.list)
    RepaintViewer()
end

-- ------------------------------------------------------------
-- Slash
-- ------------------------------------------------------------
_G.SLASH_ROBUIBUFFBARSCOLORS1 = "/rbc"
SlashCmdList.ROBUIBUFFBARSCOLORS = function()
    UI:Show()
end

-- ------------------------------------------------------------
-- Hook on login + when CooldownViewer loads
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        HookViewerIfPossible()
        return
    end

    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_CooldownViewer" then
            EnsureDB()
            C_Timer.After(0.10, HookViewerIfPossible)
            return
        end
        if arg1 == ADDON then
            EnsureDB()
            return
        end
    end
end)
