local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

local function Hex2RGB(h)
    return tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255, 1
end

ns.standaloneBars["EVOKER"] = function(MainBar)
    if MainBar.__rb_evoker_built then
        if MainBar.__rb_evoker_layout then MainBar:__rb_evoker_layout() end
        if MainBar.__rb_evoker_update then MainBar:__rb_evoker_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_evoker_built = true

    MainBar:SetBackdropBorderColor(0, 0.8, 0.8, 1)

    local segs = {}
    MainBar.__rb_evoker_segs = segs

    local hexes = {"00ffff", "00dddd", "00cccc", "00bbbb", "00aaaa"}

    local function KillSegs()
        for i = 1, #segs do
            segs[i]:Hide()
            segs[i]:SetParent(nil)
            segs[i] = nil
        end
        wipe(segs)
    end

    function MainBar:__rb_evoker_build()
        KillSegs()

        local spec = GetSpecialization()
        local pt = (spec == 3) and Enum.PowerType.Anima or Enum.PowerType.Essence
        local maxP = UnitPowerMax("player", pt)
        if not maxP or maxP < 1 then maxP = (spec == 3) and 5 or 2 end

        local inner = InnerW(MainBar)
        local gap = 2
        local segW = (inner - ((maxP - 1) * gap)) / maxP
        if segW < 6 then segW = 6 end

        for i = 1, maxP do
            local seg = CreateFrame("StatusBar", nil, MainBar)
            seg:SetSize(segW, 16)
            seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            seg:SetStatusBarColor(Hex2RGB(hexes[i] or "ffffff"))

            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints()
            seg.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

            seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
            seg:SetMinMaxValues(0, 1)

            segs[i] = seg
        end
    end

    function MainBar:__rb_evoker_layout()
        local n = #segs
        if n < 1 then return end
        local inner = InnerW(MainBar)
        local gap = 2
        local segW = (inner - ((n - 1) * gap)) / n
        if segW < 6 then segW = 6 end
        for i = 1, n do
            local seg = segs[i]
            seg:SetSize(segW, 16)
            seg:ClearAllPoints()
            seg:SetPoint("LEFT", MainBar, "LEFT", 4 + (i - 1) * (segW + gap), 0)
        end
    end

    function MainBar:__rb_evoker_update(event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_MAXPOWER" then
            MainBar:__rb_evoker_build()
        end

        if #segs < 1 then MainBar:__rb_evoker_build() end

        local spec = GetSpecialization()
        local pt = (spec == 3) and Enum.PowerType.Anima or Enum.PowerType.Essence
        local cur = UnitPower("player", pt) or 0

        for i, seg in ipairs(segs) do
            seg:SetValue(i <= cur and 1 or 0)
        end
        ns.Text:SetText(cur .. " / " .. #segs)

        MainBar:__rb_evoker_layout()
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_evoker_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        if ev == "UNIT_POWER_UPDATE" then
            MainBar:__rb_evoker_update(ev)
        else
            MainBar:__rb_evoker_update(ev)
        end
    end)

    if not MainBar.__rb_evoker_resize_hooked then
        MainBar.__rb_evoker_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_evoker_layout then MainBar:__rb_evoker_layout() end
        end)
    end

    MainBar:__rb_evoker_build()
    MainBar:__rb_evoker_update("PLAYER_ENTERING_WORLD")
end