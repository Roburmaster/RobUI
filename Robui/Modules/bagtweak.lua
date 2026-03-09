local addonName = ...

-- =========================================================
-- SOB: Last Items + Bag Flash + Settings (NO SLASH)
-- PERF FIX:
--  - Remove permanent OnUpdate ticker
--  - Start glow updates ONLY while:
--      * Combined bags shown
--      * glowEnabled
--      * glowTargets not empty
--  - Stop ticker automatically when not needed
--  - Avoid rebuilding real button map every refresh unless needed
-- =========================================================

_G.SimpleOneBagDB = _G.SimpleOneBagDB or {}
local DB = _G.SimpleOneBagDB
DB.opts = DB.opts or {
    enabled = true,
    feedTTL = 300,
    glowTTL = 300,
    glowEnabled = true,
}

local FEED_MAX = 5
local C_Container = C_Container
local C_CVar = C_CVar

local combined
local feedFrame
local feedRows = {}
local feedData = {}          -- newest first
local realBtnByKey = {}      -- ["bag:slot"] = real button

local prevCounts = {}
local curCounts  = {}

local glowTargets = {}       -- ["bag:slot"] = expireTime

local settingsBtn
local settingsFrame

-- -----------------------------
-- Helpers
-- -----------------------------
local function wipeTable(t) for k in pairs(t) do t[k] = nil end end
local function Key(bag, slot) return tostring(bag) .. ":" .. tostring(slot) end

local function ForceCombinedBags()
    if C_CVar and C_CVar.GetCVarBool and C_CVar.SetCVar then
        if not C_CVar.GetCVarBool("combinedBags") then
            C_CVar.SetCVar("combinedBags", "1")
        end
    end
end

local function EnsureCombined()
    combined = _G.ContainerFrameCombinedBags
    return combined ~= nil
end

local function ClampSeconds(v, fallback)
    v = tonumber(v)
    if not v then return fallback end
    if v < 1 then v = 1 end
    if v > 3600 then v = 3600 end
    return math.floor(v + 0.5)
end

local function FindSlotForItemID(itemID)
    if not itemID or not C_Container then return nil end
    for bag = 0, 5 do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return bag, slot, info.hyperlink, info.iconFileID
            end
        end
    end
    return nil
end

-- -----------------------------
-- Real button mapping (CombinedBags)
-- PERF: rebuild only when pool may have changed
-- -----------------------------
local lastMapStamp = 0
local function RebuildRealButtonMap()
    wipeTable(realBtnByKey)
    if not EnsureCombined() then return end
    if not combined.itemButtonPool then return end

    for btn in combined.itemButtonPool:EnumerateActive() do
        if btn and btn.GetBagID and btn.GetID then
            local bag = btn:GetBagID()
            local slot = btn:GetID()
            if bag and slot then
                realBtnByKey[Key(bag, slot)] = btn
            end
        end
    end
    lastMapStamp = GetTime()
end

-- -----------------------------
-- Glow overlay on REAL bag button
-- -----------------------------
local function EnsureGlow(btn)
    if btn.SOBGlow then return end

    local g = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    g:SetSize(btn:GetWidth() * 1.8, btn:GetHeight() * 1.8)
    g:SetAlpha(0)
    btn.SOBGlow = g
end

local function HasGlowTargets()
    for _ in pairs(glowTargets) do return true end
    return false
end

-- -----------------------------
-- Glow driver (PERF: only runs when needed)
-- -----------------------------
local glowDriver = CreateFrame("Frame")
glowDriver.__running = false
glowDriver.__acc = 0

local function StopGlowUpdates()
    if glowDriver.__running then
        glowDriver.__running = false
        glowDriver:SetScript("OnUpdate", nil)
    end
end

