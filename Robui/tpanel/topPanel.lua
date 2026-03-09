local AddonName, ns = ...

local R = _G.Robui
R.TopPanel = R.TopPanel or {}
local TP = R.TopPanel

-- 1. KONFIGURASJON & DATA
local BUTTON_SIZE = 24
local SPACING = 16
local DEFAULT_Y = -30
local DEFAULT_FONT_SIZE = 36 -- Standard tekststørrelse for klokken

-- Sti til bildene
local MEDIA_PATH = "Interface\\AddOns\\"..AddonName.."\\textures\\art\\"

-- Hjelpefunksjon for å finne bilde
local function GetIconPath(name)
    if string.find(name, "%.") then
        return MEDIA_PATH .. name
    else
        return MEDIA_PATH .. name .. ".png"
    end
end

-- =============================================================
-- IMPORTANT: Use our OWN tooltip, never GameTooltip
-- This avoids tooltip/moneyframe taint when hovering action buttons
-- =============================================================
local function GetTopPanelTooltip()
    if TP.tooltip then return TP.tooltip end
    local tt = CreateFrame("GameTooltip", "RobUITopPanelTooltip", UIParent, "GameTooltipTemplate")
    tt:SetFrameStrata("TOOLTIP")
    tt:SetClampedToScreen(true)
    TP.tooltip = tt
    return tt
end

local function TP_TooltipHide()
    local tt = TP.tooltip
    if tt and tt:IsShown() then
        tt:Hide()
    end
end

local function TP_TooltipShow(owner, anchor, text)
    local tt = GetTopPanelTooltip()
    tt:Hide()
    tt:SetOwner(owner, anchor or "ANCHOR_BOTTOM")
    tt:ClearLines()
    if text and text ~= "" then
        tt:AddLine(text, 1, 1, 1)
    end
    tt:Show()
end

-- KNAPPER - VENSTRE SIDE
local LeftButtons = {
    { label = "Character", icon = "char",    func = function() ToggleCharacter("PaperDollFrame") end },
    { label = "Spellbook", icon = "spell",   func = function() if PlayerSpellsUtil then PlayerSpellsUtil.TogglePlayerSpellsFrame(3) else ToggleSpellBook(BOOKTYPE_SPELL) end end },
    { label = "Talents",   icon = "talents", func = function() if PlayerSpellsUtil then PlayerSpellsUtil.TogglePlayerSpellsFrame(2) else ToggleTalentFrame() end end },
    { label = "Friends",   icon = "friends", func = function() ToggleFriendsFrame() end },
    { label = "Guild",     icon = "guild",   func = function() ToggleGuildFrame() end },
}

-- KNAPPER - HØYRE SIDE
local RightButtons = {
    { label = "Group Finder", icon = "groupfinder",   func = function() PVEFrame_ToggleFrame() end },
    { label = "Combat Grid",  icon = "bags",            type = "macro", macro = "/rgrid" },
    { label = "Mounts",       icon = "murdata",       func = function() ToggleCollectionsJournal(1) end },
    { label = "Robui Config", icon = "settings.jpg",  func = function() if R.MasterConfig then R.MasterConfig:Toggle() end end },

    -- Hearthstone: macro secure button
    { label = "Hearthstone",  icon = "hs",            type = "macro", macro = "/use Hearthstone" },
}

-- 2. POSISJON OG FLYTTING
function TP:ApplyPosition()
    local db = R.Database.profile.toppanel
    if not self.frame then return end

    self.frame:ClearAllPoints()
    if db.point then
        self.frame:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x, db.y)
    else
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_Y)
    end
end

function TP:Nudge(dx, dy)
    local db = R.Database.profile.toppanel
    db.x = (db.x or 0) + dx
    db.y = (db.y or 0) + dy
    if not db.point then
        db.point = "TOP"
        db.relPoint = "TOP"
    end
    self:ApplyPosition()
end

function TP:ResetPosition()
    local db = R.Database.profile.toppanel
    db.point = "TOP"
    db.relPoint = "TOP"
    db.x = 0
    db.y = DEFAULT_Y
    self:ApplyPosition()
    print("|cff00b3ffRobui|r: Top Panel position reset.")
end

-- 3. AUTO-HIDE LOGIKK
local hideTimer = nil

local function UpdateVisibility(alpha)
    if not TP.leftContainer or not TP.rightContainer then return end
    TP.leftContainer:SetAlpha(alpha)
    TP.rightContainer:SetAlpha(alpha)
end

local function OnEnter()
    if hideTimer then hideTimer:Cancel() hideTimer = nil end
    local db = R.Database.profile.toppanel
    if db.hover then UpdateVisibility(1) end
end

