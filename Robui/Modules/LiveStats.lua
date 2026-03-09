-- Modules/LiveStats.lua
local ADDON_NAME, ns = ...
local R = _G.Robui
ns.livestats = ns.livestats or {}
local M = ns.livestats

local DEFAULT_COLORS = {
    Crit        = { r=0.80, g=0.20, b=0.20 },
    Haste       = { r=0.20, g=0.80, b=0.20 },
    Mastery     = { r=0.20, g=0.60, b=0.95 },
    Versatility = { r=0.85, g=0.65, b=0.10 },
    Leech       = { r=0.35, g=0.85, b=0.85 },
    Avoidance   = { r=0.75, g=0.55, b=0.90 },
    Speed       = { r=0.95, g=0.50, b=0.25 },
    Dodge       = { r=0.55, g=0.85, b=0.55 },
    Parry       = { r=0.85, g=0.55, b=0.55 },
    Strength    = { r=0.90, g=0.25, b=0.40 },
    Stamina     = { r=0.20, g=0.60, b=0.80 },
    Armor       = { r=0.50, g=0.60, b=0.70 },
    Agility     = { r=0.30, g=0.80, b=0.50 },
    Intellect   = { r=0.60, g=0.40, b=0.95 },
}

local ORDER = {
    "Crit","Haste","Mastery","Versatility","Leech",
    "Avoidance","Speed","Dodge","Parry",
    "Strength","Stamina","Armor","Agility","Intellect"
}

-- Safe DB Access
local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.livestats then
        return R.Database.profile.livestats
    end
    return nil
end

local function GetStatValue(stat)
    if stat == "Crit"        then return GetCritChance(), "Crit: %.2f%%", true
    elseif stat == "Haste"   then return GetHaste(), "Haste: %.2f%%", true
    elseif stat == "Mastery" then return GetMasteryEffect(), "Mast: %.2f%%", true
    elseif stat == "Versatility" then return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE), "Vers: %.2f%%", true
    elseif stat == "Leech"     then return GetLifesteal(), "Leech: %.2f%%", true
    elseif stat == "Avoidance" then return GetAvoidance(), "Avoid: %.2f%%", true
    elseif stat == "Speed"     then return GetCombatRatingBonus(CR_SPEED), "Speed: %.2f%%", true
    elseif stat == "Dodge"     then return GetDodgeChance(), "Dodge: %.2f%%", true
    elseif stat == "Parry"     then return GetParryChance(), "Parry: %.2f%%", true
    elseif stat == "Strength"  then local _, e = UnitStat("player", 1); return e, "STR: %d", false
    elseif stat == "Agility"   then local _, e = UnitStat("player", 2); return e, "AGI: %d", false
    elseif stat == "Stamina"   then local _, e = UnitStat("player", 3); return e, "STA: %d", false
    elseif stat == "Intellect" then local _, e = UnitStat("player", 4); return e, "INT: %d", false
    elseif stat == "Armor"     then local _, e = UnitArmor("player"); return e, "Armor: %d", false
    end
    return 0, stat..": %s", false
end

function M:RefreshLayout()
    if not self.frame then return end
    local db = GetDB()
    if not db then return end

    if not db.enabled then 
        self.frame:Hide()
        return 
    end
    
    self.frame:Show()

    local textWidth = 100 
    local rowW = db.barWidth + textWidth + 15
    local rowH = db.barHeight + 4
    local shownCount = 0

    for _, stat in ipairs(ORDER) do
        local row = self.frame.rows[stat]
        if db.stats[stat] then
            if not row then
                row = CreateFrame("Frame", nil, self.frame)
                -- Text
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 5, 0)
                row.text:SetWidth(textWidth)
                row.text:SetJustifyH("LEFT")
                -- Bar
                row.bar = CreateFrame("StatusBar", nil, row, "BackdropTemplate")
                row.bar:SetPoint("RIGHT", -5, 0)
                row.bar:SetStatusBarTexture(db.barTexture or "Interface\\Buttons\\WHITE8x8")
                row.bar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
                row.bar:SetBackdropColor(0, 0, 0, 0.5)
                self.frame.rows[stat] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 5, -5 - (shownCount * rowH))
            row:SetSize(rowW, rowH)

            row.bar:SetSize(db.barWidth, db.barHeight)
            local c = db.colors[stat] or DEFAULT_COLORS[stat]
            row.bar:SetStatusBarColor(c.r, c.g, c.b)
            row.bar:SetShown(db.showBars)

            row:Show()
            shownCount = shownCount + 1
        elseif row then
            row:Hide()
        end
    end
    self.frame:SetSize(rowW + 10, (shownCount * rowH) + 10)