local function StartGlowUpdates()
    if glowDriver.__running then return end
    glowDriver.__running = true
    glowDriver.__acc = 0

    glowDriver:SetScript("OnUpdate", function(self, elapsed)
        self.__acc = (self.__acc or 0) + (elapsed or 0)
        if self.__acc < 0.10 then return end
        self.__acc = 0

        -- Stop conditions
        if not DB.opts.enabled or not DB.opts.glowEnabled then
            StopGlowUpdates()
            return
        end
        if not EnsureCombined() or not (combined and combined:IsShown()) then
            StopGlowUpdates()
            return
        end
        if not HasGlowTargets() then
            StopGlowUpdates()
            return
        end

        -- Do the work
        local now = GetTime()
        if not combined.itemButtonPool then return end

        for btn in combined.itemButtonPool:EnumerateActive() do
            if btn and btn.GetBagID and btn.GetID then
                local bag = btn:GetBagID()
                local slot = btn:GetID()
                local k = (bag and slot) and Key(bag, slot) or nil

                if k and glowTargets[k] then
                    local exp = glowTargets[k]
                    if exp > now then
                        EnsureGlow(btn)
                        local a = 0.35 + 0.60 * (0.5 + 0.5 * math.sin(now * 6))
                        btn.SOBGlow:SetAlpha(a)
                    else
                        glowTargets[k] = nil
                        if btn.SOBGlow then btn.SOBGlow:SetAlpha(0) end
                    end
                else
                    if btn.SOBGlow then btn.SOBGlow:SetAlpha(0) end
                end
            end
        end

        -- If we just expired the last one, stop next tick
        if not HasGlowTargets() then
            StopGlowUpdates()
        end
    end)
end

local function ClearAllGlows()
    if EnsureCombined() and combined.itemButtonPool then
        for btn in combined.itemButtonPool:EnumerateActive() do
            if btn and btn.SOBGlow then
                btn.SOBGlow:SetAlpha(0)
            end
        end
    end
end

-- -----------------------------
-- Feed UI (PARENTED TO combined!)
-- -----------------------------
local function CreateFeed()
    if feedFrame then return end
    if not EnsureCombined() then return end

    feedFrame = CreateFrame("Frame", "SOB_LastItemsFeed", combined, "BackdropTemplate")
    feedFrame:SetSize(320, 24 + FEED_MAX * 20)
    feedFrame:SetFrameLevel((combined:GetFrameLevel() or 1) + 90)

    feedFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 }
    })
    feedFrame:SetBackdropColor(0,0,0,0.60)

    local title = feedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText("Last items")

    for i = 1, FEED_MAX do
        local btn = CreateFrame("Button", "SOB_FeedRow"..i, feedFrame, "SecureActionButtonTemplate")
        btn:SetSize(300, 18)
        btn:SetPoint("TOPLEFT", 8, -6 - (i * 20))
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetAlpha(0)

        btn.icon = btn:CreateTexture(nil, "OVERLAY")
        btn.icon:SetSize(16, 16)
        btn.icon:SetPoint("LEFT", 0, 0)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
        btn.text:SetJustifyH("LEFT")

        btn.itemLink = nil
        btn:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        feedRows[i] = btn
    end

    feedFrame:SetAlpha(0)
end

local function AnchorFeed()
    if not feedFrame or not combined then return end
    feedFrame:ClearAllPoints()
    feedFrame:SetPoint("TOPRIGHT", combined, "TOPLEFT", -8, -40)
end

-- -----------------------------
-- Secure forward (click REAL bag button)
-- -----------------------------
local function ApplySecureForward(feedBtn, realBtn)
    if InCombatLockdown() then return end

    if not realBtn then
        feedBtn:SetAttribute("type", nil)
        feedBtn:SetAttribute("clickbutton", nil)
        feedBtn:SetAttribute("type2", nil)
        feedBtn:SetAttribute("clickbutton2", nil)
        return
    end

    feedBtn:SetAttribute("type", "click")
    feedBtn:SetAttribute("clickbutton", realBtn)
    feedBtn:SetAttribute("type2", "click")
    feedBtn:SetAttribute("clickbutton2", realBtn)
end

