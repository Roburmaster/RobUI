-- ============================================================================
-- AurasSettings_v2.lua (RobUI)
-- V2 interface adapted for GridCore. Movers and X/Y overrides removed.
-- Reflows grid on settings changes.
-- FIXED: Added _mapsDirty = true to all list modifications (Add/Clear/Delete/Import)
-- so the new caching system in Auras_v2 updates immediately.
-- ============================================================================
local ADDON, ns = ...
local R = _G.Robui
local GC = R and R.GridCore
ns.auras_v2_settings = ns.auras_v2_settings or {}
local S = ns.auras_v2_settings

local function GetAuras() return ns.auras_v2 end
local function GetDB() local A = GetAuras(); return A and A:GetDB() end

local function ApplySettings()
    local A = GetAuras()
    if A and A.ApplyAll then A:ApplyAll() end
    if GC and GC.ReflowAll then
        GC:ReflowAll("settings:auras_v2")
    end
end

local function Clamp(v, lo, hi)
    if type(v) ~= "number" then return lo end
    return math.max(lo, math.min(hi, v))
end

-- Styling Constants
local BTN_COLOR = {r = 0.20, g = 0.25, b = 0.35, a = 1}
local BTN_HOVER = {r = 0.30, g = 0.40, b = 0.55, a = 1}

-- GUI Components
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
end

local function MakeButton(parent, text, x, y, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(w, h)
    b:SetNormalFontObject("GameFontHighlight")
    b:SetText(text)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    SkinButton(b)
    return b
end

local function MakeCheckbox(parent, label, x, y, onToggle)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(self) if onToggle then onToggle(self:GetChecked()) end end)
    return cb
end

local function MakeSlider(parent, label, x, y, minv, maxv, step, onChange)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(200)
    if s.Text then s.Text:SetText(label) end
    if s.Low then s.Low:SetText(tostring(minv)) end
    if s.High then s.High:SetText(tostring(maxv)) end
    s:SetScript("OnValueChanged", function(_, val)
        if onChange then onChange(math.floor(val + 0.5)) end
    end)
    return s
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

-- Modified to accept parentDB to trigger _mapsDirty when deleting an item
local function UpdateListDisplay(scrollChild, tableData, refreshFunc, parentDB)
    local children = { scrollChild:GetChildren() }
    for _, child in ipairs(children) do child:Hide() end

    local sorted = {}
    if tableData then
        for id, val in pairs(tableData) do if val then table.insert(sorted, id) end end
        table.sort(sorted)
    end

    local y = -2
    for _, spellID in ipairs(sorted) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(200, 16)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)

        local spellName = "Unknown"
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            if type(info) == "table" then spellName = info.name or "Unknown"
            elseif type(info) == "string" then spellName = info end
        end

        local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", row, "LEFT", 0, 0)
        t:SetText("|cffff0000[X]|r " .. tostring(spellID) .. " - " .. spellName)

        row:SetScript("OnEnter", function() t:SetTextColor(1, 1, 1) end)
        row:SetScript("OnLeave", function() t:SetTextColor(1, 0.8, 0) end)
        row:SetScript("OnClick", function()
            tableData[spellID] = nil
            if parentDB then parentDB._mapsDirty = true end -- Tell Auras_v2 to rebuild cache
            ApplySettings()
            if refreshFunc then refreshFunc() end
        end)

        y = y - 16
    end

    scrollChild:SetHeight(math.abs(y) + 20)
end

