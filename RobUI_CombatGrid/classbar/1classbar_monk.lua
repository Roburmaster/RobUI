local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["MONK"] = function(MainBar)
    if MainBar.__rb_monk_built then
        if MainBar.__rb_monk_layout then MainBar:__rb_monk_layout() end
        if MainBar.__rb_monk_update then MainBar:__rb_monk_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_monk_built = true

    MainBar:SetBackdropBorderColor(0.2, 0.8, 0.6, 1)

    local segs = {}
    MainBar.__rb_monk_segs = segs

    local Stagger = CreateFrame("StatusBar", nil, MainBar)
    MainBar.__rb_monk_stagger = Stagger
    Stagger:SetPoint("TOPLEFT", 4, -4)
    Stagger:SetPoint("BOTTOMRIGHT", -4, 4)
    Stagger:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    Stagger:Hide()

    local function KillSegs()
        for i = 1, #segs do
            segs[i]:Hide()
            segs[i]:SetParent(nil)
            segs[i] = nil
        end
        wipe(segs)
    end

    function MainBar:__rb_monk_buildChi()
        KillSegs()

        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi)
        if not maxChi or maxChi < 1 then maxChi = 4 end

        local inner = InnerW(MainBar)
        local gap = 2
        local segW = (inner - ((maxChi - 1) * gap)) / maxChi
        if segW < 6 then segW = 6 end

        for i = 1, maxChi do
            local seg = CreateFrame("StatusBar", nil, MainBar)
            seg:SetSize(segW, 16)
            seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

            if i <= 2 then
                seg:SetStatusBarColor(10/255, 186/255, 181/255, 1)
            elseif i <= 4 then
                seg:SetStatusBarColor(86/255, 223/255, 207/255, 1)
            else
                seg:SetStatusBarColor(173/255, 238/255, 217/255, 1)
            end

            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints()
            seg.bg:SetColorTexture(0.1, 0.1, 0.1, 1)

            seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
            seg:SetMinMaxValues(0, 1)

            segs[i] = seg
        end
    end

    function MainBar:__rb_monk_layout()
        -- layout is spec-dependent; just rebuild chi sizing when needed
        local spec = GetSpecialization()
        if spec == 3 and #segs > 0 then
            local maxChi = #segs
            local inner = InnerW(MainBar)
            local gap = 2
            local segW = (inner - ((maxChi - 1) * gap)) / maxChi
            if segW < 6 then segW = 6 end

            for i = 1, maxChi do
                local seg = segs[i]
                seg:SetSize(segW, 16)
                seg:ClearAllPoints()
                seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
            end
        end
    end

    function MainBar:__rb_monk_update(event, unit, pType)
        local spec = GetSpecialization()

        if spec == 1 then
            MainBar:Show()
            for _, s in ipairs(segs) do s:Hide() end
            Stagger:Show()

            local pct = (UnitStagger("player") or 0) / (UnitHealthMax("player") or 1)
            if pct < 0 then pct = 0 end
            if pct > 1 then pct = 1 end
            Stagger:SetMinMaxValues(0, 1)
            Stagger:SetValue(pct)

            if pct < 0.3 then
                Stagger:SetStatusBarColor(0.52, 1, 0.52, 1)
            elseif pct < 0.6 then
                Stagger:SetStatusBarColor(1, 0.98, 0.72, 1)
            else
                Stagger:SetStatusBarColor(1, 0.42, 0.42, 1)
            end

            ns.Text:SetText(math.floor(pct * 100) .. "%")
            return
        end

        if spec == 3 then
            MainBar:Show()
            Stagger:Hide()

            if #segs == 0 or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_MAXPOWER" then
                MainBar:__rb_monk_buildChi()
            end

            for _, s in ipairs(segs) do s:Show() end

            if event == "UNIT_POWER_UPDATE" and pType ~= "CHI" then return end

            local cur = UnitPower("player", Enum.PowerType.Chi) or 0
            for i, seg in ipairs(segs) do
                seg:SetValue(i <= cur and 1 or 0)
            end
            ns.Text:SetText(cur .. " / " .. #segs)

            MainBar:__rb_monk_layout()
            return
        end

        -- other specs: hide whole bar
        MainBar:Hide()
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_monk_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    f:RegisterUnitEvent("UNIT_HEALTH", "player")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_monk_update(ev, ...)
    end)

    if not MainBar.__rb_monk_resize_hooked then
        MainBar.__rb_monk_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_monk_layout then MainBar:__rb_monk_layout() end
        end)
    end

    MainBar:__rb_monk_update("PLAYER_ENTERING_WORLD")
end