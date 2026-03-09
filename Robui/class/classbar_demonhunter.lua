-- class/classbar_demonhunter.lua
-- Demon Hunter Classbar (Pips-area):
-- - Devourer ONLY (specID 582):
--     Single smooth bar tracking Aura ID 1225789 stacks (0..50)
--     Includes text: "Souls: X / 50"
-- - Other DH specs: hides bar

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["DEMONHUNTER"] = function(holder)
    -- Constants
    local SOULS_AURA_ID = 1225789
    local MAX_SOULS     = 50
    local DEVOURER_SPEC = 1480

    ------------------------------------------------------------------------
    -- Build visuals INSIDE holder (like monk/rogue/etc)
    ------------------------------------------------------------------------
    local SoulsBar = CreateFrame("StatusBar", nil, holder, "BackdropTemplate")
    SoulsBar:SetAllPoints(holder)
    SoulsBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    SoulsBar:SetStatusBarColor(0.40, 0.10, 0.60, 1) -- Void purple
    SoulsBar:SetMinMaxValues(0, MAX_SOULS)
    SoulsBar:SetValue(0)

    local SoulsBG = SoulsBar:CreateTexture(nil, "BACKGROUND")
    SoulsBG:SetAllPoints(SoulsBar)
    SoulsBG:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    SoulsBG:SetVertexColor(0.1, 0.1, 0.1, 1)

    local SoulsText = SoulsBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    SoulsText:SetPoint("CENTER", SoulsBar, "CENTER", 0, 0)
    SoulsText:SetText("Souls: 0 / " .. MAX_SOULS)

    ------------------------------------------------------------------------
    -- Spec helpers
    ------------------------------------------------------------------------
    local function GetSpecID()
        if not GetSpecialization or not GetSpecializationInfo then return nil end
        local idx = GetSpecialization()
        if not idx then return nil end
        local specID = GetSpecializationInfo(idx)
        return specID
    end

    local function IsDevourer()
        return GetSpecID() == DEVOURER_SPEC
    end

    ------------------------------------------------------------------------
    -- Update logic (from your standalone file, just adapted)
    ------------------------------------------------------------------------
    local function UpdateSouls()
        if not IsDevourer() then
            SoulsBar:Hide()
            return
        end

        SoulsBar:Show()

        local stacks = 0
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SOULS_AURA_ID)
            if auraData then
                stacks = auraData.applications or 0
            end
        end

        if type(stacks) ~= "number" then stacks = 0 end
        if stacks < 0 then stacks = 0 end
        if stacks > MAX_SOULS then stacks = MAX_SOULS end

        SoulsBar:SetValue(stacks)
        SoulsText:SetText("Souls: " .. stacks .. " / " .. MAX_SOULS)
    end

    ------------------------------------------------------------------------
    -- Events (kept minimal)
    ------------------------------------------------------------------------
    local evt = CreateFrame("Frame", nil, SoulsBar)
    evt:RegisterEvent("PLAYER_LOGIN")
    evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    evt:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    evt:RegisterEvent("PLAYER_TALENT_UPDATE")
    evt:RegisterUnitEvent("UNIT_AURA", "player")

    evt:SetScript("OnEvent", function(_, event, unit)
        if unit and unit ~= "player" then return end

        -- Aura changes => refresh (only matters when devourer)
        if event == "UNIT_AURA" then
            if IsDevourer() then
                UpdateSouls()
            end
            return
        end

        -- Everything else (login/spec/talents) => refresh visibility + value
        UpdateSouls()
    end)

    -- Safety kicks (spec/aura can be late)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, UpdateSouls)
        C_Timer.After(0.50, UpdateSouls)
    else
        UpdateSouls()
    end

    -- IMPORTANT: return the frame that represents the classbar
    return SoulsBar
end