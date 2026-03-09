-- BPanel/SpecLoot.lua (Formerly sls.lua)
-- Visuals Improved: Icons, Class Colors, Modern Borders, Hover effects
-- Logic Preserved: Combat Safety, Drag fix

local AddonName, ns = ...
local R = _G.Robui
ns.sls = ns.sls or {}

-- 1. Helper: Get Class Color Hex for Text
local _, classFile = UnitClass("player")
local classColor = C_ClassColor.GetClassColor(classFile)
local classHex = classColor:GenerateHexColorMarkup() -- e.g. "|cffF58CBA"

-- Helper to get config from RobuiDB
local function GetCfg()
    if R.Database and R.Database.profile and R.Database.profile.datapanel then
        return R.Database.profile.datapanel.specloot
    end
    -- Fallback
    return {
        point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 150, y = 0,
        locked = false, visible = true
    }
end

local function SaveMaybe()
    -- RobuiDB saves automatically on reload/logout
end

function ns.sls:SetVisible(show)
    local cfg = GetCfg()
    cfg.visible = not not show
    if self.frame then self.frame:SetShown(cfg.visible) end
end

function ns.sls:UpdateLock()
    local cfg = GetCfg()
    if self.frame then
        self.frame:EnableMouse(true)
    end
end

function ns.sls:Nudge(dx, dy)
    local cfg = GetCfg()
    cfg.x = (cfg.x or 0) + dx
    cfg.y = (cfg.y or 0) + dy
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    end
end

function ns.sls:Reset()
    local cfg = GetCfg()
    cfg.point, cfg.relPoint, cfg.x, cfg.y = "BOTTOMLEFT", "BOTTOMLEFT", 150, 0
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    end
end

