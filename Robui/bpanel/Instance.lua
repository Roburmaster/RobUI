local AddonName, ns = ...
local R = _G.Robui
local Mod = {}

-- 1. CONFIGURATION HELPERS
local function GetCfg()
    if R.Database and R.Database.profile and R.Database.profile.datapanel then
        return R.Database.profile.datapanel.instance
    end
    -- Fallback defaults (Midtstilt og synlig)
    return { enabled = true, point = "CENTER", x = 0, y = 0, locked = false }
end

local function SaveMaybe()
    -- RobuiDB lagrer automatisk
end

-- 2. VISUAL CONSTANTS
local Colors = {
    bg = {0.05, 0.05, 0.05, 0.95},
    border = {0.3, 0.3, 0.3, 1},
    hover = {0.2, 0.5, 0.8, 0.8},
    label = {1, 0.82, 0},         -- Gold
    value = {0, 1, 1},            -- Bright Cyan
    selection = {0.9, 0.9, 0.9},  -- Off-white
    active = {0, 1, 0.5},         -- Mint green
}

-- 3. NUDGE FUNCTION
function Mod:Nudge(dx, dy)
    local db = GetCfg()
    db.x = (db.x or 0) + dx
    db.y = (db.y or 0) + dy
    
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end
    SaveMaybe()
end

