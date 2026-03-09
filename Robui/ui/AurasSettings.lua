local ADDON, ns = ...
local R = _G.Robui
ns.auras_settings = ns.auras_settings or {}
local S = ns.auras_settings

local function GetAuras() return ns.auras or ns.Auras end
local function GetDB()
    local A = GetAuras()
    return A and A:GetDB()
end
local function Apply()
    local A = GetAuras()
    if A and A.ApplyAll then A:ApplyAll() end
end

local function Clamp(v, lo, hi)
    v = tonumber(v)
    if not v then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ------------------------------------------------------------
-- GUI Helpers (Styling)
-- ------------------------------------------------------------
local BTN_COLOR = {r = 0.25, g = 0.35, b = 0.50, a = 1}
local BTN_HOVER = {r = 0.35, g = 0.45, b = 0.60, a = 1}

local function SkinButton(btn)
    if btn.Left then btn.Left:Hide() end
    if btn.Right then btn.Right:Hide() end
    if btn.Middle then btn.Middle:Hide() end
    for _, region in ipairs({btn:GetRegions()}) do
        if region:GetObjectType() == "Texture" then region:SetTexture(nil) end
    end
    if not btn.bg then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(BTN_COLOR.r, BTN_COLOR.g, BTN_COLOR.b, BTN_COLOR.a)
        btn.bg = bg
    end
    if not btn.Backdrop then
        Mixin(btn, BackdropTemplateMixin)
        btn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        btn:SetBackdropBorderColor(0, 0, 0, 1)
    end
    btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(BTN_HOVER.r, BTN_HOVER.g, BTN_HOVER.b, BTN_HOVER.a) end)
    btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(BTN_COLOR.r, BTN_COLOR.g, BTN_COLOR.b, BTN_COLOR.a) end)
    if btn.Text then btn.Text:SetTextColor(1, 1, 1) end
    if btn:GetFontString() then btn:GetFontString():SetTextColor(1, 1, 1) end
end

-- IMPORTANT FIX: always pass real boolean, not 1/0
local function MakeCheckbox(parent, label, x, y, onToggle)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if cb.Text then cb.Text:SetText(label) end
    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        if onToggle then onToggle(v) end
    end)
    return cb
end

local function MakeSlider(parent, label, x, y, minv, maxv, step, onChange)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(220)
    if s.Text then s.Text:SetText(label) end
    if s.Low then s.Low:SetText(tostring(minv)) end
    if s.High then s.High:SetText(tostring(maxv)) end
    s:SetScript("OnValueChanged", function(_, val)
        if onChange then onChange(math.floor((tonumber(val) or 0) + 0.5)) end
    end)
    return s
end

