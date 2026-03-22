local ADDON_NAME, ns = ...
local CB = ns.CB

local CreateFrame = CreateFrame
local C_Timer = C_Timer

local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
}

local UPDATE_ONLY_EVENTS = {
    UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_EMPOWER_UPDATE = true,
}

function CB:OnEvent(bar, event, unit)
    if self.isUnlocked then return end

    if unit and unit ~= bar.unit then
        return
    end

    local dbAll = self:GetDB()
    if not dbAll or not (dbAll.global and dbAll.global.enabled) then
        self:StopBar(bar)
        return
    end

    local db = dbAll[bar.key]
    if not db or (not db.enabled and not self.isUnlocked) then
        self:StopBar(bar)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        if not self:StartOrUpdateFromUnit(bar) then
            self:StopBar(bar)
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        if bar.unit ~= "target" then
            return
        end
        if not self:StartOrUpdateFromUnit(bar) then
            self:StopBar(bar)
        end
        return
    end

    if STOP_EVENTS[event] then
        self:StopBar(bar)
        return
    end

    if UPDATE_ONLY_EVENTS[event] and (not bar.castState) then
        return
    end

    if not self:StartOrUpdateFromUnit(bar) then
        self:StopBar(bar)
    end
end

function CB:ToggleTestMode()
    self.isUnlocked = not self.isUnlocked
    for key in pairs(self.bars) do
        self:UpdateBarLayout(key)
    end
end

function CB:EnableBlizzardCastbar()
    if CastingBarFrame then
        pcall(function() CastingBarFrame:Show() end)
    end
    if PlayerCastingBarFrame then
        pcall(function() PlayerCastingBarFrame:Show() end)
    end
end

function CB:DisableBlizzardCastbar()
    if CastingBarFrame then
        pcall(function()
            CastingBarFrame:UnregisterAllEvents()
            CastingBarFrame:Hide()
        end)
    end
    if PlayerCastingBarFrame then
        pcall(function()
            PlayerCastingBarFrame:UnregisterAllEvents()
            PlayerCastingBarFrame:Hide()
        end)
    end
end

function CB:ApplyGlobalEnabledState()
    local db = self:GetDB()
    if not db then return end

    if not (db.global and db.global.enabled) then
        for _, bar in pairs(self.bars) do
            bar:UnregisterAllEvents()
            bar:SetScript("OnUpdate", nil)
            bar:SetScript("OnEvent", nil)
            bar.castState = nil
            if bar.ShieldBar then
                bar.ShieldBar:SetAlpha(0)
            end
            bar:Hide()
        end
        self:EnableBlizzardCastbar()
        return
    end

    for _, bar in pairs(self.bars) do
        bar:UnregisterAllEvents()

        bar:RegisterUnitEvent("UNIT_SPELLCAST_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", bar.unit)

        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", bar.unit)

        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", bar.unit)
        bar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", bar.unit)

        if bar.unit == "target" then
            bar:RegisterEvent("PLAYER_TARGET_CHANGED")
        end

        bar:RegisterEvent("PLAYER_REGEN_ENABLED")
        bar:RegisterEvent("PLAYER_ENTERING_WORLD")

        bar:SetScript("OnUpdate", nil)
        bar:SetScript("OnEvent", function(selfBar, event, unit)
            CB:OnEvent(selfBar, event, unit)
        end)

        self:UpdateBarLayout(bar.key)
    end

    self:DisableBlizzardCastbar()
end

function CB:Refresh()
    self:ApplyGlobalEnabledState()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if not CB:GetDB() then return end

    C_Timer.After(1, function()
        if not CB:GetDB() then return end
        CB:BuildAllBars()
        CB:RegisterGridPlugins()
        CB:RegisterWithRobUIMenu()
        CB:ApplyGlobalEnabledState()
    end)
end)

SLASH_ROBCAST1 = "/robcast"
SlashCmdList["ROBCAST"] = function(msg)
    msg = (msg or ""):lower()

    if msg == "test" then
        CB:ToggleTestMode()
        return
    elseif msg == "on" then
        local db = CB:GetDB()
        if not db then return end
        db.global.enabled = true
        CB:Refresh()
        return
    elseif msg == "off" then
        local db = CB:GetDB()
        if not db then return end
        db.global.enabled = false
        CB:Refresh()
        return
    end

    CB:OpenSettings()
end