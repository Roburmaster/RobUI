local ADDON, ns = ...
ns = _G[ADDON] or ns
_G[ADDON] = ns

ns.GearIndex = ns.GearIndex or {}
local GI = ns.GearIndex

local CreateFrame = CreateFrame
local UnitName = UnitName
local GetRealmName = GetRealmName
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemID = GetInventoryItemID
local GameTooltip = GameTooltip
local UIParent = UIParent
local wipe = wipe
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local time = time
local pcall = pcall
local format = string.format
local lower = string.lower
local tsort = table.sort
local C_Timer = C_Timer
local math_ceil = math.ceil
local max = math.max
local min = math.min
local select = select
local GetItemInfo = GetItemInfo

local C_Container = C_Container
local C_Item = C_Item
local Enum = Enum

local EnumBagIndex = Enum and Enum.BagIndex or {}

local function GetPlayerBags()
    return {
        EnumBagIndex.Backpack or 0,
        EnumBagIndex.Bag_1 or 1,
        EnumBagIndex.Bag_2 or 2,
        EnumBagIndex.Bag_3 or 3,
        EnumBagIndex.Bag_4 or 4,
        EnumBagIndex.ReagentBag or 5,
    }
end

local function GetBankBags()
    return {
        EnumBagIndex.Bank or -1,
        EnumBagIndex.CharacterBankTab_1 or 6,
        EnumBagIndex.CharacterBankTab_2 or 7,
        EnumBagIndex.CharacterBankTab_3 or 8,
        EnumBagIndex.CharacterBankTab_4 or 9,
        EnumBagIndex.CharacterBankTab_5 or 10,
        EnumBagIndex.CharacterBankTab_6 or 11,
    }
end

local function GetWarbandBags()
    return {
        EnumBagIndex.AccountBankTab_1 or 12,
        EnumBagIndex.AccountBankTab_2 or 13,
        EnumBagIndex.AccountBankTab_3 or 14,
        EnumBagIndex.AccountBankTab_4 or 15,
        EnumBagIndex.AccountBankTab_5 or 16,
    }
end

local EQUIP_SLOTS = {
    1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19
}

local SLOT_LABELS = {
    [1]  = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest",
    [6]  = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands",
    [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard",
}

local frame = CreateFrame("Frame")
GI.frame = frame

local ui
local rows = {}
local results = {}
local charButtons = {}
local catButtons = {}
local charFilters = {}
local categoryFilters = {}

local page = 1
local perPage = 14

local selectedOwner = "ALL"
local selectedCategory = "ALL"

local bagsToScan = {}
local dirtyEquip = false
local scanQueued = false
local uiRefreshQueued = false

local lastAnyScan = 0
local lastIndexBuild = 0
local MIN_SCAN_GAP = 0.25
local MIN_INDEX_GAP = 0.25

local function SafeLower(v)
    if v == nil then return "" end
    return lower(tostring(v))
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function QueueUIRefresh()
    if uiRefreshQueued then return end
    uiRefreshQueued = true
    C_Timer.After(0.10, function()
        uiRefreshQueued = false
        if ui and ui:IsShown() then
            GI:RefreshUI()
        end
    end)
end

local function GetPlayerKey()
    local realm = GetRealmName() or "UnknownRealm"
    local name = UnitName("player") or "Unknown"
    return realm, name
end

local function MakeOwnerKey(character, realm)
    return tostring(character or "?") .. "-" .. tostring(realm or "?")
end

local function EnsureDB()
    _G.RobUIGearFinderDB = _G.RobUIGearFinderDB or {}
    local db = _G.RobUIGearFinderDB

    db.characters = db.characters or {}
    db.itemIndex = db.itemIndex or {}
    
    db.warband = db.warband or {}
    db.warband.tabsData = db.warband.tabsData or {}
    db.warband.updated = db.warband.updated or 0
    
    return db
end

local function EnsureCharDB()
    local db = EnsureDB()
    local realm, name = GetPlayerKey()

    db.characters[realm] = db.characters[realm] or {}
    db.characters[realm][name] = db.characters[realm][name] or {}

    local char = db.characters[realm][name]
    char.name = name
    char.realm = realm
    char.class = select(2, UnitClass("player"))
    char.faction = UnitFactionGroup("player")
    char.updated = char.updated or 0
    
    char.bagData = char.bagData or {}
    char.bankData = char.bankData or {}
    char.equipped = char.equipped or {}

    return db, char
end

GI.EnsureDB = EnsureDB

local function GetItemName(itemID, itemLink)
    if itemLink and C_Item and C_Item.GetItemNameByHyperlink then
        local name = SafeCall(C_Item.GetItemNameByHyperlink, itemLink)
        if name then return name end
    end
    if itemID and C_Item and C_Item.GetItemNameByID then
        local name = SafeCall(C_Item.GetItemNameByID, itemID)
        if name then return name end
    end
    if itemLink then
        local name = GetItemInfo(itemLink)
        if name then return name end
    end
    if itemID then
        local name = GetItemInfo(itemID)
        if name then return name end
    end
    return itemLink or ("item:" .. tostring(itemID or 0))
end

local function GetItemInfoInstantSafe(itemID, itemLink)
    local instantID = itemID
    if not instantID and itemLink then
        instantID = tonumber(itemLink:match("item:(%d+)"))
    end
    if not instantID or not (C_Item and C_Item.GetItemInfoInstant) then
        return nil, nil, nil, nil, nil, nil, nil
    end
    return C_Item.GetItemInfoInstant(instantID)
end

local function GetBagItemLevel(bagID, slotID)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot then return nil end
    local loc = SafeCall(ItemLocation.CreateFromBagAndSlot, bagID, slotID)
    if not loc then loc = SafeCall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bagID, slotID) end
    if not loc then return nil end

    if C_Item and C_Item.GetCurrentItemLevel then
        local ilvl = SafeCall(C_Item.GetCurrentItemLevel, loc)
        if ilvl then return tonumber(ilvl) end
    end
    return nil
