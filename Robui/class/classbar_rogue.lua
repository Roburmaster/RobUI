-- class/classbar_rogue.lua
-- Combo Point pips parented into playerframe’s ClassBarHolder

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

ns.classbars["ROGUE"] = function(holder)
-- Create container
local CP = CreateFrame("Frame", nil, holder)
CP:SetAllPoints(holder)

-- Always use 6 combo points
local MAX_CP = 6
local spacing = 1
local totalW  = holder:GetWidth()
local segW    = (totalW - (MAX_CP - 1) * spacing) / MAX_CP
local height  = holder:GetHeight()

-- Color gradient for combo points
local colors = {
  { r = 1.0, g = 0.0, b = 0.0 },      -- Red
  { r = 1.0, g = 0.5, b = 0.0 },      -- Orange
  { r = 1.0, g = 1.0, b = 0.0 },      -- Yellow
  { r = 0.5, g = 1.0, b = 0.0 },      -- Light green
  { r = 0.0, g = 1.0, b = 0.0 },      -- Green
  { r = 0.0, g = 0.6, b = 0.0 },      -- Dark green
}

-- Create segments
CP.segs = {}
for i = 1, MAX_CP do
  local seg = CreateFrame("StatusBar", nil, CP, "BackdropTemplate")
  seg:SetSize(segW, height)
  seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

  local c = colors[i]
  seg:SetStatusBarColor(c.r, c.g, c.b)

  seg.bg = seg:CreateTexture(nil, "BACKGROUND")
  seg.bg:SetAllPoints(seg)
  seg.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  seg.bg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2, 1)

  if i == 1 then
    seg:SetPoint("LEFT", CP, "LEFT", 0, 0)
    else
      seg:SetPoint("LEFT", CP.segs[i - 1], "RIGHT", spacing, 0)
      end

      CP.segs[i] = seg
      end

      -- Update combo points
      local function UpdateCP(self, event, unit, powertype)
      if unit ~= "player" then return end
        if event == "UNIT_POWER_UPDATE" and powertype ~= "COMBO_POINTS" then return end

          local cur = UnitPower("player", Enum.PowerType.ComboPoints)
          for i = 1, MAX_CP do
            local seg = CP.segs[i]
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(i <= cur and 1 or 0)
            end
            end

            -- Register events
            CP:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            CP:RegisterEvent("PLAYER_ENTERING_WORLD")
            CP:SetScript("OnEvent", UpdateCP)

            -- Initial update
            UpdateCP(CP, "PLAYER_ENTERING_WORLD", "player", "COMBO_POINTS")
            end
