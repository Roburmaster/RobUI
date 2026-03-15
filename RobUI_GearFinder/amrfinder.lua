local ADDON, ns = ...
ns = _G[ADDON] or ns
_G[ADDON] = ns

ns.AMRFinder = ns.AMRFinder or {}
local AF = ns.AMRFinder

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local tostring = tostring
local tonumber = tonumber
local type = type
local lower = string.lower
local format = string.format
local gmatch = string.gmatch
local match = string.match
local tsort = table.sort
local min = math.min
local max = math.max
local math_ceil = math.ceil
local pcall = pcall
local C_Timer = C_Timer
local GetItemInfo = GetItemInfo
local GetItemIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon

local frame = CreateFrame("Frame")
AF.frame = frame

local ui
local profileButtons = {}
local rows = {}
local shopRows = {}

local importedProfiles = {}
local selectedProfile = 1
local page = 1
local perPage = 13
local currentResults = {}
local uiRefreshQueued = false

-- Fetch Queue System
local fetchQueueSet = {}
local fetchQueueList = {}
local isFetching = false
local fetchTicker = nil

local SLOT_LABELS = {
    [1]  = "Head", [2]  = "Neck", [3]  = "Shoulder", [4]  = "Shirt",
    [5]  = "Chest", [6]  = "Waist", [7]  = "Legs", [8]  = "Feet",
    [9]  = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2",
    [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back", [16] = "Main Hand",
    [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard",
}

local function SafeLower(v)
    if v == nil then return "" end
    return lower(tostring(v))
end

local function GetDB()
    if ns.GearIndex and ns.GearIndex.EnsureDB then return ns.GearIndex.EnsureDB() end
    _G.RobUIGearFinderDB = _G.RobUIGearFinderDB or {}
    _G.RobUIGearFinderDB.itemIndex = _G.RobUIGearFinderDB.itemIndex or {}
    _G.RobUIGearFinderDB.amrImports = _G.RobUIGearFinderDB.amrImports or {}
    return _G.RobUIGearFinderDB
end

local function GetItemIndex()
    local db = GetDB()
    if not db then return nil end
    return db.itemIndex
end

local function ResetFetchQueue()
    if isFetching then return end
    wipe(fetchQueueSet)
    wipe(fetchQueueList)
end

local function GetItemNameAndCache(itemID)
    if not itemID or itemID == 0 then return nil end
    local idNum = tonumber(itemID)
    if not idNum then return nil end

    local name = GetItemInfo(idNum)
    if name and name ~= "" then return name end

    if _G.C_Item and _G.C_Item.GetItemNameByID then
        local ok, cName = pcall(_G.C_Item.GetItemNameByID, idNum)
        if ok and cName and cName ~= "" then return cName end
    end

    -- Queue missing item names for the fetcher
    if not isFetching and not fetchQueueSet[idNum] then
        fetchQueueSet[idNum] = true
        fetchQueueList[#fetchQueueList + 1] = idNum
    end

    return nil
end

local function StartFetching()
    if isFetching or #fetchQueueList == 0 then return end
    isFetching = true
    
    local fetchTotal = #fetchQueueList
    local fetchCurrent = 0
    
    ui.shoppingList.fetchBtn:SetText("Fetching... 0 / " .. fetchTotal)
    ui.shoppingList.fetchBtn:Disable()
    ui.shoppingList.progressBar:SetMinMaxValues(0, fetchTotal)
    ui.shoppingList.progressBar:SetValue(0)
    ui.shoppingList.progressBar:Show()
    
    fetchTicker = C_Timer.NewTicker(0.20, function()
        fetchCurrent = fetchCurrent + 1
        local itemID = fetchQueueList[fetchCurrent]
        
        if itemID then
            if _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
                pcall(_G.C_Item.RequestLoadItemDataByID, itemID)
            end
        end
        
        ui.shoppingList.progressBar:SetValue(fetchCurrent)
        ui.shoppingList.fetchBtn:SetText("Fetching... " .. fetchCurrent .. " / " .. fetchTotal)
        
        if fetchCurrent >= fetchTotal then
            isFetching = false
            ui.shoppingList.progressBar:Hide()
            AF:RefreshUI()
        end
    end, fetchTotal)
end

local function NormalizeSlot(slotID)
    slotID = tonumber(slotID)
    if not slotID then return nil end
    return slotID
end

local function GetSlotLabel(slotID)
    return SLOT_LABELS[slotID] or ("Slot " .. tostring(slotID or "?"))
end

local function ClearImported()
    wipe(importedProfiles)
    selectedProfile = 1
    page = 1
    wipe(currentResults)
    ResetFetchQueue()
    local db = GetDB()
    db.amrImports = db.amrImports or {}
    wipe(db.amrImports)
end

local function SearchAH(searchStr)
    if not searchStr or searchStr == "" then return end

    if _G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown() then
        if _G.AuctionHouseFrame.SearchBar and _G.AuctionHouseFrame.SearchBar.SearchBox then
            _G.AuctionHouseFrame.SearchBar.SearchBox:SetText(searchStr)
            if _G.AuctionHouseFrame.SearchBar.SearchButton then
                _G.AuctionHouseFrame.SearchBar.SearchButton:Click()
                print("|cff00b3ffRobUI:|r Searching AH for: " .. searchStr)
            end
        end
    else
        print("|cff00b3ffRobUI:|r Please open the Auction House to search for: |cffffff00" .. searchStr .. "|r")
    end
end

local function ParseAMRItemsFromSegment(qSegment)
    local items = {}
    if type(qSegment) ~= "string" or qSegment == "" then return items end

    local lastItemID, lastEnchID, lastGemX, lastGemY, lastGemZ = 0, 0, 0, 0, 0

    for token in gmatch(qSegment, "([^,;]+)") do
        local idDiffStr = match(token, "^(%-?%d+)")
        local slotIDStr = match(token, "s(%d+)")
        local enchDiffStr = match(token, "e(%-?%d+)")
        local gemXDiffStr = match(token, "x(%-?%d+)")
        local gemYDiffStr = match(token, "y(%-?%d+)")
        local gemZDiffStr = match(token, "z(%-?%d+)")

        if idDiffStr and slotIDStr then
            local idDiff = tonumber(idDiffStr)
            local itemID = (lastItemID == 0) and idDiff or (lastItemID + idDiff)
            lastItemID = itemID

            local enchID, gemX, gemY, gemZ
            if enchDiffStr then
                lastEnchID = lastEnchID + tonumber(enchDiffStr)
                enchID = lastEnchID
            end
            if gemXDiffStr then
                lastGemX = lastGemX + tonumber(gemXDiffStr)
                gemX = lastGemX
            end
            if gemYDiffStr then
                lastGemY = lastGemY + tonumber(gemYDiffStr)
                gemY = lastGemY
            end
            if gemZDiffStr then
                lastGemZ = lastGemZ + tonumber(gemZDiffStr)
                gemZ = lastGemZ
            end

            items[#items + 1] = {
                itemID = itemID,
                slotID = NormalizeSlot(slotIDStr),
                slotLabel = GetSlotLabel(NormalizeSlot(slotIDStr)),
                enchantID = enchID,
                gemX = gemX,
                gemY = gemY,
                gemZ = gemZ,
            }
        end
    end
    return items
end

local function ParseSingleAMRLine(line, lineIndex)
    if type(line) ~= "string" or line == "" then return nil end

    local specName = match(line, "#_@([^@]+)@")
    local classAndIndex = match(line, "%$@([^#]+)#")
    local qSegment = match(line, ";%.q%d+;(.-)%$@")
    if not qSegment then qSegment = match(line, ";%.q%d+;(.*)") end
    if not qSegment then return nil end

    -- CORRECTED: Extract actual Scroll ItemID from the AMR dictionary.
    -- The format is @e\AmrID\ItemID\IconID\Name
    local enchantDict = {}
    for eId, itemID in gmatch(line, "@e\\(%d+)\\(%d+)\\") do
        enchantDict[tonumber(eId)] = tonumber(itemID)
    end

    local profile = {
        index = lineIndex or 1,
        className = classAndIndex or "Unknown",
        specName = specName or ("Profile " .. tostring(lineIndex or 1)),
        items = ParseAMRItemsFromSegment(qSegment),
        enchantDict = enchantDict,
        raw = line,
    }

    if #profile.items == 0 then return nil end
    return profile
end

local function ParseAMRText(text)
    ClearImported()
    local db = GetDB()
    db.amrImports = db.amrImports or {}

    local idx = 0
    for line in gmatch((text or "") .. "\n", "([^\n\r]+)") do
        local trimmed = match(line, "^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            idx = idx + 1
            local profile = ParseSingleAMRLine(trimmed, idx)
            if profile then
                importedProfiles[#importedProfiles + 1] = profile
                db.amrImports[#db.amrImports + 1] = profile
            end
        end
    end
    return importedProfiles
end

local function CollectMatchesForItem(itemID)
    local itemIndex = GetItemIndex()
    if not itemIndex or not itemID then return {} end
    local entries = itemIndex[itemID]
    if type(entries) ~= "table" then return {} end

    local out = {}
    for i = 1, #entries do out[#out + 1] = entries[i] end

    tsort(out, function(a, b)
        local asrc, bsrc = SafeLower(a.source), SafeLower(b.source)
        if asrc ~= bsrc then return asrc < bsrc end
        local achar, bchar = SafeLower(a.character), SafeLower(b.character)
        if achar ~= bchar then return achar < bchar end
        local arealm, brealm = SafeLower(a.realm), SafeLower(b.realm)
        if arealm ~= brealm then return arealm < brealm end
        return SafeLower(a.locationText) < SafeLower(b.locationText)
    end)
    return out
end

local function BuildResultsForProfile(profile)
    wipe(currentResults)
    if not profile or type(profile.items) ~= "table" then return currentResults end

    local seenBySlotAndItem = {}
    for i = 1, #profile.items do
        local item = profile.items[i]
        local key = tostring(item.slotID or 0) .. ":" .. tostring(item.itemID or 0)

        if not seenBySlotAndItem[key] then
            seenBySlotAndItem[key] = true
            
            local itemName = GetItemNameAndCache(item.itemID) or ("item:" .. tostring(item.itemID))

            currentResults[#currentResults + 1] = {
                kind = "item",
                slotID = item.slotID,
                slotLabel = item.slotLabel,
                itemID = item.itemID,
                itemName = itemName,
                matches = CollectMatchesForItem(item.itemID),
                enchantItemID = item.enchantID and profile.enchantDict[item.enchantID] or nil,
                gemX = item.gemX,
                gemY = item.gemY,
                gemZ = item.gemZ,
            }
        end
    end

    tsort(currentResults, function(a, b)
        local aslot, bslot = tonumber(a.slotID) or 999, tonumber(b.slotID) or 999
        if aslot ~= bslot then return aslot < bslot end
        return SafeLower(a.itemName) < SafeLower(b.itemName)
    end)
    return currentResults
end

local function GetSelectedProfile()
    return importedProfiles[selectedProfile]
end

local function BuildDisplayRows(profile)
    local display = {}
    local resultItems = BuildResultsForProfile(profile)

    for i = 1, #resultItems do
        local item = resultItems[i]

        if #item.matches == 0 then
            display[#display + 1] = {
                rowType = "missing",
                slotLabel = item.slotLabel,
                itemID = item.itemID,
                itemName = item.itemName,
                ownerText = "Missing",
                locationText = "Not found in Gear Finder",
                itemLink = nil,
                enchantItemID = item.enchantItemID,
                gemX = item.gemX, gemY = item.gemY, gemZ = item.gemZ,
            }
        else
            for j = 1, #item.matches do
                local m = item.matches[j]
                local ownerText = (m.source == "warbandbank") and "Warband" or (tostring(m.character or "?") .. "-" .. tostring(m.realm or "?"))
                local displayItemName = m.itemName or item.itemName
                if m.ilvl then displayItemName = displayItemName .. " (|cff00ff96ilvl " .. m.ilvl .. "|r)" end

                display[#display + 1] = {
                    rowType = "found",
                    slotLabel = item.slotLabel,
                    itemID = item.itemID,
                    itemName = displayItemName,
                    ownerText = ownerText,
                    locationText = tostring(m.locationText or "?"),
                    itemLink = m.itemLink,
                    rawMatch = m,
                    enchantItemID = item.enchantItemID,
                    gemX = item.gemX, gemY = item.gemY, gemZ = item.gemZ,
                }
            end
        end
    end
    return display
end

local function CreateSubButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(130, 14)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT")
    btn.text:SetJustifyH("LEFT")
    btn.text:SetWidth(125)
    btn.text:SetWordWrap(false)
    btn:SetFontString(btn.text)
    
    btn:SetScript("OnEnter", function(self)
        if self.btnEnabled then
            self.text:SetTextColor(1, 0.82, 0)
        end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(self.searchName or "Search")
        if self.btnEnabled then
            GameTooltip:AddLine("Click here while the Auction House is open to search for this item.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Item data is missing. Please click 'Fetch Missing Data' in the shopping list.", 1, 0.3, 0.3, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if self.btnEnabled then
            self.text:SetTextColor(0.6, 0.8, 1)
        else
            self.text:SetTextColor(0.5, 0.5, 0.5)
        end
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        if self.btnEnabled and self.searchName then
            SearchAH(self.searchName)
        end
    end)
    
    return btn
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(900, 36)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -210 - ((index - 1) * 38))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.05 or 0.02)

    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.left:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
    row.left:SetJustifyH("LEFT")
    row.left:SetWidth(520)

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWidth(350)
    
    row.enchBtn = CreateSubButton(row)
    row.enchBtn:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
    
    row.gem1Btn = CreateSubButton(row)
    row.gem1Btn:SetPoint("LEFT", row.enchBtn, "RIGHT", 4, 0)
    
    row.gem2Btn = CreateSubButton(row)
    row.gem2Btn:SetPoint("LEFT", row.gem1Btn, "RIGHT", 4, 0)
    
    row.gem3Btn = CreateSubButton(row)
    row.gem3Btn:SetPoint("LEFT", row.gem2Btn, "RIGHT", 4, 0)

    row:SetScript("OnEnter", function(self)
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.data.itemLink then GameTooltip:SetHyperlink(self.data.itemLink) else GameTooltip:SetText(self.data.itemName or ("item:" .. tostring(self.data.itemID))) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("AMR Slot: " .. tostring(self.data.slotLabel or "?"), 0.7, 0.9, 1)

        if self.data.rowType == "missing" then
            GameTooltip:AddLine("Status: Missing", 1, 0.25, 0.25)
            GameTooltip:AddLine("This item was not found in Gear Finder.", 0.85, 0.85, 0.85)
        else
            GameTooltip:AddLine("Owner: " .. tostring(self.data.ownerText or "?"), 1, 1, 1)
            GameTooltip:AddLine("Location: " .. tostring(self.data.locationText or "?"), 0.85, 0.85, 0.85)
            if self.data.rawMatch and self.data.rawMatch.source then GameTooltip:AddLine("Source: " .. tostring(self.data.rawMatch.source), 0.7, 1, 0.7) end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function CreateShopRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(330, 26)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6 - ((index - 1) * 28))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.05 or 0.02)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(180)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.btn:SetSize(80, 20)
    row.btn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.btn:SetScript("OnClick", function(self)
        if self.itemName then
            SearchAH(self.itemName)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function RefreshProfileButtons()
    if not ui then return end
    for i = 1, #profileButtons do profileButtons[i]:Hide(); profileButtons[i].profileIndex = nil end

    local btnW, btnH, gapX, gapY, cols = 170, 22, 6, 4, 5
    for i = 1, #importedProfiles do
        local p = importedProfiles[i]
        local btn = profileButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetScript("OnClick", function(self) selectedProfile = self.profileIndex or 1; page = 1; AF:RefreshUI() end)
            profileButtons[i] = btn
        end

        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui, "TOPLEFT", 14 + col * (btnW + gapX), -140 - row * (btnH + gapY))
        btn.profileIndex = i
        btn:SetText((p.specName or ("Profile " .. i)))

        if selectedProfile == i then
            btn:LockHighlight()
            if btn.Text then btn.Text:SetTextColor(1, 0.82, 0) end
        else
            btn:UnlockHighlight()
            if btn.Text then btn.Text:SetTextColor(1, 1, 1) end
        end
        btn:Show()
    end
end

local function RefreshShoppingList()
    if not ui or not ui.shoppingList then return end
    for i = 1, #shopRows do shopRows[i]:Hide() end

    local profile = GetSelectedProfile()
    if not profile or not profile.items then return end

    local requirements = {}
    for _, item in ipairs(profile.items) do
        if item.enchantID and profile.enchantDict[item.enchantID] then
            local eID = profile.enchantDict[item.enchantID]
            requirements[eID] = (requirements[eID] or 0) + 1
        end
        if item.gemX then requirements[item.gemX] = (requirements[item.gemX] or 0) + 1 end
        if item.gemY then requirements[item.gemY] = (requirements[item.gemY] or 0) + 1 end
        if item.gemZ then requirements[item.gemZ] = (requirements[item.gemZ] or 0) + 1 end
    end

    local shopItems = {}
    for itemID, count in pairs(requirements) do
        shopItems[#shopItems + 1] = { itemID = itemID, count = count }
    end
    tsort(shopItems, function(a, b) return a.itemID < b.itemID end)

    for i, data in ipairs(shopItems) do
        local row = shopRows[i]
        if not row then
            row = CreateShopRow(ui.shoppingList.scrollChild, i)
            shopRows[i] = row
        end

        row.itemID = data.itemID
        local name = GetItemNameAndCache(data.itemID)
        
        if GetItemIcon then
            local icon = GetItemIcon(data.itemID)
            if icon then row.icon:SetTexture(icon) else row.icon:SetColorTexture(0.5, 0.5, 0.5, 1) end
        end

        if name then
            row.name:SetText(tostring(data.count) .. "x " .. name)
            row.name:SetTextColor(1, 1, 1)
            row.btn.itemName = name
            row.btn:Enable()
            row.btn:SetText("Search AH")
        else
            row.name:SetText(tostring(data.count) .. "x Loading...")
            row.name:SetTextColor(0.5, 0.5, 0.5)
            row.btn.itemName = nil
            row.btn:Disable()
            row.btn:SetText("Wait...")
        end

        row:Show()
    end
end

local function SetupSubButtonLogic(btn, id, prefix)
    if not id or id == 0 then
        btn:Hide()
        return
    end
    
    local name = GetItemNameAndCache(id)
    if name then
        btn.searchName = name
        btn.text:SetText(prefix .. ": " .. name)
        btn.text:SetTextColor(0.6, 0.8, 1)
        btn.btnEnabled = true
    else
        btn.searchName = nil
        btn.text:SetText(prefix .. ": Loading...")
        btn.text:SetTextColor(0.5, 0.5, 0.5)
        btn.btnEnabled = false
    end
    btn:Show()
end

local function CreateUI()
    if ui then return end

    ui = CreateFrame("Frame", "RobUI_AMRFinderFrame", UIParent, "BackdropTemplate")
    ui:SetSize(940, 740)
    ui:SetPoint("CENTER", -170, 0)
    ui:SetMovable(true); ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton"); ui:SetScript("OnDragStart", ui.StartMoving); ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
    ui:SetClampedToScreen(true); ui:Hide()
    ui:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    ui:SetBackdropColor(0, 0, 0, 1)

    ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.title:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -14); ui.title:SetText("RobUI AMR Finder")
    ui.close = CreateFrame("Button", nil, ui, "UIPanelCloseButton"); ui.close:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -4, -4)

    ui.help = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.help:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -40); ui.help:SetWidth(890); ui.help:SetJustifyH("LEFT")
    ui.help:SetText("Paste AskMrRobot export lines below, then click Import. Use the Shopping List on the right to buy required Enchants and Gems.")

    ui.importBoxBG = CreateFrame("Frame", nil, ui, "BackdropTemplate")
    ui.importBoxBG:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -64); ui.importBoxBG:SetSize(720, 62)
    ui.importBoxBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    ui.importBoxBG:SetBackdropColor(0, 0, 0, 0.45)

    ui.importScroll = CreateFrame("ScrollFrame", nil, ui.importBoxBG, "UIPanelScrollFrameTemplate")
    ui.importScroll:SetPoint("TOPLEFT", 6, -6); ui.importScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.importBox = CreateFrame("EditBox", nil, ui.importScroll)
    ui.importBox:SetMultiLine(true); ui.importBox:SetFontObject("ChatFontNormal"); ui.importBox:SetAutoFocus(false); ui.importBox:SetWidth(670)
    ui.importBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.importScroll:SetScrollChild(ui.importBox)

    ui.importBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.importBtn:SetSize(90, 24); ui.importBtn:SetPoint("TOPLEFT", ui.importBoxBG, "TOPRIGHT", 10, -2); ui.importBtn:SetText("Import")
    ui.importBtn:SetScript("OnClick", function()
        local parsed = ParseAMRText(ui.importBox:GetText() or "")
        if #parsed == 0 then print("|cff00b3ffRobUI:|r No valid AskMrRobot profiles found."); AF:RefreshUI(); return end
        selectedProfile = 1; page = 1; AF:RefreshUI()
        print("|cff00b3ffRobUI:|r Imported " .. tostring(#parsed) .. " AskMrRobot profile(s).")
    end)

    ui.clearBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.clearBtn:SetSize(90, 24); ui.clearBtn:SetPoint("TOPLEFT", ui.importBtn, "BOTTOMLEFT", 0, -6); ui.clearBtn:SetText("Clear")
    ui.clearBtn:SetScript("OnClick", function() ClearImported(); ui.importBox:SetText(""); AF:RefreshUI() end)

    ui.summary = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.summary:SetPoint("TOPLEFT", ui, "TOPLEFT", 14, -135); ui.summary:SetWidth(890); ui.summary:SetJustifyH("LEFT")

    ui.headerLeft = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.headerLeft:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -194); ui.headerLeft:SetText("AMR Item / Slot / Sub-items")
    ui.headerRight = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.headerRight:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -16, -194); ui.headerRight:SetText("Owner / Location")

    ui.prevBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.prevBtn:SetSize(80, 22); ui.prevBtn:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 14, 14); ui.prevBtn:SetText("Prev")
    ui.prevBtn:SetScript("OnClick", function() page = max(1, page - 1); AF:RefreshUI() end)
    ui.nextBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.nextBtn:SetSize(80, 22); ui.nextBtn:SetPoint("LEFT", ui.prevBtn, "RIGHT", 8, 0); ui.nextBtn:SetText("Next")
    ui.nextBtn:SetScript("OnClick", function() page = page + 1; AF:RefreshUI() end)

    ui.pageText = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.pageText:SetPoint("LEFT", ui.nextBtn, "RIGHT", 14, 0)

    for i = 1, perPage do rows[i] = CreateRow(ui, i) end

    -- Shopping List Frame
    ui.shoppingList = CreateFrame("Frame", "RobUI_AMRShoppingList", ui, "BackdropTemplate")
    ui.shoppingList:SetSize(360, 740)
    ui.shoppingList:SetPoint("TOPLEFT", ui, "TOPRIGHT", 4, 0)
    ui.shoppingList:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    ui.shoppingList:SetBackdropColor(0, 0, 0, 1)

    ui.shoppingList.title = ui.shoppingList:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.shoppingList.title:SetPoint("TOPLEFT", ui.shoppingList, "TOPLEFT", 14, -14)
    ui.shoppingList.title:SetText("Shopping List")

    -- Fetch Mechanics
    ui.shoppingList.fetchBtn = CreateFrame("Button", nil, ui.shoppingList, "UIPanelButtonTemplate")
    ui.shoppingList.fetchBtn:SetSize(330, 24)
    ui.shoppingList.fetchBtn:SetPoint("TOPLEFT", ui.shoppingList, "TOPLEFT", 14, -40)
    ui.shoppingList.fetchBtn:SetText("Fetch Missing Data")
    ui.shoppingList.fetchBtn:SetScript("OnClick", StartFetching)

    ui.shoppingList.progressBar = CreateFrame("StatusBar", nil, ui.shoppingList, "BackdropTemplate")
    ui.shoppingList.progressBar:SetSize(330, 12)
    ui.shoppingList.progressBar:SetPoint("TOPLEFT", ui.shoppingList.fetchBtn, "BOTTOMLEFT", 0, -4)
    ui.shoppingList.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    ui.shoppingList.progressBar:SetStatusBarColor(0, 0.8, 0)
    ui.shoppingList.progressBar:Hide()

    ui.shoppingList.scrollFrame = CreateFrame("ScrollFrame", nil, ui.shoppingList, "UIPanelScrollFrameTemplate")
    ui.shoppingList.scrollFrame:SetPoint("TOPLEFT", 10, -90)
    ui.shoppingList.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    ui.shoppingList.scrollChild = CreateFrame("Frame", nil, ui.shoppingList.scrollFrame)
    ui.shoppingList.scrollChild:SetSize(320, 1)
    ui.shoppingList.scrollFrame:SetScrollChild(ui.shoppingList.scrollChild)
