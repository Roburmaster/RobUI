local AddonName, ns = ...
local R = _G.Robui
local Mod = {}

-- 1. ICONS & VARIABLES
local I_GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local I_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local I_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
local I_TOKEN  = "|TInterface\\Icons\\WoW_Token01:14:14:0:0|t"

local floor = math.floor
local abs   = math.abs
local fmt   = string.format

local currentView = "session"
local lastMoney = 0
local isRepairing = false
local SessionData = { income = {}, expense = {}, profit = 0 }

-- Cached keys/db (perf)
local realmKey, charKey
local historyDB -- points to RobUIGoldDB[realmKey][charKey]
local lastResetCheck = 0
local pendingMoneyUpdate = false

-- Reused table for tooltip sorting (avoid alloc every hover)
local tooltipSorted = {}

-- 2. CONFIGURATION HELPERS
local function GetCfg()
    if R.Database and R.Database.profile and R.Database.profile.datapanel and R.Database.profile.datapanel.gold then
        return R.Database.profile.datapanel.gold
    end
    return {
        enabled = true, visible = true, locked = false,
        point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -38, y = 4,
        autoRepair = true, guildRepair = true, autoSell = false
    }
end

local function SaveMaybe()
    -- RobuiDB lagrer automatisk
end

local function InitHistoryKeys()
    if realmKey and charKey then return end
    realmKey = (GetRealmName() or "UnknownRealm") .. " - " .. (UnitFactionGroup("player") or "Neutral")
    charKey  = UnitName("player") or "UnknownChar"
end

local function EnsureHistoryDB()
    InitHistoryKeys()

    _G.RobUIGoldDB = _G.RobUIGoldDB or {}
    local root = _G.RobUIGoldDB
    root[realmKey] = root[realmKey] or {}
    root[realmKey][charKey] = root[realmKey][charKey] or {}

    local db = root[realmKey][charKey]
    if not db.history then
        db.history = {
            day   = { income = {}, expense = {}, profit = 0, date = 0 },
            week  = { income = {}, expense = {}, profit = 0, week = 0 },
            month = { income = {}, expense = {}, profit = 0, month = 0 },
        }
    end
    db.class = select(2, UnitClass("player"))
    historyDB = db
    return db
end

local function FormatMoney(money, full)
    money = tonumber(money) or 0
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100
    local goldStr = BreakUpLargeNumbers(gold)

    if full then
        return fmt("%s%s %d%s %d%s", goldStr, I_GOLD, silver, I_SILVER, copper, I_COPPER)
    end
    if gold > 0 then
        return fmt("|cffffffff%s|r%s", goldStr, I_GOLD)
    elseif silver > 0 then
        return fmt("|cffffffff%d|r%s", silver, I_SILVER)
    end
    return fmt("|cffffffff%d|r%s", copper, I_COPPER)
end

-- 3. NUDGE FUNCTION (Moving 1px)
function Mod:Nudge(dx, dy)
    local cfg = GetCfg()
    cfg.x = (cfg.x or 0) + dx
    cfg.y = (cfg.y or 0) + dy

    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point or "BOTTOMRIGHT", UIParent, cfg.relPoint or cfg.point or "BOTTOMRIGHT", cfg.x or 0, cfg.y or 0)
    end
    SaveMaybe()
end

function Mod:Reset()
    local cfg = GetCfg()
    cfg.point, cfg.relPoint, cfg.x, cfg.y = "BOTTOMRIGHT", "BOTTOMRIGHT", -38, 4
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    end
    SaveMaybe()
end

function Mod:SetVisible(show)
    local cfg = GetCfg()
    cfg.visible = not not show
    if self.frame then self.frame:SetShown(cfg.visible and cfg.enabled) end
    SaveMaybe()
end

-- 4. LOGIC & AUTOMATION
local function CheckResetsThrottled()
    -- kjør maks 1 gang per minutt (date() er ikke gratis)
    local t = GetTime()
    if (t - lastResetCheck) < 60 then return end
    lastResetCheck = t

    local db = historyDB or EnsureHistoryDB()
    local now = date("*t")
    local week = tonumber(date("%V"))

    if db.history.day.date ~= now.yday then
        db.history.day = { income = {}, expense = {}, profit = 0, date = now.yday }
    end
    if db.history.week.week ~= week then
        db.history.week = { income = {}, expense = {}, profit = 0, week = week }
    end
    if db.history.month.month ~= now.month then
        db.history.month = { income = {}, expense = {}, profit = 0, month = now.month }
    end
