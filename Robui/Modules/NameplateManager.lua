local AddonName, ns = ...
local R = _G.Robui
local M = {}
ns.NameplateManager = M

-- Liste over støttede addons og hvordan de åpnes
local SUPPORTED_ADDONS = {
    ["Plater"] = {
        desc = "Advanced, highly customizable nameplates.",
        icon = "Interface\\AddOns\\Plater\\media\\texture_logo",
        openFunc = function()
            if SlashCmdList["PLATER"] then SlashCmdList["PLATER"]("") end
        end
    },
    ["Platynator"] = {
        desc = "Lightweight and clean nameplates.",
        openFunc = function()
            print("Use /platynator to configure.")
        end
    },
    ["Plate-o-Matic"] = {
        desc = "Integrated Quest & Progress plates (RobUI style).",
        openFunc = function()
            if _G.PlateOMatic_CreateConfig and R.MasterConfig then
                -- Denne håndteres av panelet
            elseif SlashCmdList["PLATEOMATIC"] then
                SlashCmdList["PLATEOMATIC"]("")
            end
        end
    },
}

-- =============================================================
-- 1. LOGIKK: VALG OG OPPSETT
-- =============================================================

function M:SetChoice(choice)
    if not SUPPORTED_ADDONS[choice] then return end

    -- Sikre DB finnes
    Robuinp = Robuinp or {}
    Robuinp.global = Robuinp.global or {}
    Robuinp.char = Robuinp.char or {}

    Robuinp.global.NameplateChoice = choice

    -- Markér at popupen allerede er vist for denne characteren
    Robuinp.char.NameplatesPopupShown = true

    print("|cff00b3ffRobUI:|r Nameplate addon set to: |cff00ff00" .. choice .. "|r")

    local reloadNeeded = false

    -- 1. Aktiver valgt addon
    C_AddOns.EnableAddOn(choice)
    if not C_AddOns.IsAddOnLoaded(choice) then
        reloadNeeded = true
    end

    -- 2. Deaktiver de andre
    for name, _ in pairs(SUPPORTED_ADDONS) do
        if name ~= choice then
            if C_AddOns.GetAddOnInfo(name) then
                C_AddOns.DisableAddOn(name)
                if C_AddOns.IsAddOnLoaded(name) then
                    reloadNeeded = true
                end
            end
        end
    end

    -- 3. Reload eller oppdater meny
    if reloadNeeded then
        StaticPopupDialogs["ROBUI_RELOAD_PLATES"] = {
            text = "RobUI has updated your addon selection.\nA reload is required to disable the conflicting addons.",
            button1 = "Reload Now",
            button2 = "Later",
            OnAccept = function() C_UI.Reload() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("ROBUI_RELOAD_PLATES")
    else
        M:RegisterConfigPanel(choice)
    end

    if M.popup then M.popup:Hide() end
end

-- =============================================================
-- 2. GUI: VELGER (POPUP)
-- =============================================================

function M:ShowSelectionFrame()
    -- Sikre DB finnes (så vi kan markere "Active")
    Robuinp = Robuinp or {}
    Robuinp.global = Robuinp.global or {}
    Robuinp.char = Robuinp.char or {}

    if M.popup then M.popup:Show() return end

    local f = CreateFrame("Frame", "RobUI_NameplateChooser", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(450, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")

    if f.TitleBg then f.TitleBg:SetHeight(30) end
    if f.TitleText then
        f.TitleText:SetText("RobUI Nameplate Manager")
    end

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOP", 0, -40)
    desc:SetWidth(400)
    desc:SetText("Multiple nameplate addons detected.\nPlease choose which one RobUI should use.\n(The others will be disabled automatically)")

    local yOffset = -90
    local foundAny = false

    for name, info in pairs(SUPPORTED_ADDONS) do
        if C_AddOns.GetAddOnInfo(name) then -- Sjekk om installert
            foundAny = true

            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(140, 30)
            btn:SetPoint("TOPLEFT", 30, yOffset)
            btn:SetText(name)

            -- Marker valgt
            if Robuinp.global.NameplateChoice == name then
                btn:SetText(name .. " (Active)")
                btn:SetEnabled(false)
            end

            btn:SetScript("OnClick", function() M:SetChoice(name) end)

            local infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            infoText:SetPoint("LEFT", btn, "RIGHT", 10, 0)
            infoText:SetText(info.desc)
            infoText:SetTextColor(0.7, 0.7, 0.7)

            yOffset = yOffset - 40
        end
    end

    if not foundAny then
        desc:SetText("No supported nameplate addons found.\n(Plater, Platynator, Plate-o-Matic)")
    end

    M.popup = f
end

-- =============================================================
-- 3. GUI: MASTERCONFIG KNAPP
-- =============================================================

function M:RegisterConfigPanel(choice)
    local p = CreateFrame("Frame", nil, UIParent)

    local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 20, -20)
    t:SetText("Nameplates: " .. choice)

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 20, -60)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Active Addon: |cff00ff00" .. choice .. "|r\n\nClick the button below to open its configuration.")

    local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btn:SetSize(200, 30)
    btn:SetPoint("TOPLEFT", 20, -110)
    btn:SetText("Open " .. choice .. " Config")
    btn:SetScript("OnClick", function()
        if R.MasterConfig and R.MasterConfig.frame then R.MasterConfig.frame:Hide() end
        local addonInfo = SUPPORTED_ADDONS[choice]
        if addonInfo and addonInfo.openFunc then
            addonInfo.openFunc()
        end
    end)

    if choice == "Plate-o-Matic" and _G.PlateOMatic_CreateConfig then
        desc:Hide()
        btn:Hide()
        t:Hide()
        _G.PlateOMatic_CreateConfig(p)
    end

    local switchBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    switchBtn:SetSize(140, 25)
    switchBtn:SetPoint("BOTTOMLEFT", 20, 20)
    switchBtn:SetText("Switch Addon")
    switchBtn:SetScript("OnClick", function()
        if R.MasterConfig and R.MasterConfig.frame then R.MasterConfig.frame:Hide() end
        M:ShowSelectionFrame()
    end)

    if R.RegisterModulePanel then
        R:RegisterModulePanel("Nameplates", p)
    end
end

-- =============================================================
-- 4. INITIALISERING
-- =============================================================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- Sikre at SV finnes
    Robuinp = Robuinp or {}
    Robuinp.global = Robuinp.global or {}
    Robuinp.char = Robuinp.char or {}

    local choice = Robuinp.global.NameplateChoice

    if choice then
        if C_AddOns.IsAddOnLoaded(choice) then
            M:RegisterConfigPanel(choice)
        else
            Robuinp.global.NameplateChoice = nil

            -- VIS BARE 1 GANG PER CHARACTER (auto)
            if not Robuinp.char.NameplatesPopupShown then
                Robuinp.char.NameplatesPopupShown = true
                C_Timer.After(2, function() M:ShowSelectionFrame() end)
            end
        end
    else
        local count = 0
        for name, _ in pairs(SUPPORTED_ADDONS) do
            if C_AddOns.GetAddOnInfo(name) then count = count + 1 end
        end

        -- VIS BARE 1 GANG PER CHARACTER (auto)
        if count > 0 and not Robuinp.char.NameplatesPopupShown then
            Robuinp.char.NameplatesPopupShown = true
            C_Timer.After(3, function() M:ShowSelectionFrame() end)
        end
    end
end)

-- Slash kommando for å åpne velgeren manuelt (alltid tilgjengelig)
SLASH_ROBUI_PLATES1 = "/robiplates"
SlashCmdList["ROBUI_PLATES"] = function()
    M:ShowSelectionFrame()
end
