local AddonName, ns = ...
local R = _G.Robui

-- -------------------------------------------------------------------------
-- FADER LOGIC
-- -------------------------------------------------------------------------
local tracked = {}
local state = { inCombat = false }

local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.actionbars then
        return R.Database.profile.actionbars.fader
    end
    return nil
end

local function TooltipActive()
    return (GameTooltip and GameTooltip:IsShown())
        or (ShoppingTooltip1 and ShoppingTooltip1:IsShown())
        or (ShoppingTooltip2 and ShoppingTooltip2:IsShown())
end

local function FadeTo(frame, targetAlpha, time)
    if not frame then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        frame:SetAlpha(1)
        return
    end

    if time and time > 0 then
        UIFrameFadeIn(frame, time, frame:GetAlpha(), targetAlpha)
    else
        frame:SetAlpha(targetAlpha)
    end
end

local function HookFrame(frame)
    if frame and not tracked[frame] then
        tracked[frame] = true
    end
end

-- Poll Frame for safe mouse checking
local pollFrame = CreateFrame("Frame")
pollFrame.t = 0
pollFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = GetDB()
    if not db or not db.enabled then return end

    -- While tooltip is actively building/showing on action buttons, don't spam fades.
    -- (This reduces taint pressure with other actionbar hooks.)
    if TooltipActive() then return end

    self.t = (self.t or 0) + elapsed
    if self.t < 0.10 then return end -- 10 times/sec
    self.t = 0

    for frame in pairs(tracked) do
        local name = frame and frame.GetName and frame:GetName()
        if name and db.bars and db.bars[name] then
            local isOver = (frame.IsMouseOver and frame:IsMouseOver()) or MouseIsOver(frame)
            local currentAlpha = frame:GetAlpha()
            local inCombatShow = state.inCombat and db.showInCombat

            if inCombatShow then
                FadeTo(frame, 1, db.fadeInTime)
            elseif isOver then
                FadeTo(frame, 1, db.fadeInTime)
                frame.__lingerStart = nil
            else
                if currentAlpha > (db.hiddenAlpha or 0) then
                    if not frame.__lingerStart then
                        frame.__lingerStart = GetTime()
                    elseif (GetTime() - frame.__lingerStart) > (db.hoverLinger or 0) then
                        FadeTo(frame, db.hiddenAlpha or 0, db.fadeOutTime or 0)
                        frame.__lingerStart = nil
                    end
                end
            end
        else
            -- If bar is disabled in settings, ensure it's visible
            if frame and frame.GetAlpha and frame:GetAlpha() < 1 then
                FadeTo(frame, 1, 0.2)
            end
        end
    end
end)

-- Event Handling
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        state.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        state.inCombat = false
    end

    local bars = {
        "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarRight", "MultiBarLeft", "PetActionBar", "StanceBar"
    }

    for _, name in ipairs(bars) do
        local bar = _G[name]
        if bar then HookFrame(bar) end
    end
end)