end

local ITEM_CLASS_NAMES = {
    [Enum and Enum.ItemClass and Enum.ItemClass.Weapon or -1001] = "Weapons",
    [Enum and Enum.ItemClass and Enum.ItemClass.Armor or -1002] = "Armor",
    [Enum and Enum.ItemClass and Enum.ItemClass.Container or -1003] = "Containers",
    [Enum and Enum.ItemClass and Enum.ItemClass.Consumable or -1004] = "Consumables",
    [Enum and Enum.ItemClass and Enum.ItemClass.Gem or -1005] = "Gems",
    [Enum and Enum.ItemClass and Enum.ItemClass.Reagent or -1006] = "Reagents",
    [Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods or -1007] = "Trade Goods",
    [Enum and Enum.ItemClass and Enum.ItemClass.Recipe or -1008] = "Recipes",
    [Enum and Enum.ItemClass and Enum.ItemClass.Questitem or -1009] = "Quest",
    [Enum and Enum.ItemClass and Enum.ItemClass.Miscellaneous or -1010] = "Misc",
    [Enum and Enum.ItemClass and Enum.ItemClass.Profession or -1011] = "Profession",
    [Enum and Enum.ItemClass and Enum.ItemClass.Battlepet or -1012] = "Battle Pets",
}

local function IsEquippableByInfo(itemID, itemLink)
    if C_Item and C_Item.IsEquippableItem then
        local ok = SafeCall(C_Item.IsEquippableItem, itemLink or itemID)
        if ok ~= nil then return ok and true or false end
    end
    local _, _, _, equipLoc, _, itemClass = GetItemInfoInstantSafe(itemID, itemLink)
    if equipLoc and equipLoc ~= "" then return true end
    if Enum and Enum.ItemClass and (itemClass == Enum.ItemClass.Armor or itemClass == Enum.ItemClass.Weapon) then return true end
    return false
end

local function ResolveCategory(itemID, itemLink)
    local _, _, _, equipLoc, _, itemClass, itemSubClass = GetItemInfoInstantSafe(itemID, itemLink)
    if IsEquippableByInfo(itemID, itemLink) then return "Gear" end
    if itemClass and ITEM_CLASS_NAMES[itemClass] then return ITEM_CLASS_NAMES[itemClass] end
    if type(itemSubClass) == "number" then return "Class " .. tostring(itemSubClass) end
    return "Other"
end

