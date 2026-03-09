-- Modules/MythicGear.lua
-- RobUI - Mythic Gear Suggestions (Integrated with MasterConfig)

local ADDON, ns = ...
local R = _G.Robui
ns.mythicGear = ns.mythicGear or {}

-- Uses ns.gear (populated by Data/Gear.lua)
local GearList = ns.gear or {}

-- Safe DB Access
local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.mythicgear then
        return R.Database.profile.mythicgear
    end
    return nil
end

local frame
local tabs = {}
local panels = {}

local GROUPS = {
    { name = "Head",      keys = {"Head"} },
    { name = "Neck",      keys = {"Neck"} },
    { name = "Back",      keys = {"Back"} },
    { name = "Shoulders", keys = {"Shoulders"} },
    { name = "Chest",     keys = {"Chest"} },
    { name = "Wrist",     keys = {"Wrist"} },
    { name = "Hands",     keys = {"Hands"} },
    { name = "Waist",     keys = {"Waist"} },
    { name = "Legs",      keys = {"Legs"} },
    { name = "Feet",      keys = {"Feet"} },
    { name = "Rings",     keys = {"Rings"} },
    { name = "Trinkets",  keys = {"Trinkets"} },
    { name = "Main Hand", keys = {"Main Hand"} },
    { name = "Off Hand",  keys = {"Off Hand"} },
}

local function SaveFramePos(f)
    local db = GetDB()
    if not f or not db then return end
    local p, rel, rp, x, y = f:GetPoint()
    db.pos = { p or "CENTER", "UIParent", rp or "CENTER", math.floor(x or 0), math.floor(y or 0) }
end

local function RestoreFramePos(f)
    local db = GetDB()
    if not f or not db then return end
    local pos = db.pos
    f:ClearAllPoints()
    if type(pos) == "table" and #pos == 5 then
        f:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
    else
        f:SetPoint("CENTER")
    end
end

local function InsertItemLink(itemID)
    if not itemID then return end
    local link = (C_Item and C_Item.GetItemLinkByID and C_Item.GetItemLinkByID(itemID)) or select(2, GetItemInfo(itemID))
    if link and ChatEdit_GetActiveWindow() then
        ChatEdit_InsertLink(link)
    end
end

local function ShowItemTooltip(self)
    if not self or not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local link = (C_Item and C_Item.GetItemLinkByID and C_Item.GetItemLinkByID(self.itemID)) or select(2, GetItemInfo(self.itemID))
    if not link then
        GameTooltip:SetText("Loading...")
        GameTooltip:Show()
        C_Timer.After(0.25, function()
            if self and self:IsMouseOver() then ShowItemTooltip(self) end
        end)
        return
    end
    GameTooltip:SetHyperlink(link)
    if IsShiftKeyDown() then GameTooltip_ShowCompareItem(GameTooltip) end
    GameTooltip:Show()
end

local function HideItemTooltip() GameTooltip_Hide() end

local function CreateSlotPanel(name)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetAllPoints(frame.content)
    panel:Hide()
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    panel.title:SetText(name)
    panel.pool = {}
    panel.used = 0
    return panel
end

local function AcquireRow(panel)
    panel.used = (panel.used or 0) + 1
    local row = panel.pool[panel.used]
    if row then row:Show(); return row end

    row = CreateFrame("Button", nil, panel)
    row:SetHeight(20)
    row:SetPoint("LEFT", panel, "LEFT", 10, 0)
    row:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
    row:RegisterForClicks("LeftButtonUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.txt:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.txt:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.txt:SetJustifyH("LEFT")

    row:SetScript("OnEnter", ShowItemTooltip)
    row:SetScript("OnLeave", HideItemTooltip)
    row:SetScript("OnClick", function(self) InsertItemLink(self.itemID) end)

    panel.pool[panel.used] = row
    return row
end

local function PopulatePanel(panel, items)
    panel.used = 0
    for _, row in ipairs(panel.pool) do row:Hide() end

    local yOff = -40
    for _, item in ipairs(items or {}) do
        local row = AcquireRow(panel)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOff)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, yOff)
        
        row.itemID = item.id
        row.txt:SetText(item.name or ("ItemID: " .. tostring(item.id)))
        
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)) or select(10, GetItemInfo(item.id))
        row.icon:SetTexture(icon)
        
        yOff = yOff - 20
    end
end

