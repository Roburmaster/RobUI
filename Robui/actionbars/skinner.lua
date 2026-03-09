local AddonName, ns = ...
local R = _G.Robui

R.ActionBars = R.ActionBars or {}
local AB = R.ActionBars

-- -------------------------------------------------------------------------
-- 1) CONSTANTS & PROFILES
-- -------------------------------------------------------------------------
local SkinProfiles = {
    ["Meta"]      = { zoom = 0.08, edgeSize = 1, borderColor = {0, 0, 0, 1},           backdropColor = {0.1, 0.1, 0.1, 0.9}, fontScale = 12, hotkeyPos = "TOPRIGHT" },
    ["Glass"]     = { zoom = 0.10, edgeSize = 1, borderColor = {0.2, 0.2, 0.2, 0.5},   backdropColor = {0, 0, 0, 0.5},       fontScale = 11, hotkeyPos = "TOP" },
    ["Minimal"]   = { zoom = 0.15, edgeSize = 0, borderColor = {0, 0, 0, 0},           backdropColor = {0, 0, 0, 0},         fontScale = 10, hotkeyPos = "CENTER" },
    ["Dark Mode"] = { zoom = 0.08, edgeSize = 2, borderColor = {0, 0, 0, 1},           backdropColor = {0, 0, 0, 1},         fontScale = 12, hotkeyPos = "TOPRIGHT" },
    ["Classy"]    = { zoom = 0.08, edgeSize = 1, borderColor = (R.Colors and R.Colors.blue) or {0.2, 0.6, 1, 1}, backdropColor = {0.1, 0.1, 0.1, 0.9}, fontScale = 12, hotkeyPos = "TOPRIGHT" },
    ["Custom"]    = { zoom = 0.08, edgeSize = 1, borderColor = {0.2, 0.2, 0.2, 1},     backdropColor = {0.1, 0.1, 0.1, 0.8}, fontScale = 12, hotkeyPos = "TOPRIGHT" },
}

local function EnsureDB()
    R.Database = R.Database or {}
    R.Database.profile = R.Database.profile or {}
    R.Database.profile.actionbars = R.Database.profile.actionbars or {}
    local db = R.Database.profile.actionbars

    if db.enabled == nil then db.enabled = false end
    if db.showKeybinds == nil then db.showKeybinds = true end
    if db.style == nil then db.style = "Meta" end
    if db.customColor == nil then db.customColor = {0.2, 0.2, 0.2, 1} end

    db.fader = db.fader or {}
    db.fader.bars = db.fader.bars or {}

    return db
end

local function GetDB()
    if R.Database and R.Database.profile and R.Database.profile.actionbars then
        return R.Database.profile.actionbars
    end
    return EnsureDB()
end

local function GetSkinConfig()
    local db = GetDB()
    local src = SkinProfiles[db.style] or SkinProfiles["Meta"]

    local p = {}
    for k, v in pairs(src) do p[k] = v end

    if db.style == "Custom" then
        local c = db.customColor or {0.2, 0.2, 0.2, 1}
        p.borderColor = { c[1], c[2], c[3], c[4] or 1 }
        p.backdropColor = { (c[1] or 0.2) * 0.5, (c[2] or 0.2) * 0.5, (c[3] or 0.2) * 0.5, 0.8 }
    end

    return p
end

local function MakeStyleKey()
    local db = GetDB()
    local cc = db.customColor or {}
    return table.concat({
        tostring(db.enabled),
        tostring(db.showKeybinds),
        tostring(db.style),
        tostring(cc[1] or ""),
        tostring(cc[2] or ""),
        tostring(cc[3] or ""),
        tostring(cc[4] or ""),
    }, "|")
end

-- -------------------------------------------------------------------------
-- 2) KEYBIND CLEANER + CACHE
-- -------------------------------------------------------------------------
local function CleanBindText(key)
    if not key or key == "" then return nil end
    key = key:gsub("SHIFT%-", "S-")
    key = key:gsub("CTRL%-",  "C-")
    key = key:gsub("ALT%-",   "A-")
    key = key:gsub("MOUSEBUTTON", "M")
    key = key:gsub("MOUSEWHEELUP", "WU")
    key = key:gsub("MOUSEWHEELDOWN", "WD")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("SPACE", "Spc")
    key = key:gsub("[^\032-\126]", "")
    return key
end

