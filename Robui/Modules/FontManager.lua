-- Modules/FontManager.lua
-- RobUI Font Manager (Integrated + Search + Optimized List)

local ADDON, ns = ...
local R = _G.Robui
ns.media = ns.media or {}
local M = ns.media

-- Prøv å hente LibSharedMedia
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- -----------------------------------------------------------------------------
-- REGISTRER DINE LOKALE FONTER HER
-- -----------------------------------------------------------------------------
local LocalFonts = {
    ["Noto Serif Georgian"] = "Interface\\AddOns\\Robui\\media\\fonts\\Noto_Serif_Georgian\\NotoSerifGeorgian-VariableFont_wdth,wght.ttf",
    ["Roboto Condensed"]    = "Interface\\AddOns\\Robui\\media\\fonts\\Roboto_Condensed\\RobotoCondensed-Regular.ttf",
    ["Roboto"]              = "Interface\\AddOns\\Robui\\media\\fonts\\Roboto\\Roboto-Regular.ttf",
    ["Overpass"]            = "Interface\\AddOns\\Robui\\media\\fonts\\Overpass\\Overpass-Regular.ttf",
    ["Oswald"]              = "Interface\\AddOns\\Robui\\media\\fonts\\Oswald\\Oswald-Regular.ttf",
    ["Montserrat"]          = "Interface\\AddOns\\Robui\\media\\fonts\\Montserrat\\Montserrat-Regular.ttf",
    ["Chakra Petch"]        = "Interface\\AddOns\\Robui\\media\\fonts\\Chakra_Petch\\ChakraPetch-Regular.ttf",
}

local function DefaultFontPath()
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Kobling til databasen
local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.media then
        return R.Database.profile.media
    end
    return nil
end

M._fonts   = M._fonts or {}
M._targets = M._targets or {}
M._inited  = M._inited or false

function M:Init()
    if self._inited then return end
    self._inited = true

    -- 1. Standard
    if not self._fonts["Default"] then
        self._fonts["Default"] = DefaultFontPath()
    end

    -- 2. Lokale fonter
    for name, path in pairs(LocalFonts) do
        self._fonts[name] = path
        if LSM then LSM:Register("font", name, path) end
    end

    -- 3. LibSharedMedia fonter
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            self._fonts[name] = LSM:Fetch("font", name)
        end
        LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType, key)
            if mediaType == "font" then
                self._fonts[key] = LSM:Fetch("font", key)
                if M.settingsFrame and M.settingsFrame:IsVisible() and M.settingsFrame.RefreshList then
                    M.settingsFrame.RefreshList()
                end
            end
        end)
    end
end

