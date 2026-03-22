local ADDON_NAME, ns = ...
local CB = ns.CB

local tonumber = tonumber
local pcall = pcall
local type = type
local floor = math.floor
local max = math.max
local min = math.min

function CB:Clamp01(x)
    x = tonumber(x) or 0
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

function CB:SafeSetText(fs, txt, fallback)
    if not fs then return end
    local ok = pcall(fs.SetText, fs, txt)
    if not ok and fallback ~= nil then
        pcall(fs.SetText, fs, fallback)
    end
end

function CB:SafeSetTexture(tex, val)
    if not tex then return end
    pcall(tex.SetTexture, tex, val)
end

function CB:SafeSetCastText(fs, primary, secondary, fallback)
    if not fs then return end

    if primary ~= nil then
        local ok = pcall(fs.SetText, fs, primary)
        if ok then return end
        ok = pcall(fs.SetFormattedText, fs, "%s", primary)
        if ok then return end
    end

    if secondary ~= nil then
        local ok = pcall(fs.SetText, fs, secondary)
        if ok then return end
        ok = pcall(fs.SetFormattedText, fs, "%s", secondary)
        if ok then return end
    end

    if fallback ~= nil then
        local ok = pcall(fs.SetText, fs, fallback)
        if ok then return end
        pcall(fs.SetFormattedText, fs, "%s", fallback)
    end
end

function CB:IsExtraKey(key)
    return key == "player_extra" or key == "target_extra"
end

function CB:IsVerticalKey(key)
    if not self:IsExtraKey(key) then return false end
    local dbAll = self:GetDB()
    local db = dbAll and dbAll[key]
    return (db and db.vertical) and true or false
end

function CB:ComputeIconSize(key, db)
    local vertical = (self:IsExtraKey(key) and db and db.vertical) and true or false
    local override = tonumber(db.iconSize) or 0
    if override > 0 then
        return max(4, floor(override + 0.5))
    end
    if vertical then
        return max(4, floor((tonumber(db.width) or 14) + 0.5))
    end
    return max(4, floor((tonumber(db.height) or 14) + 0.5))
end

function CB:CreateSafeBorder(parent, inset, edge, bgRGBA, borderRGBA)
    if parent.__bg then return end

    inset = inset or 0
    edge = edge or 1
    bgRGBA = bgRGBA or {0.1, 0.1, 0.1, 0.9}
    borderRGBA = borderRGBA or {0, 0, 0, 1}

    local bg = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    bg:SetVertexColor(bgRGBA[1], bgRGBA[2], bgRGBA[3], bgRGBA[4])
    parent.__bg = bg

    local function MakeEdge()
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetVertexColor(borderRGBA[1], borderRGBA[2], borderRGBA[3], borderRGBA[4])
        return t
    end

    local top = MakeEdge()
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    top:SetHeight(edge)

    local bot = MakeEdge()
    bot:SetPoint("BOTTOMLEFT", 0, 0)
    bot:SetPoint("BOTTOMRIGHT", 0, 0)
    bot:SetHeight(edge)

    local left = MakeEdge()
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(edge)

    local right = MakeEdge()
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(edge)

    parent.__bTop, parent.__bBot, parent.__bLeft, parent.__bRight = top, bot, left, right
end

function CB:CreateFontString(parent, align, size)
    local db = self:GetDB()
    local font = (db and db.global and db.global.font) or "Fonts\\FRIZQT__.TTF"
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size or 10, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(align or "LEFT")
    fs:SetWordWrap(false)
    return fs
end