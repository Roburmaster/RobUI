local AddonName, ns = ...
local R = ns
R.MasterConfig = {}
local GUI = R.MasterConfig

-- Dine design-variabler
local FRAME_WIDTH = 1200
local FRAME_HEIGHT = 800
local SIDEBAR_WIDTH = 160

-- Farge-fallback i tilfelle R.Colors mangler (sikkerhet)
if not R.Colors then
    R.Colors = {
        header = {0.1, 0.1, 0.1, 0.9},
        hover = {0.2, 0.2, 0.2, 0.5},
        blue = {0, 0.4, 1, 0.8}
    }
end

-- Sikre tabeller
R.ModulePanels = R.ModulePanels or {}
R.ModuleOrder = R.ModuleOrder or {}

function GUI:Create()
    if self.frame then return end

    -- 1. Setup General Panel first (så den havner i listen)
    self:CreateGeneralPanel()
    
    -- Sjekk om General ligger i rekkefølgen, hvis ikke legg den først
    local hasGeneral = false
    for _, name in ipairs(R.ModuleOrder) do
        if name == "General" then hasGeneral = true break end
    end
    if not hasGeneral then
        table.insert(R.ModuleOrder, 1, "General")
    end

    -- 2. Hovedvindu (Ditt Design)
    local f = CreateFrame("Frame", "RobuiConfig", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    
    R:CreateBackdrop(f)
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetSize(SIDEBAR_WIDTH, 40)
    R:CreateBackdrop(header)
    header:SetBackdropColor(unpack(R.Colors.header))
    
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER")
    title:SetText("|cff00b3ffRobui|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)

    self.sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    self.sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    self.sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    self.sidebar:SetWidth(SIDEBAR_WIDTH)
    R:CreateBackdrop(self.sidebar)
    self.sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    self.content = CreateFrame("Frame", nil, f, "BackdropTemplate")
    self.content:SetPoint("TOPLEFT", header, "TOPRIGHT", 1, 0)
    self.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    R:CreateBackdrop(self.content)
    self.content:SetBackdropColor(0, 0, 0, 0.3) 

    self.frame = f
    self.tabs = {}
    
    -- 3. Bygg Tabs
    local index = 1
    local order = R.ModuleOrder or {}
    
    if #order == 0 then
        local t = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER")
        t:SetText("No modules registered.")
    else
        for _, name in ipairs(order) do
            self:CreateTab(name, index)
            index = index + 1
        end
        -- Velg første tab (som nå bør være General)
        self:SelectTab(order[1])
    end
end

-- Funksjon for å lage General-fanen innhold
function GUI:CreateGeneralPanel()
    local p = CreateFrame("Frame", nil, UIParent) -- Parent settes senere av SelectTab
    
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 40, -40)
    title:SetText("General Settings")
    
    -- UI Scale Slider
    local slider = CreateFrame("Slider", "RobUIGeneralScale", p, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 40, -80)
    slider:SetWidth(200)
    slider:SetMinMaxValues(0.6, 1.2)
    
    -- Hent verdi fra DB sikkert
    local currentScale = 1.0
    if R.Database and R.Database.profile and R.Database.profile.general then
        currentScale = R.Database.profile.general.scale or 1.0
    end
    slider:SetValue(currentScale)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    
    _G[slider:GetName() .. "Text"]:SetText("UI Scale")
    _G[slider:GetName() .. "Low"]:SetText("0.6")
    _G[slider:GetName() .. "High"]:SetText("1.2")
    
    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    valText:SetText(slider:GetValue())
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100 + 0.5) / 100
        valText:SetText(value)
        if R.Database and R.Database.profile then
            R.Database.profile.general.scale = value
        end
    end)
    
    -- Reload Button
    local reloadBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 25)
    reloadBtn:SetPoint("LEFT", slider, "RIGHT", 40, 0)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", C_UI.Reload)

    -- --- INSTALLER BUTTON (NY) ---
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetWidth(400)
    line:SetPoint("TOPLEFT", 40, -140)
    line:SetColorTexture(1, 1, 1, 0.2)

    local installTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    installTitle:SetPoint("TOPLEFT", 40, -160)
    installTitle:SetText("Unit Frames Setup")

    local installBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    installBtn:SetSize(160, 30)
    installBtn:SetPoint("TOPLEFT", 40, -190)
    installBtn:SetText("Open Installer")
    installBtn:SetScript("OnClick", function()
        GUI:Toggle() -- Lukk config
        if ns.robinstall then
            ns.robinstall:Toggle()
        else
            print("Robui: Installer module not loaded.")
        end
    end)
    
    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("LEFT", installBtn, "RIGHT", 15, 0)
    desc:SetText("Run the layout wizard for Unit Frames.")

    -- Registrer panelet
    R.ModulePanels["General"] = p