function Mod:Initialize()
    local db = GetCfg()
    -- VIKTIG: Vi fjerner 'if not db.enabled then return end' her.
    -- Rammen må opprettes for at vi skal kunne slå den på senere uten reload.
    
    if self.frame then return end

    -- 4. MAIN ANCHOR FRAME
    local mainFrame = CreateFrame("Frame", "RobUIInstanceSwitcherFrame", UIParent, "BackdropTemplate")
    self.frame = mainFrame
    
    mainFrame:SetSize(240, 30)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")

    -- Apply Saved Position (Defaults to CENTER)
    mainFrame:ClearAllPoints()
    if db.point then
        mainFrame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    else
        -- Force Center if no data
        db.point = "CENTER"
        db.x = 0
        db.y = 0
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Visibility Check
    if db.enabled then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end

    -- Logic for saving position via Drag
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        db.point = point
        db.x = xOfs
        db.y = yOfs
        SaveMaybe()
    end)
    mainFrame:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not db.locked then mainFrame:StartMoving() end
    end)

    mainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.3)
    mainFrame:SetBackdropBorderColor(0, 0, 0, 0)
    
    -- Tooltip
    mainFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Instance Difficulty")
        if not db.locked then
            GameTooltip:AddLine("Shift+Drag to move", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    mainFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Update Function Declaration
    local UpdateAll

    -- 5. DROPDOWN CREATION FUNCTION
    local function CreateMiniDropdown(label, options, xOffset)
        local btn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
        btn:SetSize(75, 22)
        btn:SetPoint("LEFT", mainFrame, "LEFT", xOffset, 0)
        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(unpack(Colors.bg))
        btn:SetBackdropBorderColor(unpack(Colors.border))

        -- Header label (Gold)
        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetScale(0.75)
        title:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 2, 2)
        title:SetText(label)
        title:SetTextColor(unpack(Colors.label))

        -- Main Display Text
        local valText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valText:SetScale(0.85)
        valText:SetPoint("CENTER", 0, 0)
        valText:SetTextColor(unpack(Colors.value))
        valText:SetShadowColor(0, 0, 0, 1)
        valText:SetShadowOffset(1, -1)

        -- Menu frame
        local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        menu:SetSize(85, #options * 20 + 6)
        menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 12)
        menu:SetBackdrop(btn:GetBackdrop())
        menu:SetBackdropColor(unpack(Colors.bg))
        menu:SetBackdropBorderColor(unpack(Colors.border))
        menu:SetFrameStrata("TOOLTIP")
        menu:Hide()

        btn:SetScript("OnClick", function()
            if menu:IsShown() then menu:Hide() else menu:Show() end
        end)

        local menuButtons = {}
        for i, opt in ipairs(options) do
            local mBtn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            mBtn:SetSize(77, 18)
            mBtn:SetPoint("BOTTOM", 0, 3 + ((i-1) * 19))

            local mText = mBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mText:SetScale(0.85)
            mText:SetPoint("LEFT", 6, 0)
            mText:SetText(opt.name)
            mText:SetTextColor(unpack(Colors.selection))
            mText:SetShadowOffset(1, -1)

            mBtn:SetScript("OnEnter", function(self)
                self:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
                self:SetBackdropColor(unpack(Colors.hover))
                mText:SetTextColor(1, 1, 1)
            end)
            mBtn:SetScript("OnLeave", function(self)
                self:SetBackdrop(nil)
                UpdateAll()
            end)

            mBtn:SetScript("OnClick", function()
                if InCombatLockdown() then return end
                if opt.type == "dungeon" then SetDungeonDifficultyID(opt.id)
                elseif opt.type == "raid" then SetRaidDifficultyID(opt.id)
                elseif opt.type == "legacy" then SetLegacyRaidDifficultyID(opt.id) end
                menu:Hide()
            end)

            mBtn.text = mText
            mBtn.opt = opt
            table.insert(menuButtons, mBtn)
        end

        btn.valText = valText
        btn.menuButtons = menuButtons
        return btn
    end

    -- 6. DATA INITIALIZATION
    local dungeonDD = CreateMiniDropdown("DUNGEON", {
        {name = "Normal", id = 1, type = "dungeon"},
        {name = "Heroic", id = 2, type = "dungeon"},
        {name = "Mythic", id = 23, type = "dungeon"},
    }, 5)

    local raidDD = CreateMiniDropdown("RAID", {
        {name = "Normal", id = 14, type = "raid"},
        {name = "Heroic", id = 15, type = "raid"},
        {name = "Mythic", id = 16, type = "raid"},
    }, 83)

    local legacyDD = CreateMiniDropdown("LEGACY", {
        {name = "10N", id = 3, type = "legacy"},
        {name = "25N", id = 4, type = "legacy"},
        {name = "10H", id = 5, type = "legacy"},
        {name = "25H", id = 6, type = "legacy"},
    }, 161)

    -- 7. UPDATE ALL DISPLAYS
    UpdateAll = function()
        local curD = GetDungeonDifficultyID()
        local curR = GetRaidDifficultyID()
        local curL = GetLegacyRaidDifficultyID()

        local dName = GetDifficultyInfo(curD)
        local rName = GetDifficultyInfo(curR)
        local lName = (curL == 3 and "10N") or (curL == 4 and "25N") or (curL == 5 and "10H") or (curL == 6 and "25H") or "-"

        dungeonDD.valText:SetText(dName or "Normal")
        raidDD.valText:SetText(rName or "Normal")
        legacyDD.valText:SetText(lName)

        local dropdowns = {dungeonDD, raidDD, legacyDD}
        local currents = {curD, curR, curL}

        for i, dd in ipairs(dropdowns) do
            for _, mBtn in ipairs(dd.menuButtons) do
                if mBtn.opt.id == currents[i] then
                    mBtn.text:SetTextColor(unpack(Colors.active))
                else
                    mBtn.text:SetTextColor(unpack(Colors.selection))
                end
            end
        end
    end

    -- 8. EVENT REGISTRATION
    mainFrame:SetScript("OnEvent", function(self, event, arg1)
        UpdateAll()
    end)
    mainFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    UpdateAll()
    
    -- 9. SETTINGS FRAME (Popup with Nudge)
    function Mod:CreateSettingsFrame()
        if self.settingsFrame then return self.settingsFrame end
        
        local f = CreateFrame("Frame", "RobUIInstanceSettings", UIParent, "BackdropTemplate")
        f:SetSize(300, 240)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:Hide()
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Instance Tool Settings")
        
        local function CreateBtn(label, w, x, y, func)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(w, 22)
            b:SetPoint("TOPLEFT", x, y)
            b:SetText(label)
            b:SetScript("OnClick", func)
            return b
        end
        
        -- Visibility
        CreateBtn("Show", 80, 20, -50, function() 
            db.enabled = true
            mainFrame:Show()
            print("Instance Tool: Shown")
        end)
        
        CreateBtn("Hide", 80, 110, -50, function() 
            db.enabled = false
            mainFrame:Hide()
            print("Instance Tool: Hidden")
        end)
        
        -- Locking
        CreateBtn("Lock", 80, 20, -80, function() 
            db.locked = true
            print("Instance Tool: Locked")
        end)
        
        CreateBtn("Unlock", 80, 110, -80, function() 
            db.locked = false
            print("Instance Tool: Unlocked")
        end)
        
        -- Nudge Controls (Arrows)
        local function CreateNudgeBtn(label, x, y, dx, dy)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(28, 22)
            b:SetPoint("TOPLEFT", x, y)
            b:SetText(label)
            b:SetScript("OnClick", function() Mod:Nudge(dx, dy) end)
            return b
        end
        
        -- Positioning Controls
        CreateNudgeBtn("↑", 135, -120,  0,  1)
        CreateNudgeBtn("↓", 135, -150,  0, -1)
        CreateNudgeBtn("←", 105, -150, -1,  0)
        CreateNudgeBtn("→", 165, -150,  1,  0)
        
        -- Reset
        CreateBtn("Reset Position", 140, 80, -190, function() 
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER")
            db.point = "CENTER"
            db.x = 0
            db.y = 0
            print("Instance Tool: Position Reset to Center")
        end)
        
        -- Close
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        
        self.settingsFrame = f
        return f
    end

    -- 10. SLASH COMMAND
    SLASH_INSTSET1 = "/inst"
    SLASH_INSTSET2 = "/instset"
    SlashCmdList.INSTSET = function()
        local f = Mod:CreateSettingsFrame()
        if f:IsShown() then f:Hide() else f:Show() end
    end
end

-- Hook into BPanel initialization
if R.BPanel then
    hooksecurefunc(R.BPanel, "Initialize", function() 
        Mod:Initialize() 
    end)
end