local function ShowTab(id)
    for idx, tab in ipairs(tabs) do
        local active = (idx == id)
        tab.bg:SetBackdropColor(active and 0.30 or 0.10, active and 0.30 or 0.10, active and 0.30 or 0.10, 0.85)
        if panels[idx] then panels[idx]:Hide() end
    end
    if panels[id] then panels[id]:Show() end
end

function ns.mythicGear:Initialize()
    if frame then return end
    
    frame = CreateFrame("Frame", "RobUIMythicGearFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 380)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveFramePos(self) end)
    frame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16, insets={ left=4, right=4, top=4, bottom=4 },
    })
    frame:SetBackdropColor(0,0,0,0.85)
    RestoreFramePos(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Mythic Gear")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    frame.tabContainer = CreateFrame("Frame", nil, frame)
    frame.tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
    frame.tabContainer:SetSize(500, 90)

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.tabContainer, "BOTTOMLEFT", 0, -10)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

    local rows = {5, 5, 4}
    local w, h, s = 90, 20, 4
    local idx = 1
    for r = 1, #rows do
        for c = 1, rows[r] do
            if idx > #GROUPS then break end
            local g = GROUPS[idx]
            local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
            tab:SetSize(w, h)
            tab:SetPoint("TOPLEFT", frame.tabContainer, "TOPLEFT", (c-1)*(w+s), -(r-1)*(h+s))
            tab.bg = tab
            tab.bg:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background", tile=true, tileSize=16 })
            tab.bg:SetBackdropColor(0.10, 0.10, 0.10, 0.85)
            
            tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tab.text:SetAllPoints()
            tab.text:SetText(g.name)
            
            panels[idx] = CreateSlotPanel(g.name)
            local thisIdx = idx
            tab:SetScript("OnClick", function() ShowTab(thisIdx) end)
            tabs[idx] = tab
            idx = idx + 1
        end
    end
    frame:Hide()
end

local function CurrentSpecKey()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local _, specName = GetSpecializationInfo(specIndex)
    local className = select(1, UnitClass("player"))
    if not className or not specName then return nil end
    return className .. " - " .. specName
end

local function BuildForSpec(specKey)
    ns.mythicGear:Initialize()
    if not frame then return end
    frame.title:SetText("Mythic Gear: " .. (specKey or "Unknown"))
    
    for i, g in ipairs(GROUPS) do
        local list = {}
        local specTbl = (ns.gear and specKey and ns.gear[specKey]) or nil
        if specTbl then
            for _, k in ipairs(g.keys) do
                local slotItems = specTbl[k] or {}
                for _, itm in ipairs(slotItems) do list[#list+1] = itm end
            end
        end
        PopulatePanel(panels[i], list)
    end
    ShowTab(1)
end

function ns.mythicGear:Toggle()
    self:Initialize()
    if not frame then return end
    local key = CurrentSpecKey()
    if key then BuildForSpec(key) end
    frame:SetShown(not frame:IsShown())
end

-- Slash command
SLASH_ROBGEAR1 = "/robgear"
SlashCmdList["ROBGEAR"] = function() ns.mythicGear:Toggle() end

-- -----------------------------------------------------------------------------
-- SETTINGS PANEL (MasterConfig Integration)
-- -----------------------------------------------------------------------------

function ns.mythicGear:CreateSettingsFrame()
    if self.settingsFrame then return self.settingsFrame end
    
    local f = CreateFrame("Frame", "RobUIMythicGearSettings", UIParent)
    f:SetSize(400, 300)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Mythic Gear Recommendations")

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 20, -50)
    desc:SetText("This module shows a list of recommended gear from Mythic+ dungeons.")
    
    local btnOpen = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnOpen:SetSize(160, 30)
    btnOpen:SetPoint("TOPLEFT", 20, -90)
    btnOpen:SetText("Open Gear Window")
    btnOpen:SetScript("OnClick", function() 
        ns.mythicGear:Toggle() 
    end)

    local btnReset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnReset:SetSize(160, 30)
    btnReset:SetPoint("TOPLEFT", 20, -130)
    btnReset:SetText("Reset Position")
    btnReset:SetScript("OnClick", function()
        local db = GetDB()
        if db then db.pos = nil end
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
        end
        print("RobUI: Gear window position reset.")
    end)

    if R.RegisterModulePanel then
        R:RegisterModulePanel("Gear", f)
    end
    
    self.settingsFrame = f
    return f
end

-- Init Loader
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        ns.mythicGear:Initialize()
        ns.mythicGear:CreateSettingsFrame()
    end)
end)