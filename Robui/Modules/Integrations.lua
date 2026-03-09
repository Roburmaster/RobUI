-- RobUI/Modules/Integrations.lua
-- Integrerer eksterne addons inn i RobUI MasterConfig
-- 12.0 SAFE: IKKE kall CompactUnitFrame_* (secret values crash)

local AddonName, ns = ...
local R = _G.Robui

local function SafePOM_RefreshAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local db = _G.PlateOMaticDB or {}

    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in pairs(plates) do
        local uf = plate and plate.UnitFrame
        if uf and not uf:IsForbidden() then
            -- 1) Oppdater POM-mixin hvis den finnes
            local m = uf.POM_Mixin
            if m and m.UpdateVisuals then
                -- samme rekkefølge som POM
                pcall(m.UpdateVisuals, m)
                if m.UpdateQuest then pcall(m.UpdateQuest, m) end
                if m.UpdateName  then pcall(m.UpdateName,  m) end
                if m.UpdateHealth then pcall(m.UpdateHealth, m) end

                -- UpdateState kan kreve safe unit (POM gjør sjekk selv i sin Apply)
                if m.UpdateState then
                    pcall(m.UpdateState, m)
                end
            end

            -- 2) Buff/Debuff scaling (som POM hooker i CompactUnitFrame_UpdateAuras)
            local bScale = (db.buffSize or 20) / 18
            local dScale = (db.debuffSize or 20) / 18
            if uf.BuffFrame and uf.BuffFrame.SetScale then
                pcall(uf.BuffFrame.SetScale, uf.BuffFrame, bScale)
            end
            if uf.DebuffFrame and uf.DebuffFrame.SetScale then
                pcall(uf.DebuffFrame.SetScale, uf.DebuffFrame, dScale)
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not (R and R.RegisterModulePanel) then return end

    -- ------------------------------------------------------------
    -- Plate-o-Matic (split version)
    -- ------------------------------------------------------------
    do
        local POM = _G.PlateOMatic
        if POM and POM.config and POM.config.Build then
            local p = CreateFrame("Frame", nil, UIParent)
            p:SetSize(1020, 760)

            local function applyAll()
                -- 12.0 SAFE refresh (ingen CompactUnitFrame_* kall)
                SafePOM_RefreshAll()

                if POM.preview and POM.preview.frame and POM.preview.frame.Refresh then
                    POM.preview.frame:Refresh()
                end
            end

            local skins = POM.SKINS or ns.SKINS
            POM.config:Build(p, skins, applyAll)

            R:RegisterModulePanel("Nameplates", p)
            print("|cff00b3ffRobui:|r Integrated Plate-o-Matic settings.")
        end
    end

    -- ------------------------------------------------------------
    -- RobUIHeal (embedded settings)  <-- VIKTIG: addon heter RobUIHeal
    -- ------------------------------------------------------------
    do
        local RH = _G.RobUIHeal
        if RH and RH.Settings and RH.Settings.BuildRobUI then
            local p = CreateFrame("Frame", nil, UIParent)
            p:SetSize(1020, 760)

            RH.Settings:BuildRobUI(p)

            R:RegisterModulePanel("RobHeal", p)
            print("|cff00b3ffRobui:|r Integrated RobUIHeal settings.")
        end
    end
end)
