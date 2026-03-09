local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function InnerW(MainBar)
    local w = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    w = tonumber(w) or 220
    local inner = w - 8
    if inner < 80 then inner = 80 end
    return inner
end

ns.standaloneBars["WARLOCK"] = function(MainBar)
    if MainBar.__rb_lock_built then
        if MainBar.__rb_lock_layout then MainBar:__rb_lock_layout() end
        if MainBar.__rb_lock_update then MainBar:__rb_lock_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_lock_built = true

    MainBar:SetBackdropBorderColor(0.6, 0.2, 0.8, 1)

    local bar = CreateFrame("StatusBar", nil, MainBar)
    MainBar.__rb_lock_bar = bar
    bar:SetPoint("TOPLEFT", 4, -4)
    bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0, 1, 1)

    local divs = {}
    for i = 1, 4 do
        local div = bar:CreateTexture(nil, "OVERLAY")
        div:SetColorTexture(0, 0, 0, 0.8)
        div:SetSize(2, 24)
        divs[i] = div
    end
    MainBar.__rb_lock_divs = divs

    function MainBar:__rb_lock_layout()
        local inner = InnerW(MainBar)
        local maxVal = 5 -- shards display as 0..5
        for i = 1, 4 do
            local div = divs[i]
            div:ClearAllPoints()
            div:SetPoint("LEFT", bar, "LEFT", (inner / maxVal) * i, 0)
        end
    end

    function MainBar:__rb_lock_update(event, unit, pType)
        if event == "UNIT_POWER_UPDATE" and pType ~= "SOUL_SHARDS" then return end
        local cur = UnitPower("player", Enum.PowerType.SoulShards) or 0
        bar:SetMinMaxValues(0, 5)
        bar:SetValue(cur)
        ns.Text:SetText(cur .. " / 5")
    end

    local f = CreateFrame("Frame")
    MainBar.__rb_lock_frame = f
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, ev, ...)
        MainBar:__rb_lock_update(ev, ...)
    end)

    if not MainBar.__rb_lock_resize_hooked then
        MainBar.__rb_lock_resize_hooked = true
        MainBar:HookScript("OnSizeChanged", function()
            if MainBar.__rb_lock_layout then MainBar:__rb_lock_layout() end
        end)
    end

    MainBar:__rb_lock_layout()
    MainBar:__rb_lock_update("PLAYER_ENTERING_WORLD")
end