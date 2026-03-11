local _, ns = ...
ns.standaloneBars = ns.standaloneBars or {}

local function GetInnerWidth(MainBar)
    local width = (MainBar and MainBar.GetWidth and MainBar:GetWidth()) or 220
    width = tonumber(width) or 220
    local inner = width - 4 -- Tighter padding for a sleeker look
    if inner < 80 then inner = 80 end
    return inner
end

-- Use a built-in flat texture for a modern, clean look without adding file bloat
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8x8"

ns.standaloneBars["MONK"] = function(MainBar)
    if MainBar.__rb_monk_built then
        if MainBar.__rb_monk_layout then MainBar:__rb_monk_layout() end
        if MainBar.__rb_monk_update then MainBar:__rb_monk_update("PLAYER_ENTERING_WORLD") end
        return
    end
    MainBar.__rb_monk_built = true

    -- Darken the main backdrop border to make the bright class colors pop
    MainBar:SetBackdropBorderColor(0, 0, 0, 1)

    local segments = {}
    MainBar.__rb_monk_segs = segments

    -- Stagger Bar (Brewmaster)
    local Stagger = CreateFrame("StatusBar", nil, MainBar)
    MainBar.__rb_monk_stagger = Stagger
    Stagger:SetPoint("TOPLEFT", 2, -2)
    Stagger:SetPoint("BOTTOMRIGHT", -2, 2)
    Stagger:SetStatusBarTexture(FLAT_TEXTURE)
    Stagger:Hide()

    -- Stagger background
    local StaggerBG = Stagger:CreateTexture(nil, "BACKGROUND")
    StaggerBG:SetAllPoints()
    StaggerBG:SetTexture(FLAT_TEXTURE)
    StaggerBG:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local function ClearSegments()
        for i = 1, #segments do
            segments[i]:Hide()
            segments[i]:SetParent(nil)
            segments[i] = nil
        end
        wipe(segments)
    end

    function MainBar:__rb_monk_buildChi()
        ClearSegments()

        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi)
        if not maxChi or maxChi < 1 then maxChi = 4 end

        local innerWidth = GetInnerWidth(MainBar)
        local gap = 3 -- Slightly wider gap for distinction
        local segmentWidth = (innerWidth - ((maxChi - 1) * gap)) / maxChi
        if segmentWidth < 6 then segmentWidth = 6 end

        for i = 1, maxChi do
            -- Needs BackdropTemplate for the border in modern WoW API
            local seg = CreateFrame("StatusBar", nil, MainBar, "BackdropTemplate")
            seg:SetSize(segmentWidth, 18)
            seg:SetStatusBarTexture(FLAT_TEXTURE)
            
            -- Vibrant, uniform modern Monk teal for all points
            seg:SetStatusBarColor(0.0, 1.0, 0.59, 1) 

            -- Empty background state
            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints()
            seg.bg:SetTexture(FLAT_TEXTURE)
            seg.bg:SetVertexColor(0.06, 0.06, 0.06, 0.9) -- Very dark grey

            -- Crisp 1px inner border around each segment
            seg:SetBackdrop({
                edgeFile = FLAT_TEXTURE,
                edgeSize = 1,
            })
            seg:SetBackdropBorderColor(0, 0, 0, 1)

            seg:SetPoint("LEFT", MainBar, "LEFT", 2 + (i - 1) * (segmentWidth + gap), 0)
            seg:SetMinMaxValues(0, 1)

            segments[i] = seg
        end
    end

    function MainBar:__rb_monk_layout()
        local spec = GetSpecialization()
        if spec == 3 and #segments > 0 then
            local maxChi = #segments
            local innerWidth = GetInnerWidth(MainBar)
            local gap = 3
            local segmentWidth = (innerWidth - ((maxChi - 1) * gap)) / maxChi
            if segmentWidth < 6 then segmentWidth = 6 end

            for i = 1, maxChi do
                local seg = segments[i]
                seg:SetSize(segmentWidth, 18)
                seg:ClearAllPoints()
                seg:SetPoint("LEFT", MainBar, "LEFT", 2 + (i - 1) * (segmentWidth + gap), 0)
            end
        end
    end

    function MainBar:__rb_monk_update(event, unit, powerType)
        local spec = GetSpecialization()

        -- Brewmaster logic
        if spec == 1 then
            MainBar:Show()
            for _, s in ipairs(segments) do s:Hide() end
            Stagger:Show()

            local staggerAmount = UnitStagger("player") or 0
            local maxHealth = UnitHealthMax("player") or 1
            local percent = staggerAmount / maxHealth
            
            if percent < 0 then percent = 0 end
            if percent > 1 then percent = 1 end
            
            Stagger:SetMinMaxValues(0, 1)
            Stagger:SetValue(percent)

            -- Modern, slightly adjusted stagger colors
            if percent < 0.3 then
                Stagger:SetStatusBarColor(0.2, 0.8, 0.2, 1)
            elseif percent < 0.6 then
                Stagger:SetStatusBarColor(0.9, 0.8, 0.2, 1)
            else
                Stagger:SetStatusBarColor(0.9, 0.2, 0.2, 1)
            end

            if ns.Text then
                ns.Text:SetText(math.floor(percent * 100) .. "%")
            end
            return
        end

        -- Windwalker logic
        if spec == 3 then
            MainBar:Show()
            Stagger:Hide()

            if #segments == 0 or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_MAXPOWER" then
                MainBar:__rb_monk_buildChi()
            end

            for _, s in ipairs(segments) do s:Show() end

            if event == "UNIT_POWER_UPDATE" and powerType ~= "CHI" then return end

            local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
            for i, seg in ipairs(segments) do
                -- Toggle segment visibility based on current Chi
                if i <= currentChi then
                    seg:SetValue(1)
                    seg:SetAlpha(1)
                else
                    seg:SetValue(0)
                    seg:SetAlpha(0.5) -- Dim the border slightly when empty
                end
            end
            
            if ns.Text then
                ns.Text:SetText(currentChi .. " / " .. #segments)
            end

            MainBar:__rb_monk_layout()
            return
        end

        -- Other specs (Mistweaver)
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
