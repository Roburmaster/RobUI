-- instancetools/markers.lua
-- RobUI - Instance Tools: Markers (Integrated)

local addonName, ns = ...
local R = _G.Robui
ns.instancetools = ns.instancetools or {}

local module = ns.instancetools.markers or {}
ns.instancetools.markers = module

local nudgeStep = 10

-- --- [ HELPER FUNCTIONS ] ---

local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.markers then
        return R.Database.profile.markers
    end
    return nil
end

local function Round(v)
    return math.floor((v or 0) + 0.5)
end

local function CanLeadTools()
    return IsInGroup() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end

local function RestorePosition(frame)
    local db = GetDB()
    if not db then return end
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
end

local function StyleButton(btn)
    if not btn then return end
    if btn.Left then btn.Left:SetAlpha(0) end
    if btn.Right then btn.Right:SetAlpha(0) end
    if btn.Middle then btn.Middle:SetAlpha(0) end

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.2)
    btn:SetHighlightTexture(hl)

    local push = btn:CreateTexture(nil, "ARTWORK")
    push:SetAllPoints()
    push:SetColorTexture(0, 0, 0, 0.5)
    btn:SetPushedTexture(push)
end

-- --- [ MAIN INITIALIZATION ] ---

function module:Initialize()
    if module.frame then return end
    local db = GetDB()
    if not db then return end

    local btnSize, spacing, padding = 24, 1, 2
    local markers = {
        { id = 1, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
        { id = 2, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        { id = 3, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
        { id = 4, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
        { id = 5, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        { id = 6, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
        { id = 7, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
        { id = 8, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    }

    local numButtons = 1 + #markers + 3
    local totalWidth = (numButtons * btnSize) + ((numButtons - 1) * spacing) + (padding * 2)

    local f = CreateFrame("Frame", "RobUIInstanceMarkerFrame", UIParent, "BackdropTemplate")
    f:SetSize(totalWidth, btnSize + (padding * 2))
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:EnableMouse(true)

    -- Sync visibility logic with enabled state
    if db.enabled and db.visible then
        f:Show()
    else
        f:Hide()
    end

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    RestorePosition(f)

    local function OnDragStart(self)
        local curSV = GetDB()
        if curSV.locked or not IsShiftKeyDown() or InCombatLockdown() then return end
        f:StartMoving()
    end

    local function OnDragStop(self)
        f:StopMovingOrSizing()
        local curSV = GetDB()
        local p, _, rp, x, y = f:GetPoint()
        curSV.point, curSV.relPoint, curSV.xOfs, curSV.yOfs = p, rp, Round(x), Round(y)
    end

    f:SetScript("OnDragStart", OnDragStart)
    f:SetScript("OnDragStop", OnDragStop)

    local function AddTooltip(btn, title, lines)
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(title, 1, 1, 1)
            if lines then for _, ln in ipairs(lines) do GameTooltip:AddLine(ln, 0.8, 0.8, 0.8) end end
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", GameTooltip_Hide)
    end

    local anchor
    local toggled = {}

    local toggle = CreateFrame("Button", nil, f, "BackdropTemplate")
    toggle:SetSize(btnSize, btnSize)
    toggle:SetPoint("LEFT", f, "LEFT", padding, 0)
    StyleButton(toggle)
    toggle:RegisterForDrag("LeftButton")
    toggle:SetScript("OnDragStart", OnDragStart)
    toggle:SetScript("OnDragStop", OnDragStop)

    local togIcon = toggle:CreateTexture(nil, "ARTWORK")
    togIcon:SetSize(14, 14); togIcon:SetPoint("CENTER")
    togIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    togIcon:SetDesaturated(true)
    toggle:SetScript("OnEnter", function() togIcon:SetDesaturated(false) end)
    toggle:SetScript("OnLeave", function() togIcon:SetDesaturated(true) end)
    AddTooltip(toggle, "Markers", { "Click: Show/Hide", "Shift+Drag: Move" })
    anchor = toggle

    for i, info in ipairs(markers) do
        local btn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, BackdropTemplate")
        btn:SetSize(btnSize, btnSize)
        btn:SetPoint("LEFT", anchor, "RIGHT", spacing, 0)
        StyleButton(btn)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/wm " .. info.id)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexture(info.tex); tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        toggled[#toggled + 1] = btn
        anchor = btn
        AddTooltip(btn, "World Marker " .. info.id)
    end

    local clear = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, BackdropTemplate")
    clear:SetSize(btnSize, btnSize); clear:SetPoint("LEFT", anchor, "RIGHT", spacing, 0)
    StyleButton(clear); clear:RegisterForClicks("AnyUp", "AnyDown")
    clear:SetAttribute("type", "macro"); clear:SetAttribute("macrotext", "/cwm all")
    local clearIcon = clear:CreateTexture(nil, "ARTWORK")
    clearIcon:SetSize(16, 16); clearIcon:SetPoint("CENTER")
    clearIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    toggled[#toggled + 1] = clear; anchor = clear
    AddTooltip(clear, "Clear All Markers")

    local rcBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    rcBtn:SetSize(btnSize, btnSize); rcBtn:SetPoint("LEFT", anchor, "RIGHT", spacing, 0)
    StyleButton(rcBtn)
    local rcIcon = rcBtn:CreateTexture(nil, "ARTWORK")
    rcIcon:SetSize(16, 16); rcIcon:SetPoint("CENTER")
    rcIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    rcBtn:SetScript("OnClick", function() if CanLeadTools() then DoReadyCheck() end end)
    toggled[#toggled + 1] = rcBtn; anchor = rcBtn
    AddTooltip(rcBtn, "Ready Check")

    local cdBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    cdBtn:SetSize(btnSize, btnSize); cdBtn:SetPoint("LEFT", anchor, "RIGHT", spacing, 0)
    StyleButton(cdBtn)
    local cdIcon = cdBtn:CreateTexture(nil, "ARTWORK")
    cdIcon:SetSize(14, 14); cdIcon:SetPoint("CENTER")
    cdIcon:SetTexture("Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-SingleRune")
    cdIcon:SetDesaturated(true)
    local cdMenu = CreateFrame("Frame", "RobUI_InstanceMarkersCountdownMenu", UIParent, "UIDropDownMenuTemplate")
    cdBtn:SetScript("OnClick", function()
        if not CanLeadTools() then return end
        UIDropDownMenu_Initialize(cdMenu, function(_, level)
            for _, s in ipairs({10, 5, 3}) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s .. " sec Countdown"; info.notCheckable = true
                info.func = function() C_PartyInfo.DoCountdown(s) end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, cdMenu, cdBtn, 0, 0)
    end)
    toggled[#toggled + 1] = cdBtn; AddTooltip(cdBtn, "Countdown")

    toggle:SetScript("OnClick", function()
        local show = not toggled[1]:IsShown()
        for _, b in ipairs(toggled) do b:SetShown(show) end
        f:SetWidth(show and totalWidth or (btnSize + (padding * 2)))
    end)

    module.frame = f
end

function module:Refresh()
    if not module.frame then module:Initialize() return end
    local db = GetDB()
    if not db then return end
    RestorePosition(module.frame)
    if db.enabled and db.visible then
        module.frame:Show()
    else
        module.frame:Hide()
    end
end

function module:CreateSettingsFrame()
    if module.settingsFrame then return end

    local f = CreateFrame("Frame", "RobUIInstanceMarkerSettingsFrame", UIParent)
    f:SetSize(400, 300)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("Markers Settings")

    local function CreateButton(label, width, x, y, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22); b:SetPoint("TOPLEFT", x, y)
        b:SetText(label); b:SetScript("OnClick", onClick)
        return b
    end

    -- Helper for checkboxes
    local function MakeCheck(parent, label, x, y, onClick)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetText(label)
        cb:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
        return cb
    end

    -- Enable Module
    local cbEnable = MakeCheck(f, "Enable Module", 20, -40, function(val)
        local db = GetDB()
        if db then
            db.enabled = val
            module:Refresh()
        end
    end)
    f.cbEnable = cbEnable

    CreateButton("Show", 100, 20, -80, function() local db=GetDB(); if db then db.visible = true; module:Refresh() end end)
    CreateButton("Hide", 100, 130, -80, function() local db=GetDB(); if db then db.visible = false; module:Refresh() end end)

    CreateButton("Lock", 100, 20, -110, function() local db=GetDB(); if db then db.locked = true end end)
    CreateButton("Unlock", 100, 130, -110, function() local db=GetDB(); if db then db.locked = false end end)

    local lblMove = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblMove:SetPoint("TOPLEFT", 20, -150)
    lblMove:SetText("Nudge Position:")

    CreateButton("1px", 60, 20, -170, function() nudgeStep = 1 end)
    CreateButton("10px", 60, 85, -170, function() nudgeStep = 10 end)
    CreateButton("100px", 60, 150, -170, function() nudgeStep = 100 end)

    -- Direction buttons
    CreateButton("↑", 30, 260, -165, function() local db = GetDB(); if db and module.frame then db.yOfs = db.yOfs + nudgeStep; RestorePosition(module.frame) end end)
    CreateButton("↓", 30, 260, -205, function() local db = GetDB(); if db and module.frame then db.yOfs = db.yOfs - nudgeStep; RestorePosition(module.frame) end end)
    CreateButton("←", 30, 225, -185, function() local db = GetDB(); if db and module.frame then db.xOfs = db.xOfs - nudgeStep; RestorePosition(module.frame) end end)
    CreateButton("→", 30, 295, -185, function() local db = GetDB(); if db and module.frame then db.xOfs = db.xOfs + nudgeStep; RestorePosition(module.frame) end end)

    CreateButton("Reset Position", 140, 20, -220, function()
        local db = GetDB()
        if db then
            db.point = "BOTTOM"
            db.relPoint = "BOTTOM"
            db.xOfs = 0
            db.yOfs = 0
            if module.frame then RestorePosition(module.frame) end
        end
    end)

    f:SetScript("OnShow", function()
        local db = GetDB()
        if db then
            f.cbEnable:SetChecked(db.enabled == true)
        end
    end)

    module.settingsFrame = f

    if R.RegisterModulePanel then
        R:RegisterModulePanel("Markers", f)
    end
end

-- Slash Command
SLASH_ROBUIITOOL1 = "/itool"
SlashCmdList["ROBUIITOOL"] = function()
    if R.MasterConfig and R.MasterConfig.Toggle then
        if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
            R.MasterConfig:Toggle()
        end
        if R.MasterConfig.SelectTab then
            R.MasterConfig:SelectTab("Markers")
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- Wait for DB to be ready
    C_Timer.After(1, function()
        module:Initialize()
        module:CreateSettingsFrame()
    end)
end)