local function OnLeave()
    local db = R.Database.profile.toppanel
    if db.hover then
        if hideTimer then hideTimer:Cancel() end
        hideTimer = C_Timer.NewTimer(3, function()
            if TP.frame and not TP.frame:IsMouseOver() then
                UpdateVisibility(0)
            end
        end)
    end
end

-- 4. INITIALISERING
function TP:Initialize()
    local db = R.Database.profile.toppanel

    -- Standardverdier
    if db.useLocalTime == nil then db.useLocalTime = false end
    if db.fontSize == nil then db.fontSize = DEFAULT_FONT_SIZE end
    if db.scale == nil then db.scale = 1 end

    -- Main Container
    local f = CreateFrame("Frame", "RobUITopPanel", UIParent)
    f:SetSize(800, 40)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScale(db.scale or 1)

    self.frame = f
    self:ApplyPosition()

    if not db.enabled then f:Hide() end

    -- Drag Logic (SHIFT+DRAG)
    f:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not db.locked then
            f:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    end)

    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", function()
        OnLeave()
        TP_TooltipHide()
    end)

    -- --- CENTER CLOCK ---
    local center = CreateFrame("Frame", nil, f)
    center:SetSize(140, 50)
    center:SetPoint("CENTER")

    local timeText = center:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    timeText:SetPoint("CENTER")
    timeText:SetTextColor(1, 1, 1)
    timeText:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    self.timeText = timeText

    -- Clock Ticker
    C_Timer.NewTicker(1, function()
        local h, m

        if db.useLocalTime then
            local d = date("*t")
            h, m = d.hour, d.min
        else
            h, m = GetGameTime()
        end

        if db.clock24 then
            timeText:SetText(string.format("%02d:%02d", h, m))
        else
            local ampm = "AM"
            if h >= 12 then ampm = "PM" h = h - 12 end
            if h == 0 then h = 12 end
            timeText:SetText(string.format("%d:%02d %s", h, m, ampm))
        end
    end)

    -- Clock Interactions
    center:EnableMouse(true)
    center:SetScript("OnEnter", function()
        OnEnter()
        local tt = GetTopPanelTooltip()
        tt:Hide()
        tt:SetOwner(center, "ANCHOR_BOTTOM")
        tt:ClearLines()
        tt:AddDoubleLine("Time Source:", db.useLocalTime and "Local (PC)" or "Server (Realm)", 1,1,1, 0,1,0)
        tt:AddLine(" ")
        tt:AddLine(date("%A, %B %d"))
        tt:AddLine(" ")
        tt:AddLine("Shift+Drag to move", 0.6, 0.6, 0.6)
        tt:Show()
    end)
    center:SetScript("OnLeave", function()
        OnLeave()
        TP_TooltipHide()
    end)
    center:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then ToggleCalendar()
        elseif btn == "RightButton" then Stopwatch_Toggle()
        elseif btn == "MiddleButton" then C_UI.Reload() end
    end)

    -- --- BUTTON BUILDER ---
    local function CreateButtonGroup(btnList, anchorPoint, relativeTo)
        local container = CreateFrame("Frame", nil, f)
        local width = (#btnList * BUTTON_SIZE) + (#btnList * SPACING)
        container:SetSize(width, BUTTON_SIZE)

        if anchorPoint == "LEFT" then
            container:SetPoint("RIGHT", relativeTo, "LEFT", -SPACING, 0)
        else
            container:SetPoint("LEFT", relativeTo, "RIGHT", SPACING, 0)
        end

        if db.hover then container:SetAlpha(0) else container:SetAlpha(1) end

        for i, data in ipairs(btnList) do
            local b

            if data.type == "macro" then
                b = CreateFrame("Button", nil, container, "SecureActionButtonTemplate,UIPanelButtonTemplate")
                b:SetAttribute("type", "macro")
                b:SetAttribute("macrotext", data.macro)
                b:RegisterForClicks("AnyUp", "AnyDown")
            else
                b = CreateFrame("Button", nil, container)
                b:RegisterForClicks("AnyUp")
                b:SetScript("OnClick", function()
                    if InCombatLockdown() then return end
                    data.func()
                end)
            end

            b:SetSize(BUTTON_SIZE, BUTTON_SIZE)

            local offset = (i - 1) * (BUTTON_SIZE + SPACING)
            if anchorPoint == "LEFT" then
                b:SetPoint("RIGHT", container, "RIGHT", -offset, 0)
            else
                b:SetPoint("LEFT", container, "LEFT", offset, 0)
            end

            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetColorTexture(1, 1, 1, 0.1)

            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(GetIconPath(data.icon))

            b:SetScript("OnEnter", function(self)
                OnEnter()
                TP_TooltipShow(self, "ANCHOR_BOTTOM", data.label)
                tex:SetVertexColor(1, 0.8, 0)
            end)

            b:SetScript("OnLeave", function()
                OnLeave()
                TP_TooltipHide()
                tex:SetVertexColor(1, 1, 1)
            end)

            -- for UIPanelButtonTemplate: ikke vis tekst
            if b.SetText then b:SetText("") end
        end

        return container
    end

    self.leftContainer  = CreateButtonGroup(LeftButtons,  "LEFT",  center)
    self.rightContainer = CreateButtonGroup(RightButtons, "RIGHT", center)

    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        if db.hideInCombat then
            if event == "PLAYER_REGEN_DISABLED" then
                TP_TooltipHide()
                f:Hide()
            elseif db.enabled then
                f:Show()
            end
        end
    end)

    self:CreateGUI()
