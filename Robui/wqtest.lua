-- Robui/wqtest.lua
-- Visible item reward icons on World Quest pins (ONLY item rewards).
-- Non-item WQs are untouched and remain fully clickable.
--
-- Slash:
--   /rwq
--
-- Saved in RobUI profile DB:
--   R.Database.profile.wqtest.enabled

local ADDON, ns = ...
local f = CreateFrame("Frame")

local dirty = false
local TOOLTIP_SCALE = 0.80

-- Visual tuning
local ICON_SIZE   = 28
local BORDER_SIZE = 34
local HIT_SIZE    = 32
local RETRY_TICKS = 12
local RETRY_RATE  = 0.25

local retryTicker = nil

-- ------------------------------------------------------------
-- DB
-- ------------------------------------------------------------
local function GetRobui()
    return _G.Robui
end

local function GetDB()
    local R = GetRobui()
    if R and R.Database and R.Database.profile then
        R.Database.profile.wqtest = R.Database.profile.wqtest or {}
        local db = R.Database.profile.wqtest
        if db.enabled == nil then
            db.enabled = true
        end
        return db
    end

    -- Fallback only if RobUI DB is not ready yet.
    ns._wqtestFallbackDB = ns._wqtestFallbackDB or {}
    if ns._wqtestFallbackDB.enabled == nil then
        ns._wqtestFallbackDB.enabled = true
    end
    return ns._wqtestFallbackDB
end

local function IsEnabled()
    local db = GetDB()
    return db.enabled == true
end

local function SetEnabled(v)
    local db = GetDB()
    db.enabled = v and true or false
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f2, g, h, i, j = pcall(fn, ...)
    if not ok then return end
    return a, b, c, d, e, f2, g, h, i, j
end

