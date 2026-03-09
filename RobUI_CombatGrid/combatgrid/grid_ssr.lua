-- ============================================================================
-- grid_ssr.lua (RobUI GridCore) -- Script Runner (RIGHT SIDE)
-- Updated for:
--  - Per-profile DB (master/healer/tank/dps) via self.db.ssr
--  - Safe refresh when profile switches while UI is open
--  - Sorted script list
--  - Popup save dialog that always writes to CURRENT active profile db
-- ============================================================================
local AddonName, ns = ...
local GC = ns and ns.GridCore
if not GC then return end

local CreateFrame = CreateFrame
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
local loadstring = loadstring
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local type = type
local tostring = tostring
local table_sort = table.sort
local math_max = math.max

GC._ssr = GC._ssr or {
    built = false,
    parent = nil,
    current = nil,
    listButtons = {},
    listContent = nil,
    editBox = nil,
    autoRun = nil,
    UpdateList = nil,
}

local function SSR_Ensure(db)
    db.ssr = type(db.ssr) == "table" and db.ssr or {}
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

-- ---------------------------------------------------------------------------
-- Public: autorun for CURRENT active profile
-- ---------------------------------------------------------------------------
function GC:SSR_Autorun()
    self:Init()
    SSR_Ensure(self.db)

    for name, enabled in pairs(self.db.ssr.autorun) do
        if enabled and self.db.ssr.scripts[name] then
            SSR_Run(name, self.db.ssr.scripts[name])
        end
    end
end

-- ---------------------------------------------------------------------------
-- Internal helpers for UI refresh (after profile switch)
-- ---------------------------------------------------------------------------
local function SSR_GetActiveDB()
    GC:Init()
    SSR_Ensure(GC.db)
    return GC.db
end

function GC:SSR_RefreshUI()
    local s = self._ssr
    if not (s and s.built and s.UpdateList) then return end

    local db = SSR_GetActiveDB()
    s.current = db.ssr.last

    -- sync checkbox/text
    if s.autoRun then
        if s.current and db.ssr.scripts[s.current] then
            s.autoRun:SetChecked(db.ssr.autorun[s.current] or false)
        else
            s.autoRun:SetChecked(false)
        end
    end

    if s.editBox then
        if s.current and db.ssr.scripts[s.current] then
            s.editBox:SetText(db.ssr.scripts[s.current] or "")
        else
            s.editBox:SetText("")
        end
    end

    s.UpdateList()
end

-- ---------------------------------------------------------------------------
-- Save popup (defined ONCE; always writes to current active profile db)
-- ---------------------------------------------------------------------------
if not StaticPopupDialogs["ROBUIGRID_SSR_SAVE"] then
    StaticPopupDialogs["ROBUIGRID_SSR_SAVE"] = {
        text = "Enter name for the new script:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(selfPopup)
            local db = SSR_GetActiveDB()
            local s = GC._ssr
            if not (s and s.editBox) then return end

            local name = selfPopup.EditBox and selfPopup.EditBox:GetText() or ""
            name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")

            if name == "" then return end

            s.current = name
            db.ssr.last = name
            db.ssr.scripts[name] = s.editBox:GetText() or ""
            if db.ssr.autorun[name] == nil then db.ssr.autorun[name] = false end

            if s.autoRun then
                s.autoRun:SetChecked(db.ssr.autorun[name] or false)
            end
            if s.UpdateList then s.UpdateList() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- ---------------------------------------------------------------------------
-- UI builder (creates widgets once; then refreshes per active profile)
-- ---------------------------------------------------------------------------
function GC:BuildSSR(parent)
    self:Init()
    SSR_Ensure(self.db)

    local s = self._ssr
    s.parent = parent

    -- already built: just refresh against CURRENT profile db
    if s.built then
        self:SSR_RefreshUI()
        return
    end

    local listScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -28)
    listScroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 54)
    listScroll:SetWidth(150)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(150, 10)
    listScroll:SetScrollChild(listContent)
    s.listContent = listContent

    local editScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 18, 0)
    editScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 54)

    local editBox = CreateFrame("EditBox", nil, editScroll)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(999999)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetAutoFocus(false)
    editBox:SetWidth(math_max(200, (parent:GetWidth() or 500) - 230))
    editScroll:SetScrollChild(editBox)

    -- keep width reasonable on resize
    parent:HookScript("OnSizeChanged", function()
        if editBox and editBox.SetWidth then
            editBox:SetWidth(math_max(200, (parent:GetWidth() or 500) - 230))
        end
    end)

    local bg = editBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    s.editBox = editBox

    local autoRunCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    autoRunCheck:SetSize(26, 26)
    autoRunCheck.text = autoRunCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoRunCheck.text:SetPoint("LEFT", autoRunCheck, "RIGHT", 0, 1)
    autoRunCheck.text:SetText("Auto-Run on Login")
    autoRunCheck:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 22)
    s.autoRun = autoRunCheck

    autoRunCheck:SetScript("OnClick", function(selfBtn)
        local db = SSR_GetActiveDB()
        local cur = s.current
        if not cur then
            selfBtn:SetChecked(false)
            return
        end
        db.ssr.autorun[cur] = selfBtn:GetChecked() and true or false
    end)

    local function UpdateList()
        local db = SSR_GetActiveDB()

        -- hide old buttons
        for _, btn in pairs(s.listButtons) do
            if btn then btn:Hide() end
        end

        -- sorted names
        local names = {}
        for name,_ in pairs(db.ssr.scripts) do
            names[#names+1] = name
        end
        table_sort(names)

        local y = 0
        local idx = 1

        for _, name in ipairs(names) do
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
                local db2 = SSR_GetActiveDB()
                s.current = name
                db2.ssr.last = name
                editBox:SetText(db2.ssr.scripts[name] or "")
                autoRunCheck:SetChecked(db2.ssr.autorun[name] or false)
            end)

            y = y + 25
            idx = idx + 1
        end

        listContent:SetHeight(math_max(y, 10))

        -- keep editor synced
        if s.current and db.ssr.scripts[s.current] then
            editBox:SetText(db.ssr.scripts[s.current] or "")
            autoRunCheck:SetChecked(db.ssr.autorun[s.current] or false)
        else
            autoRunCheck:SetChecked(false)
        end
    end

    s.UpdateList = UpdateList

    local btnNew = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnNew:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    btnNew:SetSize(60, 25)
    btnNew:SetText("New")
    btnNew:SetScript("OnClick", function()
        local db = SSR_GetActiveDB()
        s.current = nil
        db.ssr.last = nil
        editBox:SetText("")
        autoRunCheck:SetChecked(false)
        UpdateList()
    end)

    local btnSave = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnSave:SetPoint("LEFT", btnNew, "RIGHT", 5, 0)
    btnSave:SetSize(60, 25)
    btnSave:SetText("Save")
    btnSave:SetScript("OnClick", function()
        local db = SSR_GetActiveDB()

        if s.current then
            db.ssr.scripts[s.current] = editBox:GetText() or ""
        else
            StaticPopup_Show("ROBUIGRID_SSR_SAVE")
            return
        end

        UpdateList()
    end)

    local btnDelete = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btnDelete:SetPoint("LEFT", btnSave, "RIGHT", 5, 0)
    btnDelete:SetSize(60, 25)
    btnDelete:SetText("Delete")
    btnDelete:SetScript("OnClick", function()
        local db = SSR_GetActiveDB()

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
        SSR_Run(s.current or "Unsaved", editBox:GetText() or "")
    end)

    -- mark built + initial sync
    s.built = true
    s.current = self.db.ssr.last
    UpdateList()
end