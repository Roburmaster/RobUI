-- ============================================================================
-- override.lua (ctDB) - Setup Wizard & Simple overrides
-- Includes:
--  - Setup Wizard (Intro, Rotation Helper, Combat Grid)
--  - Player frame (ct_player): ctDB.player.shown
--  - Target frame (ct_target): ctDB.target.shown
--  - PIC Incoming Casts: RobUIIncomingCastDB.enabled
--
-- Slash:
--   /robsetup   - Starts the first-time setup wizard
--   /ctoverride - Opens the Overrides frame
--   /ors        - Opens the Overrides frame directly (Setup Step 4)
-- ============================================================================
local AddonName, ns = ...
ns = _G[AddonName] or ns or {}
_G[AddonName] = ns

local CreateFrame = CreateFrame
local UIParent = UIParent
local type = type
local wipe = wipe
local ReloadUI = ReloadUI
local tinsert = tinsert
local C_Timer = C_Timer

-- Safe fallback for modern WoW (Retail) and older clients (Classic)
local EnableAddOn = C_AddOns and C_AddOns.EnableAddOn or EnableAddOn
local DisableAddOn = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn

-- ============================================================================
-- DATABASE & APPLY FUNCTIONS
-- ============================================================================
local function EnsureCTDB()
    if ns.GetCTDB then ns.GetCTDB() end
    local ctDB = _G.ctDB
    if type(ctDB) ~= "table" then _G.ctDB = {}; ctDB = _G.ctDB end
    ctDB.player = ctDB.player or {}
    ctDB.target = ctDB.target or {}

    if ctDB.player.shown == nil then ctDB.player.shown = true end
    if ctDB.target.shown == nil then ctDB.target.shown = true end
    return ctDB
end

local function EnsurePICDB()
    if type(_G.RobUIIncomingCastDB) ~= "table" then
        _G.RobUIIncomingCastDB = {}
    end
    if _G.RobUIIncomingCastDB.enabled == nil then
        _G.RobUIIncomingCastDB.enabled = true
    end
    return _G.RobUIIncomingCastDB
end

local function EnsureSetupDB()
    if type(_G.RobUISetupDB) ~= "table" then
        _G.RobUISetupDB = {}
    end
    if _G.RobUISetupDB.hasRunSetup == nil then
        _G.RobUISetupDB.hasRunSetup = false
    end
    return _G.RobUISetupDB
end

local function ApplyPICNow()
    local picDB = EnsurePICDB()
    local M = ns.IncomingPlayerCasts

    if not (M and type(M) == "table") then return end

    if not picDB.enabled then
        if M.eventFrame then
            M.eventFrame:UnregisterAllEvents()
            M.eventFrame:Hide()
        end
        if M.ui and M.ui.holder then
            M.ui.holder:Hide()
        end
        if M.active then wipe(M.active) end
        if M.order then wipe(M.order) end
        return
    end

    if type(M.Enable) == "function" then
        M:Enable()
    end
end

local function ApplyNow()
    EnsureCTDB()
    EnsurePICDB()

    if ns.Player and ns.Player.root then
        ns.Player:ApplyLayout()
        ns.Player:ApplyVisibility()
        ns.Player:UpdateLockState()
        ns.Player:UpdateValues()
    end

    if ns.Target and ns.Target.root then
        ns.Target:ApplyLayout()
        ns.Target:ApplySecureVisibility()
        ns.Target:UpdateLockState()
        ns.Target:UpdateValues()
    end

    ApplyPICNow()
end

-- ============================================================================
-- UNIFIED FRAME (Setup & Overrides)
-- ============================================================================
local F

local function CreateUI()
    if F then return end

    local ctDB = EnsureCTDB()
    local picDB = EnsurePICDB()

    F = CreateFrame("Frame", "RobUI_MainFrame", UIParent, "BasicFrameTemplateWithInset")
    F:SetSize(300, 270)
    F:SetPoint("CENTER", 0, 50)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", F.StartMoving)
    F:SetScript("OnDragStop", F.StopMovingOrSizing)
    
    -- Allow closing with Escape key
    tinsert(UISpecialFrames, "RobUI_MainFrame")

    F.title = F:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    F.title:SetPoint("TOPLEFT", 12, -8)

    -- --- WIZARD ELEMENTS ---
    F.wizardText = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    F.wizardText:SetPoint("TOP", F, "TOP", 0, -50)
    F.wizardText:SetWidth(260)
    F.wizardText:SetWordWrap(true)

    F.btnNext = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    F.btnNext:SetSize(100, 25)
    F.btnNext:SetPoint("BOTTOM", F, "BOTTOM", 0, 20)
    F.btnNext:SetText("Next")

    F.btnYes = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    F.btnYes:SetSize(80, 25)
    F.btnYes:SetPoint("BOTTOMLEFT", F, "BOTTOM", -85, 20)
    F.btnYes:SetText("Yes")

    F.btnNo = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    F.btnNo:SetSize(80, 25)
    F.btnNo:SetPoint("BOTTOMRIGHT", F, "BOTTOM", 85, 20)
    F.btnNo:SetText("No")

    -- --- OVERRIDE ELEMENTS ---
    F.chkPlayer = CreateFrame("CheckButton", nil, F, "UICheckButtonTemplate")
    F.chkPlayer:SetPoint("TOPLEFT", 14, -36)
    F.chkPlayer.text:SetText("Enable Player Frame")
    F.chkPlayer:SetChecked(ctDB.player.shown and true or false)

    F.chkTarget = CreateFrame("CheckButton", nil, F, "UICheckButtonTemplate")
    F.chkTarget:SetPoint("TOPLEFT", 14, -64)
    F.chkTarget.text:SetText("Enable Target Frame")
    F.chkTarget:SetChecked(ctDB.target.shown and true or false)

    F.chkPIC = CreateFrame("CheckButton", nil, F, "UICheckButtonTemplate")
    F.chkPIC:SetPoint("TOPLEFT", 14, -92)
    F.chkPIC.text:SetText("Enable PIC (/pic)")
    F.chkPIC:SetChecked(picDB.enabled and true or false)

    F.note = F:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    F.note:SetPoint("TOPLEFT", 18, -126)
    F.note:SetJustifyH("LEFT")
    F.note:SetWidth(260)
    F.note:SetWordWrap(true)
    F.note:SetText("Disabled = fully hidden.\n\nPlayer and target frame need to be on to work correctly in the grid hud. You may open this window up at anytime with /ors as long as you have the sub addons on, if not you need to turn them on.")

    F.btnReload = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    F.btnReload:SetSize(120, 25)
    F.btnReload:SetPoint("BOTTOM", F, "BOTTOM", 0, 20)
    F.btnReload:SetText("Reload UI")

    -- --- BEHAVIORS ---
    F.chkPlayer:SetScript("OnClick", function(self)
        ctDB = EnsureCTDB()
        ctDB.player.shown = self:GetChecked() and true or false
        ApplyNow()
    end)

    F.chkTarget:SetScript("OnClick", function(self)
        ctDB = EnsureCTDB()
        ctDB.target.shown = self:GetChecked() and true or false
        ApplyNow()
    end)

    F.chkPIC:SetScript("OnClick", function(self)
        picDB = EnsurePICDB()
        picDB.enabled = self:GetChecked() and true or false
        ApplyNow()
    end)

    F.btnReload:SetScript("OnClick", function()
        ReloadUI()
    end)
