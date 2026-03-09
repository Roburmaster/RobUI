local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["PALADIN"] = function(MainBar)
    if MainBar.__rb_paladin_built then
        if MainBar.__rb_paladin_layout then MainBar:__rb_paladin_layout() end
        if MainBar.__rb_paladin_update then MainBar:__rb_paladin_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_paladin_built = true

    MainBar:SetBackdropBorderColor(1, 0.8, 0.1, 1)

    local bar = CreateFrame("StatusBar", nil, MainBar)
    MainBar.__rb_paladin_bar = bar
    bar:SetPoint("TOPLEFT", 4, -4)
    bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetStatusBarColor(0.95, 0.85, 0.15, 1)

    local divs = {}
    for i = 1, 4 do
        local div = bar:CreateTexture(nil, "OVERLAY")
        div:SetColorTexture(0, 0, 0, 0.8)
        div:SetSize(2, 24)
        divs[i] = div
    end
    MainBar.__rb_paladin_divs = divs

    function MainBar:__rb_paladin_layout()
        local inner = InnerW(MainBar)
        local maxVal = UnitPowerMax("player", Enum.PowerType.HolyPower) or 5
        if maxVal < 1 then maxVal = 5 end
        local sepCount = maxVal - 1
        if sepCount < 0 then sepCount = 0 end
        if sepCount > 4 then sepCount = 4 end

        for i = 1, 4 do
            local div = divs[i]
            if i <= sepCount then
                div:Show()
                div:ClearAllPoints()
                div:SetPoint("LEFT", bar, "LEFT", (inner / maxVal) * i, 0)
            else
                div:Hide()
            end
        end
    end

    function MainBar:__rb_paladin_update(event, unit, pType)
        if event == "UNIT_POWER_UPDATE" and pType ~= "HOLY_POWER" then return end

        local cur = UnitPower("player", Enum.PowerType.HolyPower) or 0
        local maxVal = UnitPowerMax("player", Enum.PowerType.HolyPower) or 5
        if maxVal < 1 then maxVal = 5 end

        bar:SetMinMaxValues(0, maxVal)
        bar:SetValue(cur)
        ns.Text:SetText(cur .. " / " .. maxVal)

        if cur == maxVal then
            bar:SetStatusBarColor(1, 0.95, 0.3, 1)
            MainBar:SetBackdropBorderColor(1, 1, 0.5, 1)
        else
            bar:SetStatusBarColor(0.95, 0.85, 0.15, 1)
            MainBar:SetBackdropBorderColor(1, 0.8, 0.1, 1)
        end

        MainBar:__rb_paladin_layout()
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_paladin_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_paladin_update(ev, ...)
    end)

    if not MainBar.__rb_paladin_resize_hooked then
        MainBar.__rb_paladin_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_paladin_layout then MainBar:__rb_paladin_layout() end
        end)
    end

    MainBar:__rb_paladin_layout()
    MainBar:__rb_paladin_update("PLAYER_ENTERING_WORLD")
end