end

function M:UpdateAll()
    if not self.frame or not self.frame:IsShown() then return end
    for stat, row in pairs(self.frame.rows) do
        if row:IsShown() then
            local val, fmt, isPercent = GetStatValue(stat)
            row.text:SetText(fmt:format(val))

            if isPercent then
                row.bar:SetMinMaxValues(0, 100)
                row.bar:SetValue(math.max(0.1, math.min(val, 100)))
            else
                local _, maxV = row.bar:GetMinMaxValues()
                if val > maxV then row.bar:SetMinMaxValues(0, val * 1.2) end
                row.bar:SetValue(val)
            end
        end
    end
end

function M:CreateSettingsFrame()
    if self.settingsFrame then return self.settingsFrame end
    
    local f = CreateFrame("Frame", "RobUILiveStatsConfig", UIParent)
    self.settingsFrame = f
    f:SetSize(300, 480)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("LiveStats Config")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -50)
    scroll:SetPoint("BOTTOMRIGHT", -30, 20)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(240, 1)
    scroll:SetScrollChild(content)

    -- Enable Checkbox
    local cbEnable = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", 0, 0)
    cbEnable.Text:SetText("Enable Module")
    cbEnable:SetScript("OnClick", function(s) 
        local db = GetDB(); if db then db.enabled = s:GetChecked(); M:RefreshLayout() end
    end)
    -- Hook OnShow to update state
    f:HookScript("OnShow", function() 
        local db = GetDB(); if db then cbEnable:SetChecked(db.enabled) end 
    end)

    local y = -30
    for _, stat in ipairs(ORDER) do
        local r = CreateFrame("Frame", nil, content)
        r:SetSize(240, 26)
        r:SetPoint("TOPLEFT", 0, y)

        local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", 0, 0)
        cb.Text:SetText(stat)
        cb:SetScript("OnClick", function(s) 
            local db = GetDB(); if db then db.stats[stat] = s:GetChecked(); M:RefreshLayout() end
        end)
        -- Hook update
        r:SetScript("OnShow", function()
            local db = GetDB(); if db then cb:SetChecked(db.stats[stat]) end
        end)

        -- Color Picker Button
        local cp = CreateFrame("Button", nil, r)
        cp:SetSize(16, 16)
        cp:SetPoint("RIGHT", -5, 0)
        local t = cp:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        
        -- Color update logic
        r:HookScript("OnShow", function()
            local db = GetDB()
            if db then
                local c = db.colors[stat]
                t:SetColorTexture(c.r, c.g, c.b)
            end
        end)

        cp:SetScript("OnClick", function()
            local db = GetDB()
            if not db then return end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = db.colors[stat].r, g = db.colors[stat].g, b = db.colors[stat].b,
                swatchFunc = function()
                    local r,g,b = ColorPickerFrame:GetColorRGB()
                    db.colors[stat] = {r=r, g=g, b=b}
                    t:SetColorTexture(r,g,b)
                    M:RefreshLayout()
                end,
            })
        end)
        
        y = y - 28
    end
    content:SetHeight(math.abs(y) + 50)

    if R.RegisterModulePanel then
        R:RegisterModulePanel("LiveStats", f)
    end
    return f
end

function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    
    local db = GetDB()
    if not db then return end -- wait for DB

    if not self.frame then
        local f = CreateFrame("Frame", "RobUILiveStatsFrame", UIParent, "BackdropTemplate")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(s)
            s:StopMovingOrSizing()
            local p, _, rp, x, y = s:GetPoint()
            db.point, db.x, db.y = p, x, y
        end)
        f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        f:SetBackdropColor(0,0,0,0.6)
        f.rows = {}
        self.frame = f
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.point or "TOPLEFT", UIParent, db.point or "TOPLEFT", db.x or 20, db.y or -200)
    
    self:RefreshLayout()
    self:CreateSettingsFrame()
    
    if not self.ticker then
        self.ticker = C_Timer.NewTicker(0.5, function() self:UpdateAll() end)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() 
    C_Timer.After(1, function() M:Initialize() end)
end)