local ADDON_NAME, ns = ...
local CB = ns.CB

local CreateFrame = CreateFrame
local UIParent = UIParent
local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local unpack = unpack
local type = type

function CB:CreateCastbarFrame(key, unit)
    local db = self:GetDB()
    local texture = (db and db.global and db.global.texture) or "Interface\\Buttons\\WHITE8x8"

    local bar = CreateFrame("StatusBar", "RobUI_" .. key, UIParent)
    bar:SetStatusBarTexture(texture)
    bar:SetFrameStrata("HIGH")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")

    bar.ShieldBar = CreateFrame("StatusBar", nil, bar)
    bar.ShieldBar:SetAllPoints(bar)
    bar.ShieldBar:SetStatusBarTexture(texture)
    bar.ShieldBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
    bar.ShieldBar:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.ShieldBar:SetAlpha(0)

    bar.TextHolder = CreateFrame("Frame", nil, bar)
    bar.TextHolder:SetAllPoints(bar)
    bar.TextHolder:SetFrameLevel(bar:GetFrameLevel() + 3)

    bar:SetScript("OnDragStart", function(self)
        if not CB.isUnlocked then return end
        local pid = self.__gridPluginId
        if pid and CB:GridIsAttached(pid) then return end
        self:StartMoving()
    end)

    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local pid = self.__gridPluginId
        if pid and CB:GridIsAttached(pid) then
            CB:UpdateBarLayout(key)
            return
        end

        local dbAll = CB:GetDB()
        if dbAll and dbAll[key] then
            local centerX = self:GetCenter()
            local screenWidth = UIParent:GetSize()
            local x = centerX - (screenWidth / 2)
            local y = self:GetBottom()

            dbAll[key].x = floor(x)
            dbAll[key].y = floor(y)

            CB:UpdateBarLayout(key)
            if CB.SettingsPanel and CB.SettingsPanel.RefreshSection then
                CB.SettingsPanel:RefreshSection()
            end
        end
    end)

    bar:Hide()

    self:CreateSafeBorder(bar, 0, 1, {0.1, 0.1, 0.1, 0.9}, {0, 0, 0, 1})

    bar.Icon = bar:CreateTexture(nil, "ARTWORK")
    bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    bar.iconBorder = CreateFrame("Frame", nil, bar)
    bar.iconBorder:SetFrameLevel(bar:GetFrameLevel() + 2)
    self:CreateSafeBorder(bar.iconBorder, 0, 1, {0, 0, 0, 0}, {0, 0, 0, 1})

    bar.Text = self:CreateFontString(bar.TextHolder, "LEFT", 10)
    bar.Time = self:CreateFontString(bar.TextHolder, "RIGHT", 10)
    bar.Text:SetDrawLayer("OVERLAY", 7)
    bar.Time:SetDrawLayer("OVERLAY", 7)

    bar.Spark = bar:CreateTexture(nil, "OVERLAY")
    bar.Spark:SetColorTexture(1, 1, 1, 0.8)
    bar.Spark:SetBlendMode("ADD")
    bar.Spark:Hide()

    if unit == "player" then
        bar.SafeZone = bar:CreateTexture(nil, "BACKGROUND")
        bar.SafeZone:SetColorTexture(0.8, 0, 0, 0.5)
        bar.SafeZone:Hide()
    end

    bar.key = key
    bar.unit = unit
    bar.castState = nil
    bar._defaultColor = {1, 1, 1, 1}

    bar:HookScript("OnShow", function(self)
        if CB.isUnlocked then return end
        if not self.castState then
            self:Hide()
        end
    end)

    self.bars[key] = bar
    return bar
end

