-- Modules/CharacterStats.lua
local ADDON_NAME, ns = ...
local R = _G.Robui
ns.stats = {}

-- === Configuration & Skinning ===
local SKIN = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    panelBg = {0.05, 0.05, 0.05, 0.85},
    panelBorder = {0.2, 0.2, 0.2, 1},
    barBg = {0.15, 0.15, 0.15, 0.5},
    targetLine = {1, 0.85, 0, 1}, -- Gull farge for target marker
}

local BAR_W, BAR_H, SPACING = 34, 140, 10
local ORDER = {"Crit", "Haste", "Mastery", "Versatility", "Avoidance", "Leech", "Speed"}
local ABBR = { Crit="Crit", Haste="Hast", Mastery="Mast", Versatility="Vers", Avoidance="Avoi", Leech="Leec", Speed="Spd" }
local COLORS = {
    Crit        = {0.8, 0.2, 0.2}, Haste       = {0.2, 0.8, 0.2}, Mastery     = {0.2, 0.6, 1.0},
    Versatility = {1.0, 0.8, 0.2}, Leech       = {0.7, 0.4, 1.0}, Avoidance   = {0.4, 1.0, 1.0},
    Speed       = {1.0, 0.5, 0.3},
}

-- === Helper Functions ===
local function IsCasterClass(class)
    return class == "MAGE" or class == "PRIEST" or class == "WARLOCK" or class == "DRUID" or class == "SHAMAN"
end

local SPELL_SCHOOL_MAP = {
    ARCANE = 7, FIRE = 3, FROST = 5,
    AFFLICTION = 6, DEMONOLOGY = 6, DESTRUCTION = 6,
    BALANCE = 5, ELEMENTAL = 4,
}

local function FetchCrit()
    local _, class = UnitClass("player")
    if IsCasterClass(class) then
        local spec = GetSpecialization()
        local name = spec and select(2, GetSpecializationInfo(spec)):upper() or ""
        local school = SPELL_SCHOOL_MAP[name] or 7
        return GetSpellCritChance(school) or 0
    else
        return GetCritChance() or 0
    end
end

-- === Numeric Panel ===
function ns.stats:CreateNumericPanel()
    if self.numFrame then return end
    local f = CreateFrame("Frame", "RobUIStatsPanel", CharacterFrame, "BackdropTemplate")
    self.numFrame = f
    f:SetSize(170, 155)
    f:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 335, -18)

    f:SetBackdrop({ bgFile = SKIN.bgFile, edgeFile = SKIN.edgeFile, edgeSize = SKIN.edgeSize })
    f:SetBackdropColor(unpack(SKIN.panelBg))
    f:SetBackdropBorderColor(unpack(SKIN.panelBorder))

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Detailed Stats")
    title:SetTextColor(1, 0.82, 0)

    self.numLines = {}
    for i, stat in ipairs(ORDER) do
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 12, -35 - (i-1)*16)
        label:SetText(stat..":")
        label:SetTextColor(0.8, 0.8, 0.8)

        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        val:SetPoint("CENTER", label, "CENTER", 0, 0)

        self.numLines[stat] = val
    end

    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("COMBAT_RATING_UPDATE")
    f:SetScript("OnEvent", function() self:UpdateNumeric() end)
    self:UpdateNumeric()
end

function ns.stats:UpdateNumeric()
    local fetchers = {
        Crit = FetchCrit,
        Haste = GetHaste,
        Mastery = function() return select(1, GetMasteryEffect()) or 0 end,
        Versatility = function()
            return (C_PaperDollInfo and C_PaperDollInfo.GetVersatilityDamageBonus and C_PaperDollInfo.GetVersatilityDamageBonus())
            or GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
        end,
        Leech = GetLifesteal,
        Avoidance = GetAvoidance,
        Speed = function() return GetCombatRatingBonus(CR_SPEED) end,
    }

    for stat, fontString in pairs(self.numLines) do
        local val = fetchers[stat]() or 0
        fontString:SetText(string.format("%.2f%%", val))
    end
end

