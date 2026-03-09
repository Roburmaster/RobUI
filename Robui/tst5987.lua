local currentScriptName = nil

-- Function to safely initialize the database and new autorun table
local function EnsureDB()
    if type(SSR_DB) ~= "table" then SSR_DB = {} end
    if type(SSR_DB.scripts) ~= "table" then SSR_DB.scripts = {} end
    if type(SSR_DB.autorun) ~= "table" then SSR_DB.autorun = {} end
end

-- Main Frame
local frame = CreateFrame("Frame", "SimpleScriptRunnerFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(600, 400)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
frame.title:SetText("Simple Script Runner")

-- Left side: Script List
local listScroll = CreateFrame("ScrollFrame", "SSR_ListScrollFrame", frame, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", 10, -35)
listScroll:SetPoint("BOTTOMLEFT", 10, 50)
listScroll:SetWidth(150)

local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetSize(150, 10)
listScroll:SetScrollChild(listContent)

-- Right side: Editor
local editScroll = CreateFrame("ScrollFrame", "SSR_EditScrollFrame", frame, "UIPanelScrollFrameTemplate")
editScroll:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 25, 0)
editScroll:SetPoint("BOTTOMRIGHT", -30, 50)

local editBox = CreateFrame("EditBox", "SSR_EditBox", editScroll)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(99999)
editBox:SetFontObject("ChatFontNormal")
editBox:SetWidth(360)
editBox:SetAutoFocus(false)
editScroll:SetScrollChild(editBox)

local bg = editBox:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.5)

-- Auto-Run Checkbox setup
local autoRunCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
autoRunCheck:SetSize(26, 26)
autoRunCheck.text = autoRunCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoRunCheck.text:SetPoint("LEFT", autoRunCheck, "RIGHT", 0, 1)
autoRunCheck.text:SetText("Auto-Run on Login")

autoRunCheck:SetScript("OnClick", function(self)
    if currentScriptName then
        EnsureDB()
        SSR_DB.autorun[currentScriptName] = self:GetChecked()
        if self:GetChecked() then
            print("|cff00ff00[SSR]: Auto-run enabled for:|r", currentScriptName)
        else
            print("|cffff0000[SSR]: Auto-run disabled for:|r", currentScriptName)
        end
    else
        self:SetChecked(false) -- Prevent checking if no script is loaded
    end
end)

-- Function to update the visual list of scripts
local listButtons = {}
local function UpdateScriptList()
    EnsureDB()
    
    -- Clear old buttons
    for _, btn in pairs(listButtons) do 
        btn:Hide() 
    end
    
    local yOffset = 0
    local index = 1
    for name, code in pairs(SSR_DB.scripts) do
        local btn = listButtons[index]
        if not btn then
            btn = CreateFrame("Button", nil, listContent, "GameMenuButtonTemplate")
            btn:SetSize(140, 20)
            listButtons[index] = btn
        end
        
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn:SetText(name)
        btn:Show()
        
        btn:SetScript("OnClick", function()
            currentScriptName = name
            editBox:SetText(code)
            
            -- Update checkbox visually to match the database
            autoRunCheck:SetChecked(SSR_DB.autorun[name] or false)
            
            print("|cff00ff00[SSR]: Loaded script:|r", name)
        end)
        
        yOffset = yOffset + 25
        index = index + 1
    end
    listContent:SetHeight(math.max(yOffset, 10))
end

-- Function to safely run code (prevents broken scripts from crashing the UI)
local function RunScriptCode(name, code)
    local func, err = loadstring(code)
    if func then
        local success, runErr = pcall(func)
        if not success then
            print("|cffff0000[SSR] Runtime Error in " .. name .. ":|r", runErr)
        end
    else
        print("|cffff0000[SSR] Syntax Error in " .. name .. ":|r", err)
    end
end

-- Database Initialization & Auto-Run Execution
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, loadedName)
    -- Initialize DB when the addon folder loads (Update "Robui" if you change the folder name)
    if event == "ADDON_LOADED" and loadedName == "Robui" then 
        EnsureDB()
        UpdateScriptList()
        
    -- Execute all scripts marked for auto-run once the player actually logs in
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        for name, isAutoRun in pairs(SSR_DB.autorun) do
            if isAutoRun and SSR_DB.scripts[name] then
                print("|cff00ff00[SSR]: Auto-running script:|r", name)
                RunScriptCode(name, SSR_DB.scripts[name])
            end
        end
    end
end)

-- Bottom Buttons
local btnNew = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnNew:SetPoint("BOTTOMLEFT", 10, 10)
btnNew:SetSize(60, 25)
btnNew:SetText("New")
btnNew:SetScript("OnClick", function()
    currentScriptName = nil
    editBox:SetText("")
    autoRunCheck:SetChecked(false)
end)

local btnSave = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnSave:SetPoint("LEFT", btnNew, "RIGHT", 5, 0)
btnSave:SetSize(60, 25)
btnSave:SetText("Save")

-- Popup dialog for naming a new script
StaticPopupDialogs["SSR_SAVE_SCRIPT"] = {
    text = "Enter name for the new script:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        EnsureDB()
        local name = self.EditBox:GetText()
        if name and name ~= "" then
            currentScriptName = name
            SSR_DB.scripts[name] = editBox:GetText()
            
            -- New scripts have autorun disabled by default
            if SSR_DB.autorun[name] == nil then
                SSR_DB.autorun[name] = false
            end
            
            UpdateScriptList()
            autoRunCheck:SetChecked(SSR_DB.autorun[name])
            print("|cff00ff00[SSR]: Saved script:|r", name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

btnSave:SetScript("OnClick", function()
    EnsureDB()
    if currentScriptName then
        SSR_DB.scripts[currentScriptName] = editBox:GetText()
        print("|cff00ff00[SSR]: Updated script:|r", currentScriptName)
    else
        StaticPopup_Show("SSR_SAVE_SCRIPT")
    end
end)

local btnDelete = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnDelete:SetPoint("LEFT", btnSave, "RIGHT", 5, 0)
btnDelete:SetSize(60, 25)
btnDelete:SetText("Delete")
btnDelete:SetScript("OnClick", function()
    EnsureDB()
    if currentScriptName and SSR_DB.scripts[currentScriptName] then
        SSR_DB.scripts[currentScriptName] = nil
        SSR_DB.autorun[currentScriptName] = nil -- Clean up autorun data
        print("|cffff0000[SSR]: Deleted script:|r", currentScriptName)
        
        currentScriptName = nil
        editBox:SetText("")
        autoRunCheck:SetChecked(false)
        UpdateScriptList()
    end
end)

-- Position the Auto-Run Checkbox next to the Delete button
autoRunCheck:SetPoint("LEFT", btnDelete, "RIGHT", 15, -2)

local btnRun = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnRun:SetPoint("BOTTOMRIGHT", -10, 10)
btnRun:SetSize(90, 25)
btnRun:SetText("Run Code")
btnRun:SetScript("OnClick", function()
    if currentScriptName then
        print("|cff00ff00[SSR]: Running " .. currentScriptName .. "...|r")
    else
        print("|cff00ff00[SSR]: Running unsaved code...|r")
    end
    RunScriptCode(currentScriptName or "Unsaved", editBox:GetText())
end)

-- Slash command to open/close
SLASH_SSR1 = "/ssr"
SlashCmdList["SSR"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end