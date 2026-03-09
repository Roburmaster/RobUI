local AddonName, ns = ...
local R = _G.Robui
R.AutoSellSettings = {}
local UI = R.AutoSellSettings

-- 1. ADVARSEL DIALOG
StaticPopupDialogs["ROBUI_AUTOSELL_WARNING"] = {
    text = "|cffff0000WARNING:|r You are turning on Auto Sell.\n\nMake sure you have set the correct wanted settings (Threshold, Whitelist, etc).\n\nThe system is |cffff0000UNFORGIVING|r and items sold might be lost forever.\n\nAre you sure?",
    button1 = "Yes, Enable",
    button2 = "Cancel",
    OnAccept = function(self, data)
    data.cfg.enabled = true
    data.cb:SetChecked(true)
    print("|cff00ff00Robui:|r Auto Sell Enabled.")
    end,
    OnCancel = function(self, data)
    data.cfg.enabled = false
    data.cb:SetChecked(false)
    end,
    timeout = 0,
    whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
}

-- 2. HJELPERE
local function ParseItem(raw)
if not raw then return nil end
    raw = raw:match("^%s*(.-)%s*$")
    if raw == "" then return nil end
        local id = tonumber(raw) or raw:match("|Hitem:(%d+):")
        if id then return tonumber(id) end
            local _, link = GetItemInfo(raw)
            if link then return tonumber(link:match("item:(%d+):")) end
                return nil
                end

                -- 3. GUI
                function UI:CreateGUI()
                if not R.Database or not R.Database.profile or not R.Database.profile.autosell then
                    C_Timer.After(1, function() UI:CreateGUI() end)
                    return
                    end

                    local p = CreateFrame("Frame", nil, UIParent)
                    local cfg = R.Database.profile.autosell

                    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                    title:SetPoint("TOPLEFT", 20, -20)
                    title:SetText("Auto Sell Settings")

                    -- Checkbox Helper
                    local y = -60
                    local function AddCheck(label, key)
                    local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
                    cb:SetPoint("TOPLEFT", 20, y)
                    cb.text:SetText(label)
                    cb.text:SetFontObject("GameFontHighlight")
                    cb:SetChecked(cfg[key])

                    -- Standard oppførsel (overskrives for 'enabled')
                    cb:SetScript("OnClick", function(self)
                    cfg[key] = self:GetChecked()
                    end)

                    y = y - 30
                    return cb
                    end

                    -- --- ENABLE MED ADVARSEL ---
                    local cbEnable = AddCheck("Enable Auto-Sell", "enabled")
                    cbEnable:SetScript("OnClick", function(self)
                    local isChecked = self:GetChecked()
                    if isChecked then
                        -- Slå av visuelt midlertidig og vis advarsel
                        self:SetChecked(false)
                        local dialog = StaticPopup_Show("ROBUI_AUTOSELL_WARNING")
                        if dialog then
                            dialog.data = { cfg = cfg, cb = self }
                            end
                            else
                                cfg.enabled = false
                                print("|cffff0000Robui:|r Auto Sell Disabled.")
                                end
                                end)

                    AddCheck("Sell Gray Items", "sellGray")
                    AddCheck("Sell Warbound Gear (below threshold)", "sellWarbound")
                    AddCheck("Log Sales to Chat", "logSales")

                    local cbShift = AddCheck("Shift-Click Mode (60s)", "shiftClickEnabled")
                    cbShift:SetScript("OnClick", function(self)
                    cfg.shiftClickEnabled = self:GetChecked()
                    if cfg.shiftClickEnabled then
                        print("|cff00b3ffAutoSell:|r Shift-Click bag items active for 60s.")
                        C_Timer.After(60, function()
                        cfg.shiftClickEnabled = false
                        if cbShift:IsVisible() then cbShift:SetChecked(false) end
                            print("|cff00b3ffAutoSell:|r Shift-Click mode OFF.")
                            end)
                        end
                        end)

                    -- Threshold Slider
                    y = y - 10
                    local slider = CreateFrame("Slider", "RobUIASThresh", p, "OptionsSliderTemplate")
                    slider:SetPoint("TOPLEFT", 20, y)
                    slider:SetWidth(200)
                    slider:SetMinMaxValues(1, 650)
                    slider:SetValue(cfg.threshold or 10)
                    slider:SetValueStep(1)
                    slider:SetObeyStepOnDrag(true)
                    _G[slider:GetName().."Text"]:SetText("Item Level Threshold: " .. (cfg.threshold or 10))
                    _G[slider:GetName().."Low"]:SetText("1")
                    _G[slider:GetName().."High"]:SetText("650")

                    slider:SetScript("OnValueChanged", function(self, val)
                    val = math.floor(val)
                    cfg.threshold = val
                    _G[slider:GetName().."Text"]:SetText("Item Level Threshold: " .. val)
                    end)

                    -- List Inputs
                    y = y - 60
                    local function CreateInput(label, anchorX, anchorY, isBlacklist)
                    local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    lbl:SetPoint("TOPLEFT", anchorX, anchorY)
                    lbl:SetText(label)

                    local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
                    eb:SetSize(180, 20)
                    eb:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -5)
                    eb:SetAutoFocus(false)

                    local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
                    btn:SetSize(60, 22)
                    btn:SetPoint("LEFT", eb, "RIGHT", 5, 0)
                    btn:SetText("Add")
                    btn:SetScript("OnClick", function()
                    local id = ParseItem(eb:GetText())
                    if id then
                        if R.AutoSell and R.AutoSell.AddToList then
                            R.AutoSell:AddToList(isBlacklist and "blacklist" or "whitelist", id)
                            eb:SetText("")
                            UI:UpdateLists()
                            end
                            end
                            end)

                    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
                    scroll:SetSize(240, 200)
                    scroll:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -10)

                    local content = CreateFrame("Frame", nil, scroll)
                    content:SetSize(240, 200)
                    scroll:SetScrollChild(content)

                    local bg = CreateFrame("Frame", nil, p, "BackdropTemplate")
                    bg:SetPoint("TOPLEFT", scroll, -5, 5)
                    bg:SetPoint("BOTTOMRIGHT", scroll, 25, -5)
                    R:CreateBackdrop(bg)
                    bg:SetBackdropColor(0,0,0,0.3)

                    return content
                    end

                    self.whiteContent = CreateInput("Whitelist (Always Sell)", 20, y, false)
                    self.blackContent = CreateInput("Blacklist (Never Sell)", 300, y, true)

                    UI:UpdateLists()
                    R:RegisterModulePanel("AutoSell", p)
                    end

                    function UI:UpdateLists()
                    if not self.whiteContent then return end
                        if not R.Database.global or not R.Database.global.autosellLists then return end

                            local function Fill(frame, list)
                            for _, child in ipairs({frame:GetChildren()}) do child:Hide() end
                                if not list then return end

                                    for i, id in ipairs(list) do
                                        local btn = CreateFrame("Button", nil, frame)
                                        btn:SetSize(230, 18)
                                        btn:SetPoint("TOPLEFT", 0, -(i-1)*18)

                                        local name, link = GetItemInfo(id)
                                        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                        btn.text:SetPoint("LEFT", 5, 0)
                                        btn.text:SetText(link or ("ID: "..id))

                                        btn:SetScript("OnEnter", function(self)
                                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                        GameTooltip:SetItemByID(id)
                                        GameTooltip:Show()
                                        end)
                                        btn:SetScript("OnLeave", GameTooltip_Hide)

                                        btn:SetScript("OnClick", function()
                                        table.remove(list, i)
                                        UI:UpdateLists()
                                        end)
                                        end
                                        end

                                        Fill(self.whiteContent, R.Database.global.autosellLists.whitelist)
                                        Fill(self.blackContent, R.Database.global.autosellLists.blacklist)
                                        end

                                        -- Init
                                        local loader = CreateFrame("Frame")
                                        loader:RegisterEvent("PLAYER_LOGIN")
                                        loader:SetScript("OnEvent", function(self, event)
                                        C_Timer.After(1, function() UI:CreateGUI() end)
                                        end)

                                        -- Slash Command
                                        SLASH_ROBUIAUTOSELL1 = "/autosell"
                                        SLASH_ROBUIAUTOSELL2 = "/as"
                                        SLASH_ROBUIAUTOSELL3 = "/rauto"

                                        SlashCmdList.ROBUIAUTOSELL = function()
                                        if R.MasterConfig and R.MasterConfig.Toggle then
                                            if not R.MasterConfig.frame or not R.MasterConfig.frame:IsShown() then
                                                R.MasterConfig:Toggle()
                                                end
                                                if R.MasterConfig.SelectTab then
                                                    R.MasterConfig:SelectTab("AutoSell")
                                                    end
                                                    else
                                                        print("Robui: MasterConfig not loaded.")
                                                        end
                                                        end