-- === Bar Panel ===
function ns.stats:CreateBarPanel()
    if self.barFrame then return end
    local f = CreateFrame("Frame", "RobUIStatsBarPanel", CharacterFrame, "BackdropTemplate")
    self.barFrame = f
    f:SetSize(#ORDER * (BAR_W + SPACING) + 25, BAR_H + 85)
    f:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", 10, 10)

    f:SetBackdrop({ bgFile = SKIN.bgFile, edgeFile = SKIN.edgeFile, edgeSize = SKIN.edgeSize })
    f:SetBackdropColor(unpack(SKIN.panelBg))
    f:SetBackdropBorderColor(unpack(SKIN.panelBorder))

    self.barTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.barTitle:SetPoint("TOPLEFT", 15, -12)

    self.currentBars, self.targetMarkers, self.targetLabels, self.currentLabels = {}, {}, {}, {}

    for i, stat in ipairs(ORDER) do
        local xOffset = 15 + (i-1) * (BAR_W + SPACING)

        -- Bar Background
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(BAR_W, BAR_H)
        bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", xOffset, 30)
        bg:SetColorTexture(unpack(SKIN.barBg))

        -- Name Label
        local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("TOP", bg, "BOTTOM", 0, -4)
        name:SetText(ABBR[stat])
        name:SetTextColor(0.7, 0.7, 0.7)

        -- Current Value Bar
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(BAR_W)
        bar:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
        local col = COLORS[stat]
        bar:SetColorTexture(col[1], col[2], col[3], 0.9)
        self.currentBars[stat] = bar

        -- Target Marker
        local marker = f:CreateTexture(nil, "OVERLAY")
        marker:SetSize(BAR_W + 4, 2)
        marker:SetColorTexture(unpack(SKIN.targetLine))
        self.targetMarkers[stat] = marker

        -- Labels
        local tLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tLabel:SetPoint("BOTTOM", bg, "TOP", 0, 14)
        tLabel:SetTextColor(1, 0.85, 0)
        self.targetLabels[stat] = tLabel

        local cLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cLabel:SetPoint("TOP", bg, "BOTTOM", 0, -16)
        self.currentLabels[stat] = cLabel
    end

    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function() self:UpdateBar() end)
end

function ns.stats:UpdateBar()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    if not spec then return end
    local _, specRaw = GetSpecializationInfo(spec)
    if not specRaw then return end

    -- Bruk ns.stats_data i stedet for stats_mplus
    local classKey = class:upper():gsub("DEATHKNIGHT", "DEATH_KNIGHT"):gsub("DEMONHUNTER", "DEMON_HUNTER")
    local getterKey = "Get_" .. classKey .. "_" .. specRaw:upper():gsub("%s", "_")
    local getter = ns.stats_data and ns.stats_data[getterKey]

    self.barTitle:SetText(specRaw .. " Goals")

    local fetchers = {
        Crit = FetchCrit, Haste = GetHaste,
        Mastery = function() return select(1, GetMasteryEffect()) or 0 end,
        Versatility = function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0 end,
        Leech = GetLifesteal, Avoidance = GetAvoidance, Speed = function() return GetCombatRatingBonus(CR_SPEED) end,
    }

    for i, stat in ipairs(ORDER) do
        local currentPct = fetchers[stat]() or 0
        local bar = self.currentBars[stat]
        bar:SetHeight(math.max(1, (currentPct/100) * BAR_H))
        self.currentLabels[stat]:SetText(math.floor(currentPct).."%")

        local key = (stat == "Crit") and "Strike" or stat
        local marker = self.targetMarkers[stat]
        local tLabel = self.targetLabels[stat]

        if type(getter) == "function" then
            local targets = getter()
            local targetPct = (targets[key] and targets[key].percent) or 0

            if targetPct > 0 then
                marker:SetPoint("CENTER", bar:GetParent(), "BOTTOMLEFT", 15 + (i-1)*(BAR_W+SPACING) + (BAR_W/2), 30 + (targetPct/100)*BAR_H)
                marker:Show()
                tLabel:SetText(math.floor(targetPct).."%")
                tLabel:Show()
            else
                marker:Hide() tLabel:Hide()
            end
        else
            marker:Hide() tLabel:Hide()
        end
    end
    self.barFrame:Show()
end

-- === Loader ===
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- Hook CharacterFrame to show these panels when the user opens their character sheet
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            ns.stats:CreateNumericPanel()
            ns.stats:CreateBarPanel()
            ns.stats:UpdateBar()
            ns.stats:UpdateNumeric()
        end)
    end
end)