local function Tooltip_SetScaled(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetScale(TOOLTIP_SCALE)
end

local function Tooltip_Reset()
    GameTooltip:Hide()
    GameTooltip:SetScale(1)
end

local function GetRewardItemLink(questID)
    local link = SafeCall(GetQuestLogItemLink, "reward", 1, questID)
    if link then return link end

    link = SafeCall(GetQuestLogItemLink, "reward", 1)
    return link
end

local function EnsureRewardCache(questID)
    if type(HaveQuestRewardData) == "function" and not HaveQuestRewardData(questID) then
        if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then
            C_TaskQuest.RequestPreloadRewardData(questID)
        end
        return false
    end
    return true
end

local function HasItemReward(questID)
    if not questID then return false end
    if not EnsureRewardCache(questID) then return false end

    local link = GetRewardItemLink(questID)
    if link then
        return true
    end

    local num = SafeCall(GetNumQuestLogRewards, questID) or 0
    if num > 0 then
        local _, texture = SafeCall(GetQuestLogRewardInfo, 1, questID)
        if texture then
            return true
        end
    end

    return false
end

local function GetItemIconTexture(questID)
    if not questID then return nil end
    if not EnsureRewardCache(questID) then return nil end

    local num = SafeCall(GetNumQuestLogRewards, questID) or 0
    if num > 0 then
        local _, texture, count = SafeCall(GetQuestLogRewardInfo, 1, questID)
        if texture then
            local countText = (type(count) == "number" and count > 1) and tostring(count) or nil
            return texture, countText
        end
    end

    return nil
end

local function EnsureVisuals(pin)
    if pin.__robui_itemRewardIcon then
        return pin.__robui_itemRewardIcon, pin.__robui_itemRewardText, pin.__robui_itemRewardHit
    end

    local tex = pin:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetPoint("CENTER", pin, "CENTER", 0, 0)
    tex:SetSize(ICON_SIZE, ICON_SIZE)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tex:SetAlpha(1)
    tex:Hide()

    local border = pin:CreateTexture(nil, "OVERLAY", nil, 7)
    border:SetPoint("CENTER", tex, "CENTER", 0, 0)
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    border:SetAlpha(1)
    border:Hide()

    local txt = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOP", tex, "BOTTOM", 0, -2)
    txt:SetJustifyH("CENTER")
    txt:SetText("")
    txt:Hide()

    local hit = CreateFrame("Button", nil, pin)
    hit:SetSize(HIT_SIZE, HIT_SIZE)
    hit:SetPoint("CENTER", tex, "CENTER", 0, 0)
    hit:EnableMouse(false)
    hit:Hide()

    hit:SetScript("OnEnter", function(self)
        local qid = pin and pin.questID
        if not qid then return end

        local link = GetRewardItemLink(qid)
        if not link then return end

        Tooltip_SetScaled(self)
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)

    hit:SetScript("OnLeave", function()
        Tooltip_Reset()
    end)

    pin.__robui_itemRewardIcon = tex
    pin.__robui_itemRewardBorder = border
    pin.__robui_itemRewardText = txt
    pin.__robui_itemRewardHit = hit

    return tex, txt, hit
end

local function ClearPin(pin)
    if not pin then return end

    if pin.__robui_itemRewardIcon then
        pin.__robui_itemRewardIcon:Hide()
    end

    if pin.__robui_itemRewardBorder then
        pin.__robui_itemRewardBorder:Hide()
    end

    if pin.__robui_itemRewardText then
        pin.__robui_itemRewardText:SetText("")
        pin.__robui_itemRewardText:Hide()
    end

    if pin.__robui_itemRewardHit then
        pin.__robui_itemRewardHit:EnableMouse(false)
        pin.__robui_itemRewardHit:Hide()
    end
end

local function DecoratePinIfItem(pin)
    if not pin or not pin.questID then return end
    if not IsEnabled() then return end

    local questID = pin.questID
    if not HasItemReward(questID) then return end

    local texPath, countText = GetItemIconTexture(questID)
    if not texPath then return end

    local icon, txt, hit = EnsureVisuals(pin)

    local baseLevel = pin:GetFrameLevel() or 1
    icon:SetDrawLayer("OVERLAY", 7)

    if pin.__robui_itemRewardBorder then
        pin.__robui_itemRewardBorder:SetDrawLayer("OVERLAY", 7)
    end

    if txt then
        txt:SetDrawLayer("OVERLAY", 7)
    end

    hit:SetFrameLevel(baseLevel + 50)

    icon:SetTexture(texPath)
    icon:Show()

    if pin.__robui_itemRewardBorder then
        pin.__robui_itemRewardBorder:Show()
    end

    if countText then
        txt:SetText(countText)
        txt:Show()
    else
        txt:SetText("")
        txt:Hide()
    end

    hit:Show()
    hit:EnableMouse(true)
end

local function ClearAllPins()
    if not WorldMapFrame or not WorldMapFrame.EnumeratePinsByTemplate then return end

    for pin in WorldMapFrame:EnumeratePinsByTemplate("WorldMap_WorldQuestPinTemplate") do
        ClearPin(pin)
    end
end

local function RefreshPins()
    dirty = false

    if not WorldMapFrame or not WorldMapFrame.EnumeratePinsByTemplate then
        return
    end

    for pin in WorldMapFrame:EnumeratePinsByTemplate("WorldMap_WorldQuestPinTemplate") do
        ClearPin(pin)
        if IsEnabled() then
            DecoratePinIfItem(pin)
        end
    end
end

local function StopRetry()
    if retryTicker then
        retryTicker:Cancel()
        retryTicker = nil
    end
end

local function StartRetryWhileMapOpen()
    StopRetry()

    if not IsEnabled() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local ticks = 0
    retryTicker = C_Timer.NewTicker(RETRY_RATE, function()
        if not IsEnabled() then
            StopRetry()
            ClearAllPins()
            return
        end

        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            StopRetry()
            return
        end

        ticks = ticks + 1
        RefreshPins()

        if ticks >= RETRY_TICKS then
            StopRetry()
        end
    end)
end

local function MarkDirty()
    if not IsEnabled() then
        dirty = false
        StopRetry()
        ClearAllPins()
        return
    end

    if dirty then return end
    dirty = true

    C_Timer.After(0.05, function()
        if dirty and IsEnabled() then
            RefreshPins()
            StartRetryWhileMapOpen()
        end
    end)
end

-- ------------------------------------------------------------
-- Slash
-- ------------------------------------------------------------
SLASH_ROBUIWQ1 = "/rwq"
SlashCmdList["ROBUIWQ"] = function(msg)
    msg = tostring(msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "on" then
        SetEnabled(true)
    elseif msg == "off" then
        SetEnabled(false)
    else
        SetEnabled(not IsEnabled())
    end

    if IsEnabled() then
        print("|cff33ff99RobUI|r WQ item rewards: |cff00ff00ON|r")
        MarkDirty()
    else
        print("|cff33ff99RobUI|r WQ item rewards: |cffff3333OFF|r")
        StopRetry()
        ClearAllPins()
    end
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            local db = GetDB()
            if db.enabled == nil then
                db.enabled = true
            end
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if WorldMapFrame then
            WorldMapFrame:HookScript("OnShow", function()
                if IsEnabled() then
                    MarkDirty()
                    StartRetryWhileMapOpen()
                end
            end)

            WorldMapFrame:HookScript("OnHide", function()
                StopRetry()
                Tooltip_Reset()
            end)

            if WorldMapFrame.RefreshAllDataProviders then
                hooksecurefunc(WorldMapFrame, "RefreshAllDataProviders", function()
                    if IsEnabled() then
                        MarkDirty()
                    end
                end)
            end
        end

        if IsEnabled() then
            MarkDirty()
        else
            ClearAllPins()
        end
        return
    end

    if IsEnabled() then
        MarkDirty()
    else
        StopRetry()
        ClearAllPins()
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_DATA_LOAD_RESULT")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")