end

function TP:Update()
    if not self.frame then return end
    local db = R.Database.profile.toppanel

    self.frame:SetScale(db.scale or 1)
    if db.enabled then self.frame:Show() else self.frame:Hide() end

    if db.hover then UpdateVisibility(0) else UpdateVisibility(1) end

    if self.timeText then
        self.timeText:SetFont(STANDARD_TEXT_FONT, db.fontSize or DEFAULT_FONT_SIZE, "OUTLINE")
    end

    self:ApplyPosition()
end

-- 5. SETTINGS MENU
function TP:CreateGUI()
    local p = CreateFrame("Frame", nil, UIParent)
    local db = R.Database.profile.toppanel

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Top Panel Settings")

    local y = -50
    local function AddCheck(label, key)
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb.text:SetText(label)
        cb.text:SetFontObject("GameFontHighlight")
        cb:SetChecked(db[key])
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked()
            TP:Update()
        end)
        y = y - 35
    end

    AddCheck("Enable Top Panel", "enabled")
    AddCheck("24 Hour Clock", "clock24")
    AddCheck("Use Local Time (PC)", "useLocalTime")
    AddCheck("Hide in Combat", "hideInCombat")
    AddCheck("Auto-Hide Buttons (3s Delay)", "hover")
    AddCheck("Lock Position", "locked")

    y = y - 10

    local sliderScale = CreateFrame("Slider", "RobUITopPanelScale", p, "OptionsSliderTemplate")
    sliderScale:SetPoint("TOPLEFT", 20, y)
    sliderScale:SetMinMaxValues(0.5, 2.0)
    sliderScale:SetValue(db.scale or 1)
    sliderScale:SetValueStep(0.1)
    _G[sliderScale:GetName() .. "Text"]:SetText("Panel Scale")
    _G[sliderScale:GetName() .. "Low"]:SetText("0.5")
    _G[sliderScale:GetName() .. "High"]:SetText("2.0")

    sliderScale:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        db.scale = value
        if TP.frame then TP.frame:SetScale(value) end
    end)

    local sliderFont = CreateFrame("Slider", "RobUIClockSize", p, "OptionsSliderTemplate")
    sliderFont:SetPoint("LEFT", sliderScale, "RIGHT", 40, 0)
    sliderFont:SetMinMaxValues(12, 64)
    sliderFont:SetValue(db.fontSize or DEFAULT_FONT_SIZE)
    sliderFont:SetValueStep(1)
    _G[sliderFont:GetName() .. "Text"]:SetText("Clock Font Size")
    _G[sliderFont:GetName() .. "Low"]:SetText("12")
    _G[sliderFont:GetName() .. "High"]:SetText("64")

    sliderFont:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.fontSize = value
        TP:Update()
    end)

    y = y - 50

    local nudgeLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nudgeLabel:SetPoint("TOPLEFT", 20, y)
    nudgeLabel:SetText("Position Nudge:")

    local function CreateNudgeBtn(label, dx, dy, offsetX, offsetY)
        local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        btn:SetSize(30, 25)
        btn:SetPoint("LEFT", nudgeLabel, "RIGHT", offsetX, offsetY)
        btn:SetText(label)
        btn:SetScript("OnClick", function() TP:Nudge(dx, dy) end)
    end

    CreateNudgeBtn("U",  0,  1,  50,  15)
    CreateNudgeBtn("D",  0, -1,  50, -15)
    CreateNudgeBtn("L", -1,  0,  20,   0)
    CreateNudgeBtn("R",  1,  0,  80,   0)

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("TOPLEFT", 20, y - 50)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function() TP:ResetPosition() end)

    R:RegisterModulePanel("TopPanel", p)
end

-- Loader
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, arg1)
    if arg1 == AddonName then
        TP:Initialize()
    end
end)
