local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["ROGUE"] = function(MainBar)
    if MainBar.__rb_rogue_built then
        if MainBar.__rb_rogue_layout then MainBar:__rb_rogue_layout() end
        if MainBar.__rb_rogue_update then MainBar:__rb_rogue_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_rogue_built = true

    MainBar:SetBackdropBorderColor(1, 1, 0.2, 1)

    local segs = {}
    MainBar.__rb_rogue_segs = segs

    local colors = {
        {1,0,0}, {1,0.5,0}, {1,1,0}, {0.5,1,0}, {0,1,0}, {0,0.6,0}
    }
    local maxCP = 6

    for i = 1, maxCP do
        local seg = CreateFrame("StatusBar", nil, MainBar)
        seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        seg:SetStatusBarColor(colors[i][1], colors[i][2], colors[i][3], 1)

        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints()
        seg.bg:SetColorTexture(colors[i][1]*0.2, colors[i][2]*0.2, colors[i][3]*0.2, 1)

        seg:SetMinMaxValues(0, 1)
        segs[i] = seg
    end

    function MainBar:__rb_rogue_layout()
        local inner = InnerW(MainBar)
        local gap = 2
        local segW = (inner - ((maxCP - 1) * gap)) / maxCP
        if segW < 6 then segW = 6 end

        for i = 1, maxCP do
            local seg = segs[i]
            seg:SetSize(segW, 16)
            seg:ClearAllPoints()
            seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
        end
    end

    function MainBar:__rb_rogue_update(event, unit, pType)
        if event == "UNIT_POWER_UPDATE" and pType ~= "COMBO_POINTS" then return end
        local cur = UnitPower("player", Enum.PowerType.ComboPoints) or 0
        for i = 1, maxCP do segs[i]:SetValue(i <= cur and 1 or 0) end
        ns.Text:SetText(cur .. " / " .. maxCP)
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_rogue_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_rogue_update(ev, ...)
    end)

    if not MainBar.__rb_rogue_resize_hooked then
        MainBar.__rb_rogue_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_rogue_layout then MainBar:__rb_rogue_layout() end
        end)
    end

    MainBar:__rb_rogue_layout()
    MainBar:__rb_rogue_update("PLAYER_ENTERING_WORLD")
end