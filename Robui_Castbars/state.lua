local ADDON_NAME, ns = ...
local CB = ns.CB

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCastingInfo = UnitCastingInfo or UnitSpellcastInfo
local UnitChannelInfo = UnitChannelInfo or UnitSpellcastChannelInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration

function CB:GetUnitCastState(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return nil end

    local durObj = UnitCastingDuration and UnitCastingDuration(unit)
    if durObj then
        local name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        return {
            kind = "cast",
            name = name,
            text = text,
            texture = texture,
            notInterruptible = notInterruptible and true or false,
            durationObject = durObj,
        }
    end

    local cdurObj = UnitChannelDuration and UnitChannelDuration(unit)
    if cdurObj then
        local cname, ctext, ctexture, _, _, _, _, cnotInterruptible, isEmpowered = UnitChannelInfo(unit)
        return {
            kind = isEmpowered and "empower" or "channel",
            name = cname,
            text = ctext,
            texture = ctexture,
            notInterruptible = cnotInterruptible and true or false,
            durationObject = cdurObj,
        }
    end

    return nil
end

function CB:StopBar(bar)
    if not bar then return end

    bar.castState = nil
    bar:SetScript("OnUpdate", nil)

    if bar.Spark then
        bar.Spark:Hide()
    end

    if bar.ShieldBar then
        bar.ShieldBar:SetAlpha(0)
    end

    self:HideEmpowerVisuals(bar)
    bar:Hide()
end

function CB:OnUpdateActive(bar)
    if self.isUnlocked then return end

    local state = bar.castState
    if not state or not state.durationObject then
        self:StopBar(bar)
        return
    end

    pcall(function()
        bar.Time:SetFormattedText("%.1f", state.durationObject:GetRemainingDuration())
    end)
end

function CB:ApplyStateToBar(bar, state)
    if not (bar and state and state.durationObject) then return false end

    bar.castState = state

    if bar.ShieldBar then
        -- Player casts should never show shield
        if bar.unit == "player" then
            bar.ShieldBar:SetAlpha(0)
        else
            if state.notInterruptible then
                bar.ShieldBar:SetAlpha(1)
            else
                bar.ShieldBar:SetAlpha(0)
            end
        end
    end

    self:SafeSetCastText(bar.Text, state.name, state.text, "")
    self:SafeSetTexture(bar.Icon, state.texture)

    if bar.SetTimerDuration then
        pcall(bar.SetTimerDuration, bar, state.durationObject)
    end

    if bar.ShieldBar and bar.ShieldBar.SetTimerDuration then
        pcall(bar.ShieldBar.SetTimerDuration, bar.ShieldBar, state.durationObject)
    end

    if bar.Spark then
        bar.Spark:Hide()
    end

    if state.kind == "empower" then
        self:LayoutEmpower4Segments(bar)
    else
        self:HideEmpowerVisuals(bar)
    end

    bar:SetAlpha(1)
    bar:Show()
    bar:SetScript("OnUpdate", function(selfBar)
        CB:OnUpdateActive(selfBar)
    end)

    self:OnUpdateActive(bar)
    return true
end

function CB:StartOrUpdateFromUnit(bar)
    local state = self:GetUnitCastState(bar.unit)
    if not state then
        self:StopBar(bar)
        return false
    end
    return self:ApplyStateToBar(bar, state)
end
