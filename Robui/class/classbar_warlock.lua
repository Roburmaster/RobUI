-- class/classbar_warlock.lua
-- Registers a Soul Shard bar for Warlocks under RobUIPlayerFrame.ClassBarHolder

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["WARLOCK"] = function(holder)
-- Create a container for Soul Shards inside the ClassBarHolder
local SSD = CreateFrame("Frame", "RobUIWarlockShardBar", holder)
SSD:SetAllPoints(holder)
SSD.bg = SSD:CreateTexture(nil, "BACKGROUND")
SSD.bg:SetAllPoints(SSD)
-- separator background → black
SSD.bg:SetColorTexture(0, 0, 0, 1)

-- Determine max shards (retail Warlocks always have 5)
local pt = Enum.PowerType.SoulShards
local maxShards = UnitPowerMax("player", pt)
if maxShards < 1 then maxShards = 5 end

    -- Calculate spacing and segment size based on holder’s dimensions
    local spacing = 4
    local totalW  = holder:GetWidth()
    local segW    = (totalW - (maxShards - 1) * spacing) / maxShards
    local segH    = holder:GetHeight()

    -- Create individual shard segments
    SSD.segs = {}
    for i = 1, maxShards do
        local seg = CreateFrame("StatusBar", nil, SSD, "BackdropTemplate")
        seg:SetSize(segW, segH)
        seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        -- unfilled shards: dark grey background
        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints(seg)
        seg.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        seg.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

        if i == 1 then
            seg:SetPoint("LEFT", SSD, "LEFT", 0, 0)
            else
                seg:SetPoint("LEFT", SSD.segs[i - 1], "RIGHT", spacing, 0)
                end

                SSD.segs[i] = seg
                end

                -- Update function to fill/dim shards based on current Soul Shard count
                local function UpdateShards(self, event, unit, powerType)
                if unit ~= "player" or (event == "UNIT_POWER_UPDATE" and powerType ~= "SOUL_SHARDS") then
                    return
                    end

                    local current = UnitPower("player", pt) or 0
                    for idx, seg in ipairs(SSD.segs) do
                        seg:SetMinMaxValues(0, 1)
                        if idx <= current then
                            seg:SetValue(1)
                            -- filled shard in #ff00ff
                            seg:SetStatusBarColor(1, 0, 1, 1)
                            else
                                seg:SetValue(0)
                                end
                                end
                                end

                                -- Register events to track shard changes and initial draw
                                SSD:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
                                SSD:RegisterUnitEvent("UNIT_MAXPOWER",    "player")
                                SSD:RegisterEvent("PLAYER_ENTERING_WORLD")
                                SSD:SetScript("OnEvent", UpdateShards)

                                -- Force one initial update
                                UpdateShards(SSD, "PLAYER_ENTERING_WORLD", "player", "SOUL_SHARDS")
                                end

