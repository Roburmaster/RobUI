-- POM Modern UI Test - Full Layout Framework
local addonName = "POM_ModernUI"

-- Main Configuration Window
local mainFrame = CreateFrame("Frame", "POM_MainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(850, 600)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

mainFrame.backdropInfo = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}
mainFrame:ApplyBackdrop()
mainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
mainFrame:SetBackdropBorderColor(0, 0, 0, 1)

-- Title Bar
local titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
titleBar:SetSize(850, 30)
titleBar:SetPoint("TOP", mainFrame, "TOP", 0, 0)
titleBar.backdropInfo = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 0 }
titleBar:ApplyBackdrop()
titleBar:SetBackdropColor(0.15, 0.15, 0.15, 1)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleText:SetPoint("LEFT", titleBar, "LEFT", 15, 0)
titleText:SetText("POM Configuration - Modern Layout")

local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

-- Sidebar (Navigation)
local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
sidebar:SetSize(200, 570)
sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
sidebar.backdropInfo = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
sidebar:ApplyBackdrop()
sidebar:SetBackdropColor(0.08, 0.08, 0.08, 1)
sidebar:SetBackdropBorderColor(0, 0, 0, 1)

-- Content Area 
local contentArea = CreateFrame("Frame", "POM_ContentArea", mainFrame)
contentArea:SetSize(650, 570)
contentArea:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)

-- Panel Storage and Management
local panels = {}
local function ShowPanel(index)
    for i, panel in ipairs(panels) do
        if i == index then
            panel:Show()
        else
            panel:Hide()
        end
    end
end

-- UI Component Helper Functions
local function CreateCheckbox(parent, labelText, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(24, 24)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    text:SetText(labelText)
    return cb
end

local function CreateSlider(parent, labelText, minVal, maxVal, currentVal, x, y)
    -- Generates a unique global name by removing spaces/symbols from the label text
    local cleanLabel = string.gsub(labelText, "[^%w]", "")
    -- Adding GetTime ensures multiple sliders with the same name don't clash
    local frameName = "POM_Slider_" .. cleanLabel .. tostring(GetTime()):gsub("%.", "")
    
    local slider = CreateFrame("Slider", frameName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(currentVal)
    slider:SetValueStep(0.1)
    slider:SetWidth(150)
    
    _G[slider:GetName() .. 'Low']:SetText(tostring(minVal))
    _G[slider:GetName() .. 'High']:SetText(tostring(maxVal))
    _G[slider:GetName() .. 'Text']:SetText(labelText)
    
    return slider
end

local function CreateColorBox(parent, labelText, r, g, b, x, y)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box.backdropInfo = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
    box:ApplyBackdrop()
    box:SetBackdropColor(r, g, b, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", box, "RIGHT", 10, 0)
    text:SetText(labelText)
    return box
end

local function CreateSectionHeader(parent, labelText, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetText(labelText)
    return text
end

-- Function to generate sidebar category buttons and their panels
local function CreateCategory(name, index)
    -- Button
    local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
    btn:SetSize(190, 30)
    btn:SetPoint("TOP", sidebar, "TOP", 0, -(10 + ((index - 1) * 35)))
    btn.backdropInfo = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 0 }
    btn:ApplyBackdrop()
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", btn, "LEFT", 15, 0)
    text:SetText(name)
    
    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.3, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    btn:SetScript("OnClick", function() ShowPanel(index) end)
    
    -- Panel
    local panel = CreateFrame("Frame", nil, contentArea)
    panel:SetAllPoints(contentArea)
    panel:Hide()
    panels[index] = panel
    return panel
end

-- ==========================================
-- POPULATING THE PANELS
-- ==========================================

-- Tab 1: General Options & Skins
local p1 = CreateCategory("General & Options", 1)
CreateSectionHeader(p1, "Options", 30, -30)
CreateCheckbox(p1, "Hide Elite Icon", 30, -60)
CreateCheckbox(p1, "Show Target Arrows", 30, -90)
CreateCheckbox(p1, "Show Threat Progress", 30, -120)

CreateSectionHeader(p1, "Sliders", 300, -30)
CreateSlider(p1, "Global Scale", 0.5, 2.0, 1.0, 300, -70)
CreateSlider(p1, "Target Scale", 0.5, 2.0, 1.25, 300, -130)
CreateSlider(p1, "Out of CC", 0, 100, 30, 300, -190)

-- Tab 2: Heights & Colors
local p2 = CreateCategory("Heights & Base Colors", 2)
CreateSectionHeader(p2, "Heights (Override)", 30, -30)
CreateCheckbox(p2, "Use Global Height Override", 30, -60)
CreateSlider(p2, "Normal Height", 5, 50, 14, 30, -100)
CreateSlider(p2, "High level Height", 5, 50, 20, 30, -160)

CreateSectionHeader(p2, "Base Colors", 300, -30)
CreateColorBox(p2, "Normal", 0, 0, 1, 300, -70)
CreateColorBox(p2, "High level (+3)", 1, 0, 1, 300, -100)
CreateColorBox(p2, "Player +1", 1, 0.5, 0, 300, -130)
CreateColorBox(p2, "Target Border Color", 1, 0, 0.5, 300, -180)

-- Tab 3: Threat & Aggro
local p3 = CreateCategory("Threat & Aggro", 3)
CreateSectionHeader(p3, "Threat Settings", 30, -30)
CreateCheckbox(p3, "Enable Threat System", 30, -60)
CreateCheckbox(p3, "Colorate By Threat", 30, -90)
CreateCheckbox(p3, "Tank Mode Enable", 30, -120)

CreateSectionHeader(p3, "Threat Colors", 300, -30)
CreateColorBox(p3, "High Threat", 1, 0, 0, 300, -70)
CreateColorBox(p3, "Medium Threat", 1, 0.5, 0, 300, -100)
CreateColorBox(p3, "Low Threat", 0, 1, 0, 300, -130)
CreateColorBox(p3, "Tank Safe / Have Aggro", 0, 0.8, 0, 300, -160)

-- Tab 4: Spells & PVP
local p4 = CreateCategory("Spells & PVP", 4)
CreateSectionHeader(p4, "POM Spells", 30, -30)
CreateCheckbox(p4, "Enable Spell Warnings", 30, -60)
CreateSlider(p4, "Cast Sound Target", 0, 1, 0.5, 30, -100)
CreateCheckbox(p4, "Nameplate Cast Text", 30, -160)

CreateSectionHeader(p4, "PVP Settings", 300, -30)
CreateCheckbox(p4, "Enable PVP Module", 300, -60)
CreateCheckbox(p4, "Arena", 300, -90)
CreateCheckbox(p4, "Battlegrounds", 400, -90)
CreateSlider(p4, "Healer Mark Size", 5, 50, 20, 300, -140)

-- Show first panel by default
ShowPanel(1)
mainFrame:Hide()

SLASH_POMUI1 = "/pomui"
SlashCmdList["POMUI"] = function()
    if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show() end
end