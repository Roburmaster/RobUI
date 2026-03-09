local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["DEATHKNIGHT"] = function(MainBar)
    if MainBar.__rb_dk_built then
        if MainBar.__rb_dk_layout then MainBar:__rb_dk_layout() end
        if MainBar.__rb_dk_update then MainBar:__rb_dk_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_dk_built = true

    MainBar:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)

    local RK = CreateFrame("Frame", nil, MainBar)
    MainBar.__rb_dk_root = RK
    RK:SetPoint("TOPLEFT", 4, -4)
    RK:SetPoint("BOTTOMRIGHT", -4, 4)

    local segs = {}
    RK.segs = segs

    for i = 1, 6 do
        local seg = CreateFrame("StatusBar", nil, RK)
        seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        seg:SetStatusBarColor(0.6, 0.0, 0.0, 1)

        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints()
        seg.bg:SetColorTexture(0.15, 0, 0, 1)

        segs[i] = seg
    end

    function MainBar:__rb_dk_layout()
        local inner = InnerW(MainBar)
        local gap = 2
        local n = 6
        local segW = (inner - ((n - 1) * gap)) / n
        if segW < 6 then segW = 6 end

        for i = 1, n do
            local seg = segs[i]
            seg:SetSize(segW, 16)
            seg:ClearAllPoints()
            seg:SetPoint("LEFT", RK, "LEFT", (i - 1) * (segW + gap), 0)
        end
    end

    RK.__acc = 0
    local function OnTick(self, el)
        self.__acc = self.__acc + el
        if self.__acc < 0.05 then return end
        self.__acc = 0

        local now, any = GetTime(), false
        for _, bar in ipairs(self.segs) do
            if not bar.ready and bar.start and bar.dur then
                local remain = bar.dur - (now - bar.start)
                if remain > 0 then
                    any = true
                    bar:SetValue(bar.dur - remain)
                else
                    bar.ready = true
                    bar:SetValue(1)
                end
            end
        end
        if not any then self:SetScript("OnUpdate", nil) end
    end

    function MainBar:__rb_dk_update()
        local tick, readyCount = false, 0
        for i, bar in ipairs(segs) do
            local start, dur, ready = GetRuneCooldown(i)
            if start then
                bar.start, bar.dur, bar.ready = start, dur, ready
                if ready then
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(1)
                    readyCount = readyCount + 1
                else
                    tick = true
                    bar:SetMinMaxValues(0, dur)
                    bar:SetValue(dur - (GetTime() - start))
                end
            end
        end

        ns.Text:SetText(readyCount .. " / 6")

        if tick and not RK:GetScript("OnUpdate") then
            RK.__acc = 0
            RK:SetScript("OnUpdate", OnTick)
        end

        MainBar:__rb_dk_layout()
    end

    RK:SetScript("OnEvent", function() MainBar:__rb_dk_update() end)
    RK:RegisterEvent("PLAYER_ENTERING_WORLD")
    RK:RegisterEvent("RUNE_POWER_UPDATE")

    if not MainBar.__rb_dk_resize_hooked then
        MainBar.__rb_dk_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_dk_layout then MainBar:__rb_dk_layout() end
        end)
    end

    MainBar:__rb_dk_layout()
    MainBar:__rb_dk_update()
end