-- Modules/TooltipID.lua
-- Appends item IDs to item tooltips using TooltipDataProcessor (Retail 10.0.2+)

local ADDON, ns = ...
local R = _G.Robui

local function AddItemID(tooltip, data)
    if not tooltip or not data then return end

    -- Avoid forbidden tooltips (can happen in some UI paths)
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end

    local id = data.id
    if not id then return end

    -- Prevent duplicates when tooltip refreshes/rebuilds
    if tooltip.__robui_lastItemID == id then return end
    tooltip.__robui_lastItemID = id

    tooltip:AddLine(("Item ID: |cff00c0fa%s|r"):format(id))

    -- IMPORTANT:
    -- DO NOT call tooltip:Show() here.
    -- Calling :Show() during tooltip building is a classic taint trigger
    -- and will break money tooltip rendering (secret value errors).
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddItemID)
    end
end)