end

local function UpdateHistory(diff)
    diff = tonumber(diff) or 0
    if diff == 0 then return end

    local db = historyDB or EnsureHistoryDB()
    local isIncomeNow = diff > 0
    local absDiff = abs(diff)

    local category
    if isRepairing then
        category = "repair"
    elseif (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown()) then
        category = "auction"
    elseif MerchantFrame and MerchantFrame:IsShown() then
        category = "merchant"
    elseif MailFrame and MailFrame:IsShown() then
        category = "mail"
    elseif QuestFrame and QuestFrame:IsShown() then
        category = "quest"
    else
        category = isIncomeNow and "quest" or "other"
    end

    -- Session + day/week/month
    local t1, t2, t3, t4 = SessionData, db.history.day, db.history.week, db.history.month

    t1.profit = (t1.profit or 0) + diff
    t2.profit = (t2.profit or 0) + diff
    t3.profit = (t3.profit or 0) + diff
    t4.profit = (t4.profit or 0) + diff

    if isIncomeNow then
        t1.income[category] = (t1.income[category] or 0) + absDiff
        t2.income[category] = (t2.income[category] or 0) + absDiff
        t3.income[category] = (t3.income[category] or 0) + absDiff
        t4.income[category] = (t4.income[category] or 0) + absDiff
    else
        t1.expense[category] = (t1.expense[category] or 0) + absDiff
        t2.expense[category] = (t2.expense[category] or 0) + absDiff
        t3.expense[category] = (t3.expense[category] or 0) + absDiff
        t4.expense[category] = (t4.expense[category] or 0) + absDiff
    end

    if Mod.breakdownFrame and Mod.breakdownFrame:IsShown() then
        Mod:UpdateBreakdown()
    end
end

local function AutoRepairItems()
    local cfg = GetCfg()
    if not cfg.autoRepair or not CanMerchantRepair() then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost == 0 then return end

    isRepairing = true

    if cfg.guildRepair and IsInGuild() and CanGuildBankRepair() then
        local gMoney = GetGuildBankWithdrawMoney()
        if gMoney == -1 or gMoney >= cost then
            RepairAllItems(true)
            print("|cff00ff00[Economy]|r Repaired (Guild): " .. FormatMoney(cost, true))
            isRepairing = false
            return
        end
    end

    if GetMoney() >= cost then
        RepairAllItems()
        print("|cff00ff00[Economy]|r Repaired (Personal): " .. FormatMoney(cost, true))
    end

    C_Timer.After(0.5, function() isRepairing = false end)
end

local function AutoSellGreys()
    if not GetCfg().autoSell then return end

    local profit = 0

    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                -- quality kommer direkte her (mye billigere enn GetItemInfo)
                local q = info.quality
                if q == 0 then
                    -- vendor price: GetItemInfo kan være nil hvis ikke cached, men på greys er det vanligvis cached.
                    local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(info.hyperlink)
                    if price and price > 0 then
                        profit = profit + (price * (info.stackCount or 1))
                        C_Container.UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end

    if profit > 0 then
        print("|cff00ff00[Economy]|r Sold Junk: " .. FormatMoney(profit, true))
    end
end