-- Settings Frame (Visuals tweaked slightly for consistency)
function ns.sls:CreateSettingsFrame()
    if self.settingsFrame and self.settingsFrame:IsObjectType("Frame") then
        return self.settingsFrame
    end

    local cfg = GetCfg()
    local f = CreateFrame("Frame", "RobUISLSSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 240)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:Hide()

    local function CreateButton(label, width, x, y, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end

    CreateButton("Show",   120, 10,  -20, function() ns.sls:SetVisible(true) end)
    CreateButton("Hide",   120, 150, -20, function() ns.sls:SetVisible(false) end)
    CreateButton("Lock",   120, 10,  -60, function() cfg.locked = true;  ns.sls:UpdateLock() end)
    CreateButton("Unlock", 120, 150, -60, function() cfg.locked = false; ns.sls:UpdateLock() end)
    CreateButton("↑",       28, 115, -100, function() ns.sls:Nudge(0, 1) end)
    CreateButton("←",       28,  85, -130, function() ns.sls:Nudge(-1, 0) end)
    CreateButton("↓",       28, 115, -130, function() ns.sls:Nudge(0, -1) end)
    CreateButton("→",       28, 145, -130, function() ns.sls:Nudge(1, 0) end)
    CreateButton("Reset",  120, 10,  -170, function() ns.sls:Reset() end)
    CreateButton("Close",  120, 90,  -210, function() f:Hide() end)

    self.settingsFrame = f
    return f
end

-- Helper to create stylized buttons with icons
local function CreateVisualButton(parent, width)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 24)

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(18, 18)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Crop borders (Modern look)

    -- Text
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetWordWrap(false)

    -- Hover Highlight
    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetColorTexture(1, 1, 1, 0.1) -- Faint white overlay on hover

    return btn
end

function ns.sls:Initialize()
    if self.frame then return end

    local cfg = GetCfg()

    -- Main Frame
    local f = CreateFrame("Frame", "RobUISpecLootFrame", UIParent, "BackdropTemplate")
    self.frame = f

    -- Increased width slightly to fit icons
    f:SetSize(240, 30)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Visual: Dark background with border
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9) -- Dark Grey Background
    f:SetBackdropBorderColor(0, 0, 0, 1)   -- Black Border

    f:ClearAllPoints()
    f:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    f:SetShown(cfg.visible)

    -- Drag Logic
    f:SetScript("OnDragStart", function()
        cfg = GetCfg()
        if cfg.locked then return end
        if InCombatLockdown() then return end
        f:StartMoving()
    end)

    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        cfg = GetCfg()
        local p, _, rp, x, y = f:GetPoint()
        cfg.point    = p  or "BOTTOMLEFT"
        cfg.relPoint = rp or "BOTTOMLEFT"
        cfg.x        = math.floor(x or 0)
        cfg.y        = math.floor(y or 0)
    end)

    -- Dropdown
    local dropdown = CreateFrame("Frame", "RobUISpecLootDropdown", f, "UIDropDownMenuTemplate")
    dropdown:Hide()

    -- Visual Buttons
    -- 1. Spec Button
    local specBtn = CreateVisualButton(f, 100)
    specBtn:SetPoint("LEFT", f, "LEFT", 0, 0)

    -- Separator Line
    local sep = f:CreateTexture(nil, "OVERLAY")
    sep:SetSize(1, 20)
    sep:SetColorTexture(0.3, 0.3, 0.3, 1)
    sep:SetPoint("LEFT", specBtn, "RIGHT", 0, 0)

    -- 2. Loot Spec Button
    local lootBtn = CreateVisualButton(f, 138)
    lootBtn:SetPoint("LEFT", sep, "RIGHT", 0, 0)

    -- Tooltips
    specBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Specialization")
        GameTooltip:AddLine("Click to change spec", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    specBtn:SetScript("OnLeave", GameTooltip_Hide)

    lootBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Loot Specialization")
        GameTooltip:AddLine("Click to change loot spec", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    lootBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Logic: Update Text and Icons
    local function UpdateText()
        -- 1. Current Spec
        local currentSpec = GetSpecialization()
        local currentID, currentName, _, currentIcon

        if currentSpec then
            currentID, currentName, _, currentIcon = GetSpecializationInfo(currentSpec)
        else
            currentName = "None"
            currentIcon = 134400 -- Question mark
        end

        -- Update Spec Button
        specBtn.icon:SetTexture(currentIcon)
        specBtn.text:SetText(classHex .. (currentName or "Error"))

        -- 2. Loot Spec
        local lootSpec = GetLootSpecialization()
        local lootName, lootIcon

        if lootSpec == 0 then
            -- "Current" means matching current spec
            lootName = "Current"
            lootIcon = currentIcon -- Use current spec icon, maybe desaturate later if desired
        else
            local _
            _, lootName, _, lootIcon = GetSpecializationInfoByID(lootSpec)
        end

        -- Update Loot Button
        if not lootName then lootName = "Unknown" end
        if not lootIcon then lootIcon = 134400 end

        lootBtn.icon:SetTexture(lootIcon)
        lootBtn.text:SetText("|cffffffffLoot: " .. classHex .. lootName)
    end

    -- Click Handlers (Dropdowns)
    specBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end

        UIDropDownMenu_Initialize(dropdown, function(_, level)
            for i = 1, GetNumSpecializations() do
                local id, name, _, icon = GetSpecializationInfo(i)
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.icon = icon -- Add icon to dropdown too!
                info.checked = (GetSpecialization() == i)
                info.func = function()
                    C_SpecializationInfo.SetSpecialization(i)
                    C_Timer.After(0.5, UpdateText)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")

        ToggleDropDownMenu(1, nil, dropdown, specBtn, 0, 0)
    end)

    lootBtn:SetScript("OnClick", function()
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            -- Default Option
            local defaultInfo = UIDropDownMenu_CreateInfo()
            defaultInfo.text = "Current Spec"
            defaultInfo.checked = (GetLootSpecialization() == 0)
            -- Fetch current spec icon for the "Current" option
            local currentS = GetSpecialization()
            if currentS then
                local _, _, _, cIcon = GetSpecializationInfo(currentS)
                defaultInfo.icon = cIcon
            end
            defaultInfo.func = function()
                SetLootSpecialization(0)
                C_Timer.After(0.2, UpdateText)
            end
            UIDropDownMenu_AddButton(defaultInfo, level)

            -- Specific Options
            for i = 1, GetNumSpecializations() do
                local id, name, _, icon = GetSpecializationInfo(i)
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.icon = icon
                info.checked = (GetLootSpecialization() == id)
                info.func = function()
                    SetLootSpecialization(id)
                    C_Timer.After(0.2, UpdateText)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")

        ToggleDropDownMenu(1, nil, dropdown, lootBtn, 0, 0)
    end)

    local evt = CreateFrame("Frame")
    evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    evt:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    evt:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    evt:SetScript("OnEvent", UpdateText)

    UpdateText()

    if not self.settingsFrame then self:CreateSettingsFrame() end
    self:UpdateLock()
end

SLASH_SLSSET1 = "/slsset"
SlashCmdList.SLSSET = function()
    if not ns.sls.settingsFrame then ns.sls:CreateSettingsFrame() end
    ns.sls.settingsFrame:SetShown(not ns.sls.settingsFrame:IsShown())
end

-- Hook into BPanel
if R.BPanel then
    hooksecurefunc(R.BPanel, "Initialize", function() 
        ns.sls:Initialize() 
    end)
end