function S:Create()
    local f = CreateFrame("Frame", "RobUI_AurasV2SettingsFrame", UIParent)
    f:SetSize(1000, 680)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -15)
    f.title:SetText("Auras V2 (GridCore Integration)")

    -- Enable
    f.cbEnable = MakeCheckbox(f, "Enable Auras V2 Module", 20, -45, function(v)
        local db = GetDB()
        if db then db.enabled = v; ApplySettings() end
    end)

    -- Preview Mode (Dummy Auras)
    f.cbPreview = MakeCheckbox(f, "Preview Mode (Show Dummy Auras)", 20, -70, function(v)
        local db = GetDB()
        if db then db.preview = v; ApplySettings() end
    end)

    -- Edit mode button (GridCore)
    MakeButton(f, "Toggle Grid Layout", 300, -45, 140, 26, function()
        if GC and GC.ToggleEditMode then GC:ToggleEditMode() end
    end)

    -- Import/Export popup
    local shareFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    shareFrame:SetSize(400, 350)
    shareFrame:SetPoint("CENTER")
    shareFrame:SetFrameLevel(100)
    shareFrame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    shareFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    shareFrame:SetBackdropBorderColor(0, 0, 0, 1)
    shareFrame:Hide()
    shareFrame:EnableMouse(true)

    local shareTitle = shareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    shareTitle:SetPoint("TOP", 0, -15)
    shareTitle:SetText("Import / Export List")

    local shareDesc = shareFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shareDesc:SetPoint("TOP", 0, -40)
    shareDesc:SetText("Copy to share, or paste a list of Spell IDs (separated by commas) to import.")

    local shareScroll = CreateFrame("ScrollFrame", nil, shareFrame, "UIPanelScrollFrameTemplate")
    shareScroll:SetPoint("TOPLEFT", 20, -70)
    shareScroll:SetPoint("BOTTOMRIGHT", -40, 60)

    local shareEdit = CreateFrame("EditBox", nil, shareScroll)
    shareEdit:SetMultiLine(true)
    shareEdit:SetFontObject("ChatFontNormal")
    shareEdit:SetWidth(340)
    shareEdit:SetAutoFocus(true)
    shareScroll:SetScrollChild(shareEdit)

    MakeButton(shareFrame, "Import / Add to List", 20, -305, 150, 26, function()
        local text = shareEdit:GetText()
        local db = GetDB()
        if db and shareFrame.targetKey and shareFrame.targetList then
            db[shareFrame.targetKey][shareFrame.targetList] = db[shareFrame.targetKey][shareFrame.targetList] or {}
            local listRef = db[shareFrame.targetKey][shareFrame.targetList]
            for idStr in string.gmatch(text, "%d+") do
                local id = tonumber(idStr)
                if id and id > 0 then listRef[id] = true end
            end
            db[shareFrame.targetKey]._mapsDirty = true -- Tell Auras_v2 to rebuild cache
            ApplySettings()
            if shareFrame.refreshFunc then shareFrame.refreshFunc() end
            shareFrame:Hide()
        end
    end)

    MakeButton(shareFrame, "Close", 280, -305, 100, 26, function() shareFrame:Hide() end)

    local function OpenShareFrame(title, key, listName, refreshFunc)
        shareFrame.targetKey = key
        shareFrame.targetList = listName
        shareFrame.refreshFunc = refreshFunc
        shareTitle:SetText("I/O: " .. title .. " - " .. listName)

        local db = GetDB()
        local ids = {}
        if db and db[key] and db[key][listName] then
            for id, val in pairs(db[key][listName]) do
                if val then table.insert(ids, id) end
            end
        end
        shareEdit:SetText(table.concat(ids, ", "))
        shareFrame:Show()
    end

    local function GroupBlock(title, key, x, y)
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetPoint("TOPLEFT", x, y)
        box:SetSize(235, 550)
        box:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets = { left=1, right=1, top=1, bottom=1 }
        })
        box:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
        box:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        local bgHeader = box:CreateTexture(nil, "BACKGROUND", nil, 1)
        bgHeader:SetPoint("TOPLEFT", 1, -1)
        bgHeader:SetPoint("TOPRIGHT", -1, -1)
        bgHeader:SetHeight(28)
        bgHeader:SetColorTexture(0.15, 0.15, 0.15, 1)

        local t = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -8)
        t:SetText(title)

        box.cbShow = MakeCheckbox(box, "Show Frame", 15, -40, function(v)
            local db = GetDB()
            if db then db[key].shown = v; ApplySettings() end
        end)

        box.cbMine = MakeCheckbox(box, "Show Only Mine", 15, -70, function(v)
            local db = GetDB()
            if db then db[key].onlyMine = v; ApplySettings() end
        end)

        local dirs = { "RIGHT", "LEFT", "UP", "DOWN" }
        box.btnGrowth = MakeButton(box, "Growth: RIGHT", 15, -110, 205, 24, function(self)
            local db = GetDB()
            if not db then return end
            local current = db[key].growth or "RIGHT"
            local nextDir = "RIGHT"
            for i, d in ipairs(dirs) do
                if d == current then nextDir = dirs[(i % 4) + 1] break end
            end
            db[key].growth = nextDir
            self:SetText("Growth: " .. nextDir)
            ApplySettings()
        end)

        box.slSize = MakeSlider(box, "Icon Size", 15, -170, 16, 64, 1, function(v)
            local db = GetDB()
            if db then db[key].size = v; ApplySettings() end
        end)

        box.slMax = MakeSlider(box, "Max Auras", 15, -230, 1, 40, 1, function(v)
            local db = GetDB()
            if db then db[key].max = v; ApplySettings() end
        end)

        box.slGap = MakeSlider(box, "Spacing Gap", 15, -290, 0, 20, 1, function(v)
            local db = GetDB()
            if db then db[key].gap = v; ApplySettings() end
        end)

        -- Blacklist
        local blt = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        blt:SetPoint("TOPLEFT", 15, -345)
        blt:SetText("Blacklist (Spell ID):")

        box.ebBL = MakeEditBox(box, 15, -360, 70, 20)

        local sfBL = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sfBL:SetPoint("TOPLEFT", 15, -385)
        sfBL:SetSize(190, 50)
        local cBL = CreateFrame("Frame", nil, sfBL)
        cBL:SetSize(190, 1)
        sfBL:SetScrollChild(cBL)

        local function RefreshBL()
            local db = GetDB()
            if db then UpdateListDisplay(cBL, db[key].blacklist, RefreshBL, db[key]) end
        end
        box.RefreshBL = RefreshBL

        MakeButton(box, "Add", 88, -360, 42, 20, function()
            local db = GetDB()
            local id = tonumber(box.ebBL:GetNumber())
            if db and id and id > 0 then
                db[key].blacklist = db[key].blacklist or {}
                db[key].blacklist[id] = true
                db[key]._mapsDirty = true -- Tell Auras_v2 to rebuild cache
                box.ebBL:SetText("")
                ApplySettings()
                RefreshBL()
            end
        end)

        MakeButton(box, "Clear", 132, -360, 45, 20, function()
            local db = GetDB()
            if db then
                db[key].blacklist = {}
                db[key]._mapsDirty = true -- Tell Auras_v2 to rebuild cache
                ApplySettings()
                RefreshBL()
            end
        end)

        MakeButton(box, "I/O", 179, -360, 36, 20, function()
            OpenShareFrame(title, key, "blacklist", RefreshBL)
        end)

        -- Whitelist
        local wlt = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        wlt:SetPoint("TOPLEFT", 15, -455)
        wlt:SetText("Whitelist (Spell ID):")

        box.ebWL = MakeEditBox(box, 15, -470, 70, 20)

        local sfWL = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sfWL:SetPoint("TOPLEFT", 15, -495)
        sfWL:SetSize(190, 50)
        local cWL = CreateFrame("Frame", nil, sfWL)
        cWL:SetSize(190, 1)
        sfWL:SetScrollChild(cWL)

        local function RefreshWL()
            local db = GetDB()
            if db then UpdateListDisplay(cWL, db[key].whitelist, RefreshWL, db[key]) end
        end
        box.RefreshWL = RefreshWL

        MakeButton(box, "Add", 88, -470, 42, 20, function()
            local db = GetDB()
            local id = tonumber(box.ebWL:GetNumber())
            if db and id and id > 0 then
                db[key].whitelist = db[key].whitelist or {}
                db[key].whitelist[id] = true
                db[key]._mapsDirty = true -- Tell Auras_v2 to rebuild cache
                box.ebWL:SetText("")
                ApplySettings()
                RefreshWL()
            end
        end)

        MakeButton(box, "Clear", 132, -470, 45, 20, function()
            local db = GetDB()
            if db then
                db[key].whitelist = {}
                db[key]._mapsDirty = true -- Tell Auras_v2 to rebuild cache
                ApplySettings()
                RefreshWL()
            end
        end)

        MakeButton(box, "I/O", 179, -470, 36, 20, function()
            OpenShareFrame(title, key, "whitelist", RefreshWL)
        end)

        return box
    end

    local startY = -100
    f.boxPD = GroupBlock("Player Debuffs", "playerDebuffs", 15, startY)
    f.boxPB = GroupBlock("Player Buffs",   "playerBuffs",   260, startY)
    f.boxTD = GroupBlock("Target Debuffs", "targetDebuffs", 505, startY)
    f.boxTB = GroupBlock("Target Buffs",   "targetBuffs",   750, startY)

    self.frame = f
    f:SetScript("OnShow", function() self:Refresh() end)

    if R.RegisterModulePanel then
        R:RegisterModulePanel("Auras V2", f)
    end
end

function S:Refresh()
    if not self.frame then return end
    local db = GetDB()
    if not db then return end

    self.frame.cbEnable:SetChecked(db.enabled == true)
    self.frame.cbPreview:SetChecked(db.preview == true)

    local function Fill(box, key)
        local c = db[key]
        if not c then return end
        box.cbShow:SetChecked(c.shown ~= false)
        box.cbMine:SetChecked(c.onlyMine == true)
        box.slSize:SetValue(Clamp(c.size or 24, 16, 64))
        box.slMax:SetValue(Clamp(c.max or 10, 1, 40))
        box.slGap:SetValue(Clamp(c.gap or 2, 0, 20))
        box.btnGrowth:SetText("Growth: " .. (c.growth or "RIGHT"))
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

    SLASH_ROBUIAURASV21 = "/aurasv2"
    SlashCmdList.ROBUIAURASV2 = function()
        if R.MasterConfig and R.MasterConfig.Toggle then
            if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
                R.MasterConfig:Toggle()
            end
            if R.MasterConfig.SelectTab then
                R.MasterConfig:SelectTab("Auras V2")
            end
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        S:Initialize()
        S:Create()
        S:Refresh()
    end)
end)