local BindingCache = {}   -- [buttonName] = "S-1" etc
local function GetButtonBindingText(button)
    local name = button and button.GetName and button:GetName()
    if not name then return nil end

    local cached = BindingCache[name]
    if cached ~= nil then
        return cached ~= "" and cached or nil
    end

    -- Build once if missing (normally built on UPDATE_BINDINGS)
    local k1 = GetBindingKey("CLICK " .. name .. ":LeftButton")
    if k1 then
        local t = CleanBindText(k1)
        BindingCache[name] = t or ""
        return t
    end

    local patterns = {
        ["^ActionButton(%d+)$"]               = "ACTIONBUTTON",
        ["^MultiBarBottomLeftButton(%d+)$"]   = "MULTIACTIONBAR1BUTTON",
        ["^MultiBarBottomRightButton(%d+)$"]  = "MULTIACTIONBAR2BUTTON",
        ["^MultiBarRightButton(%d+)$"]        = "MULTIACTIONBAR3BUTTON",
        ["^MultiBarLeftButton(%d+)$"]         = "MULTIACTIONBAR4BUTTON",
    }

    for pat, bindingPrefix in pairs(patterns) do
        local id = name:match(pat)
        if id then
            local a1 = GetBindingKey(bindingPrefix .. id)
            local t = CleanBindText(a1)
            BindingCache[name] = t or ""
            return t
        end
    end

    BindingCache[name] = ""
    return nil
end

local function RebuildBindingCacheForKnownButtons()
    -- Only rebuild for buttons we actually track
    AB._buttons = AB._buttons or {}
    for btn in pairs(AB._buttons) do
        if btn and btn.GetName then
            local n = btn:GetName()
            if n then
                BindingCache[n] = nil
                GetButtonBindingText(btn) -- fills cache
            end
        end
    end
end

-- -------------------------------------------------------------------------
-- 3) TOOLTIP-SAFE GUARD
-- -------------------------------------------------------------------------
local function TooltipActive()
    return (GameTooltip and GameTooltip:IsShown())
        or (ShoppingTooltip1 and ShoppingTooltip1:IsShown())
        or (ShoppingTooltip2 and ShoppingTooltip2:IsShown())
end

local function ShouldDefer()
    if TooltipActive() then return true end
    if InCombatLockdown() then return true end
    return false
end

-- -------------------------------------------------------------------------
-- 4) SKINNING ENGINE (FAST)
-- -------------------------------------------------------------------------
AB._buttons = AB._buttons or {}      -- set-like: [button]=true
AB._skinVersion = AB._skinVersion or 1
AB._lastStyleKey = AB._lastStyleKey or nil

local function TrackButton(btn)
    if not btn then return end
    AB._buttons[btn] = true
end

local function UpdateHotkeys(button)
    local hotkey = button and button.HotKey
    if not hotkey then return end

    local db = GetDB()
    if not db.enabled or not db.showKeybinds then
        hotkey:Hide()
        return
    end

    local text = GetButtonBindingText(button)
    if not text then
        hotkey:Hide()
        return
    end

    local cfg = GetSkinConfig()
    hotkey:SetText(text)
    hotkey:Show()
    hotkey:SetVertexColor(0.8, 0.8, 0.8)
    hotkey:ClearAllPoints()
    hotkey:SetPoint(cfg.hotkeyPos, 0, -2)
end

local function SkinButton(button, cfg)
    if not button or not button.GetName then return end
    TrackButton(button)

    local db = GetDB()
    if not db.enabled then return end

    -- Never touch during combat/tooltip
    if ShouldDefer() then
        AB._pendingApply = true
        return
    end

    -- Static skin: only redo when version changed
    if button.RobUISkinnedVersion ~= AB._skinVersion then
        button.RobUISkinnedVersion = AB._skinVersion

        local name = button:GetName()
        local icon   = button.icon or (name and _G[name .. "Icon"])
        local normal = button.NormalTexture or (name and _G[name .. "NormalTexture"])
        local flash  = button.Flash or (name and _G[name .. "Flash"])

        if normal then normal:SetAlpha(0) end
        if flash then flash:SetTexture("") end
        if button.SlotBackground and button.SlotBackground.Hide then button.SlotBackground:Hide() end

        if icon then
            icon:SetTexCoord(cfg.zoom, 1 - cfg.zoom, cfg.zoom, 1 - cfg.zoom)
            icon:SetDrawLayer("BACKGROUND", -1)
        end

        if not button.RobUIBackdrop then
            button.RobUIBackdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button.RobUIBackdrop:SetAllPoints(button)
            button.RobUIBackdrop:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        end

        local bg = button.RobUIBackdrop
        bg:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = cfg.edgeSize,
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            insets   = { left = 0, right = 0, top = 0, bottom = 0 }
        })

        local bc  = cfg.borderColor or {0,0,0,1}
        local bgc = cfg.backdropColor or {0,0,0,0.8}

        bg:SetBackdropBorderColor(bc[1] or 0, bc[2] or 0, bc[3] or 0, bc[4] or 1)
        bg:SetBackdropColor(bgc[1] or 0, bgc[2] or 0, bgc[3] or 0, bgc[4] or 0.8)
        bg:Show()
    end

    -- Hotkey can change without reskin (bindings)
    UpdateHotkeys(button)