end

function AF:RefreshUI()
    if not ui then return end
    RefreshProfileButtons()
    
    if not isFetching then
        ResetFetchQueue()
    end

    local profile = GetSelectedProfile()

    if not profile then
        ui.summary:SetText("No imported profiles."); ui.pageText:SetText("Page 1 / 1")
        for i = 1, perPage do rows[i]:Hide(); rows[i].data = nil end
        RefreshShoppingList()
        return
    end

    local displayRows = BuildDisplayRows(profile)
    local totalFound, totalMissing = 0, 0
    for i = 1, #displayRows do if displayRows[i].rowType == "missing" then totalMissing = totalMissing + 1 else totalFound = totalFound + 1 end end

    ui.summary:SetText(format("Profile: %s  |  ClassKey: %s  |  AMR Items: %d  |  Found Rows: %d  |  Missing: %d",
        tostring(profile.specName or "?"), tostring(profile.className or "?"), #(profile.items or {}), totalFound, totalMissing))

    local totalPages = max(1, math_ceil(#displayRows / perPage))
    if page < 1 then page = 1 end
    if page > totalPages then page = totalPages end

    local startIndex = (page - 1) * perPage + 1
    for i = 1, perPage do
        local data = displayRows[startIndex + i - 1]
        local row = rows[i]

        if not data then
            row:Hide(); row.data = nil
        else
            local statusColor = (data.rowType == "missing") and "|cffff5050" or "|cff80ff80"
            local itemText = statusColor .. "[" .. tostring(data.slotLabel or "?") .. "]|r " .. tostring(data.itemLink or data.itemName or ("item:" .. tostring(data.itemID)))
            
            local rightText = (data.rowType == "missing") 
                and ("|cffff5050Missing|r  |cffbfbfbf[" .. tostring(data.locationText or "?") .. "]|r")
                or ("|cffffffff" .. tostring(data.ownerText or "?") .. "|r  |cffbfbfbf[" .. tostring(data.locationText or "?") .. "]|r")

            row.left:SetText(itemText)
            row.right:SetText(rightText)
            
            SetupSubButtonLogic(row.enchBtn, data.enchantItemID, "Ench")
            SetupSubButtonLogic(row.gem1Btn, data.gemX, "Gem")
            SetupSubButtonLogic(row.gem2Btn, data.gemY, "Gem")
            SetupSubButtonLogic(row.gem3Btn, data.gemZ, "Gem")

            row.data = data
            row:Show()
        end
    end
    ui.pageText:SetText(format("Page %d / %d  |  Rows: %d", page, totalPages, #displayRows))

    RefreshShoppingList()

    if not isFetching then
        if #fetchQueueList > 0 then
            ui.shoppingList.fetchBtn:SetText("Fetch Missing Data (" .. #fetchQueueList .. ")")
            ui.shoppingList.fetchBtn:Enable()
        else
            ui.shoppingList.fetchBtn:SetText("All Data Loaded")
            ui.shoppingList.fetchBtn:Disable()
        end
    end
end

function AF:ToggleUI()
    CreateUI(); if ui:IsShown() then ui:Hide() else ui:Show(); self:RefreshUI() end
end

function AF:ImportText(text)
    CreateUI(); ui.importBox:SetText(text or ""); ParseAMRText(text or "")
    selectedProfile = 1; page = 1; self:RefreshUI()
end

local function QueueUIRefresh()
    if uiRefreshQueued or isFetching then return end
    uiRefreshQueued = true
    C_Timer.After(0.25, function()
        uiRefreshQueued = false
        if ui and ui:IsShown() then
            AF:RefreshUI()
        end
    end)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if ui and ui:IsShown() then
            QueueUIRefresh()
        end
    end
end)
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

SLASH_ROBUIAMR1 = "/ramr"
SlashCmdList["ROBUIAMR"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    if msg == "" then AF:ToggleUI(); return end
    if SafeLower(msg) == "clear" then
        ClearImported(); if ui then ui.importBox:SetText(""); AF:RefreshUI() end
        print("|cff00b3ffRobUI:|r AMR import cleared."); return
    end
    AF:ImportText(msg); if ui then ui:Show() end
end