local function MakeButton(parent, text, x, y, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(w, h)
    b:SetNormalFontObject("GameFontHighlight")
    b:SetText(text)
    b:SetScript("OnClick", function() if onClick then onClick() end end)
    SkinButton(b)
    return b
end

local function MakeEditBox(parent, x, y, w, h)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetSize(w, h)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

local function UpdateListDisplay(scrollChild, tableData, refreshFunc, parentDB)
    -- hide previous rows
    local children = { scrollChild:GetChildren() }
    for _, child in ipairs(children) do child:Hide() end

    local sorted = {}
    if type(tableData) == "table" then
        for id, val in pairs(tableData) do
            if val then sorted[#sorted + 1] = tonumber(id) or id end
        end
        table.sort(sorted, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    end

    local y = -2
    for _, spellID in ipairs(sorted) do
        local sid = tonumber(spellID) or 0

        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(200, 16)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)

        local spellName = "Unknown"
        if C_Spell and C_Spell.GetSpellInfo and sid > 0 then
            local info = C_Spell.GetSpellInfo(sid)
            if type(info) == "table" then
                spellName = info.name or "Unknown"
            elseif type(info) == "string" then
                spellName = info
            end
        end

        local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", row, "LEFT", 0, 0)
        t:SetText("|cffff0000[X]|r " .. tostring(sid) .. " - " .. spellName)

        row:SetScript("OnEnter", function() t:SetTextColor(1, 1, 1) end)
        row:SetScript("OnLeave", function() t:SetTextColor(1, 0.8, 0) end)

        row:SetScript("OnClick", function()
            if type(tableData) == "table" then
                tableData[sid] = nil
                if parentDB then parentDB._mapsDirty = true end
            end
            Apply()
            if refreshFunc then refreshFunc() end
        end)

        y = y - 16
    end

    scrollChild:SetHeight(math.abs(y) + 20)
end

function S:Create()
    local f = CreateFrame("Frame", "RobUI_AurasSettingsFrame", UIParent)
    f:SetSize(1000, 600)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -12)
    f.title:SetText("Auras Settings")

    f.cbEnable = MakeCheckbox(f, "Enable Module", 20, -40, function(v)
        local db = GetDB()
        if db then db.enabled = v; Apply() end
    end)

    f.padTop = MakeSlider(f, "Attach: TOP pad", 150, -45, 0, 40, 1, function(v)
        local db = GetDB(); if db then db.attachTopPad = v; Apply() end
    end)
    f.padBottomP = MakeSlider(f, "Bottom (Player)", 380, -45, 0, 60, 1, function(v)
        local db = GetDB(); if db then db.attachBottomPad = v; Apply() end
    end)
    f.padBottomT = MakeSlider(f, "Bottom (Target)", 610, -45, 0, 60, 1, function(v)
        local db = GetDB(); if db then db.attachBottomPadTarget = v; Apply() end
    end)

    -- (du hadde en knapp her som kaller A:ReattachAll() men den finnes ikke i auras.lua du postet)
    -- Jeg lar den være, men guarder så den ikke feiler.
    MakeButton(f, "Re-attach Frames", 840, -50, 140, 24, function()
        local A = GetAuras()
        if A and A.ReattachAll then A:ReattachAll() end
    end)

    local function GroupBlock(title, key, x, y, lockOnlyMine)
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetPoint("TOPLEFT", x, y); box:SetSize(240, 500)
        box:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets = { left=1, right=1, top=1, bottom=1 }
        })
        box:SetBackdropColor(0, 0, 0, 0.25)
        box:SetBackdropBorderColor(0, 0, 0, 0.6)

        local t = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", 10, -10)
        t:SetText(title)

        -- NEW: Enabled per group
        box.cbEnabled = MakeCheckbox(box, "Enabled", 10, -30, function(v)
            local db = GetDB()
            if db and db[key] then db[key].enabled = v; Apply() end
        end)

        -- Existing: Show/Hide (visual)
        box.cbShow = MakeCheckbox(box, "Show", 10, -54, function(v)
            local db = GetDB()
            if db and db[key] then db[key].shown = v; Apply() end
        end)

        box.cbLock = MakeCheckbox(box, "Lock", 10, -78, function(v)
            local db = GetDB()
            if db and db[key] then db[key].locked = v; Apply() end
        end)

        box.cbMine = MakeCheckbox(box, "Only mine", 10, -102, function(v)
            local db = GetDB(); if not (db and db[key]) then return end
            if lockOnlyMine then
                db[key].onlyMine = true
                box.cbMine:SetChecked(true)
            else
                db[key].onlyMine = v
            end
            Apply()
        end)

        if lockOnlyMine then
            box.cbMine:Disable()
            if box.cbMine.Text then box.cbMine.Text:SetText("Only mine (forced)") end
        end

        box.slSize = MakeSlider(box, "Size", 10, -140, 12, 60, 1, function(v)
            local db = GetDB(); if db and db[key] then db[key].size = v; Apply() end
        end)
        box.slMax = MakeSlider(box, "Max", 10, -196, 1, 60, 1, function(v)
            local db = GetDB(); if db and db[key] then db[key].max = v; Apply() end
        end)
        box.slGap = MakeSlider(box, "Gap", 10, -252, 0, 20, 1, function(v)
            local db = GetDB(); if db and db[key] then db[key].gap = v; Apply() end
        end)

        local blt = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        blt:SetPoint("TOPLEFT", 10, -285)
        blt:SetText("Blacklist (Spell ID):")

        box.ebBL = MakeEditBox(box, 10, -300, 70, 20)

        local sfBL = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sfBL:SetPoint("TOPLEFT", 10, -325)
        sfBL:SetSize(210, 60)
        local cBL = CreateFrame("Frame", nil, sfBL)
        cBL:SetSize(210, 1)
        sfBL:SetScrollChild(cBL)
        box.blContent = cBL

        local function RefreshBL()
            local db = GetDB()
            if db and db[key] then
                UpdateListDisplay(cBL, db[key].blacklist, RefreshBL, db[key])
            end
        end
        box.RefreshBL = RefreshBL

        MakeButton(box, "Add", 85, -300, 60, 20, function()
            local db = GetDB()
            if not (db and db[key]) then return end
            local id = tonumber(box.ebBL:GetNumber())
            if id and id > 0 then
                db[key].blacklist[id] = true
                db[key]._mapsDirty = true
                box.ebBL:SetText("")
                Apply()
                RefreshBL()
            end
        end)

        MakeButton(box, "Clear", 150, -300, 50, 20, function()
            local db = GetDB()
            if not (db and db[key]) then return end
            db[key].blacklist = {}
            db[key]._mapsDirty = true
            Apply()
            RefreshBL()
        end)

        local wlt = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        wlt:SetPoint("TOPLEFT", 10, -420)
        wlt:SetText("Whitelist (Spell ID):")

        box.ebWL = MakeEditBox(box, 10, -435, 70, 20)

        local sfWL = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sfWL:SetPoint("TOPLEFT", 10, -460)
        sfWL:SetSize(210, 60)
        local cWL = CreateFrame("Frame", nil, sfWL)
        cWL:SetSize(210, 1)
        sfWL:SetScrollChild(cWL)
        box.wlContent = cWL

        local function RefreshWL()
            local db = GetDB()
            if db and db[key] then
                UpdateListDisplay(cWL, db[key].whitelist, RefreshWL, db[key])
            end
        end
        box.RefreshWL = RefreshWL

        MakeButton(box, "Add", 85, -435, 60, 20, function()
            local db = GetDB()
            if not (db and db[key]) then return end
            local id = tonumber(box.ebWL:GetNumber())
            if id and id > 0 then
                db[key].whitelist[id] = true
                db[key]._mapsDirty = true
                box.ebWL:SetText("")
                Apply()
                RefreshWL()
            end
        end)

        MakeButton(box, "Clear", 150, -435, 50, 20, function()
            local db = GetDB()
            if not (db and db[key]) then return end
            db[key].whitelist = {}
            db[key]._mapsDirty = true
            Apply()
            RefreshWL()
        end)

        return box
    end

    local startY = -90
    f.boxPD = GroupBlock("Player Debuffs", "playerDebuffs", 10,  startY)
    f.boxPB = GroupBlock("Player Buffs",   "playerBuffs",   260, startY)
    f.boxTD = GroupBlock("Target Debuffs", "targetDebuffs", 510, startY)
    f.boxTB = GroupBlock("Target Buffs",   "targetBuffs",   760, startY)

    self.frame = f

    -- CRITICAL: refresh UI from DB whenever shown (fixes reload showing unchecked + empty lists)
    f:SetScript("OnShow", function()
        S:Refresh()
    end)

    if R and R.RegisterModulePanel then
        R:RegisterModulePanel("Auras", f)
    end

    -- Also do an initial refresh after creation
    C_Timer.After(0, function() S:Refresh() end)