local function AddEntry(bucket, entry)
    if not bucket or not entry or not entry.itemID then return end
    bucket[#bucket + 1] = entry
end

local function CreateEntry(itemID, itemLink, count, ilvl, locationText, sourceType)
    local category = ResolveCategory(itemID, itemLink)
    return {
        itemID = itemID,
        itemLink = itemLink,
        itemName = GetItemName(itemID, itemLink),
        count = count or 1,
        ilvl = ilvl,
        locationText = locationText,
        category = category,
        sourceType = sourceType or "unknown",
        isGear = (category == "Gear"),
    }
end

local function BuildItemIndex()
    local now = time()
    if (now - lastIndexBuild) < MIN_INDEX_GAP then return end
    lastIndexBuild = now

    local db = EnsureDB()
    wipe(db.itemIndex)

    for realm, realmData in pairs(db.characters) do
        for charName, char in pairs(realmData) do
            local function ingest(bucket, source)
                if type(bucket) ~= "table" then return end
                for i = 1, #bucket do
                    local entry = bucket[i]
                    if entry and entry.itemID then
                        local t = db.itemIndex[entry.itemID]
                        if not t then
                            t = {}
                            db.itemIndex[entry.itemID] = t
                        end
                        t[#t + 1] = {
                            itemID = entry.itemID,
                            itemLink = entry.itemLink,
                            itemName = entry.itemName,
                            count = entry.count,
                            ilvl = entry.ilvl,
                            source = source,
                            locationText = entry.locationText,
                            character = charName,
                            realm = realm,
                            class = char.class,
                            updated = char.updated,
                            category = entry.category or "Other",
                            sourceType = entry.sourceType or source,
                            isGear = entry.isGear and true or false,
                        }
                    end
                end
            end

            local hasNewBagData = false
            if char.bagData then
                for _, bucket in pairs(char.bagData) do
                    hasNewBagData = true
                    ingest(bucket, "bags")
                end
            end
            if not hasNewBagData and char.bags then ingest(char.bags, "bags") end

            local hasNewBankData = false
            if char.bankData then
                for _, bucket in pairs(char.bankData) do
                    hasNewBankData = true
                    ingest(bucket, "bank")
                end
            end
            if not hasNewBankData then
                if char.bank then ingest(char.bank, "bank") end
                if char.bankTabs then ingest(char.bankTabs, "bank") end
            end

            if char.equipped then ingest(char.equipped, "equipped") end
        end
    end

    if db.warband then
        local function ingestWarband(bucket)
            if type(bucket) ~= "table" then return end
            for i = 1, #bucket do
                local entry = bucket[i]
                if entry and entry.itemID then
                    local t = db.itemIndex[entry.itemID]
                    if not t then
                        t = {}
                        db.itemIndex[entry.itemID] = t
                    end
                    t[#t + 1] = {
                        itemID = entry.itemID,
                        itemLink = entry.itemLink,
                        itemName = entry.itemName,
                        count = entry.count,
                        ilvl = entry.ilvl,
                        source = "warbandbank",
                        locationText = entry.locationText,
                        character = "Warband",
                        realm = "Account",
                        class = "WARBAND",
                        updated = db.warband.updated,
                        category = entry.category or "Other",
                        sourceType = entry.sourceType or "warbandbank",
                        isGear = entry.isGear and true or false,
                    }
                end
            end
        end

        local hasNewWarbandData = false
        if db.warband.tabsData then
            for _, bucket in pairs(db.warband.tabsData) do
                hasNewWarbandData = true
                ingestWarband(bucket)
            end
        end
        if not hasNewWarbandData and db.warband.tabs then
            ingestWarband(db.warband.tabs)
        end
    end
end

local function ScanGenericBag(bagID, targetTable, locationPrefix, sourceType)
    if not C_Container then return false end
    
    local numSlots = SafeCall(C_Container.GetContainerNumSlots, bagID) or 0
    if numSlots == 0 then
        return false -- Bag data not streamed yet or tab not purchased
    end

    local bucket = {}
    for slotID = 1, numSlots do
        local itemID = SafeCall(C_Container.GetContainerItemID, bagID, slotID)
        if itemID then
            local itemLink = SafeCall(C_Container.GetContainerItemLink, bagID, slotID)
            local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slotID)
            local count = (type(info) == "table" and info.stackCount) and tonumber(info.stackCount) or 1
            local ilvl = GetBagItemLevel(bagID, slotID)
            
            AddEntry(bucket, CreateEntry(
                itemID,
                itemLink,
                count,
                ilvl,
                format("%s, Slot %d", locationPrefix, slotID),
                sourceType
            ))
        end
    end
    
    targetTable[bagID] = bucket
    return true
end

local function ScanEquipped(bucket)
    wipe(bucket)
    for _, slotID in ipairs(EQUIP_SLOTS) do
        local itemID = GetInventoryItemID("player", slotID)
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemID and itemLink then
            AddEntry(bucket, CreateEntry(
                itemID,
                itemLink,
                1,
                nil,
                SLOT_LABELS[slotID] or ("Equip " .. tostring(slotID)),
                "equipped"
            ))
        end
    end
end

local function GetBagPrefix(bagID, group, index)
    if group == "player" then return "Bag " .. tostring(bagID) end
    if group == "bank" then return bagID == -1 and "Bank" or ("Bank Bag " .. tostring(bagID)) end
    if group == "warband" then return "Warband Tab " .. tostring(index) end
    return "Bag " .. tostring(bagID)
end