end

-- ============================================================================
-- STEP CONTROLLER
-- ============================================================================
local function ShowStep(step)
    CreateUI()
    F:Show()
    F.currentStep = step

    -- Hide everything first to reset state
    F.wizardText:Hide()
    F.btnNext:Hide()
    F.btnYes:Hide()
    F.btnNo:Hide()
    F.chkPlayer:Hide()
    F.chkTarget:Hide()
    F.chkPIC:Hide()
    F.note:Hide()
    F.btnReload:Hide()

    if step == 1 then
        F.title:SetText("RobUI Setup")
        F.wizardText:SetText("Robui Combat Tool, grid and rotation helper.")
        F.wizardText:Show()
        F.btnNext:Show()

        F.btnNext:SetScript("OnClick", function() ShowStep(2) end)

    elseif step == 2 then
        F.title:SetText("RobUI Setup")
        F.wizardText:SetText("Do you want to use the new Rotation helper?")
        F.wizardText:Show()
        F.btnYes:Show()
        F.btnNo:Show()

        F.btnYes:SetScript("OnClick", function()
            EnableAddOn("RobUI_CombatAssistant") 
            print("|cff00ff00[RobUI]|r Rotation Helper will be ENABLED after reload.")
            ShowStep(3)
        end)
        F.btnNo:SetScript("OnClick", function()
            DisableAddOn("RobUI_CombatAssistant") 
            print("|cffff0000[RobUI]|r Rotation Helper will be DISABLED after reload.")
            ShowStep(3)
        end)

    elseif step == 3 then
        F.title:SetText("RobUI Setup")
        F.wizardText:SetText("Do you want to use the new combat grid system (hud)?")
        F.wizardText:Show()
        F.btnYes:Show()
        F.btnNo:Show()

        F.btnYes:SetScript("OnClick", function()
            EnableAddOn("RobUI_CombatGrid") 
            print("|cff00ff00[RobUI]|r Combat Grid will be ENABLED after reload.")
            ShowStep(4)
        end)
        F.btnNo:SetScript("OnClick", function()
            DisableAddOn("RobUI_CombatGrid") 
            print("|cffff0000[RobUI]|r Combat Grid will be DISABLED after reload.")
            ShowStep(4)
        end)

    elseif step == 4 then
        -- Setup is now complete
        local setupDB = EnsureSetupDB()
        setupDB.hasRunSetup = true

        F.title:SetText("Overrides")
        F.chkPlayer:Show()
        F.chkTarget:Show()
        F.chkPIC:Show()
        F.note:Show()
        F.btnReload:Show()
    end
end

-- ============================================================================
-- SLASH COMMANDS & AUTO-SHOW
-- ============================================================================
SLASH_ROBSETUP1 = "/robsetup"
SlashCmdList.ROBSETUP = function() ShowStep(1) end

SLASH_CTOVERRIDE1 = "/ctoverride"
SLASH_CTOVERRIDE2 = "/ors"
SlashCmdList.CTOVERRIDE = function() 
    if F and F:IsShown() and F.currentStep == 4 then
        F:Hide()
    else
        ShowStep(4) 
    end
end

-- Wait for variables and UI to fully load before checking
local loginCheck = CreateFrame("Frame")
loginCheck:RegisterEvent("PLAYER_ENTERING_WORLD")
loginCheck:SetScript("OnEvent", function(self, event, isInitialLogin, isReloading)
    local setupDB = EnsureSetupDB()
    if not setupDB.hasRunSetup then
        -- Adding a slight delay to ensure the UI is ready to show frames
        C_Timer.After(1, function()
            ShowStep(1)
        end)
    end
    self:UnregisterAllEvents()
end)