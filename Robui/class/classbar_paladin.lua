-- class/classbar_paladin.lua
-- Holy Power pips parented into playerframe’s ClassBarHolder

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["PALADIN"] = function(holder)
-- Create container
local HP = CreateFrame("Frame", nil, holder)
HP:SetAllPoints(holder)

-- Pip factory
local function CreatePip(parent, w, h)
local sb = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
sb:SetSize(w, h)
sb:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
sb:SetStatusBarColor(1,0.8,0,1)
sb.bg = sb:CreateTexture(nil,"BACKGROUND")
sb.bg:SetAllPoints(sb)
sb.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
sb.bg:SetVertexColor(.1,.1,.1,1)
return sb
end

-- Build pips
HP.pips = {}
local maxHP, spacing = 5, 1
local totalW = holder:GetWidth()
local pipW   = (totalW - (maxHP-1)*spacing) / maxHP
for i = 1, maxHP do
    local pip = CreatePip(HP, pipW, holder:GetHeight())
    if i == 1 then
        pip:SetPoint("LEFT", HP, "LEFT", 0, 0)
        else
            pip:SetPoint("LEFT", HP.pips[i-1], "RIGHT", spacing, 0)
            end
            HP.pips[i] = pip
            end

            -- Update function
            local function UpdateHoly(self, event, unit, powerType)
            if unit ~= "player" then return end
                if event == "UNIT_POWER_UPDATE" and powerType ~= "HOLY_POWER" then return end
                    local cur = UnitPower("player", Enum.PowerType.HolyPower)
                    for i, pip in ipairs(HP.pips) do
                        pip:SetMinMaxValues(0,1)
                        pip:SetValue(i <= cur and 1 or 0)
                        end
                        end

                        -- Register events
                        HP:SetScript("OnEvent", UpdateHoly)
                        HP:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
                        HP:RegisterEvent("PLAYER_ENTERING_WORLD")

                        -- Initial draw
                        UpdateHoly(HP, "PLAYER_ENTERING_WORLD", "player", "HOLY_POWER")
                        end
