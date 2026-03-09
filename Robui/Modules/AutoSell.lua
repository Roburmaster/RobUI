local AddonName, ns = ...
local R = _G.Robui
R.AutoSell = {}
local AS = R.AutoSell

print("|cff00ff00Robui:|r AutoSell Logic Loaded.") -- DEBUG

-- 1. HJELPEFUNKSJONER
local function IsWarboundItem(loc)
if not loc then return false end
    if C_Item and C_Item.IsBoundToAccountUntilEquip then
        local ok, res = pcall(C_Item.IsBoundToAccountUntilEquip, loc)
        return ok and res or false
        end
        return false
        end

        local function IsEquippableItem(itemID)
        if C_Item and C_Item.IsEquippableItem then
            local ok, res = pcall(C_Item.IsEquippableItem, itemID)
            return ok and res or false
            end
            return false
            end

            local function GetItemLevel(loc)
            if not loc then return nil end
                if C_Item and C_Item.GetCurrentItemLevel then
                    local ok, ilvl = pcall(C_Item.GetCurrentItemLevel, loc)
                    if ok then return ilvl end
                        end
                        return nil
                        end

                        -- 2. PUBLIC API
                        function AS:AddToList(listType, id)
                        if not R.Database or not R.Database.global then return end
                            local db = R.Database.global.autosellLists
                            if not db then return end

                                local list = (listType == "whitelist") and db.whitelist or db.blacklist
                                for _, v in ipairs(list) do
                                    if v == id then return end
                                        end
                                        table.insert(list, id)
                                        print(("|cff00b3ffAutoSell:|r Added %d to %s"):format(id, listType))
                                        end

                                        -- 3. HOVEDLOGIKK
                                        local function ScanAndSell()
                                        if not R.Database or not R.Database.profile then return end
                                            local cfg = R.Database.profile.autosell
                                            local lists = R.Database.global.autosellLists

                                            if not cfg or not cfg.enabled then return end

                                                local thr = tonumber(cfg.threshold) or 0
                                                local whiteSet, blackSet = {}, {}

                                                if lists then
                                                    for _, id in ipairs(lists.whitelist) do whiteSet[id] = true end
                                                        for _, id in ipairs(lists.blacklist) do blackSet[id] = true end
                                                            end

                                                            local sellList = {}

                                                            for bag = 0, 4 do
                                                                local slots = C_Container.GetContainerNumSlots(bag)
                                                                for slot = 1, slots do
                                                                    local info = C_Container.GetContainerItemInfo(bag, slot)
                                                                    if info and info.itemID then
                                                                        local id = info.itemID
                                                                        local link = info.hyperlink

                                                                        if blackSet[id] then
                                                                            -- skip
                                                                            elseif whiteSet[id] then
                                                                                table.insert(sellList, { bag = bag, slot = slot, link = link })
                                                                                else
                                                                                    local quality = info.quality
                                                                                    if quality == 0 then
                                                                                        if cfg.sellGray then
                                                                                            table.insert(sellList, { bag = bag, slot = slot, link = link })
                                                                                            end
                                                                                            else
                                                                                                if IsEquippableItem(id) then
                                                                                                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                                                                                                    local ilvl = GetItemLevel(loc)
                                                                                                    if ilvl and ilvl < thr then
                                                                                                        local isWarbound = IsWarboundItem(loc)
                                                                                                        if isWarbound then
                                                                                                            if cfg.sellWarbound then
                                                                                                                table.insert(sellList, { bag = bag, slot = slot, link = link })
                                                                                                                end
                                                                                                                else
                                                                                                                    table.insert(sellList, { bag = bag, slot = slot, link = link })
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end
                                                                                                                    end

                                                                                                                    if #sellList == 0 then return end

                                                                                                                        if cfg.logSales then
                                                                                                                            print(("|cff00b3ffAutoSell:|r Selling %d items..."):format(#sellList))
                                                                                                                            end

                                                                                                                            local idx = 1
                                                                                                                            C_Timer.NewTicker(0.15, function(tkr)
                                                                                                                            if idx > #sellList then
                                                                                                                                tkr:Cancel()
                                                                                                                                return
                                                                                                                                end
                                                                                                                                local it = sellList[idx]
                                                                                                                                C_Container.UseContainerItem(it.bag, it.slot)
                                                                                                                                if cfg.logSales then
                                                                                                                                    print(("Sold: %s"):format(it.link or "Unknown"))
                                                                                                                                    end
                                                                                                                                    idx = idx + 1
                                                                                                                                    end)
                                                                                                                            end

                                                                                                                            local f = CreateFrame("Frame")
                                                                                                                            f:RegisterEvent("MERCHANT_SHOW")
                                                                                                                            f:SetScript("OnEvent", function() C_Timer.After(0.2, ScanAndSell) end)

                                                                                                                            if ContainerFrameItemButtonMixin then
                                                                                                                                hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function(self, button)
                                                                                                                                if not R.Database or not R.Database.profile then return end
                                                                                                                                    local cfg = R.Database.profile.autosell
                                                                                                                                    if not cfg or not cfg.shiftClickEnabled then return end
                                                                                                                                        if not IsShiftKeyDown() then return end

                                                                                                                                            local bag = self:GetBagID()
                                                                                                                                            local slot = self:GetID()
                                                                                                                                            if not bag or not slot then return end

                                                                                                                                                local info = C_Container.GetContainerItemInfo(bag, slot)
                                                                                                                                                local id = info and info.itemID
                                                                                                                                                if not id then return end

                                                                                                                                                    if button == "LeftButton" then
                                                                                                                                                        AS:AddToList("whitelist", id)
                                                                                                                                                        elseif button == "RightButton" then
                                                                                                                                                            AS:AddToList("blacklist", id)
                                                                                                                                                            end

                                                                                                                                                            if R.AutoSellSettings and R.AutoSellSettings.UpdateLists then
                                                                                                                                                                R.AutoSellSettings:UpdateLists()
                                                                                                                                                                end
                                                                                                                                                                end)
                                                                                                                                end