-- -----------------------------
-- Feed refresh
-- -----------------------------
local function RefreshFeed()
    if not feedFrame then return end

    if not DB.opts.enabled then
        feedFrame:SetAlpha(0)
        StopGlowUpdates()
        ClearAllGlows()
        return
    end

    local now = GetTime()

    if combined and combined:IsShown() then
        feedFrame:SetAlpha(1)
    else
        feedFrame:SetAlpha(0)
    end

    local ttl = ClampSeconds(DB.opts.feedTTL, 300)
    local kept = {}
    for _, e in ipairs(feedData) do
        if e and (now - (e.time or 0)) <= ttl then
            kept[#kept + 1] = e
        end
    end
    feedData = kept

    while #feedData > FEED_MAX do
        table.remove(feedData)
    end

    -- PERF: button pool can change when bags update; don't rebuild constantly elsewhere
    RebuildRealButtonMap()

    for i = 1, FEED_MAX do
        local row = feedRows[i]
        local e = feedData[i]

        if e then
            row.itemLink = e.link
            row.icon:SetTexture(e.icon)
            row.text:SetText(e.text or "Item")
            row:SetAlpha(1)

            local rb = realBtnByKey[Key(e.bag, e.slot)]
            ApplySecureForward(row, rb)
        else
            row.itemLink = nil
            row.icon:SetTexture(nil)
            row.text:SetText("")
            row:SetAlpha(0)
            ApplySecureForward(row, nil)
        end
    end

    -- Start/stop glow updates based on actual state
    if DB.opts.glowEnabled and combined and combined:IsShown() and HasGlowTargets() then
        StartGlowUpdates()
    else
        StopGlowUpdates()
    end
end

-- -----------------------------
-- Settings button + frame (ON FEED FRAME)
-- -----------------------------
local function CreateSettingsButton()
    if settingsBtn or not feedFrame then return end

    settingsBtn = CreateFrame("Button", nil, feedFrame, "UIPanelButtonTemplate")
    settingsBtn:SetSize(22, 18)
    settingsBtn:SetText("⚙")
    settingsBtn:SetPoint("TOPRIGHT", feedFrame, "TOPRIGHT", -6, -4)
    settingsBtn:SetFrameLevel(feedFrame:GetFrameLevel() + 5)

    settingsBtn:SetScript("OnClick", function()
        if not settingsFrame then
            settingsFrame = CreateFrame("Frame", nil, feedFrame, "BackdropTemplate")
            settingsFrame:SetSize(240, 140)
            settingsFrame:SetPoint("TOPRIGHT", feedFrame, "TOPLEFT", -6, 0)
            settingsFrame:SetFrameLevel(feedFrame:GetFrameLevel() + 20)

            settingsFrame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left=3, right=3, top=3, bottom=3 }
            })
            settingsFrame:SetBackdropColor(0,0,0,0.8)

            local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOPLEFT", 8, -8)
            title:SetText("Last Items Settings")

            local enable = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
            enable:SetPoint("TOPLEFT", 10, -28)
            enable.text = enable:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            enable.text:SetPoint("LEFT", enable, "RIGHT", 6, 0)
            enable.text:SetText("Enable")
            enable:SetChecked(DB.opts.enabled)

            local glow = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
            glow:SetPoint("TOPLEFT", 10, -52)
            glow.text = glow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            glow.text:SetPoint("LEFT", glow, "RIGHT", 6, 0)
            glow.text:SetText("Flash in bag")
            glow:SetChecked(DB.opts.glowEnabled)

            local feedLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            feedLabel:SetPoint("TOPLEFT", 10, -78)
            feedLabel:SetText("List time (sec):")

            local feedBox = CreateFrame("EditBox", nil, settingsFrame, "InputBoxTemplate")
            feedBox:SetSize(60, 20)
            feedBox:SetPoint("LEFT", feedLabel, "RIGHT", 8, 0)
            feedBox:SetAutoFocus(false)
            feedBox:SetText(tostring(DB.opts.feedTTL or 300))

            local glowLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            glowLabel:SetPoint("TOPLEFT", 10, -102)
            glowLabel:SetText("Flash time (sec):")

            local glowBox = CreateFrame("EditBox", nil, settingsFrame, "InputBoxTemplate")
            glowBox:SetSize(60, 20)
            glowBox:SetPoint("LEFT", glowLabel, "RIGHT", 8, 0)
            glowBox:SetAutoFocus(false)
            glowBox:SetText(tostring(DB.opts.glowTTL or 300))

            local apply = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
            apply:SetSize(60, 22)
            apply:SetText("Apply")
            apply:SetPoint("BOTTOMRIGHT", -8, 8)

            local close = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
            close:SetSize(60, 22)
            close:SetText("Close")
            close:SetPoint("RIGHT", apply, "LEFT", -6, 0)

            close:SetScript("OnClick", function()
                settingsFrame:SetAlpha(0)
            end)

            apply:SetScript("OnClick", function()
                DB.opts.enabled     = enable:GetChecked() and true or false
                DB.opts.glowEnabled = glow:GetChecked() and true or false
                DB.opts.feedTTL     = ClampSeconds(feedBox:GetText(), 300)
                DB.opts.glowTTL     = ClampSeconds(glowBox:GetText(), 300)

                if not DB.opts.glowEnabled then
                    wipeTable(glowTargets)
                    StopGlowUpdates()
                    ClearAllGlows()
                end

                RefreshFeed()
            end)

            settingsFrame._enable  = enable
            settingsFrame._glow    = glow
            settingsFrame._feedBox = feedBox
            settingsFrame._glowBox = glowBox
            settingsFrame:SetAlpha(0)
        end

        if settingsFrame:GetAlpha() > 0.5 then
            settingsFrame:SetAlpha(0)
        else
            settingsFrame._enable:SetChecked(DB.opts.enabled)
            settingsFrame._glow:SetChecked(DB.opts.glowEnabled)
            settingsFrame._feedBox:SetText(tostring(DB.opts.feedTTL or 300))
            settingsFrame._glowBox:SetText(tostring(DB.opts.glowTTL or 300))
            settingsFrame:SetAlpha(1)
        end
    end)