local function PerformScan()
    scanQueued = false
    local now = time()
    if (now - lastAnyScan) < MIN_SCAN_GAP then
        scanQueued = true
        C_Timer.After(MIN_SCAN_GAP, PerformScan)
        return
    end
    lastAnyScan = now

    local db, char = EnsureCharDB()
    local changed = false

    for bagID, _ in pairs(bagsToScan) do
        local scanned = false
        
        for i, b in ipairs(GetPlayerBags()) do
            if b == bagID then
                if ScanGenericBag(bagID, char.bagData, GetBagPrefix(bagID, "player", i), "bags") then changed = true end
                scanned = true; break
            end
        end
        
        if not scanned then
            for i, b in ipairs(GetBankBags()) do
                if b == bagID then
                    if ScanGenericBag(bagID, char.bankData, GetBagPrefix(bagID, "bank", i), "bank") then changed = true end
                    scanned = true; break
                end
            end
        end
        
        if not scanned then
            for i, b in ipairs(GetWarbandBags()) do
                if b == bagID then
                    if ScanGenericBag(bagID, db.warband.tabsData, GetBagPrefix(bagID, "warband", i), "warbandbank") then changed = true end
                    scanned = true; break
                end
            end
        end
    end
    
    wipe(bagsToScan)

    if dirtyEquip then
        dirtyEquip = false
        ScanEquipped(char.equipped)
        changed = true
    end

    if changed then
        char.updated = now
        db.warband.updated = now
        BuildItemIndex()
        QueueUIRefresh()
    end
end

local function QueueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0.20, PerformScan)
end

local function QueueBagScan(bagID)
    if bagID then
        bagsToScan[bagID] = true
        QueueScan()
    end
end

local function QueueFullScan()
    for _, b in ipairs(GetPlayerBags()) do bagsToScan[b] = true end
    for _, b in ipairs(GetBankBags()) do bagsToScan[b] = true end
    for _, b in ipairs(GetWarbandBags()) do bagsToScan[b] = true end
    dirtyEquip = true
    QueueScan()
end

local function QueueBankScan()
    for _, b in ipairs(GetBankBags()) do bagsToScan[b] = true end
    for _, b in ipairs(GetWarbandBags()) do bagsToScan[b] = true end
    QueueScan()
end

local function PassesOwnerFilter(entry)
    if selectedOwner == "ALL" then return true end
    if selectedOwner == "WARBAND" then return entry.source == "warbandbank" end
    return MakeOwnerKey(entry.character, entry.realm) == selectedOwner
end

local function PassesCategoryFilter(entry)
    if selectedCategory == "ALL" then return true end
    return SafeLower(entry.category) == SafeLower(selectedCategory)
end

local function MatchesSearch(entry, needle)
    if needle == "" then return true end
    local fields = {
        entry.itemName, entry.itemLink, entry.character, entry.realm,
        entry.locationText, entry.source, entry.category, tostring(entry.itemID),
    }
    for i = 1, #fields do
        if SafeLower(fields[i]):find(needle, 1, true) then return true end
    end
    return false
end

