-- class/classbar_evoker.lua
-- Evoker Essence (spec 1/2) and Anima (spec 3) bars — custom cyan‐shades per segment

local ADDON, ns = ...
ns.classbars = ns.classbars or {}

-- helper: “#rrggbb” → 0–1 RGB + α=1
local function HexToRGBA(hex)
hex = hex:gsub("#","")
if #hex == 6 then
  local r = tonumber(hex:sub(1,2),16)/255
  local g = tonumber(hex:sub(3,4),16)/255
  local b = tonumber(hex:sub(5,6),16)/255
  return r, g, b, 1
  end
  -- fallback white
  return 1,1,1,1
  end

  ns.classbars["EVOKER"] = function(holder)
  -- container
  local EB = CreateFrame("Frame","RobUIEvokerBar",holder)
  EB:SetAllPoints(holder)
  EB.bg = EB:CreateTexture(nil,"BACKGROUND")
  EB.bg:SetAllPoints(EB)
  EB.bg:SetColorTexture(0,0,0,0.5)

  -- determine Essence vs Anima and segment count
  local spec = GetSpecialization()
  local pt   = (spec==3) and Enum.PowerType.Anima or Enum.PowerType.Essence
  local maxP = UnitPowerMax("player",pt) or ((spec==3) and 5 or 2)
  if maxP < 1 then maxP = (spec==3) and 5 or 2 end

    -- your five custom cyan shades
    local segmentHex = {
      "#00ffff",  -- (0,255,255)
      "#00dddd",  -- (0,221,221)
      "#00cccc",  -- (0,204,204)
      "#00bbbb",  -- (0,187,187)
      "#00aaaa",  -- (0,170,170)
    }

    -- layout maths
    local spacing = 4
    local totalW  = holder:GetWidth()
    local segW    = (totalW - (maxP-1)*spacing) / maxP
    local segH    = holder:GetHeight()

    EB.segs = {}
    for i=1,maxP do
      local seg = CreateFrame("StatusBar",nil,EB,"BackdropTemplate")
      seg:SetSize(segW,segH)
      seg:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

      -- pick colour for this segment (or white if out of range)
      local hex = segmentHex[i] or "#FFFFFF"
      local r,g,b,a = HexToRGBA(hex)
      seg:SetStatusBarColor(r,g,b,a)

      seg.bg = seg:CreateTexture(nil,"BACKGROUND")
      seg.bg:SetAllPoints(seg)
      seg.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
      seg.bg:SetVertexColor(0.15,0.15,0.15,1)

      if i==1 then
        seg:SetPoint("LEFT",EB,"LEFT",0,0)
        else
          seg:SetPoint("LEFT",EB.segs[i-1],"RIGHT",spacing,0)
          end

          EB.segs[i] = seg
          end

          -- update handler
          local function Update(self,event,unit)
          if unit~="player" then return end
            local cur = UnitPower("player",pt) or 0
            for idx,seg in ipairs(EB.segs) do
              seg:SetMinMaxValues(0,1)
              seg:SetValue(idx<=cur and 1 or 0)
              end
              end

              EB:RegisterUnitEvent("UNIT_POWER_UPDATE","player")
              EB:RegisterUnitEvent("UNIT_MAXPOWER",   "player")
              EB:RegisterEvent("PLAYER_ENTERING_WORLD")
              EB:SetScript("OnEvent",Update)
              Update(EB,"PLAYER_ENTERING_WORLD","player")
              end