end

-- -----------------------------
-- Snapshot diff (captures purchases)
-- -----------------------------
local function BuildCounts(out)
    wipeTable(out)
    for bag = 0, 5 do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and info.stackCount and info.stackCount > 0 then
                out[info.itemID] = (out[info.itemID] or 0) + info.stackCount
            end
        end
    end
end

local function PushAcquired(itemID, diffCount)
    local bag, slot, link, icon = FindSlotForItemID(itemID)
    if not bag or not slot then return end

    local name = (link and GetItemInfo(link)) or ("Item " .. itemID)
    local text = (diffCount and diffCount > 1) and ("+%d %s"):format(diffCount, name) or ("+ " .. name)

    table.insert(feedData, 1, {
        itemID = itemID,
        bag    = bag,
        slot   = slot,
        link   = link,
        icon   = icon,
        text   = text,
        time   = GetTime(),
    })

    while #feedData > FEED_MAX do
        table.remove(feedData)
    end

    if DB.opts.glowEnabled then
        local glowT = ClampSeconds(DB.opts.glowTTL, 300)
        glowTargets[Key(bag, slot)] = GetTime() + glowT
        if combined and combined:IsShown() then
            StartGlowUpdates()
        end
    end
end

local initialized = false
local function InitSnapshot()
    if initialized then return end
    initialized = true
    BuildCounts(prevCounts)
end

local function DiffAndUpdate()
    if not DB.opts.enabled then return end

    BuildCounts(curCounts)

    for itemID, newCount in pairs(curCounts) do
        local old = prevCounts[itemID] or 0
        local diff = newCount - old
        if diff > 0 then
            PushAcquired(itemID, diff)
        end
    end

    wipeTable(prevCounts)
    for k, v in pairs(curCounts) do
        prevCounts[k] = v
    end

    RefreshFeed()
end

-- -----------------------------
-- Hook combined updates
-- -----------------------------
local function HookCombined()
    if not EnsureCombined() then return end
    if combined.__sobHooked then return end
    combined.__sobHooked = true

    CreateFeed()
    AnchorFeed()
    CreateSettingsButton()

    combined:HookScript("OnShow", function()
        AnchorFeed()
        RefreshFeed()
        if settingsFrame then settingsFrame:SetAlpha(0) end
    end)

    combined:HookScript("OnHide", function()
        if feedFrame then feedFrame:SetAlpha(0) end
        if settingsFrame then settingsFrame:SetAlpha(0) end
        StopGlowUpdates()
        ClearAllGlows()
    end)

    if combined.UpdateItems then
        hooksecurefunc(combined, "UpdateItems", function()
            AnchorFeed()
            -- Map changes here sometimes; rebuild once per update burst:
            RebuildRealButtonMap()
            RefreshFeed()
        end)
    end
end

-- -----------------------------
-- Events
-- -----------------------------
ForceCombinedBags()

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        HookCombined()
        InitSnapshot()
        RefreshFeed()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        HookCombined()
        InitSnapshot()
        DiffAndUpdate()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        RefreshFeed()
        return
    end
end)

print("|cff00ff00SOB loaded.|r  (⚙ on Last Items frame)")