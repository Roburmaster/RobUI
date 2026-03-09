local AddonName, ns = ...
_G["Robui"] = ns
local R = ns

-- 1. MODULE REGISTRY & EVENTS
R.ModulePanels = {} 
R.ModuleOrder = {}

-- Update Placeholders (Modules will overwrite these)
R.UpdateActionBars = function() end
R.UpdateDataModules = function() end

function R:RegisterModulePanel(name, frame)
    if not name or not frame then return end
    R.ModulePanels[name] = frame
    frame:Hide()
    
    local exists = false
    for _, v in ipairs(R.ModuleOrder) do
        if v == name then exists = true break end
    end
    if not exists then
        table.insert(R.ModuleOrder, name)
        table.sort(R.ModuleOrder)
    end
end

-- 2. SHARED COLORS
R.Colors = {
    bg      = {0.1, 0.1, 0.1, 0.95},
    border  = {0, 0, 0, 1},
    header  = {0.15, 0.15, 0.15, 1},
    hover   = {0.2, 0.2, 0.2, 1},
    blue    = {0, 0.7, 1, 1},
    red     = {0.8, 0.1, 0.1, 1},
    green   = {0.1, 0.8, 0.1, 1},
    gold    = {1, 0.82, 0, 1},
}

-- 3. API
function R:CreateBackdrop(f)
    if not f then return end
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(unpack(R.Colors.bg))
    f:SetBackdropBorderColor(unpack(R.Colors.border))
end

-- 4. INITIALIZATION
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if R.Database then R.Database:Initialize() end
        print("|cff00b3ffRobui|r initialized. Type /robui to configure.")
        self:UnregisterEvent("ADDON_LOADED")
        
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if R.Database then R.Database:HandleSpecSwitch() end
    end
end)

-- 5. SLASH COMMANDS
SLASH_ROBUI1 = "/robui"
SLASH_ROBUI2 = "/rb"
SlashCmdList["ROBUI"] = function()
    if R.MasterConfig then R.MasterConfig:Toggle() end
end