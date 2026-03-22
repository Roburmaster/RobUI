local ADDON_NAME, ns = ...
local CB = ns.CB

local ipairs = ipairs

local EMPOWER_SEGMENT_COLORS = {
    { r = 0.30, g = 0.80, b = 1.00, a = 0.22 },
    { r = 0.45, g = 1.00, b = 0.45, a = 0.22 },
    { r = 1.00, g = 0.92, b = 0.25, a = 0.22 },
    { r = 1.00, g = 0.45, b = 0.20, a = 0.22 },
}

local EMPOWER_SEP_COLOR = { r = 0, g = 0, b = 0, a = 0.35 }
local EMPOWER_SEP_WIDTH = 1

function CB:EnsureEmpowerVisuals(bar)
    if bar.__empower then return end

    bar.__empower = {}
    bar.__empower.baseSeg = {}

    for i = 1, 4 do
        local t = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:Hide()
        bar.__empower.baseSeg[i] = t
    end

    bar.__empower.baseSep = {}
    for i = 1, 3 do
        local s = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        s:SetTexture("Interface\\Buttons\\WHITE8x8")
        s:SetVertexColor(EMPOWER_SEP_COLOR.r, EMPOWER_SEP_COLOR.g, EMPOWER_SEP_COLOR.b, EMPOWER_SEP_COLOR.a)
        s:Hide()
        bar.__empower.baseSep[i] = s
    end
end

function CB:HideEmpowerVisuals(bar)
    if not bar.__empower then return end
    local e = bar.__empower

    if e.baseSeg then
        for _, t in ipairs(e.baseSeg) do
            t:Hide()
        end
    end

    if e.baseSep then
        for _, s in ipairs(e.baseSep) do
            s:Hide()
        end
    end
end

function CB:LayoutEmpower4Segments(bar)
    self:EnsureEmpowerVisuals(bar)

    local e = bar.__empower
    local W = bar:GetWidth() or 0
    local H = bar:GetHeight() or 0
    if W <= 0 or H <= 0 then return end

    local segW = W * 0.25

    for i = 1, 4 do
        local t = e.baseSeg[i]
        local c = EMPOWER_SEGMENT_COLORS[i]
        t:SetVertexColor(c.r, c.g, c.b, c.a or 0.22)
        t:SetWidth(segW)
        t:SetHeight(H)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * segW, 0)
        t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * segW, 0)
        t:Show()
    end

    for i = 1, 3 do
        local s = e.baseSep[i]
        local px = i * segW
        s:SetWidth(EMPOWER_SEP_WIDTH)
        s:SetHeight(H)
        s:ClearAllPoints()
        s:SetPoint("TOP", bar, "TOPLEFT", px, 0)
        s:SetPoint("BOTTOM", bar, "BOTTOMLEFT", px, 0)
        s:Show()
    end
end

function CB:ApplyTextLayout(bar, key, db)
    if not (bar and bar.Text and bar.Time and bar.TextHolder) then return end

    bar.Text:ClearAllPoints()
    bar.Time:ClearAllPoints()

    local isExtra = self:IsExtraKey(key)
    local vertical = (isExtra and db and db.vertical) and true or false

    local tx = (isExtra and tonumber(db.textX)) or 0
    local ty = (isExtra and tonumber(db.textY)) or 0
    local timex = (isExtra and tonumber(db.timeX)) or 0
    local timey = (isExtra and tonumber(db.timeY)) or 0

    if isExtra then
        local tbw = tonumber(db.textBoxW) or 160
        local tbh = tonumber(db.textBoxH) or 18
        local mbw = tonumber(db.timeBoxW) or 60
        local mbh = tonumber(db.timeBoxH) or 18

        tbw = math.max(20, math.floor(tbw + 0.5))
        tbh = math.max(8, math.floor(tbh + 0.5))
        mbw = math.max(20, math.floor(mbw + 0.5))
        mbh = math.max(8, math.floor(mbh + 0.5))

        bar.Text:SetWidth(tbw)
        bar.Text:SetHeight(tbh)
        bar.Time:SetWidth(mbw)
        bar.Time:SetHeight(mbh)

        if vertical then
            bar.Text:SetJustifyH("CENTER")
            bar.Time:SetJustifyH("CENTER")
            bar.Text:SetPoint("CENTER", bar.TextHolder, "CENTER", tx, ty)
            bar.Time:SetPoint("CENTER", bar.TextHolder, "CENTER", timex, timey)
        else
            bar.Text:SetJustifyH("LEFT")
            bar.Time:SetJustifyH("RIGHT")
            bar.Text:SetPoint("LEFT", bar.TextHolder, "LEFT", 4 + tx, ty)
            bar.Time:SetPoint("RIGHT", bar.TextHolder, "RIGHT", -4 + timex, timey)
        end
        return
    end

    bar.Text:SetJustifyH("LEFT")
    bar.Time:SetJustifyH("RIGHT")
    bar.Text:SetPoint("LEFT", bar.TextHolder, "LEFT", 4, 0)
    bar.Time:SetPoint("RIGHT", bar.TextHolder, "RIGHT", -4, 0)
    bar.Text:SetWidth(160)
end

function CB:ApplyOrientation(bar, key, db)
    if not bar then return end
    local vertical = (self:IsExtraKey(key) and db and db.vertical) and true or false

    if vertical then
        pcall(bar.SetOrientation, bar, "VERTICAL")
        if bar.ShieldBar then
            pcall(bar.ShieldBar.SetOrientation, bar.ShieldBar, "VERTICAL")
        end
    else
        pcall(bar.SetOrientation, bar, "HORIZONTAL")
        if bar.ShieldBar then
            pcall(bar.ShieldBar.SetOrientation, bar.ShieldBar, "HORIZONTAL")
        end
    end
end