end

local function CollectDefaultButtons()
    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "PetActionButton",
        "StanceButton",
    }

    for _, prefix in ipairs(prefixes) do
        local maxN = (prefix == "PetActionButton") and 10 or 12
        for i = 1, maxN do
            local btn = _G[prefix .. i]
            if btn then TrackButton(btn) end
        end
    end

    if ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.buttons then
        for btn in pairs(ActionBarButtonEventsFrame.buttons) do
            if type(btn) == "table" and btn.GetName then
                TrackButton(btn)
            end
        end
    end
end

local function ApplyToAll(forceReskin)
    local db = GetDB()
    if not db.enabled then return end
    if ShouldDefer() then
        AB._pendingApply = true
        return
    end

    CollectDefaultButtons()

    local styleKey = MakeStyleKey()
    if forceReskin or AB._lastStyleKey ~= styleKey then
        AB._lastStyleKey = styleKey
        AB._skinVersion = (AB._skinVersion or 1) + 1
    end

    local cfg = GetSkinConfig()
    for btn in pairs(AB._buttons) do
        SkinButton(btn, cfg)
    end
end

-- Export update function for profile switches
R.UpdateActionBars = function()
    AB.RequestApply(true)
end

-- -------------------------------------------------------------------------
-- 5) COALESCED APPLY (NO OnUpdate polling)
-- -------------------------------------------------------------------------
AB._pendingApply = false
AB._applyScheduled = false
AB._nextDelay = 0.08 -- backoff if we keep deferring

function AB.RequestApply(forceReskin)
    AB._forceReskin = AB._forceReskin or false
    if forceReskin then AB._forceReskin = true end

    AB._pendingApply = true
    if AB._applyScheduled then return end
    AB._applyScheduled = true

    local function TryApply()
        AB._applyScheduled = false
        if not AB._pendingApply then return end

        if ShouldDefer() then
            -- backoff a bit while tooltip/combat blocks
            AB._nextDelay = math.min(0.30, (AB._nextDelay or 0.08) + 0.05)
            AB._applyScheduled = true
            C_Timer.After(AB._nextDelay, TryApply)
            return
        end

        AB._nextDelay = 0.08
        AB._pendingApply = false

        local fr = AB._forceReskin
        AB._forceReskin = false
        ApplyToAll(fr)
    end

    C_Timer.After(0.05, TryApply)
end

-- Trigger apply when tooltip closes (instant “defer release” without polling)
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnHide", function()
        if AB._pendingApply and not ShouldDefer() then
            AB.RequestApply(false)
        end
    end)
end

-- -------------------------------------------------------------------------
-- 6) EVENTS (LIGHT)
-- -------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_BINDINGS")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")

-- Throttle spammy events into one apply
local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        AB._pendingApply = true
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        AB.RequestApply(false)
        return
    end

    if event == "UPDATE_BINDINGS" then
        wipe(BindingCache)
        RebuildBindingCacheForKnownButtons()
        -- only hotkey refresh needed; no forced reskin
        AB.RequestApply(false)
        return
    end

    -- ENTERING_WORLD / SLOT_CHANGED
    AB.RequestApply(false)
end
f:SetScript("OnEvent", OnEvent)

-- -------------------------------------------------------------------------
-- 7) HOOKS (DO NOT SKIN IN Update!)
-- -------------------------------------------------------------------------
local hooker = CreateFrame("Frame")
hooker:RegisterEvent("PLAYER_LOGIN")
hooker:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()

    -- IMPORTANT: Update hook must be ultra-cheap (no SkinButton!)
    if not AB._hooked and ActionBarActionButtonMixin then
        hooksecurefunc(ActionBarActionButtonMixin, "Update", function(btn)
            local db = GetDB()
            if not db.enabled then return end
            TrackButton(btn)

            -- only hotkeys; and only if enabled
            if db.showKeybinds then
                -- If tooltip/combat, just queue one apply
                if ShouldDefer() then
                    AB.RequestApply(false)
                    return
                end
                UpdateHotkeys(btn)
            end
        end)

        hooksecurefunc(ActionBarActionButtonMixin, "UpdateHotkeys", function(btn)
            local db = GetDB()
            if not db.enabled then return end
            TrackButton(btn)

            if ShouldDefer() then
                AB.RequestApply(false)
                return
            end

            UpdateHotkeys(btn)
        end)

        AB._hooked = true
    end
