local AddonName, ns = ...
local R = _G.Robui
local UF_Panel = {}

-- Helper: Finn modulene sikkert
local function GetUnitFrame(unit)
if not ns.UnitFrames then return nil end
    if unit == "player" then return ns.UnitFrames.Player end
        if unit == "target" then return ns.UnitFrames.Target end
            if unit == "targettarget" then return ns.UnitFrames.TargetTarget end
                if unit == "focus" then return ns.UnitFrames.Focus end
                    if unit == "pet" then return ns.UnitFrames.Pet end
                        return nil
                        end

                        -- Helper: Finn settings-modulene sikkert
                        local function GetSettings(unit)
                        if not ns.UnitFrames then return nil end
                            local key = (unit == "targettarget") and "TargetTarget" or (unit:gsub("^%l", string.upper))
                            if ns.UnitFrames[key] and ns.UnitFrames[key].Settings then
                                return ns.UnitFrames[key].Settings
                                end
                                return nil
                                end

                                function UF_Panel:CreateGUI()
                                local p = CreateFrame("Frame", nil, UIParent)

                                -- Tittel
                                local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                                title:SetPoint("TOPLEFT", 20, -20)
                                title:SetText("Unit Frames")

                                local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                desc:SetPoint("TOPLEFT", 20, -45)
                                desc:SetText("Enable and configure individual unit frames.")

                                -- Liste-container
                                local listView = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
                                listView:SetPoint("TOPLEFT", 0, -70)
                                listView:SetPoint("BOTTOMRIGHT", -30, 0)

                                local listContent = CreateFrame("Frame", nil, listView)
                                listContent:SetSize(600, 600)
                                listView:SetScrollChild(listContent)

                                -- Settings-container (for embedding)
                                local settingsContainer = CreateFrame("Frame", nil, p)
                                settingsContainer:SetPoint("TOPLEFT", 0, -60)
                                settingsContainer:SetPoint("BOTTOMRIGHT", 0, 0)
                                settingsContainer:Hide()

                                -- Tilbake-knapp
                                local backBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
                                backBtn:SetSize(80, 22)
                                backBtn:SetPoint("TOPRIGHT", -30, -20)
                                backBtn:SetText("<< Back")
                                backBtn:Hide()

                                -- Variabler for å gjenopprette vindu-stil når man går tilbake
                                local activeEmbeddedFrame = nil
                                local originalProps = {}

                                local function ReleaseFrame()
                                if not activeEmbeddedFrame then return end
                                    local f = activeEmbeddedFrame
                                    local props = originalProps

                                    f:Hide()
                                    f:SetParent(UIParent)
                                    f:ClearAllPoints()
                                    f:SetPoint("CENTER")
                                    f:SetFrameStrata("DIALOG")

                                    -- Gjenopprett utseende (hvis lagret)
                                    if f.SetBackdrop and props.backdrop then f:SetBackdrop(props.backdrop) end
                                        if f.SetBackdropColor and props.bgColor then f:SetBackdropColor(unpack(props.bgColor)) end
                                            if f.SetBackdropBorderColor and props.borderColor then f:SetBackdropBorderColor(unpack(props.borderColor)) end

                                                if f.SetMovable then f:SetMovable(true) end
                                                    f:EnableMouse(true)

                                                    -- Vis lukkeknappen igjen
                                                    for i=1, f:GetNumChildren() do
                                                        local child = select(i, f:GetChildren())
                                                        if child:IsObjectType("Button") and child:GetSize() < 40 then
                                                            child:Show()
                                                            end
                                                            end

                                                            activeEmbeddedFrame = nil
                                                            end

                                                            backBtn:SetScript("OnClick", function()
                                                            ReleaseFrame()
                                                            settingsContainer:Hide()
                                                            backBtn:Hide()
                                                            listView:Show()
                                                            title:SetText("Unit Frames")
                                                            end)

                                                            local function EmbedFrame(unit, label)
                                                            local settings = GetSettings(unit)
                                                            if not settings then return end

                                                                -- Sørg for at rammen er laget
                                                                if settings.Toggle and not settings.frame then settings:Build() end

                                                                    local f = settings.frame
                                                                    if not f then return end

                                                                        -- Lagre tilstand
                                                                        activeEmbeddedFrame = f
                                                                        local bgR, bgG, bgB, bgA = 0,0,0,0
                                                                        if f.GetBackdropColor then bgR, bgG, bgB, bgA = f:GetBackdropColor() end

                                                                            local bR, bG, bB, bA = 0,0,0,0
                                                                            if f.GetBackdropBorderColor then bR, bG, bB, bA = f:GetBackdropBorderColor() end

                                                                                originalProps = {
                                                                                    backdrop = f.GetBackdrop and f:GetBackdrop(),
                                                                                    bgColor = {bgR, bgG, bgB, bgA},
                                                                                    borderColor = {bR, bG, bB, bA},
                                                                                }

                                                                                -- Bytt visning
                                                                                listView:Hide()
                                                                                settingsContainer:Show()
                                                                                backBtn:Show()
                                                                                title:SetText("Settings: " .. label)

                                                                                -- "Fang" rammen
                                                                                f:SetParent(settingsContainer)
                                                                                f:ClearAllPoints()
                                                                                f:SetPoint("TOPLEFT", 0, 0)
                                                                                f:SetPoint("BOTTOMRIGHT", 0, 0)
                                                                                f:Show()

                                                                                -- Fjern popup-stil
                                                                                if f.SetBackdrop then f:SetBackdrop(nil) end
                                                                                    f:EnableMouse(false)
                                                                                    if f.SetMovable then f:SetMovable(false) end

                                                                                        -- Skjul lukkeknapp
                                                                                        for i=1, f:GetNumChildren() do
                                                                                            local child = select(i, f:GetChildren())
                                                                                            if child:IsObjectType("Button") then
                                                                                                local w, h = child:GetSize()
                                                                                                if w > 20 and w < 40 then child:Hide() end
                                                                                                    end
                                                                                                    end

                                                                                                    if settings.RefreshIfOpen then settings.RefreshIfOpen() end
                                                                                                        end

                                                                                                        local y = -10
                                                                                                        local function AddRow(unit, label)
                                                                                                        local mod = GetUnitFrame(unit)

                                                                                                        -- FIX: Sjekk at databasen og tabellen faktisk finnes før vi prøver å hente [unit]
                                                                                                        local db
                                                                                                        if R.Database and R.Database.profile and R.Database.profile.unitframes then
                                                                                                            db = R.Database.profile.unitframes[unit]
                                                                                                            end

                                                                                                            if not db then
                                                                                                                -- Debug beskjed hvis noe mangler, men krasjer ikke
                                                                                                                -- print("Robui: Missing DB entry for", unit)
                                                                                                                return
                                                                                                                end

                                                                                                                local cb = CreateFrame("CheckButton", nil, listContent, "UICheckButtonTemplate")
                                                                                                                cb:SetPoint("TOPLEFT", 20, y)
                                                                                                                cb.text:SetText(label)
                                                                                                                cb:SetChecked(db.shown)

                                                                                                                cb:SetScript("OnClick", function(self)
                                                                                                                local val = self:GetChecked()
                                                                                                                if mod and mod.SetShown then
                                                                                                                    mod:SetShown(val)
                                                                                                                    else
                                                                                                                        db.shown = val
                                                                                                                        end
                                                                                                                        end)

                                                                                                                local btn = CreateFrame("Button", nil, listContent, "GameMenuButtonTemplate")
                                                                                                                btn:SetSize(100, 22)
                                                                                                                btn:SetPoint("LEFT", cb.text, "RIGHT", 20, 0)
                                                                                                                btn:SetText("Settings")
                                                                                                                btn:SetScript("OnClick", function()
                                                                                                                EmbedFrame(unit, label)
                                                                                                                end)

                                                                                                                y = y - 35
                                                                                                                end

                                                                                                                AddRow("player", "Player Frame")
                                                                                                                AddRow("target", "Target Frame")
                                                                                                                AddRow("targettarget", "Target of Target")
                                                                                                                AddRow("focus", "Focus Frame")
                                                                                                                AddRow("pet", "Pet Frame")

                                                                                                                R:RegisterModulePanel("UnitFrames", p)
                                                                                                                end

                                                                                                                -- Init
                                                                                                                local loader = CreateFrame("Frame")
                                                                                                                loader:RegisterEvent("ADDON_LOADED")
                                                                                                                loader:SetScript("OnEvent", function(self, event, arg1)
                                                                                                                if arg1 == AddonName then
                                                                                                                    UF_Panel:CreateGUI()
                                                                                                                    end
                                                                                                                    end)
