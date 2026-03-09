-- ============================================================================
-- ce.lua
-- CombatGrid Help / Explanation Window
--
-- Slashes:
--   /rgrid help   -> toggle help
--   /ce           -> toggle help
--   /cgridhelp    -> toggle help
-- ============================================================================

local ADDON, ns = ...
local GC = ns and ns.GridCore
if not GC then return end

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown

ns.CombatGridHelp = ns.CombatGridHelp or {}
local CE = ns.CombatGridHelp

-- ---------------------------------------------------------------------------
-- Text content
-- ---------------------------------------------------------------------------

local HELP_TEXT = [[
|cff00b3ffROBUI GRID – USER GUIDE|r

RobUI Grid is an advanced visual anchor, layout, and scripting system.

--------------------------------------------------
PROFILES & ROLES
--------------------------------------------------
The grid automatically switches layouts based on your role (Tank, Healer, DPS).
• AUTO: Layout automatically updates based on your current spec.
• MASTER: A global layout shared across all characters.

Use "Pull" to copy the Global Master layout to your current role.
Use "Push" to save your current role's layout back to the Global Master.

--------------------------------------------------
BASIC WORKFLOW & PLUGINS
--------------------------------------------------
1) Type /rgrid to open Edit Mode.
2) Click "Add Anchor" to create a new anchor.
3) Select an anchor to adjust GX / GY positions.
4) Select a Plugin on the left and click "Add".

Plugins do NOT auto-attach. You must manually add them.
You can adjust the Width, Height, and Orientation of the attached plugin frame directly from the anchor controls. Use "Swap" to quickly invert dimensions.

--------------------------------------------------
SELECTION & MOVEMENT
--------------------------------------------------
• Click anchor = Select
• Shift + Click = Multi-select anchors
• Drag anchors = Move freely (snaps to grid)
• Arrow buttons = Nudge 1 pixel (Hold SHIFT to nudge 5 pixels)
• Labels Button = Toggle coordinate display on/off

--------------------------------------------------
GROUPS & VISIBILITY
--------------------------------------------------
Groups let multiple anchors share visibility rules.

Group Visibility:
• ALWAYS = Always shown
• COMBAT = Only visible in combat
• HIDDEN = Never shown

Anchor Visibility:
• INHERIT = Follows the Group Visibility setting
• ALWAYS / COMBAT / HIDDEN = Overrides the group setting

--------------------------------------------------
SCRIPTS (SSR)
--------------------------------------------------
The right-side panel is the Simple Script Runner.
You can write and save custom Lua scripts per profile.
Check "Auto-Run on Login" to automatically execute a script when the UI loads.

--------------------------------------------------
SHORTCUTS
--------------------------------------------------
/rgrid          → Toggle grid edit mode
/rgrid edit     → Force edit mode on
/rgrid hide     → Force edit mode off
/rgrid auto     → Enable automatic role profiles
/rgrid master   → Force manual Master profile
/ce             → Open this help window

--------------------------------------------------
ADVANCED NOTES
--------------------------------------------------
• Anchors, groups, and scripts are persistent per profile.
• Global Scale affects all attached plugins simultaneously.
• Visibility updates automatically on combat state changes.
]]

-- ---------------------------------------------------------------------------
-- Create Help Frame
-- ---------------------------------------------------------------------------

function CE:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "RobUI_CombatGridHelp", UIParent, "BackdropTemplate")
    self.frame = f

    f:SetSize(600, 720) -- Slightly taller to fit the new text
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.90)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Drag
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
    end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("RobUI Grid Guide")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(80, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    close:SetText("Close")
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Scroll
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 16)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWidth(520)
    text:SetText(HELP_TEXT)

    content:SetHeight(text:GetStringHeight() + 20)
end

function CE:Toggle()
    if not self.frame then
        self:Create()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

-- ---------------------------------------------------------------------------
-- Hook /rgrid help
-- ---------------------------------------------------------------------------

local oldSlash = SlashCmdList["ROBUIGRID"]
SlashCmdList["ROBUIGRID"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "help" then
        CE:Toggle()
        return
    end
    if oldSlash then oldSlash(msg) end
end

-- ---------------------------------------------------------------------------
-- Dedicated slashes to open help
-- ---------------------------------------------------------------------------

SLASH_ROBUICE1 = "/ce"
SlashCmdList["ROBUICE"] = function()
    CE:Toggle()
end

SLASH_CGRIDHELP1 = "/cgridhelp"
SlashCmdList["CGRIDHELP"] = function()
    CE:Toggle()
end