-- class/classbar_shaman.lua
-- Elemental = show Maelstrom
-- Other specs = hide

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["SHAMAN"] = function(holder)

    local function IsElemental()
        local idx = GetSpecialization()
        if not idx then return false end
        local specID = select(1, GetSpecializationInfo(idx))
        return specID == 262
    end

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetAllPoints(holder)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(0.0, 0.6, 1.0)
    bar:Hide()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, 0.6)

    local function Update()
        if not IsElemental() then
            bar:Hide()
            return
        end

        bar:Show()

        -- Use class power directly
        local powerType = UnitPowerType("player")
        local cur = UnitPower("player", powerType)
        local max = UnitPowerMax("player", powerType)

        bar:SetMinMaxValues(0, max or 100)
        bar:SetValue(cur or 0)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    f:RegisterEvent("UNIT_DISPLAYPOWER")

    f:SetScript("OnEvent", function(_, event, unit)
        if unit and unit ~= "player" then return end
        Update()
    end)

    C_Timer.After(0.1, Update)
end