function CB:UpdateBarLayout(key)
    local bar = self.bars[key]
    local dbAll = self:GetDB()
    if not dbAll then return end

    local db = dbAll[key]
    if not bar or not db then return end

    if not (dbAll.global and dbAll.global.enabled) then
        bar:Hide()
        return
    end

    if not db.enabled and not self.isUnlocked then
        bar:Hide()
        return
    end

    local tex = dbAll.global.texture or "Interface\\Buttons\\WHITE8x8"

    bar:SetStatusBarTexture(tex)
    if bar.ShieldBar then
        bar.ShieldBar:SetStatusBarTexture(tex)
    end

    bar:SetSize(db.width, db.height)
    if bar.TextHolder then
        bar.TextHolder:SetAllPoints(bar)
    end

    self:ApplyOrientation(bar, key, db)

    local pluginId = bar.__gridPluginId
    local attachedToGrid = (type(pluginId) == "string" and pluginId ~= "" and self:GridIsAttached(pluginId)) and true or false

    if not attachedToGrid then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", db.x, db.y)
    end

    if type(db.color) == "table" then
        bar._defaultColor = db.color
        bar:SetStatusBarColor(unpack(db.color))
    else
        bar._defaultColor = {1, 1, 1, 1}
        bar:SetStatusBarColor(1, 1, 1, 1)
    end

    if bar.ShieldBar then
        local sc = db.shieldColor or {0.5, 0.5, 0.5, 1}
        bar.ShieldBar:SetStatusBarColor(sc[1] or 0.5, sc[2] or 0.5, sc[3] or 0.5, sc[4] or 1)
    end

    local iconSize = self:ComputeIconSize(key, db)
    if db.showIcon or self.isUnlocked then
        bar.Icon:Show()
        bar.iconBorder:Show()
        bar.Icon:ClearAllPoints()
        bar.iconBorder:ClearAllPoints()
        bar.Icon:SetSize(iconSize, iconSize)
        bar.iconBorder:SetSize(iconSize, iconSize)
        bar.Icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
        bar.iconBorder:SetPoint("CENTER", bar.Icon, "CENTER", 0, 0)
    else
        bar.Icon:Hide()
        bar.iconBorder:Hide()
    end

    if bar.SafeZone then
        bar.SafeZone:Hide()
    end

    local font = dbAll.global.font or "Fonts\\FRIZQT__.TTF"
    local tSize = tonumber(db.textSize)
    if type(tSize) ~= "number" then tSize = 11 end
    local tiSize = tonumber(db.timeSize)
    if type(tiSize) ~= "number" then tiSize = tSize end

    tSize = max(6, min(32, floor(tSize + 0.5)))
    tiSize = max(6, min(32, floor(tiSize + 0.5)))

    bar.Text:SetFont(font, tSize, "OUTLINE")
    bar.Time:SetFont(font, tiSize, "OUTLINE")
    self:ApplyTextLayout(bar, key, db)

    if self.isUnlocked then
        bar:Show()
        bar:SetAlpha(1)
        bar:SetValue(1)
        self:SafeSetText(bar.Text, key:upper(), key:upper())
        self:SafeSetText(bar.Time, attachedToGrid and "rgrid" or "Move Me", "Move Me")
        if bar.Spark then bar.Spark:Hide() end
        self:SafeSetTexture(bar.Icon, 134400)
        bar:EnableMouse(not attachedToGrid)
        self:HideEmpowerVisuals(bar)

        if bar.ShieldBar then
            -- Player bars should never show shield
            if bar.unit == "player" then
                bar.ShieldBar:SetAlpha(0)
            else
                bar.ShieldBar:SetAlpha(1)
            end
        end
        return
    end

    bar:EnableMouse(false)

    if not bar.castState then
        if bar.ShieldBar then
            bar.ShieldBar:SetAlpha(0)
        end
        bar:Hide()
        self:HideEmpowerVisuals(bar)
        return
    end

    if bar.castState.kind == "empower" then
        self:LayoutEmpower4Segments(bar)
    else
        self:HideEmpowerVisuals(bar)
    end

    -- Safety: player bars should never show shield from layout side either
    if bar.ShieldBar and bar.unit == "player" then
        bar.ShieldBar:SetAlpha(0)
    end
end

function CB:BuildAllBars()
    self:CreateCastbarFrame("player", "player")
    self:CreateCastbarFrame("player_mini", "player")
    self:CreateCastbarFrame("player_extra", "player")
    self:CreateCastbarFrame("target", "target")
    self:CreateCastbarFrame("target_mini", "target")
    self:CreateCastbarFrame("target_extra", "target")
end
