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
        if v == name then
            exists = true
            break
        end
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
    if not f.SetBackdrop then
        Mixin(f, BackdropTemplateMixin)
    end

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(unpack(R.Colors.bg))
    f:SetBackdropBorderColor(unpack(R.Colors.border))
end

-- 4. MAIN UNIT FRAME SCALE
function R:GetMainUnitFrameScale()
    local scale = 1

    if self.Database
        and self.Database.profile
        and self.Database.profile.general
        and self.Database.profile.general.unitFrameScale
    then
        scale = tonumber(self.Database.profile.general.unitFrameScale) or 1
    end

    if scale < 0.50 then scale = 0.50 end
    if scale > 2.00 then scale = 2.00 end

    return scale
end

function R:ApplyMainUnitFrameScale()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local scale = self:GetMainUnitFrameScale()

    if self.PlayerFrame and self.PlayerFrame.SetScale then
        self.PlayerFrame:SetScale(scale)
    end

    if self.TargetFrame and self.TargetFrame.SetScale then
        self.TargetFrame:SetScale(scale)
    end

    if self.TargetTargetFrame and self.TargetTargetFrame.SetScale then
        self.TargetTargetFrame:SetScale(scale)
    end

    if self.FocusFrame and self.FocusFrame.SetScale then
        self.FocusFrame:SetScale(scale)
    end

    if self.PetFrame and self.PetFrame.SetScale then
        self.PetFrame:SetScale(scale)
    end
end

function R:ApplyMainUnitFrameScaleDeferred()
    self:ApplyMainUnitFrameScale()

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            if R and R.ApplyMainUnitFrameScale then
                R:ApplyMainUnitFrameScale()
            end
        end)

        C_Timer.After(1.0, function()
            if R and R.ApplyMainUnitFrameScale then
                R:ApplyMainUnitFrameScale()
            end
        end)
    end
end

-- 5. INITIALIZATION
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if R.Database then
            R.Database:Initialize()
        end

        print("|cff00b3ffRobui|r initialized. Type /robui to configure.")
        R:ApplyMainUnitFrameScaleDeferred()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        R:ApplyMainUnitFrameScaleDeferred()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if R.Database then
            R.Database:HandleSpecSwitch()
        end

        R:ApplyMainUnitFrameScaleDeferred()

    elseif event == "PLAYER_REGEN_ENABLED" then
        R:ApplyMainUnitFrameScaleDeferred()
    end
end)

-- 6. SLASH COMMANDS
SLASH_ROBUI1 = "/robui"
SLASH_ROBUI2 = "/rb"
SlashCmdList["ROBUI"] = function()
    if R.MasterConfig then
        R.MasterConfig:Toggle()
    end
end
