-- ============================================================================
-- windowmover.lua (RobUI)
-- Move Blizzard windows with SHIFT + drag on a top handle (32px).
-- Saves positions per RobUI profile: R.Database.profile.windows[key]
-- Includes questgiver dialogs:
--   - GossipFrame (talk/choices)
--   - QuestFrame  (accept/complete/progress)
-- ============================================================================

local AddonName, ns = ...
local R = _G.Robui
R.WindowMover = {}
local WM = R.WindowMover

-- ------------------------------------------------------------
-- DB helpers (FIX: always ensure table exists before use)
-- ------------------------------------------------------------
local function EnsureWindowsDB()
    if not R.Database or not R.Database.profile then return nil end
    if not R.Database.profile.windows then
        R.Database.profile.windows = {}
    end
    return R.Database.profile.windows
end

local function SavePosition(frame, key)
    local db = EnsureWindowsDB()
    if not db or not frame or not frame.GetPoint then return end

    local p, _, rp, x, y = frame:GetPoint()
    db[key] = {
        point    = p  or "CENTER",
        relPoint = rp or "CENTER",
        x        = x  or 0,
        y        = y  or 0,
    }
end

local function ApplyPosition(frame, key)
    if not frame or not frame.ClearAllPoints then return end
    if InCombatLockdown() then return end

    local db = EnsureWindowsDB()
    local d = db and db[key]
    if not d then return end

    frame:ClearAllPoints()
    frame:SetPoint(d.point, UIParent, d.relPoint, d.x, d.y)
end

-- ------------------------------------------------------------
-- Blizzard UI loader helper (so Gossip/Quest frames exist)
-- ------------------------------------------------------------
local function TryLoadBlizzardUI(addonName)
    if not addonName then return end
    if IsAddOnLoaded(addonName) then return end
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, addonName)
    end
end

-- ------------------------------------------------------------
-- Drag handle
-- ------------------------------------------------------------
local function EnsureDragHandle(frame, key)
    if not frame or frame.__robui_wmove_handle then return end
    frame.__robui_wmove_handle = true

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetUserPlaced(true)

    local h = CreateFrame("Frame", nil, frame)
    h:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    h:SetHeight(32)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")

    h:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        if not IsShiftKeyDown() then return end
        if frame.StartMoving then frame:StartMoving() end
    end)

    h:SetScript("OnDragStop", function()
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        SavePosition(frame, key)
    end)

    -- Re-apply when shown (important for quest dialogs that may be positioned on open)
    frame:HookScript("OnShow", function()
        ApplyPosition(frame, key)
    end)
end

local function SetupFrame(frame, key)
    if not frame then return end
    ApplyPosition(frame, key)
    EnsureDragHandle(frame, key)
end

-- ------------------------------------------------------------
-- Targets (including questgiver dialogs)
-- ------------------------------------------------------------
local TARGETS = {
    { key="CharacterFrame", get=function() return _G.CharacterFrame end },
    { key="WorldMapFrame",  get=function() return _G.WorldMapFrame end },
    { key="PVEFrame",       get=function() return _G.PVEFrame end },

    -- Professions can be nil until loaded/opened
    { key="ProfessionsFrame", get=function() return _G.ProfessionsFrame end },

    -- Questgiver dialogs:
    { key="GossipFrame", get=function()
        if not _G.GossipFrame then TryLoadBlizzardUI("Blizzard_GossipUI") end
        return _G.GossipFrame
    end },
    { key="QuestFrame", get=function()
        if not _G.QuestFrame then TryLoadBlizzardUI("Blizzard_QuestUI") end
        return _G.QuestFrame
    end },
}

function WM:ApplyAll()
    for _, t in ipairs(TARGETS) do
        local f = t.get and t.get()
        if f then
            SetupFrame(f, t.key)
        end
    end
end

-- ------------------------------------------------------------
-- GUI panel (for RobUI settings container)
-- ------------------------------------------------------------
function WM:CreateGUI()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(560, 260)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Window Mover")

    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 20, -60)
    desc:SetJustifyH("LEFT")
    desc:SetText("Hold SHIFT + Venstreklikk og dra i øverste felt (32px) på vinduet for å flytte.\nPosisjoner lagres per profil.\n\nStøtter også questgiver-dialogene (Gossip/Quest).")

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(200, 30)
    resetBtn:SetPoint("TOPLEFT", 20, -150)
    resetBtn:SetText("Reset Positions")
    resetBtn:SetScript("OnClick", function()
        local db = EnsureWindowsDB()
        if db then wipe(db) end
        WM:ApplyAll()
    end)

    if R.RegisterModulePanel then
        R:RegisterModulePanel("Window Mover", p)
    end
end

-- ------------------------------------------------------------
-- Boot + re-apply when Blizzard quest/gossip UI loads
-- ------------------------------------------------------------
local mover = CreateFrame("Frame")
mover:RegisterEvent("PLAYER_LOGIN")
mover:RegisterEvent("ADDON_LOADED")
mover:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            WM:ApplyAll()
            WM:CreateGUI()
        end)
        return
    end

    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_QuestUI" or arg1 == "Blizzard_GossipUI" then
            C_Timer.After(0, function()
                WM:ApplyAll()
            end)
        end
    end
end)