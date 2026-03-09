local AddonName, ns = ...
local R = _G.Robui
R.BPanel = {}
local BP = R.BPanel

-- 1. INITIALIZE BOTTOM BAR
function BP:Initialize()
    local f = CreateFrame("Frame", "RobUIBottomPanel", UIParent, "BackdropTemplate")
    f:SetFrameStrata("BACKGROUND")
    f:SetHeight(32)
    f:SetAlpha(0.9)
    f:EnableMouse(false)
    
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT",  UIParent, "BOTTOMLEFT",  0, 0)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)

    R:CreateBackdrop(f)
    f:SetBackdropColor(0, 0, 0, 0.75)
    f:SetBackdropBorderColor(1, 1, 1, 0.12)
    
    self.frame = f
    
    if R.Database.profile.datapanel.enabled then
        f:Show()
    else
        f:Hide()
    end
end

-- 2. CONFIGURATION PANEL SYSTEM
function BP:CreateGUI()
    local p = CreateFrame("Frame", nil, UIParent)
    self.configPanel = p
    
    -- Title Header
    local header = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 20, -20)
    header:SetText("Bottom Panel & Modules")
    self.header = header

    -- --- CONTAINER FOR LIST VIEW (Checkboxes) ---
    local listView = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    listView:SetPoint("TOPLEFT", 0, -60)
    listView:SetPoint("BOTTOMRIGHT", -30, 0)
    
    local listContent = CreateFrame("Frame", nil, listView)
    listContent:SetSize(600, 600)
    listView:SetScrollChild(listContent)
    self.listView = listView

    -- --- CONTAINER FOR SETTINGS VIEW (Embedded Modules) ---
    local settingsContainer = CreateFrame("Frame", nil, p)
    settingsContainer:SetPoint("TOPLEFT", 0, -60)
    settingsContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    settingsContainer:Hide() -- Hidden by default
    self.settingsContainer = settingsContainer

    -- --- BACK BUTTON ---
    local backBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    backBtn:SetSize(80, 22)
    backBtn:SetPoint("TOPRIGHT", -30, -20)
    backBtn:SetText("<< Back")
    backBtn:Hide()
    
    -- Logic to go back to list
    backBtn:SetScript("OnClick", function()
        settingsContainer:Hide()     -- Hide settings container
        backBtn:Hide()               -- Hide back button
        listView:Show()              -- Show list again
        header:SetText("Bottom Panel & Modules") -- Reset title
        
        -- Hide any currently embedded child
        if BP.embeddedFrame then
            BP.embeddedFrame:Hide()
            BP.embeddedFrame = nil
        end
    end)

    -- --- FUNCTION TO EMBED A FRAME ---
    local function EmbedFrame(frameName, initFunc, titleName)
        -- 1. Ensure the frame exists
        if initFunc then initFunc() end
        local f = _G[frameName]
        
        if not f then 
            print("Robui: Could not find frame "..frameName)
            return 
        end

        -- 2. Switch Views
        listView:Hide()
        settingsContainer:Show()
        backBtn:Show()
        header:SetText("Settings: " .. titleName)

        -- 3. Modify the target frame to fit inside
        f:SetParent(settingsContainer)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 20, -20)
        f:SetPoint("BOTTOMRIGHT", -20, 20)
        f:SetFrameStrata("HIGH") -- Ensure it's above the container
        f:Show()
        
        -- 4. Strip "Popup" styling (Backdrop, Border, Close Button)
        if f.SetBackdrop then f:SetBackdrop(nil) end
        f:EnableMouse(false) -- Disable dragging of the whole window inside the tab
        if f.SetMovable then f:SetMovable(false) end
        
        -- Try to find and hide the "Close" button usually named "Close" or implicit
        for i=1, f:GetNumChildren() do
            local child = select(i, f:GetChildren())
            if child:IsObjectType("Button") then
                local text = child:GetText()
                if text == "Close" or text == "Lukk" then
                    child:Hide()
                end
            end
        end
        
        BP.embeddedFrame = f
    end

    -- --- POPULATE LIST VIEW ---
    local y = -10
    local db = R.Database.profile.datapanel

    -- Master Toggle
    local cbMain = CreateFrame("CheckButton", nil, listContent, "UICheckButtonTemplate")
    cbMain:SetPoint("TOPLEFT", 20, y)
    cbMain.text:SetText("|cffffd100Background Panel|r (The black strip)")
    cbMain:SetChecked(db.enabled)
    cbMain:SetScript("OnClick", function(self) 
        db.enabled = self:GetChecked()
        if db.enabled then BP.frame:Show() else BP.frame:Hide() end
    end)
    y = y - 40

    -- Module Row Helper
    local function AddModuleRow(label, dbTable, frameName, slashFunc)
        -- Enable Checkbox
        local cb = CreateFrame("CheckButton", nil, listContent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb.text:SetText(label)
        cb:SetChecked(dbTable.enabled)
        
        cb:SetScript("OnClick", function(self)
            dbTable.enabled = self:GetChecked()
            -- Toggle the actual module frame visibility immediately
            local frame = _G[frameName]
            if frame then frame:SetShown(dbTable.enabled) end
        end)

        -- Settings Button (Opens Embedded View)
        local btn = CreateFrame("Button", nil, listContent, "GameMenuButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("LEFT", cb.text, "RIGHT", 20, 0)
        btn:SetText("Configure")
        btn:SetScript("OnClick", function()
            EmbedFrame(frameName, slashFunc, label)
        end)

        y = y - 35
    end

    -- Add Modules
    AddModuleRow("System Stats (FPS/MS)", db.system, "RobUIMSSettingsFrame", SlashCmdList.MSSET) -- Note: Using SettingsFrame here
    AddModuleRow("Gold & Economy", db.gold, "RobUIGoldSettingsFrame", SlashCmdList.GOLDSET)
    AddModuleRow("Durability", db.durability, "RobUIDurabilitySettings", SlashCmdList.DURAV2SET)
    AddModuleRow("Spec & Loot", db.specloot, "RobUISLSSettingsFrame", SlashCmdList.SLSSET)
    AddModuleRow("Instance Difficulty", db.instance, "RobUIInstanceSettings", SlashCmdList.INSTSET)

    -- Extra Automation Settings
    y = y - 20
    local subHeader = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subHeader:SetPoint("TOPLEFT", 20, y)
    subHeader:SetText("Quick Automation")
    y = y - 25

    local function AddSimpleCheck(label, key)
        local cb = CreateFrame("CheckButton", nil, listContent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb.text:SetText(label)
        cb:SetChecked(db.gold[key])
        cb:SetScript("OnClick", function(self) db.gold[key] = self:GetChecked() end)
        y = y - 30
    end

    AddSimpleCheck("Auto Repair Items", "autoRepair")
    AddSimpleCheck("Use Guild Funds", "guildRepair")
    AddSimpleCheck("Auto Sell Junk", "autoSell")

    R:RegisterModulePanel("DataPanel", p)
end

-- Initialize
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == AddonName then
        BP:Initialize()
        BP:CreateGUI()
    end
end)