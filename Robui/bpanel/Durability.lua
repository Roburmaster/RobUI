-- BPanel/Durability.lua (Tidligere durav2.lua)
-- Visuals: Shield Icon, Colored Text based on %, Detailed Tooltip
-- Logic: Integrert med RobuiDB

local AddonName, ns = ...
local R = _G.Robui
local Mod = {}

-- 1. HELPER FUNCTIONS
local function Print(msg)
    print("|cff00b3ff[RobUI]|r " .. tostring(msg))
end

local function GetCfg()
    if R.Database and R.Database.profile and R.Database.profile.datapanel then
        return R.Database.profile.datapanel.durability
    end
    -- Fallback
    return { 
        enabled = true, 
        point = "BOTTOMLEFT", x = 120, y = 30, 
        locked = false, 
        autoHide = true 
    }
end

local function SaveMaybe()
    -- RobuiDB lagrer automatisk
end

-- 2. CONSTANTS & LOGIC
local slots = {
    { id = INVSLOT_HEAD, name = HEADSLOT },
    { id = INVSLOT_SHOULDER, name = SHOULDERSLOT },
    { id = INVSLOT_CHEST, name = CHESTSLOT },
    { id = INVSLOT_WAIST, name = WAISTSLOT },
    { id = INVSLOT_LEGS, name = LEGSSLOT },
    { id = INVSLOT_FEET, name = FEETSLOT },
    { id = INVSLOT_WRIST, name = WRISTSLOT },
    { id = INVSLOT_HAND, name = HANDSLOT },
    { id = INVSLOT_MAINHAND, name = MAINHANDSLOT },
    { id = INVSLOT_OFFHAND, name = OFFHANDSLOT },
}

local function GetDuraColor(perc)
    if perc > 80 then return "|cff00ff00" -- Green
    elseif perc > 50 then return "|cffffff00" -- Yellow
    elseif perc > 20 then return "|cffff8000" -- Orange
    else return "|cffff0000" end -- Red
end

local function ComputeDurability()
    local curSum, maxSum = 0, 0
    local itemsFound = 0
    for _, info in ipairs(slots) do
        local cur, mx = GetInventoryItemDurability(info.id)
        if cur and mx then
            curSum = curSum + cur
            maxSum = maxSum + mx
            itemsFound = itemsFound + 1
        end
    end
    local perc = (maxSum > 0) and math.floor((curSum / maxSum) * 100 + 0.5) or 100
    return perc, itemsFound
end

-- 3. INITIALIZATION
function Mod:Initialize()
    local db = GetCfg()
    if not db.enabled then return end
    if self.frame then return end

    -- Create Frame
    local f = CreateFrame("Frame", "RobUIDurabilityFrame", UIParent, "BackdropTemplate")
    self.frame = f
    
    f:SetSize(100, 26) -- Standard size
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("HIGH")

    -- Apply Position
    f:ClearAllPoints()
    if db.point then
        f:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 120, 30)
    end

    -- Visual Style (Backdrop)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Icon
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\Icons\\INV_Shield_04")
    icon:SetDesaturated(true)
    f.icon = icon

    -- Text
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    f.text = text

    -- Update Logic
    local function UpdateText()
        local perc, count = ComputeDurability()
        
        if count == 0 then
            f:SetAlpha(0) -- Hide if no gear
        elseif db.autoHide and perc == 100 then
            f:SetAlpha(0) -- Hide at 100% if autoHide is on
        else
            f:SetAlpha(1)
            f.text:SetText(GetDuraColor(perc) .. perc .. "%|r")
        end
    end

    -- Loop (Interval 1 sec)
    f:SetScript("OnUpdate", function(self, elapsed)
        self.__t = (self.__t or 0) + elapsed
        if self.__t >= 1 then
            UpdateText()
            self.__t = 0
        end
    end)

    -- Drag Logic
    f:SetScript("OnDragStart", function()
        if not db.locked and IsShiftKeyDown() then f:StartMoving() end
    end)
    
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        db.point = p
        db.x = math.floor(x + 0.5)
        db.y = math.floor(y + 0.5)
        SaveMaybe()
    end)

    -- Tooltip
    f:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f, "ANCHOR_TOPLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Durability Status", 0, 1, 0)
        GameTooltip:AddLine(" ")

        for _, info in ipairs(slots) do
            local cur, mx = GetInventoryItemDurability(info.id)
            if cur and mx then
                local perc = math.floor(cur / mx * 100 + 0.5)
                local link = GetInventoryItemLink("player", info.id)
                if link then
                    local itemName, _, quality = GetItemInfo(link)
                    local r, g, b = GetItemQualityColor(quality)
                    local iconTex = GetInventoryItemTexture("player", info.id)
                    GameTooltip:AddDoubleLine("|T"..iconTex..":14:14:0:0:64:64:4:60:4:60|t " .. itemName, GetDuraColor(perc) .. perc .. "%", r, g, b)
                end
            end
        end
        GameTooltip:AddLine(" ")
        if not db.locked then
            GameTooltip:AddLine("|cff888888Shift-Drag to move|r")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    
    -- Initial Update
    UpdateText()
    
    -- 4. SETTINGS FRAME (Popup)
    function Mod:CreateSettingsFrame()
        if self.settingsFrame then return self.settingsFrame end
        
        local f = CreateFrame("Frame", "RobUIDurabilitySettings", UIParent, "BackdropTemplate")
        self.settingsFrame = f
        
        f:SetSize(300, 200)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", 
            tile=true, tileSize=16, edgeSize=12, 
            insets={left=3,right=3,top=3,bottom=3}
        })
        f:SetBackdropColor(0,0,0,0.9)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:Hide()

        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -10)
        t:SetText("Durability Settings")

        local function QuickBtn(name, x, y, func)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(80, 22)
            b:SetPoint("TOPLEFT", x, y)
            b:SetText(name)
            b:SetScript("OnClick", func)
            return b
        end

        QuickBtn("Lock", 20, -40, function() db.locked = true; Print("Locked") end)
        QuickBtn("Unlock", 110, -40, function() db.locked = false; Print("Unlocked (Shift-Drag)") end)
        
        QuickBtn("Show", 20, -70, function() 
            db.autoHide = false 
            UpdateText() 
            Print("Auto-Hide Disabled (Always Shown)") 
        end)
        
        QuickBtn("Auto-Hide", 110, -70, function() 
            db.autoHide = true 
            UpdateText() 
            Print("Auto-Hide Enabled (Hidden at 100%)") 
        end)
        
        QuickBtn("Reset Pos", 200, -40, function() 
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 120, 30)
            db.point, db.x, db.y = "BOTTOMLEFT", 120, 30
            Print("Position Reset") 
        end)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
    end
    
    -- 5. SLASH COMMANDS
    SLASH_DURAV21 = "/durav2"
    SlashCmdList["DURAV2"] = function()
        if Mod.frame then Mod.frame:SetShown(not Mod.frame:IsShown()) end
    end

    SLASH_DURAV2SET1 = "/durav2set"
    SlashCmdList["DURAV2SET"] = function()
        Mod:CreateSettingsFrame()
        Mod.settingsFrame:SetShown(not Mod.settingsFrame:IsShown())
    end
end

-- Hook into BPanel
if R.BPanel then
    hooksecurefunc(R.BPanel, "Initialize", function() 
        Mod:Initialize() 
    end)
end