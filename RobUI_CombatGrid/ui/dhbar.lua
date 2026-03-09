-- RGridCore plugin: Devourer Souls Bar
-- Tracks Aura ID 1225789 up to 50 stacks.
-- Only loads for Demon Hunters, and only shows if in the "Devour" spec.

local _, playerClass = UnitClass("player")
if playerClass ~= "DEMONHUNTER" then return end -- Abort loading entirely if not a Demon Hunter

    local PLUGIN_ID = "rgrid_devourer_souls"
    local frame
    local registered = false

    local SOULS_AURA_ID = 1225789
    local MAX_SOULS = 50

    -- Adjust this if your spec goes by a specific ID instead of a name.
    local REQUIRED_SPEC_NAME = "devour"

    ------------------------------------------------------------------------
    -- Spec Check Logic
    ------------------------------------------------------------------------
    local function IsValidSpec()
    local specIndex = GetSpecialization()
    if not specIndex then return false end

        local _, specName = GetSpecializationInfo(specIndex)
        if specName and string.find(string.lower(specName), REQUIRED_SPEC_NAME) then
            return true
            end

            return false
            end

            ------------------------------------------------------------------------
            -- Update Logic
            ------------------------------------------------------------------------
            local function UpdateSouls()
            if not frame then return end

                -- Hide the bar elements safely if not in the correct spec
                if not IsValidSpec() then
                    frame.bar:Hide()
                    return
                    else
                        frame.bar:Show()
                        end

                        local stacks = 0
                        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SOULS_AURA_ID)

                        if auraData then
                            stacks = auraData.applications or 0
                            end

                            frame.bar:SetValue(stacks)
                            frame.text:SetText("Souls: " .. stacks .. " / " .. MAX_SOULS)
                            end

                            ------------------------------------------------------------------------
                            -- Build Frame
                            ------------------------------------------------------------------------
                            local function BuildFrame()
                            if frame then return frame end

                                frame = CreateFrame("Frame", "RGrid_DevourerBarFrame", UIParent)
                                frame:SetSize(200, 20)

                                -- Visuals: Souls Bar
                                local SoulsBar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
                                SoulsBar:SetAllPoints(frame)
                                SoulsBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
                                SoulsBar:SetStatusBarColor(0.40, 0.10, 0.60, 1) -- Void purple color

                                local SoulsBG = SoulsBar:CreateTexture(nil, "BACKGROUND")
                                SoulsBG:SetAllPoints(SoulsBar)
                                SoulsBG:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
                                SoulsBG:SetVertexColor(0.1, 0.1, 0.1, 1)

                                -- Text overlay
                                local SoulsText = SoulsBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                SoulsText:SetPoint("CENTER", SoulsBar, "CENTER", 0, 0)

                                SoulsBar:SetMinMaxValues(0, MAX_SOULS)
                                SoulsBar:SetValue(0)
                                SoulsText:SetText("Souls: 0 / " .. MAX_SOULS)

                                frame.bar = SoulsBar
                                frame.text = SoulsText

                                -- Events
                                frame:RegisterEvent("PLAYER_ENTERING_WORLD")
                                frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
                                frame:RegisterUnitEvent("UNIT_AURA", "player")

                                frame:SetScript("OnEvent", function(self, event, unit)
                                if event == "UNIT_AURA" and unit ~= "player" then return end
                                    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
                                        UpdateSouls()
                                        end)

                                -- Initial check in case the aura is already active upon login/reload
                                C_Timer.After(0.10, function()
                                UpdateSouls()
                                end)

                                return frame
                                end

                                ------------------------------------------------------------------------
                                -- Scale Handling
                                ------------------------------------------------------------------------
                                local function ApplyScale(f, s)
                                if f and f.SetScale then
                                    f:SetScale(s or 1)
                                    end
                                    end

                                    ------------------------------------------------------------------------
                                    -- Registration with GridCore
                                    ------------------------------------------------------------------------
                                    local function TryRegister()
                                    if registered then return true end

                                        local GC = _G.RGridCore
                                        if not (GC and GC.RegisterPlugin) then
                                            return false
                                            end

                                            -- We only register it, so it appears in the settings list.
                                            -- The user must manually attach/enable it from the UI.
                                            GC:RegisterPlugin(PLUGIN_ID, {
                                                name = "Devourer Souls Bar",
                                                build = BuildFrame,
                                                setScale = ApplyScale,
                                                default = {
                                                    gx = 0,
                                                    gy = -150,
                                                    group = 0,
                                                    label = "Devourer",
                                                    showMode = "INHERIT",
                                                },
                                            })

                                            registered = true
                                            return true
                                            end

                                            ------------------------------------------------------------------------
                                            -- Safe Initialization
                                            ------------------------------------------------------------------------
                                            local tries = 0

                                            local function Pump()
                                            tries = tries + 1

                                            if TryRegister() then return end

                                                if tries < 50 then
                                                    C_Timer.After(0.2, Pump)
                                                    end
                                                    end

                                                    Pump()