end

function S:Refresh()
    if not self.frame then return end
    local db = GetDB()
    if not db then return end

    self.frame.cbEnable:SetChecked(db.enabled == true)
    self.frame.padTop:SetValue(Clamp(db.attachTopPad, 0, 40))
    self.frame.padBottomP:SetValue(Clamp(db.attachBottomPad, 0, 60))
    self.frame.padBottomT:SetValue(Clamp(db.attachBottomPadTarget, 0, 60))

    local function Fill(box, key)
        local c = db[key]
        if not c then return end

        box.cbEnabled:SetChecked(c.enabled == true)
        box.cbShow:SetChecked(c.shown == true)
        box.cbLock:SetChecked(c.locked == true)
        box.cbMine:SetChecked(c.onlyMine == true)

        box.slSize:SetValue(Clamp(c.size, 12, 60))
        box.slMax:SetValue(Clamp(c.max, 1, 60))
        box.slGap:SetValue(Clamp(c.gap, 0, 20))

        box.RefreshBL()
        box.RefreshWL()
    end

    Fill(self.frame.boxPD, "playerDebuffs")
    Fill(self.frame.boxPB, "playerBuffs")
    Fill(self.frame.boxTD, "targetDebuffs")
    Fill(self.frame.boxTB, "targetBuffs")
end

function S:Initialize()
    if self._init then return end
    self._init = true

    SLASH_ROBUIAURAS1 = "/auras"
    SlashCmdList.ROBUIAURAS = function()
        if R and R.MasterConfig and R.MasterConfig.Toggle then
            if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
                R.MasterConfig:Toggle()
            end
            if R.MasterConfig.SelectTab then
                R.MasterConfig:SelectTab("Auras")
            end
        end

        -- Force refresh even if tab system doesn't trigger OnShow properly
        C_Timer.After(0, function() S:Refresh() end)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        S:Initialize()
        S:Create()
    end)
end)