end)

-- -------------------------------------------------------------------------
-- 8) CONFIG PANEL (same as before; unchanged logic, but calls RequestApply)
-- -------------------------------------------------------------------------
local function CreateGUI()
    local panel = CreateFrame("Frame", nil, UIParent)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -40)
    scroll:SetPoint("BOTTOMRIGHT", -30, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 900)
    scroll:SetScrollChild(content)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10)
    title:SetText("Action Bars Configuration")

    local function AddCheck(label, getter, setter, yOff)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOff)
        cb.text:SetText(label)

        cb:SetScript("OnShow", function(self)
            self:SetChecked(getter() and true or false)
        end)

        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked() and true or false)
            AB.RequestApply(true)
        end)

        return cb
    end

    local t1 = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t1:SetPoint("TOPLEFT", 20, -10)
    t1:SetText("Visual Styling")

    local y = -40

    AddCheck("Enable Skinning",
        function() return GetDB().enabled end,
        function(v) GetDB().enabled = v end,
        y
    )
    y = y - 30

    AddCheck("Show Keybinds",
        function() return GetDB().showKeybinds end,
        function(v) GetDB().showKeybinds = v end,
        y
    )

    y = y - 40
    local t2 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t2:SetPoint("TOPLEFT", 20, y)
    t2:SetText("Theme:")

    y = y - 20
    local styles = { "Meta", "Glass", "Minimal", "Dark Mode", "Classy", "Custom" }
    for i, style in ipairs(styles) do
        local btn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
        btn:SetSize(100, 25)
        btn:SetPoint("TOPLEFT", 20 + ((i-1) * 110), y)
        btn:SetText(style)
        btn:SetScript("OnClick", function()
            GetDB().style = style
            AB.RequestApply(true)
        end)
    end

    -- fader UI (db only)
    y = y - 60
    local div = content:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(1, 1, 1, 0.2)
    div:SetSize(600, 1)
    div:SetPoint("TOPLEFT", 10, y)

    y = y - 20
    local t3 = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t3:SetPoint("TOPLEFT", 20, y)
    t3:SetText("Hover Fading (Fader)")

    y = y - 30
    local function GetFaderDB()
        local db = GetDB()
        db.fader = db.fader or {}
        db.fader.bars = db.fader.bars or {}
        return db.fader
    end

    AddCheck("Enable Fading",
        function() return GetFaderDB().enabled end,
        function(v) GetFaderDB().enabled = v end,
        y
    )
    y = y - 30

    AddCheck("Always Show in Combat",
        function() return GetFaderDB().showInCombat end,
        function(v) GetFaderDB().showInCombat = v end,
        y
    )

    y = y - 40
    local t4 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t4:SetPoint("TOPLEFT", 20, y)
    t4:SetText("Bars to Fade:")

    y = y - 25
    local bars = {
        MainMenuBar = "Main Bar",
        MultiBarBottomLeft = "Bottom Left",
        MultiBarBottomRight = "Bottom Right",
        MultiBarRight = "Right Bar 1",
        MultiBarLeft = "Right Bar 2",
        PetActionBar = "Pet Bar",
        StanceBar = "Stance Bar"
    }

    for k, label in pairs(bars) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb.text:SetText(label)
        cb:SetScript("OnShow", function(self)
            self:SetChecked(GetFaderDB().bars[k] and true or false)
        end)
        cb:SetScript("OnClick", function(self)
            GetFaderDB().bars[k] = self:GetChecked() and true or false
        end)
        y = y - 25
    end

    if R.RegisterModulePanel then
        R:RegisterModulePanel("ActionBars", panel)
    end
end

-- -------------------------------------------------------------------------
-- 9) INIT
-- -------------------------------------------------------------------------
local guiLoader = CreateFrame("Frame")
guiLoader:RegisterEvent("ADDON_LOADED")
guiLoader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= AddonName then return end
    EnsureDB()
    CreateGUI()

    -- initial apply (coalesced)
    AB.RequestApply(true)
end)