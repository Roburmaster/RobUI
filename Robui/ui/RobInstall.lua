local AddonName, ns = ...
local R = _G.Robui
ns.robinstall = ns.robinstall or {}
local mod = ns.robinstall

-- Debug print for å bekrefte at filen leses (vises i chat ved login)
-- print("|cff00b3ffRobui:|r Installer module loaded.")

-- 1. HELPER FUNCTIONS
local function Round(v)
v = tonumber(v)
if not v then return 0 end
    return math.floor(v + 0.5)
    end

    local function IsInstalled()
    -- Sjekk at databasen faktisk finnes før vi leser
    if R.Database and R.Database.char and R.Database.char.installed then
        return true
        end
        return false
        end

        local function MarkInstalled()
        if R.Database and R.Database.char then
            R.Database.char.installed = true
            print("|cff00b3ffRobui:|r Setup complete.")
            end
            end

            local function RefreshFrames()
            if ns.UnitFrames then
                local UF = ns.UnitFrames
                if UF.Player and UF.Player.ForceUpdate then UF.Player:ForceUpdate() end
                    if UF.Target and UF.Target.ForceUpdate then UF.Target:ForceUpdate() end
                        if UF.TargetTarget and UF.TargetTarget.ForceUpdate then UF.TargetTarget:ForceUpdate() end
                            if UF.Focus and UF.Focus.ForceUpdate then UF.Focus:ForceUpdate() end
                                if UF.Pet and UF.Pet.ForceUpdate then UF.Pet:ForceUpdate() end
                                    end
                                    end

                                    -- 2. LAYOUT DATA
                                    local LAYOUT_STANDARD = {
                                        player = { w=230, hpH=36, point="CENTER", relPoint="CENTER", x=-280, y=-140 },
                                        target = { w=230, hpH=36, point="CENTER", relPoint="CENTER", x= 280, y=-140 },
                                        focus  = { w=140, hpH=20, point="CENTER", relPoint="CENTER", x=-400, y=0 },
                                        tot    = { w=140, hpH=20, point="CENTER", relPoint="CENTER", x= 400, y=0 },
                                        pet    = { w=120, hpH=18, point="CENTER", relPoint="CENTER", x=-280, y=-200 },
                                    }

                                    local PRESETS = {
                                        Melee  = LAYOUT_STANDARD,
                                        Ranged = LAYOUT_STANDARD,
                                        Tank   = LAYOUT_STANDARD,
                                        Healer = LAYOUT_STANDARD,
                                    }

                                    local function ApplyConfig(unit, presetData)
                                    -- Sikkerhetsjekk: Finnes databasen?
                                    if not R.Database or not R.Database.profile or not R.Database.profile.unitframes then
                                        return
                                        end

                                        local db = R.Database.profile.unitframes[unit]
                                        if not db or not presetData then return end

                                            db.point = presetData.point
                                            db.relPoint = presetData.relPoint
                                            db.x = presetData.x
                                            db.y = presetData.y
                                            db.w = presetData.w
                                            db.hpH = presetData.hpH
                                            db.shown = true
                                            end

                                            local function ApplyPreset(layoutName)
                                            local layout = PRESETS[layoutName]
                                            if not layout then return end

                                                ApplyConfig("player", layout.player)
                                                ApplyConfig("target", layout.target)
                                                ApplyConfig("focus",  layout.focus)
                                                ApplyConfig("targettarget", layout.tot)
                                                ApplyConfig("pet",    layout.pet)

                                                RefreshFrames()
                                                print("|cff00b3ffRobui:|r Applied layout: " .. layoutName)
                                                end

                                                -- 3. IMPORT / EXPORT
                                                local function ExportString()
                                                if not R.Database or not R.Database.profile then return "" end
                                                    local db = R.Database.profile.unitframes
                                                    local function Pack(u)
                                                    local d = db[u]
                                                    if not d then return u..":0,0,CENTER,CENTER,0,0" end
                                                        return string.format("%s:%d,%d,%s,%s,%d,%d", u, Round(d.w), Round(d.hpH), d.point, d.relPoint, Round(d.x), Round(d.y))
                                                        end
                                                        return "v1;" .. Pack("player") .. ";" .. Pack("target") .. ";" .. Pack("focus") .. ";" .. Pack("targettarget") .. ";" .. Pack("pet")
                                                        end

                                                        local function ImportString(s)
                                                        if type(s) ~= "string" then return false end
                                                            s = s:gsub("^%s+", ""):gsub("%s+$", "")
                                                            if not s:match("^v1;") then return false end

                                                                local function ParseBlock(block)
                                                                local unit, rest = block:match("^([^:]+):(.+)$")
                                                                if not unit or not rest then return end
                                                                    local w, h, p, rp, x, y = rest:match("^([%-]?%d+),([%-]?%d+),([^,]+),([^,]+),([%-]?%d+),([%-]?%d+)$")
                                                                    if w then
                                                                        if R.Database and R.Database.profile and R.Database.profile.unitframes then
                                                                            local db = R.Database.profile.unitframes[unit]
                                                                            if db then
                                                                                db.w, db.hpH = tonumber(w), tonumber(h)
                                                                                db.point, db.relPoint = p, rp
                                                                                db.x, db.y = tonumber(x), tonumber(y)
                                                                                end
                                                                                end
                                                                                end
                                                                                end

                                                                                for block in s:gmatch("([^;]+)") do
                                                                                    if block ~= "v1" then ParseBlock(block) end
                                                                                        end

                                                                                        RefreshFrames()
                                                                                        return true
                                                                                        end

                                                                                        -- 4. GUI CONSTRUCTION
                                                                                        local UI
                                                                                        local function BuildUI()
                                                                                        if UI then return UI end

                                                                                            local f = CreateFrame("Frame", "RobUI_Installer", UIParent, "BackdropTemplate")
                                                                                            UI = f
                                                                                            f:SetSize(600, 350)
                                                                                            f:SetPoint("CENTER")
                                                                                            f:SetFrameStrata("DIALOG")
                                                                                            f:EnableMouse(true)
                                                                                            f:SetMovable(true)
                                                                                            f:RegisterForDrag("LeftButton")
                                                                                            f:SetScript("OnDragStart", f.StartMoving)
                                                                                            f:SetScript("OnDragStop", f.StopMovingOrSizing)

                                                                                            f:SetBackdrop({
                                                                                                bgFile = "Interface\\Buttons\\WHITE8x8",
                                                                                                edgeFile = "Interface\\Buttons\\WHITE8x8",
                                                                                                edgeSize = 1,
                                                                                            })
                                                                                            f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
                                                                                            f:SetBackdropBorderColor(0, 0, 0, 1)

                                                                                            local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                                                                                            title:SetPoint("TOP", 0, -15)
                                                                                            title:SetText("RobUI Setup")

                                                                                            local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                                                                            sub:SetPoint("TOP", 0, -40)
                                                                                            sub:SetText("Choose a preset layout for your Unit Frames")

                                                                                            local function CreateBtn(text, x, y, w, func)
                                                                                            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                                                                                            b:SetSize(w or 120, 30)
                                                                                            b:SetPoint("TOPLEFT", x, y)
                                                                                            b:SetText(text)
                                                                                            b:SetScript("OnClick", func)
                                                                                            return b
                                                                                            end

                                                                                            local y = -80
                                                                                            local x = 40
                                                                                            CreateBtn("Melee", x, y, 120, function() ApplyPreset("Melee") end)
                                                                                            CreateBtn("Ranged", x+130, y, 120, function() ApplyPreset("Ranged") end)
                                                                                            CreateBtn("Tank", x+260, y, 120, function() ApplyPreset("Tank") end)
                                                                                            CreateBtn("Healer", x+390, y, 120, function() ApplyPreset("Healer") end)

                                                                                            local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                                                                            lbl:SetPoint("TOPLEFT", 40, -150)
                                                                                            lbl:SetText("Import / Export Layout String:")

                                                                                            local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
                                                                                            eb:SetSize(510, 30)
                                                                                            eb:SetPoint("TOPLEFT", 45, -170)
                                                                                            eb:SetAutoFocus(false)

                                                                                            CreateBtn("Export", 40, -210, 100, function()
                                                                                            eb:SetText(ExportString())
                                                                                            eb:HighlightText()
                                                                                            eb:SetFocus()
                                                                                            end)

                                                                                            CreateBtn("Import", 150, -210, 100, function()
                                                                                            if ImportString(eb:GetText()) then
                                                                                                print("Import successful!")
                                                                                                else
                                                                                                    print("Invalid string.")
                                                                                                    end
                                                                                                    end)

                                                                                            -- Close / Finish (FIX: Uses C_UI.Reload)
                                                                                            CreateBtn("Finish Setup", 200, -280, 200, function()
                                                                                            MarkInstalled()
                                                                                            f:Hide()
                                                                                            C_UI.Reload()
                                                                                            end)

                                                                                            return f
                                                                                            end

                                                                                            function mod:Toggle()
                                                                                            local f = BuildUI()
                                                                                            if f:IsShown() then f:Hide() else f:Show() end
                                                                                                end

                                                                                                -- 5. INITIALIZATION & SLASH
                                                                                                SLASH_ROBINSTALL1 = "/robinstall"
                                                                                                SlashCmdList.ROBUIINSTALL = function()
                                                                                                mod:Toggle()
                                                                                                end

                                                                                                local loader = CreateFrame("Frame")
                                                                                                loader:RegisterEvent("PLAYER_LOGIN")
                                                                                                loader:SetScript("OnEvent", function()
                                                                                                -- Vent 4 sekunder for å være helt sikker på at Database og UnitFrames er lastet
                                                                                                C_Timer.After(4, function()
                                                                                                if not IsInstalled() then
                                                                                                    mod:Toggle()
                                                                                                    end
                                                                                                    end)
                                                                                                end)
