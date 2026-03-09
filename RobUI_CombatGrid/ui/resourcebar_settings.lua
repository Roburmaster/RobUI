-- ==========================================================================
-- resourcebar_settings.lua
-- Minimal standalone settings window for the Resource Bar
-- (Unified panel is in driver.lua; this is a quick /rbar helper.)
-- SavedVariables: (none) – uses RobUI profile via ns.DB (combatgrid.resourcebar)
-- Slash: /rbar
-- ==========================================================================

local AddonName, ns = ...
ns = _G[AddonName] or ns
_G[AddonName] = ns

local function GetCfg()
    if ns.DB and ns.DB.GetConfig then
        return ns.DB:GetConfig("resourcebar")
    end
    _G.rbardb = _G.rbardb or {}
    return _G.rbardb
end

local Settings = CreateFrame("Frame", "RobUI_ResourceBar_Settings", UIParent, "BackdropTemplate")
Settings:SetSize(320, 240)
Settings:SetPoint("CENTER")
Settings:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
Settings:SetBackdropColor(0, 0, 0, 0.9)
Settings:Hide()

Settings:SetMovable(true)
Settings:EnableMouse(true)
Settings:RegisterForDrag("LeftButton")
Settings:SetScript("OnDragStart", Settings.StartMoving)
Settings:SetScript("OnDragStop", Settings.StopMovingOrSizing)

local title = Settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("Resource Bar")

local close = CreateFrame("Button", nil, Settings, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)

local function Apply()
    if ns.ResourceBar and ns.ResourceBar.ApplyConfig then
        ns.ResourceBar:ApplyConfig()
    end
end

local lock = CreateFrame("CheckButton", nil, Settings, "UICheckButtonTemplate")
lock:SetPoint("TOPLEFT", 16, -44)
lock.text:SetText("Lock")
lock:SetScript("OnClick", function(self)
    local cfg = GetCfg()
    cfg.locked = self:GetChecked() and true or false
    Apply()
end)

local textCheck = CreateFrame("CheckButton", nil, Settings, "UICheckButtonTemplate")
textCheck:SetPoint("TOPLEFT", 16, -72)
textCheck.text:SetText("Show Text")
textCheck:SetScript("OnClick", function(self)
    local cfg = GetCfg()
    cfg.showText = self:GetChecked() and true or false
    Apply()
end)

local widthSlider = CreateFrame("Slider", "RobUI_RBarWidthSlider", Settings, "OptionsSliderTemplate")
widthSlider:SetPoint("TOPLEFT", 16, -120)
widthSlider:SetMinMaxValues(100, 600)
widthSlider:SetValueStep(10)
widthSlider:SetObeyStepOnDrag(true)
widthSlider:SetWidth(240)
_G[widthSlider:GetName() .. "Low"]:SetText("100")
_G[widthSlider:GetName() .. "High"]:SetText("600")
_G[widthSlider:GetName() .. "Text"]:SetText("Width")
widthSlider:SetScript("OnValueChanged", function(_, value)
    local cfg = GetCfg()
    cfg.width = math.floor((tonumber(value) or 260) + 0.5)
    Apply()
end)

local heightSlider = CreateFrame("Slider", "RobUI_RBarHeightSlider", Settings, "OptionsSliderTemplate")
heightSlider:SetPoint("TOPLEFT", 16, -170)
heightSlider:SetMinMaxValues(10, 48)
heightSlider:SetValueStep(1)
heightSlider:SetObeyStepOnDrag(true)
heightSlider:SetWidth(240)
_G[heightSlider:GetName() .. "Low"]:SetText("10")
_G[heightSlider:GetName() .. "High"]:SetText("48")
_G[heightSlider:GetName() .. "Text"]:SetText("Height")
heightSlider:SetScript("OnValueChanged", function(_, value)
    local cfg = GetCfg()
    cfg.height = math.floor((tonumber(value) or 18) + 0.5)
    Apply()
end)

local enable = CreateFrame("CheckButton", nil, Settings, "UICheckButtonTemplate")
enable:SetPoint("TOPLEFT", 170, -44)
enable.text:SetText("Enabled")
enable:SetScript("OnClick", function(self)
    local cfg = GetCfg()
    cfg.enabled = self:GetChecked() and true or false
    Apply()
end)

local reset = CreateFrame("Button", nil, Settings, "UIPanelButtonTemplate")
reset:SetSize(120, 24)
reset:SetPoint("BOTTOMLEFT", 16, 14)
reset:SetText("Reset Position")
reset:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    local cfg = GetCfg()
    cfg.point = "CENTER"; cfg.relPoint = "CENTER"; cfg.x = 0; cfg.y = -200
    Apply()
end)

local exitBtn = CreateFrame("Button", nil, Settings, "UIPanelButtonTemplate")
exitBtn:SetSize(90, 24)
exitBtn:SetPoint("BOTTOMRIGHT", -16, 14)
exitBtn:SetText("Close")
exitBtn:SetScript("OnClick", function() Settings:Hide() end)

Settings:SetScript("OnShow", function()
    local cfg = GetCfg()
    enable:SetChecked(cfg.enabled and true or false)
    lock:SetChecked(cfg.locked and true or false)
    textCheck:SetChecked(cfg.showText and true or false)
    widthSlider:SetValue(tonumber(cfg.width) or 260)
    heightSlider:SetValue(tonumber(cfg.height) or 18)
end)

SLASH_RBAR1 = "/rbar"
SlashCmdList["RBAR"] = function()
    Settings:SetShown(not Settings:IsShown())
end