-- 5. INITIALIZATION
function Mod:Initialize()
    if self.frame then return end

    local cfg = GetCfg()
    EnsureHistoryDB()

    local f = CreateFrame("Frame", "RobUIEconomyFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(140, 26)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    f:ClearAllPoints()
    local p  = cfg.point or "BOTTOMRIGHT"
    local rp = cfg.relPoint or p
    local x  = cfg.x or -38
    local y  = cfg.y or 4
    f:SetPoint(p, UIParent, rp, x, y)
    f:SetShown(cfg.visible and cfg.enabled)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER", 0, 0)

    lastMoney = GetMoney()
    historyDB.amount = lastMoney

    -- token price fetch en gang
    if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
        C_WowTokenPublic.UpdateMarketPrice()
    end

    local function DoMoneyUpdate()
        pendingMoneyUpdate = false

        CheckResetsThrottled()

        local money = GetMoney()
        if lastMoney > 0 then
            UpdateHistory(money - lastMoney)
        end
        lastMoney = money

        local db = historyDB or EnsureHistoryDB()
        db.amount = money

        -- UI update (billig)
        f.text:SetText(FormatMoney(money, false))
        f:SetWidth(f.text:GetStringWidth() + 20)
    end

    local function RequestMoneyUpdate()
        -- Coalesce: hvis PLAYER_MONEY spammer 10x på kort tid, gjør vi 1 update neste frame
        if pendingMoneyUpdate then return end
        pendingMoneyUpdate = true
        C_Timer.After(0, DoMoneyUpdate)
    end

    f:RegisterEvent("PLAYER_MONEY")
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            AutoSellGreys()
            AutoRepairItems()
            RequestMoneyUpdate()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- hard reset check med en gang ved login
            lastResetCheck = 0
            CheckResetsThrottled()
            RequestMoneyUpdate()
        else
            RequestMoneyUpdate()
        end
    end)

    f:SetScript("OnDragStart", function()
        local c = GetCfg()
        if IsShiftKeyDown() and not c.locked and not InCombatLockdown() then
            f:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p2, _, rp2, x2, y2 = f:GetPoint()
        if p2 then
            local c = GetCfg()
            c.point, c.relPoint, c.x, c.y = p2, rp2, floor((x2 or 0) + 0.5), floor((y2 or 0) + 0.5)
            SaveMaybe()
        end
    end)

    f:SetScript("OnEnter", function(self)
        EnsureHistoryDB()

        local root = _G.RobUIGoldDB
        local realmDB = root and root[realmKey] or nil
        if not realmDB then return end

        local total = 0
        wipe(tooltipSorted)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddDoubleLine("Economy Manager", "RobUI", 0, 1, 1, 0.5, 0.5, 0.5)
        GameTooltip:AddLine(" ")

        for name, data in pairs(realmDB) do
            if type(data) == "table" and data.amount then
                tooltipSorted[#tooltipSorted + 1] = { name = name, amount = data.amount, class = data.class }
                total = total + data.amount
            end
        end

        table.sort(tooltipSorted, function(a, b) return a.amount > b.amount end)

        for i = 1, #tooltipSorted do
            local char = tooltipSorted[i]
            local color = "|cffffffff"
            if char.class then
                local cObj = C_ClassColor.GetClassColor(char.class)
                if cObj then color = cObj:GenerateHexColorMarkup() end
            end
            GameTooltip:AddDoubleLine(color .. char.name, FormatMoney(char.amount, false), 1,1,1, 1,1,1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Wealth:", FormatMoney(total, false), 1, 1, 1, 1, 1, 1)

        local tokenPrice = (C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice and C_WowTokenPublic.GetCurrentMarketPrice()) or nil
        if tokenPrice then
            GameTooltip:AddDoubleLine("WoW Token:", FormatMoney(tokenPrice, false) .. I_TOKEN, 1, 0.8, 0, 1,1,1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Shift+LeftDrag: Move", 0.4, 0.8, 1)
        GameTooltip:AddLine("Right-Click: Settings", 0.4, 0.8, 1)
        GameTooltip:AddLine("Shift+RightClick: Analysis", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    f:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            if IsShiftKeyDown() then
                local bd = Mod:CreateBreakdownFrame()
                bd:SetShown(not bd:IsShown())
                Mod:UpdateBreakdown()
            else
                if not Mod.settingsFrame then Mod:CreateGoldSettingsFrame() end
                Mod.settingsFrame:SetShown(not Mod.settingsFrame:IsShown())
            end
        end
    end)

    -- initial paint
    pendingMoneyUpdate = false
    DoMoneyUpdate()
end

-- 6. BREAKDOWN FRAME
function Mod:CreateBreakdownFrame()
    if self.breakdownFrame then return self.breakdownFrame end

    local f = CreateFrame("Frame", "RobUIEconomyBreakdown", UIParent, "BackdropTemplate")
    f:SetSize(340, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0,0,0,0.95)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("Economy Analysis")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local function CreateTab(text, mode, x)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(70, 22)
        btn:SetPoint("TOPLEFT", x, -40)
        btn:SetText(text)
        btn:SetScript("OnClick", function() currentView = mode; Mod:UpdateBreakdown() end)
        return btn
    end
    CreateTab("Session", "session", 20)
    CreateTab("Today", "day", 95)
    CreateTab("Week", "week", 170)
    CreateTab("Month", "month", 245)

    local function CreateRow(label, y)
        local row = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row:SetPoint("TOPLEFT", 25, y)
        row:SetText(label)

        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        val:SetPoint("TOPRIGHT", -25, y)
        val:SetText("-")
        return val
    end

    f.vIncQuest  = CreateRow("Loot / Quest", -100)
    f.vIncMerch  = CreateRow("Merchant", -120)
    f.vIncAuct   = CreateRow("Auction", -140)
    f.vIncMail   = CreateRow("Mailbox", -160)
    f.vExpRepair = CreateRow("Repairs", -200)
    f.vExpMerch  = CreateRow("Merchant", -220)
    f.vExpAuct   = CreateRow("Auction/Mail", -240)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(300, 24)
    bar:SetPoint("BOTTOM", 0, 20)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.2, 0.2, 0.2, 1)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bar.text:SetPoint("CENTER")

    f.profitBar = bar

    self.breakdownFrame = f
    return f
end

function Mod:UpdateBreakdown()
    local f = self.breakdownFrame
    if not f then return end

    local db = historyDB or EnsureHistoryDB()
    local data = SessionData
    if currentView == "day" then data = db.history.day
    elseif currentView == "week" then data = db.history.week
    elseif currentView == "month" then data = db.history.month end

    f.title:SetText("Economy: " .. currentView:upper())

    local inc = data.income or {}
    local exp = data.expense or {}

    f.vIncQuest:SetText(FormatMoney((inc.quest or 0) + (inc.other or 0), false))
    f.vIncMerch:SetText(FormatMoney(inc.merchant or 0, false))
    f.vIncAuct:SetText(FormatMoney(inc.auction or 0, false))
    f.vIncMail:SetText(FormatMoney(inc.mail or 0, false))

    f.vExpRepair:SetText(FormatMoney(exp.repair or 0, false))
    f.vExpMerch:SetText(FormatMoney(exp.merchant or 0, false))
    f.vExpAuct:SetText(FormatMoney((exp.auction or 0) + (exp.mail or 0), false))

    local net = data.profit or 0
    f.profitBar:SetStatusBarColor(net >= 0 and 0 or 1, net >= 0 and 1 or 0, 0)
    f.profitBar:SetValue(100)
    f.profitBar.text:SetText((net >= 0 and "Profit: +" or "Loss: ") .. FormatMoney(abs(net), false))
end

-- 7. SETTINGS FRAME (With Nudge Controls)
function Mod:CreateGoldSettingsFrame()
    if self.settingsFrame then return self.settingsFrame end

    local cfg = GetCfg()
    local f = CreateFrame("Frame", "RobUIGoldSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 360)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    f:SetBackdropColor(0,0,0,0.9)

    local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOP",0,-15)
    title:SetText("Economy Settings")

    local function CreateCheck(label, key, y)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb.text:SetText(label)
        cb:SetChecked(cfg[key])
        cb:SetScript("OnClick", function(self) cfg[key] = self:GetChecked(); SaveMaybe() end)
    end
    CreateCheck("Enable Auto Repair", "autoRepair", -65)
    CreateCheck("Use Guild Funds First", "guildRepair", -90)
    CreateCheck("Enable Auto Sell Junk", "autoSell", -115)

    local function CreateButton(label, w, x, y, func)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(label)
        b:SetScript("OnClick", func)
    end

    CreateButton("Show", 80, 20, -175, function() Mod:SetVisible(true) end)
    CreateButton("Hide", 80, 110,-175, function() Mod:SetVisible(false) end)
    CreateButton("Lock", 80, 20, -200, function() cfg.locked = true; SaveMaybe() end)
    CreateButton("Unlock",80,110,-200, function() cfg.locked = false; SaveMaybe() end)

    local function CreateNudgeBtn(label, x, y, dx, dy)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(28, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(label)
        b:SetScript("OnClick", function() Mod:Nudge(dx, dy) end)
        return b
    end

    CreateNudgeBtn("↑", 135, -230,  0,  1)
    CreateNudgeBtn("↓", 135, -260,  0, -1)
    CreateNudgeBtn("←", 105, -260, -1,  0)
    CreateNudgeBtn("→", 165, -260,  1,  0)

    CreateButton("Reset Pos", 140, 80, -290, function() Mod:Reset() end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(120, 24)
    close:SetPoint("BOTTOM", 0, 15)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)

    self.settingsFrame = f
    return f
end

-- 8. SLASH COMMANDS
SLASH_GOLDSET1 = "/goldset"
SlashCmdList.GOLDSET = function()
    if not Mod.settingsFrame then Mod:CreateGoldSettingsFrame() end
    Mod.settingsFrame:SetShown(not Mod.settingsFrame:IsShown())
end

-- Hook into BPanel
if R.BPanel then
    hooksecurefunc(R.BPanel, "Initialize", function()
        Mod:Initialize()
    end)
end