end

function GUI:CreateTab(name, index)
    local btn = CreateFrame("Button", nil, self.sidebar, "BackdropTemplate")
    btn:SetSize(SIDEBAR_WIDTH - 2, 30)
    btn:SetPoint("TOP", 0, -((index-1)*31) - 10)
    
    R:CreateBackdrop(btn)
    btn:SetBackdropColor(0, 0, 0, 0)
    btn:SetBackdropBorderColor(0, 0, 0, 0)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("LEFT", 15, 0)
    btn.text:SetText(name)
    
    btn:SetScript("OnEnter", function(s) 
        if GUI.selected ~= name then
            s:SetBackdropColor(unpack(R.Colors.hover))
        end
    end)
    btn:SetScript("OnLeave", function(s) 
        if GUI.selected ~= name then 
            s:SetBackdropColor(0, 0, 0, 0) 
        end 
    end)
    
    btn:SetScript("OnClick", function() GUI:SelectTab(name) end)
    
    self.tabs[name] = btn
end

function GUI:SelectTab(name)
    self.selected = name
    
    -- Oppdater farger på tabs
    for k, btn in pairs(self.tabs) do
        if k == name then
            btn:SetBackdropColor(unpack(R.Colors.blue))
            btn.text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0, 0, 0, 0)
            btn.text:SetTextColor(1, 0.82, 0)
        end
    end
    
    -- Skjul forrige innhold
    if self.activeContent then self.activeContent:Hide() end
    
    -- Vis nytt innhold
    local panel = R.ModulePanels[name]
    if panel then
        panel:SetParent(self.content)
        panel:SetAllPoints(self.content)
        panel:Show()
        self.activeContent = panel
        
        -- Spesialhåndtering for Profil-fanen (oppdater listen)
        if name == "Profiles" and R.Database and R.Database.RefreshPanel then
            R.Database:RefreshPanel()
        end
        -- Spesialhåndtering for AutoSell listen
        if name == "AutoSell" and R.AutoSellSettings and R.AutoSellSettings.UpdateLists then
            R.AutoSellSettings:UpdateLists()
        end
    end
end

function GUI:Toggle()
    if not self.frame then self:Create() end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

-- Støttefunksjon for moduler som registrerer seg selv
function R:RegisterModulePanel(name, frame)
    R.ModulePanels = R.ModulePanels or {}
    R.ModuleOrder = R.ModuleOrder or {}
    
    R.ModulePanels[name] = frame
    
    -- Sjekk om den allerede er i listen
    local found = false
    for _, v in ipairs(R.ModuleOrder) do
        if v == name then found = true break end
    end
    
    if not found then
        table.insert(R.ModuleOrder, name)
    end
    
    -- Hvis GUI allerede er åpen, må vi kanskje oppdatere tabs (valgfritt, men trygt)
    if GUI.frame and GUI.frame:IsShown() then
        GUI.frame:Hide() -- Enklest å lukke/åpne eller be om reload
    end
end

SLASH_ROBUI1 = "/robui"
SlashCmdList.ROBUI = function()
    GUI:Toggle()
end