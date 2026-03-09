local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["DRUID"] = function(MainBar)
    if MainBar.__rb_druid_built then
        if MainBar.__rb_druid_layout then MainBar:__rb_druid_layout() end
        if MainBar.__rb_druid_update then MainBar:__rb_druid_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_druid_built = true

    MainBar:SetBackdropBorderColor(1, 0.6, 0, 1)

    local segs = {}
    MainBar.__rb_druid_segs = segs

    local cpColors = {
        {1,0,0}, {0.6,0.3,0}, {0.9,0.7,0}, {0,0.8,0.2}, {0,0.5,0.1}
    }

    for i = 1, 5 do
        local seg = CreateFrame("StatusBar", nil, MainBar)
        seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        seg:SetStatusBarColor(cpColors[i][1], cpColors[i][2], cpColors[i][3], 1)

        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints()
        seg.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

        seg:SetMinMaxValues(0, 1)
        segs[i] = seg
    end

    function MainBar:__rb_druid_layout()
        local inner = InnerW(MainBar)
        local gap = 2
        local maxCP = 5
        local segW = (inner - ((maxCP - 1) * gap)) / maxCP
        if segW < 6 then segW = 6 end

        for i = 1, maxCP do
            local seg = segs[i]
            seg:SetSize(segW, 16)
            seg:ClearAllPoints()
            seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
        end
    end

    function MainBar:__rb_druid_update(event, unit, pType)
        if GetSpecialization() ~= 2 then
            MainBar:Hide()
            return
        else
            MainBar:Show()
        end

        if event == "UNIT_POWER_UPDATE" and pType ~= "COMBO_POINTS" then return end

        local cur = UnitPower("player", Enum.PowerType.ComboPoints) or 0
        for i = 1, 5 do
            segs[i]:SetValue(i <= cur and 1 or 0)
        end
        ns.Text:SetText(cur .. " / 5")
        MainBar:__rb_druid_layout()
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_druid_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_druid_update(ev, ...)
    end)

    if not MainBar.__rb_druid_resize_hooked then
        MainBar.__rb_druid_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_druid_layout then MainBar:__rb_druid_layout() end
        end)
    end

    MainBar:__rb_druid_layout()
    MainBar:__rb_druid_update("PLAYER_ENTERING_WORLD")
end