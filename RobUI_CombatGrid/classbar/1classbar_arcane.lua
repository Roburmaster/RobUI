local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["MAGE"] = function(MainBar)
    if MainBar.__rb_mage_built then
        if MainBar.__rb_mage_layout then MainBar:__rb_mage_layout() end
        if MainBar.__rb_mage_update then MainBar:__rb_mage_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_mage_built = true

    MainBar:SetBackdropBorderColor(0.2, 0.6, 1, 1)

    local bar = CreateFrame("StatusBar", nil, MainBar)
    MainBar.__rb_mage_bar = bar
    bar:SetPoint("TOPLEFT", 4, -4)
    bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetStatusBarColor(0.212, 0.637, 1, 1)

    local divs = {}
    for i = 1, 3 do
        local div = bar:CreateTexture(nil, "OVERLAY")
        div:SetColorTexture(0, 0, 0, 0.8)
        div:SetSize(2, 24)
        divs[i] = div
    end
    MainBar.__rb_mage_divs = divs

    function MainBar:__rb_mage_layout()
        local inner = InnerW(MainBar)
        -- Arcane Charges max is 4 => 3 separators
        for i = 1, 3 do
            local div = divs[i]
            div:ClearAllPoints()
            div:SetPoint("LEFT", bar, "LEFT", (inner / 4) * i, 0)
        end
    end

    function MainBar:__rb_mage_update(event, unit, pType)
        if event == "UNIT_POWER_UPDATE" and pType ~= "ARCANE_CHARGES" then return end
        if GetSpecialization() ~= 1 then MainBar:Hide(); return else MainBar:Show() end

        local cur = UnitPower("player", Enum.PowerType.ArcaneCharges) or 0
        bar:SetMinMaxValues(0, 4)
        bar:SetValue(cur)
        ns.Text:SetText(cur .. " / 4")
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_mage_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_mage_update(ev, ...)
        MainBar:__rb_mage_layout()
    end)

    if not MainBar.__rb_mage_resize_hooked then
        MainBar.__rb_mage_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_mage_layout then MainBar:__rb_mage_layout() end
        end)
    end

    MainBar:__rb_mage_layout()
    MainBar:__rb_mage_update("PLAYER_ENTERING_WORLD")
end