local function CollectOwnerFilters()
    wipe(charFilters)
    charFilters[#charFilters + 1] = { key = "ALL", label = "All", count = 0 }
    local db = EnsureDB()
    local temp = {}

    for realm, realmData in pairs(db.characters) do
        for charName, char in pairs(realmData) do
            local count = 0
            local hasNewBagData = false
            if char.bagData then
                for _, b in pairs(char.bagData) do count = count + #b; hasNewBagData = true end
            end
            if not hasNewBagData then count = count + (type(char.bags) == "table" and #char.bags or 0) end
            
            local hasNewBankData = false
            if char.bankData then
                for _, b in pairs(char.bankData) do count = count + #b; hasNewBankData = true end
            end
            if not hasNewBankData then
                count = count + (type(char.bank) == "table" and #char.bank or 0)
                count = count + (type(char.bankTabs) == "table" and #char.bankTabs or 0)
            end
            
            count = count + (type(char.equipped) == "table" and #char.equipped or 0)

            temp[#temp + 1] = { key = MakeOwnerKey(charName, realm), label = charName, realm = realm, count = count }
        end
    end

    tsort(temp, function(a, b)
        local al, bl = SafeLower(a.label), SafeLower(b.label)
        if al ~= bl then return al < bl end
        return SafeLower(a.realm) < SafeLower(b.realm)
    end)

    for i = 1, #temp do charFilters[#charFilters + 1] = temp[i] end

    local warbandCount = 0
    if db.warband then
        local hasNewWarbandData = false
        if db.warband.tabsData then
            for _, b in pairs(db.warband.tabsData) do warbandCount = warbandCount + #b; hasNewWarbandData = true end
        end
        if not hasNewWarbandData and type(db.warband.tabs) == "table" then
            warbandCount = #db.warband.tabs
        end
    end

    charFilters[#charFilters + 1] = { key = "WARBAND", label = "Warband", count = warbandCount }
end

local function CollectCategoryFilters()
    wipe(categoryFilters)
    categoryFilters[#categoryFilters + 1] = { key = "ALL", label = "All" }
    local counts = {}
    local db = EnsureDB()

    for _, entries in pairs(db.itemIndex) do
        for i = 1, #entries do
            local entry = entries[i]
            if PassesOwnerFilter(entry) then
                local cat = entry.category or "Other"
                counts[cat] = (counts[cat] or 0) + 1
            end
        end
    end

    local temp = {}
    for cat, count in pairs(counts) do temp[#temp + 1] = { key = cat, label = cat, count = count } end
    tsort(temp, function(a, b)
        local ac, bc = SafeLower(a.label), SafeLower(b.label)
        if ac ~= bc then return ac < bc end
        return false
    end)
    for i = 1, #temp do categoryFilters[#categoryFilters + 1] = temp[i] end

    local found = false
    for i = 1, #categoryFilters do
        if categoryFilters[i].key == selectedCategory then found = true; break end
    end
    if not found then selectedCategory = "ALL" end
end

local function UpdateButtonVisual(btn, active)
    if not btn then return end
    if active then
        btn:LockHighlight()
        if btn.Text then btn.Text:SetTextColor(1, 0.82, 0) end
    else
        btn:UnlockHighlight()
        if btn.Text then btn.Text:SetTextColor(1, 1, 1) end
    end
end

local function RefreshCharButtons()
    if not ui or not ui.charContainer then return end
    CollectOwnerFilters()

    for i = 1, #charButtons do
        charButtons[i]:Hide()
        charButtons[i].ownerKey = nil
    end

    local btnW, btnH, gapX, gapY, cols = 112, 22, 6, 4, 6
    for i = 1, #charFilters do
        local data = charFilters[i]
        local btn = charButtons[i]

        if not btn then
            btn = CreateFrame("Button", nil, ui.charContainer, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetScript("OnClick", function(self)
                selectedOwner = self.ownerKey or "ALL"
                selectedCategory = "ALL"
                page = 1
                GI:RefreshUI()
            end)
            btn:SetScript("OnEnter", function(self)
                if not self.filterData then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                if self.filterData.key == "ALL" then
                    GameTooltip:SetText("Show all characters and warband")
                elseif self.filterData.key == "WARBAND" then
                    GameTooltip:SetText("Show only warband bank items")
                else
                    GameTooltip:SetText((self.filterData.label or "?") .. "-" .. (self.filterData.realm or "?"))
                end
                GameTooltip:AddLine("Items: " .. tostring(self.filterData.count or 0), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            charButtons[i] = btn
        end

        local col, row = (i - 1) % cols, floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui.charContainer, "TOPLEFT", col * (btnW + gapX), -row * (btnH + gapY))
        btn.ownerKey = data.key
        btn.filterData = data

        local text = data.label or "?"
        if data.count and data.count > 0 then text = text .. " (" .. data.count .. ")" end
        btn:SetText(text)
        UpdateButtonVisual(btn, selectedOwner == data.key)
        btn:Show()
    end
    ui.charContainer:SetHeight(max(1, floor((#charFilters - 1) / cols) + 1) * 26)
end

local function RefreshCategoryButtons()
    if not ui or not ui.catContainer then return end
    CollectCategoryFilters()

    for i = 1, #catButtons do
        catButtons[i]:Hide()
        catButtons[i].categoryKey = nil
    end

    local btnW, btnH, gapX, gapY, cols = 108, 20, 5, 4, 6
    for i = 1, #categoryFilters do
        local data = categoryFilters[i]
        local btn = catButtons[i]

        if not btn then
            btn = CreateFrame("Button", nil, ui.catContainer, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetScript("OnClick", function(self)
                selectedCategory = self.categoryKey or "ALL"
                page = 1
                GI:RefreshUI()
            end)
            btn:SetScript("OnEnter", function(self)
                if not self.filterData then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.filterData.label or "?")
                if self.filterData.count then GameTooltip:AddLine("Items: " .. tostring(self.filterData.count), 0.8, 0.8, 0.8) end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            catButtons[i] = btn
        end

        local col, row = (i - 1) % cols, floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui.catContainer, "TOPLEFT", col * (btnW + gapX), -row * (btnH + gapY))
        btn.categoryKey = data.key
        btn.filterData = data

        local text = data.label or "?"
        if data.count and data.key ~= "ALL" then text = text .. " (" .. data.count .. ")" end
        btn:SetText(text)
        UpdateButtonVisual(btn, selectedCategory == data.key)
        btn:Show()
    end
    ui.catContainer:SetHeight(max(1, floor((#categoryFilters - 1) / cols) + 1) * 24)
end

local function GetFilteredEntries(searchText)
    local filtered, db, needle = {}, EnsureDB(), SafeLower(searchText or "")
    for _, entries in pairs(db.itemIndex) do
        for i = 1, #entries do
            local entry = entries[i]
            if PassesOwnerFilter(entry) and PassesCategoryFilter(entry) and MatchesSearch(entry, needle) then
                filtered[#filtered + 1] = entry
            end
        end
    end
    tsort(filtered, function(a, b)
        local an, bn = SafeLower(a.itemName), SafeLower(b.itemName)
        if an ~= bn then return an < bn end
        local ac, bc = SafeLower(a.character), SafeLower(b.character)
        if ac ~= bc then return ac < bc end
        local ar, br = SafeLower(a.realm), SafeLower(b.realm)
        if ar ~= br then return ar < br end
        return SafeLower(a.locationText) < SafeLower(b.locationText)
    end)
    return filtered
end

local function BuildOwnerSummary()
    local db = EnsureDB()
    if selectedOwner == "ALL" then
        local chars, total = 0, 0
        for _, realmData in pairs(db.characters) do
            for _, char in pairs(realmData) do
                chars = chars + 1
                if char.bagData then for _, b in pairs(char.bagData) do total = total + #b end end
                if char.bankData then for _, b in pairs(char.bankData) do total = total + #b end end
                total = total + (type(char.equipped) == "table" and #char.equipped or 0)
            end
        end
        local warbandCount = 0
        if db.warband and db.warband.tabsData then
            for _, b in pairs(db.warband.tabsData) do warbandCount = warbandCount + #b end
        end
        return format("All Characters  |  Characters: %d  |  Character Items: %d  |  Warband Items: %d", chars, total, warbandCount)
    end

    if selectedOwner == "WARBAND" then
        local warbandCount = 0
        if db.warband and db.warband.tabsData then
            for _, b in pairs(db.warband.tabsData) do warbandCount = warbandCount + #b end
        end
        return format("Warband Bank  |  Items: %d", warbandCount)
    end

    for realm, realmData in pairs(db.characters) do
        for charName, char in pairs(realmData) do
            if MakeOwnerKey(charName, realm) == selectedOwner then
                local bags, bank = 0, 0
                if char.bagData then for _, b in pairs(char.bagData) do bags = bags + #b end end
                if char.bankData then for _, b in pairs(char.bankData) do bank = bank + #b end end
                local equipped = type(char.equipped) == "table" and #char.equipped or 0
                local total = bags + equipped + bank
                return format("%s-%s  |  Total: %d  |  Bags: %d  |  Equipped: %d  |  Bank: %d", charName, realm, total, bags, equipped, bank)
            end
        end
    end
    return "No summary available"
end

local function BuildFilteredSummary(filtered)
    local totalStacks, uniqueItems, gearCount, catCount = 0, {}, 0, {}
    for i = 1, #filtered do
        local entry = filtered[i]
        totalStacks = totalStacks + (entry.count or 1)
        uniqueItems[entry.itemID] = true
        if entry.isGear then gearCount = gearCount + 1 end
        local cat = entry.category or "Other"
        catCount[cat] = (catCount[cat] or 0) + 1
    end
    local uniqueTotal = 0
    for _ in pairs(uniqueItems) do uniqueTotal = uniqueTotal + 1 end
    local bestCat, bestCount = "None", 0
    for cat, count in pairs(catCount) do
        if count > bestCount then bestCat, bestCount = cat, count end
    end
    return format("Filtered View  |  Entries: %d  |  Unique IDs: %d  |  Total Count: %d  |  Gear Entries: %d  |  Top Category: %s (%d)", #filtered, uniqueTotal, totalStacks, gearCount, bestCat, bestCount)
end

local function SetRowText(row, entry)
    if not entry then
        row:Hide()
        row.entry = nil
        return
    end
    local left = entry.itemLink or entry.itemName or ("item:" .. tostring(entry.itemID))
    local countText = (entry.count and entry.count > 1) and (" x" .. entry.count) or ""
    local ilvlText = entry.ilvl and (" |cff00ff96ilvl " .. entry.ilvl .. "|r") or ""
    local catText = entry.category and (" |cff9ad0ff<" .. entry.category .. ">|r") or ""
    local ownerText = (entry.source == "warbandbank") and "|cffc080ffWarband|r" or format("|cffffffff%s-%s|r", entry.character or "?", entry.realm or "?")
    row.left:SetText(left .. countText .. ilvlText .. catText)
    row.right:SetText(ownerText .. "  |cffbfbfbf[" .. tostring(entry.locationText or "?") .. "]|r")
    row.entry = entry
    row:Show()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(860, 22)
    -- Dynamisk festet til headerLeft, slik at radene skyves ned automatisk
    row:SetPoint("TOPLEFT", parent.headerLeft, "BOTTOMLEFT", -6, -8 - ((index - 1) * 24))
    
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.05 or 0.02)
    
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.left:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetWidth(500)
    
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWidth(330)

    row:SetScript("OnEnter", function(self)
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.entry.itemLink then GameTooltip:SetHyperlink(self.entry.itemLink) else GameTooltip:SetText(self.entry.itemName or ("item:" .. tostring(self.entry.itemID))) end
        GameTooltip:AddLine(" ")
        if self.entry.source == "warbandbank" then GameTooltip:AddLine("Warband", 1, 0.82, 0) else GameTooltip:AddLine((self.entry.character or "?") .. "-" .. (self.entry.realm or "?"), 1, 1, 1) end
        GameTooltip:AddLine("Category: " .. tostring(self.entry.category or "Other"), 0.7, 0.9, 1)
        GameTooltip:AddLine(self.entry.locationText or "Unknown", 0.8, 0.8, 0.8)
        if self.entry.count and self.entry.count > 1 then GameTooltip:AddLine("Count: " .. tostring(self.entry.count), 0.8, 1, 0.8) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if not self.entry or not ui then return end
        ui.searchBox:SetText(self.entry.itemName or "")
        page = 1
        GI:RefreshUI()
    end)
    return row
end

local function CreateUI()
    if ui then return end
    ui = CreateFrame("Frame", "RobUI_GearIndexFrame", UIParent, "BackdropTemplate")
    ui:SetSize(900, 700) -- Økt høyde for å gi mer plass til lister
    ui:SetPoint("CENTER")
    ui:SetMovable(true)
    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving)
    ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
    ui:SetClampedToScreen(true)
    ui:Hide()

    -- Endret bakgrunnsbilde til en solid hvit farge som vi maler helt svart
    ui:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 16, 
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    ui:SetBackdropColor(0, 0, 0, 1) -- Helt svart bakgrunn

    ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.title:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -14)
    ui.title:SetText("RobUI Item Index")

    ui.close = CreateFrame("Button", nil, ui, "UIPanelCloseButton")
    ui.close:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -4, -4)

    ui.scanBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.scanBtn:SetSize(90, 22)
    ui.scanBtn:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -40, -36)
    ui.scanBtn:SetText("Scan Now")
    ui.scanBtn:SetScript("OnClick", function()
        QueueFullScan()
        print("|cff00b3ffRobUI:|r Item index scan queued.")
    end)

    ui.searchBox = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
    ui.searchBox:SetSize(250, 24)
    ui.searchBox:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -42)
    ui.searchBox:SetAutoFocus(false)
    ui.searchBox:SetScript("OnTextChanged", function() page = 1; GI:RefreshUI() end)
    ui.searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    ui.searchLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.searchLabel:SetPoint("BOTTOMLEFT", ui.searchBox, "TOPLEFT", 4, 2)
    ui.searchLabel:SetText("Search item / char / category / location")

    ui.ownerSummary = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.ownerSummary:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -76)
    ui.ownerSummary:SetWidth(860); ui.ownerSummary:SetJustifyH("LEFT")

    ui.filteredSummary = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.filteredSummary:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -96)
    ui.filteredSummary:SetWidth(860); ui.filteredSummary:SetJustifyH("LEFT")

    -- DYNAMISK LAYOUT STARTER HER: Hver del henger sammen med den over, 
    -- så alt flytter seg nedover automatisk hvis en beholder vokser!

    ui.filterTitle = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.filterTitle:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -122)
    ui.filterTitle:SetText("Character Filters")

    ui.charContainer = CreateFrame("Frame", nil, ui)
    ui.charContainer:SetPoint("TOPLEFT", ui.filterTitle, "BOTTOMLEFT", 0, -6)
    ui.charContainer:SetPoint("RIGHT", ui, "RIGHT", -14, 0)
    ui.charContainer:SetHeight(26)

    ui.catTitle = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.catTitle:SetPoint("TOPLEFT", ui.charContainer, "BOTTOMLEFT", 0, -12)
    ui.catTitle:SetText("Category Filters")

    ui.catContainer = CreateFrame("Frame", nil, ui)
    ui.catContainer:SetPoint("TOPLEFT", ui.catTitle, "BOTTOMLEFT", 0, -6)
    ui.catContainer:SetPoint("RIGHT", ui, "RIGHT", -14, 0)
    ui.catContainer:SetHeight(24)

    ui.headerLeft = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.headerLeft:SetPoint("TOPLEFT", ui.catContainer, "BOTTOMLEFT", 2, -15)
    ui.headerLeft:SetText("Item")

    ui.headerRight = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.headerRight:SetPoint("TOPRIGHT", ui.catContainer, "BOTTOMRIGHT", -2, -15)
    ui.headerRight:SetText("Owner / Location")

    -- Laster rader (disse er nå lenket til ui.headerLeft inni CreateRow)
    for i = 1, perPage do rows[i] = CreateRow(ui, i) end

    ui.prevBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.prevBtn:SetSize(80, 22)
    ui.prevBtn:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 14, 14)
    ui.prevBtn:SetText("Prev")
    ui.prevBtn:SetScript("OnClick", function() page = max(1, page - 1); GI:RefreshUI() end)

    ui.nextBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.nextBtn:SetSize(80, 22)
    ui.nextBtn:SetPoint("LEFT", ui.prevBtn, "RIGHT", 8, 0)
    ui.nextBtn:SetText("Next")
    ui.nextBtn:SetScript("OnClick", function() page = page + 1; GI:RefreshUI() end)

    ui.pageText = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.pageText:SetPoint("LEFT", ui.nextBtn, "RIGHT", 14, 0)

    ui.help = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.help:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -14, 18)
    ui.help:SetJustifyH("RIGHT")
    ui.help:SetText("All items indexed. Bank updates when bag changes occur.")
end

function GI:BuildResults(searchText)
    wipe(results)
    local filtered = GetFilteredEntries(searchText)
    for i = 1, #filtered do results[i] = filtered[i] end
    return filtered
end

function GI:RefreshUI()
    if not ui then return end
    RefreshCharButtons()
    RefreshCategoryButtons()

    local filtered = self:BuildResults(ui.searchBox:GetText() or "")
    ui.ownerSummary:SetText(BuildOwnerSummary())
    ui.filteredSummary:SetText(BuildFilteredSummary(filtered))

    local totalPages = max(1, math_ceil(#results / perPage))
    if page < 1 then page = 1 end
    if page > totalPages then page = totalPages end

    local startIndex = (page - 1) * perPage + 1
    for i = 1, perPage do SetRowText(rows[i], results[startIndex + i - 1]) end

    local ownerLabel = selectedOwner
    if selectedOwner == "ALL" then ownerLabel = "All"
    elseif selectedOwner == "WARBAND" then ownerLabel = "Warband" end

    ui.pageText:SetText(format("Page %d / %d  |  Results: %d  |  Owner: %s  |  Category: %s", page, totalPages, #results, ownerLabel, selectedCategory))
end

function GI:ToggleUI()
    CreateUI()
    if ui:IsShown() then ui:Hide() else ui:Show(); self:RefreshUI() end
end

function GI:FindAndPrint(text)
    local filtered = GetFilteredEntries(text or "")
    print("|cff00b3ffRobUI:|r Item search: " .. (text or ""))
    if #filtered == 0 then print("|cffff4040No matches found.|r"); return end

    local shown = 0
    for i = 1, min(#filtered, 20) do
        local e = filtered[i]
        local owner = (e.source == "warbandbank") and "Warband" or ((e.character or "?") .. "-" .. (e.realm or "?"))
        local itemText = e.itemLink or e.itemName or ("item:" .. tostring(e.itemID))
        print(format("%s |cff7fd4ff<%s>|r |cffbfbfbf-> %s [%s]|r", itemText, e.category or "Other", owner, e.locationText or "?"))
        shown = shown + 1
    end
    if #filtered > shown then print(format("|cffbfbfbf...and %d more. Open /rgear for full list.|r", #filtered - shown)) end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        EnsureCharDB()
        CreateUI()
        QueueFullScan()

    elseif event == "BAG_UPDATE" then
        local bagID = ...
        if bagID then
            QueueBagScan(bagID)
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        dirtyEquip = true
        QueueScan()

    elseif event == "BANKFRAME_OPENED" then
        QueueBankScan()

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ui and ui:IsShown() then QueueUIRefresh() end
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

SLASH_ROBUIGEARINDEX1 = "/rgear"
SlashCmdList["ROBUIGEARINDEX"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = SafeLower(cmd or "")

    if msg == "" then GI:ToggleUI(); return end
    if cmd == "scan" then QueueFullScan(); print("|cff00b3ffRobUI:|r Item index scan queued."); return end
    if cmd == "find" then GI:FindAndPrint(rest or ""); return end
    if cmd == "show" then CreateUI(); ui:Show(); GI:RefreshUI(); return end
    if cmd == "hide" then if ui then ui:Hide() end; return end
    
    if cmd == "all" or cmd == "warband" then
        selectedOwner = (cmd == "all") and "ALL" or "WARBAND"
        selectedCategory = "ALL"
        page = 1
        if ui and ui:IsShown() then GI:RefreshUI() end
        return
    end

    GI:FindAndPrint(msg)
end