function M:GetFonts()
    self:Init()
    local out = {}
    for k in pairs(self._fonts) do out[#out+1] = k end
    table.sort(out)
    return out
end

function M:GetUseCustom()
    local db = GetDB()
    return db and db.useCustom or false
end

function M:SetUseCustom(v)
    local db = GetDB()
    if db then db.useCustom = (v == true) end
end

function M:GetFontKey()
    local db = GetDB()
    return db and db.fontKey or "Default"
end

function M:SetFontKey(key)
    local db = GetDB()
    if db then db.fontKey = key end
end

function M:GetActivePath()
    self:Init()
    local db = GetDB()
    
    if not db or not db.useCustom then
        return DefaultFontPath()
    end

    local p = self._fonts[db.fontKey]
    if type(p) ~= "string" or p == "" then
        return self._fonts["Default"] or DefaultFontPath()
    end

    return p
end

function M:ApplyFont(fs, size, flags)
    self:Init()
    if not (fs and fs.SetFont) then return end
    
    local path = self:GetActivePath()
    size  = tonumber(size) or 12
    flags = flags or ""
    
    local ok = pcall(fs.SetFont, fs, path, size, flags)
    if not ok then
        pcall(fs.SetFont, fs, DefaultFontPath(), size, flags)
    end
end

function M:RegisterTarget(fs, size, flags)
    self:Init()
    if not (fs and fs.SetFont and fs.GetFont) then return end

    if not size or not flags then
        local _, fontHeight, fontFlags = fs:GetFont()
        size = size or fontHeight or 12
        flags = flags or fontFlags or ""
    end
    
    self._targets[fs] = { size = size, flags = flags }
    self:ApplyFont(fs, size, flags)
end

function M:ApplyAll()
    self:Init()
    for fs, meta in pairs(self._targets) do
        if fs and fs.SetFont and meta then
            self:ApplyFont(fs, meta.size, meta.flags)
        else
            self._targets[fs] = nil
        end
    end
end

-- -----------------------------------------------------------------------------
-- GUI INTEGRATION (MASTER CONFIG)
-- -----------------------------------------------------------------------------

function M:CreateGUI()
    if M.settingsFrame then return M.settingsFrame end

    local f = CreateFrame("Frame", "RobUI_FontSettings", UIParent)
    f:SetSize(600, 500)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("Font Manager")

    -- Checkbox
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, -50)
    cb.Text:SetText("Enable Custom Font (Changes all registered texts)")
    cb:SetScript("OnClick", function(self)
        M:SetUseCustom(self:GetChecked())
        M:ApplyAll()
        if f.RefreshList then f.RefreshList() end
    end)
    f.cb = cb
    
    -- SEARCH BOX (Ny funksjon)
    local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchBox:SetSize(250, 20)
    searchBox:SetPoint("TOPLEFT", 20, -90)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(5, 5, 0, 0)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    
    local searchLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 2)
    searchLabel:SetText("Search Font:")

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetSize(400, 320)
    scroll:SetPoint("TOPLEFT", 20, -125)
    
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 500) 
    scroll:SetScrollChild(content)
    
    local bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", scroll, -5, 5)
    bg:SetPoint("BOTTOMRIGHT", scroll, 25, -5)
    bg:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1, bgFile="Interface\\Buttons\\WHITE8x8"})
    bg:SetBackdropColor(0, 0, 0, 0.3)
    bg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Oppdatert RefreshList med søk og gjenbruk av frames
    f.RefreshList = function()
        local searchTerm = searchBox:GetText():lower()
        local allFonts = M:GetFonts()
        local filteredFonts = {}

        -- Filtrering
        for _, name in ipairs(allFonts) do
            if searchTerm == "" or string.find(name:lower(), searchTerm, 1, true) then
                table.insert(filteredFonts, name)
            end
        end

        local y = -5
        local children = {content:GetChildren()}
        
        -- Skjul alle eksisterende knapper først (Frame pooling)
        for _, child in ipairs(children) do child:Hide() end

        if #filteredFonts == 0 then
            -- Valgfritt: Vis "Ingen treff" tekst her
            return
        end

        for i, fontName in ipairs(filteredFonts) do
            -- Gjenbruk knapp hvis den finnes, ellers lag ny
            local btn = children[i]
            if not btn then
                btn = CreateFrame("Button", nil, content, "BackdropTemplate")
                btn:SetSize(380, 30)
                btn:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
                
                local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                text:SetPoint("LEFT", 10, 0)
                btn.text = text
                
                btn:SetScript("OnEnter", function(self) 
                    if self.fontName ~= M:GetFontKey() then self:SetBackdropColor(0.3, 0.3, 0.3, 0.5) end 
                end)
                btn:SetScript("OnLeave", function(self) 
                    if self.fontName ~= M:GetFontKey() then self:SetBackdropColor(0.1, 0.1, 0.1, 0.5) end 
                end)
                
                btn:SetScript("OnClick", function(self)
                    M:SetFontKey(self.fontName)
                    M:ApplyAll()
                    f.RefreshList()
                end)
            end
            
            -- Oppdater knappens data
            btn.fontName = fontName
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, y)
            btn:Show()

            -- Highlight logic
            if fontName == M:GetFontKey() then
                btn:SetBackdropColor(0.2, 0.6, 1, 0.5)
            else
                btn:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end
            
            -- Sett tekst og prøv å vise riktig font
            btn.text:SetText(fontName)
            local fontPath = M._fonts[fontName]
            if fontPath then
                local ok = pcall(btn.text.SetFont, btn.text, fontPath, 16, "OUTLINE")
                if not ok then btn.text:SetFontObject("GameFontHighlight") end
            else
                btn.text:SetFontObject("GameFontHighlight")
            end
            
            y = y - 32
        end
        content:SetHeight(math.abs(y) + 10)
    end

    -- Oppdater listen når man skriver
    searchBox:SetScript("OnTextChanged", function()
        f.RefreshList()
    end)

    f:SetScript("OnShow", function()
        local db = GetDB()
        if db then
            f.cb:SetChecked(db.useCustom)
            f.RefreshList()
        end
    end)

    M.settingsFrame = f
    
    if R.RegisterModulePanel then
        R:RegisterModulePanel("Fonts", f)
    end
    
    return f
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        M:Init()
        M:ApplyAll()
        M:CreateGUI()
    end)
end)