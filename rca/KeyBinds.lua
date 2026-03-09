-- ============================================================================
-- KeyBinds.lua (RCA) - Custom Keybind Overrides UI (spec-safe + override-safe)
--  FIXES:
--   1) Works even if spell IDs are overrides (uses ns.API.GetActualSpellID)
--   2) Frame is discoverable via ns.Keybinds.Toggle() (no fragile globals)
--   3) Linux case-sensitivity note: .toc must match this filename exactly
-- ============================================================================

local AddonName, ns = ...
ns.Keybinds = ns.Keybinds or {}
local KB = ns.Keybinds

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local pairs = pairs
local type = type
local tonumber = tonumber
local tinsert = table.insert

local function ActualSpellID(id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    if ns.API and ns.API.GetActualSpellID then
        local a = ns.API.GetActualSpellID(id)
        a = tonumber(a)
        if a and a > 0 then return a end
    end
    return id
end

local function EnsureConfig()
    if not ns.CONFIG then return nil end
    ns.CONFIG.customBinds = ns.CONFIG.customBinds or {}
    return ns.CONFIG
end

-- Create once
local frame = CreateFrame("Frame", "RCAKeybindsFrame", UIParent, "BasicFrameTemplateWithInset")
KB.Frame = frame

frame:SetSize(320, 460)
frame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
frame:Hide()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOPLEFT", 12, -8)
frame.title:SetText("RCA Custom Keybinds")

local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOP", 0, -32)
info:SetWidth(290)
info:SetJustifyH("CENTER")
info:SetText("Write custom text to override icon keybinds.\nLeave blank to clear override for that spell.")

-- DROP ZONE
local dropZone = CreateFrame("Button", nil, frame, "BackdropTemplate")
dropZone:SetPoint("TOP", info, "BOTTOM", 0, -10)
dropZone:SetSize(290, 40)
dropZone:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
dropZone:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
dropZone:SetBackdropBorderColor(0, 0, 0, 1)
dropZone:EnableMouse(true)

local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dropText:SetPoint("CENTER")
dropText:SetText("Drop Spell Here to Add")
dropText:SetTextColor(0.6, 0.6, 0.6)

-- SCROLL
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", dropZone, "BOTTOMLEFT", 0, -10)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(260, 1)
scrollFrame:SetScrollChild(content)

local rows = {}

local function GatherActiveSpells()
    local spellMap = {}

    -- 1) Action bar slots
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id then
            local sid = ActualSpellID(id)
            if sid then spellMap[sid] = true end
        elseif actionType == "macro" and id then
            local macroSpell = GetMacroSpell(id)
            local sid = ActualSpellID(macroSpell)
            if sid then spellMap[sid] = true end
        end
    end

    -- 2) Anything already customized (even if not on bars)
    if ns.CONFIG and ns.CONFIG.customBinds then
        for id in pairs(ns.CONFIG.customBinds) do
            local sid = ActualSpellID(id)
            if sid then spellMap[sid] = true end
        end
    end

    -- 3) Convert to list & sort by name
    local list = {}
    for id in pairs(spellMap) do
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        if info and info.name then
            tinsert(list, { id = id, name = info.name, icon = info.iconID })
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function RefreshList()
    local cfg = EnsureConfig()
    if not cfg then return end

    local spells = GatherActiveSpells()
    local y = 0

    for i, spell in ipairs(spells) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(260, 30)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 0, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.name:SetWidth(140)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)

            row.edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.edit:SetSize(70, 20)
            row.edit:SetPoint("RIGHT", 0, 0)
            row.edit:SetAutoFocus(false)

            row.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            row.edit:SetScript("OnEditFocusLost", function(self)
                local c = EnsureConfig()
                if not c then return end

                local sid = row.spellID
                if not sid then return end

                local txt = self:GetText()
                if txt == "" then
                    c.customBinds[sid] = nil
                else
                    c.customBinds[sid] = txt
                end

                -- immediately update icons next tick
                if ns.UpdateAllVisuals then ns.UpdateAllVisuals() end
            end)

            rows[i] = row
        end

        row.spellID = spell.id
        row.icon:SetTexture(spell.icon or 134400)
        row.name:SetText(spell.name or ("Spell " .. spell.id))

        local current = ""
        if cfg.customBinds[spell.id] then current = cfg.customBinds[spell.id] end
        row.edit:SetText(current)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:Show()
        y = y - 34
    end

    for i = #spells + 1, #rows do
        rows[i]:Hide()
    end

    content:SetHeight(math.max(1, -y))
end

frame:SetScript("OnShow", function()
    EnsureConfig()
    RefreshList()
end)

-- Drop logic
dropZone:SetScript("OnReceiveDrag", function()
    local cfg = EnsureConfig()
    if not cfg then return end

    local infoType, d1, _, d3 = GetCursorInfo()
    local newID
    if infoType == "spell" then
        newID = d3
    elseif infoType == "macro" then
        newID = GetMacroSpell(d1)
    end

    newID = ActualSpellID(newID)
    if newID and newID > 0 then
        if cfg.customBinds[newID] == nil then
            cfg.customBinds[newID] = "" -- empty entry shows up
        end
        ClearCursor()
        RefreshList()
    end
end)

dropZone:SetScript("OnClick", function(self, button)
    if button == "LeftButton" and GetCursorInfo() then
        self:GetScript("OnReceiveDrag")()
    end
end)

-- Public API
function KB.Toggle()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function KB.Refresh()
    if frame:IsShown() then RefreshList() end
end