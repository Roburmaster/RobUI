-- BPanel/SystemStats.lua (Tidligere ms.lua)
-- Visuals: Dark theme, Compact Layout
-- Interaction: SHIFT+DRAG to move, CLICK to Clean RAM

local AddonName, ns = ...
local R = _G.Robui
ns.ms = ns.ms or {}

-- =========================================================
-- Locals / caches (micro-optimizations)
-- =========================================================
local floor = math.floor
local max   = math.max
local fmt   = string.format

-- 1. Helper: Get Configuration from RobuiDB
local function GetCfg()
    if R.Database and R.Database.profile and R.Database.profile.datapanel and R.Database.profile.datapanel.system then
        return R.Database.profile.datapanel.system
    end
    return {
        point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 10, y = 10,
        locked = false, visible = true
    }
end

local function SaveMaybe()
    -- DB lagres normalt ved logout/reload. Ikke gjør noe her.
end

function ns.ms:SetVisible(show)
    local cfg = GetCfg()
    cfg.visible = not not show
    if self.frame then self.frame:SetShown(cfg.visible) end
end

function ns.ms:Reset()
    local cfg = GetCfg()
    cfg.point, cfg.relPoint, cfg.x, cfg.y = "BOTTOMLEFT", "BOTTOMLEFT", 10, 10
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    end
end

function ns.ms:Nudge(dx, dy)
    local cfg = GetCfg()
    cfg.x = (cfg.x or 0) + dx
    cfg.y = (cfg.y or 0) + dy
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    end
end

function ns.ms:UpdateLock()
    local cfg = GetCfg()
    if not self.frame then return end

    -- Låst = ikke flyttbar (og mindre mouse-støy)
    if cfg.locked then
        self.frame:EnableMouse(false)
    else
        self.frame:EnableMouse(true)
    end
end

-- Settings Frame (Beholdt original logikk)
function ns.ms:CreateSettingsFrame()
    if self.settingsFrame and self.settingsFrame.IsObjectType and self.settingsFrame:IsObjectType("Frame") then
        return self.settingsFrame
    end

    local cfg = GetCfg()
    local f = CreateFrame("Frame", "RobUIMSSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 240)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:Hide()

    local function CreateButton(label, width, x, y, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end

    CreateButton("Show",   120, 10,  -20,  function() ns.ms:SetVisible(true) end)
    CreateButton("Hide",   120, 150, -20,  function() ns.ms:SetVisible(false) end)
    CreateButton("Lock",   120, 10,  -60,  function() cfg.locked = true;  ns.ms:UpdateLock() end)
    CreateButton("Unlock", 120, 150, -60,  function() cfg.locked = false; ns.ms:UpdateLock() end)

    CreateButton("↑", 28, 115, -100, function() ns.ms:Nudge(0, 1) end)
    CreateButton("←", 28,  85, -130, function() ns.ms:Nudge(-1, 0) end)
    CreateButton("↓", 28, 115, -130, function() ns.ms:Nudge(0, -1) end)
    CreateButton("→", 28, 145, -130, function() ns.ms:Nudge(1, 0) end)

    CreateButton("Reset", 120, 10,  -170, function() ns.ms:Reset() end)
    CreateButton("Close", 120, 90,  -210, function() f:Hide() end)

    self.settingsFrame = f
    return f
end

-- Helper for coloring numbers
local function GetColor(value, threshold1, threshold2, inverse)
    if inverse then
        if value < threshold1 then return "|cff00ff00"
        elseif value < threshold2 then return "|cffffff00"
        else return "|cffff0000" end
    else
        if value > threshold1 then return "|cff00ff00"
        elseif value > threshold2 then return "|cffffff00"
        else return "|cffff0000" end
    end
end

local function FormatMem(kb)
    if kb > 1024 then
        return fmt("%.1fmb", kb / 1024)
    else
        return fmt("%.0fkb", kb)
    end
end

function ns.ms:Initialize()
    if self.frame then return end

    local cfg = GetCfg()

    -- Main Frame
    local f = CreateFrame("Frame", "RobUIStatsFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(160, 26)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Visual Style
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    f:SetShown(cfg.visible)
    f:ClearAllPoints()
    f:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)

    -- Drag Handlers (SHIFT required)
    f:SetScript("OnDragStart", function()
        if not IsShiftKeyDown() then return end
        cfg = GetCfg()
        if cfg.locked then return end
        if InCombatLockdown() then return end
        f:StartMoving()
    end)

    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        cfg = GetCfg()
        local p, _, rp, x, y = f:GetPoint()
        cfg.point    = p  or "BOTTOMLEFT"
        cfg.relPoint = rp or "BOTTOMLEFT"
        cfg.x        = floor(x or 0)
        cfg.y        = floor(y or 0)
    end)

    -- Click to Garbage Collect
    f:SetScript("OnMouseDown", function()
        if IsShiftKeyDown() then return end
        if InCombatLockdown() then return end

        local before = gcinfo()
        collectgarbage("collect")
        local after = gcinfo()
        print("|cff00ff00[RobUI]|r Garbage Collected: |cffffffff" .. FormatMem(before - after) .. "|r freed.")
        if f.UpdateNow then f:UpdateNow(true) end
    end)

    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("System Stats")
        local _, _, home, world = GetNetStats()
        GameTooltip:AddDoubleLine("Home Latency:", home .. " ms", 1,1,1, 1,1,1)
        GameTooltip:AddDoubleLine("World Latency:", world .. " ms", 1,1,1, 1,1,1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to Force Garbage Collect", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Shift + Drag to Move", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    -- TEXT ELEMENTS (Compact Layout)
    local padding = 8

    local fpsBlock = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fpsBlock:SetPoint("LEFT", f, "LEFT", padding, 0)

    local msBlock = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    msBlock:SetPoint("LEFT", fpsBlock, "RIGHT", padding, 0)

    local memBlock = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memBlock:SetPoint("LEFT", msBlock, "RIGHT", padding, 0)

    -- =========================================================
    -- Performance: throttled OnUpdate instead of ticker
    -- FPS/MS updates often; Memory updates rarely.
    -- Also: only SetText if value changed.
    -- =========================================================
    f._accFast = 0
    f._accMem  = 0

    f._lastFPS = nil
    f._lastMS  = nil
    f._lastMem = nil
    f._lastFPSText = ""
    f._lastMSText  = ""
    f._lastMemText = ""

    local FAST_INTERVAL = 0.25
    local MEM_INTERVAL  = 2.0

    function f:UpdateNow(force)
        -- FPS
        local fps = floor(GetFramerate())
        if force or fps ~= self._lastFPS then
            self._lastFPS = fps
            local fpsColor = GetColor(fps, 50, 25, false)
            local txt = fpsColor .. fps .. "|r fps"
            if txt ~= self._lastFPSText then
                self._lastFPSText = txt
                fpsBlock:SetText(txt)
            end
        end

        -- MS
        local _, _, home, world = GetNetStats()
        local ms = max(home or 0, world or 0)
        if force or ms ~= self._lastMS then
            self._lastMS = ms
            local msColor = GetColor(ms, 100, 250, true)
            local txt = msColor .. ms .. "|r ms"
            if txt ~= self._lastMSText then
                self._lastMSText = txt
                msBlock:SetText(txt)
            end
        end

        -- Memory (only when our mem interval triggers or forced)
        if force then
            local mem = gcinfo()
            self._lastMem = mem
            local memColor = GetColor(mem, 25000, 40000, true)
            local txt = memColor .. FormatMem(mem)
            if txt ~= self._lastMemText then
                self._lastMemText = txt
                memBlock:SetText(txt)
            end
        end
    end

    local function StopUpdates()
        f:SetScript("OnUpdate", nil)
        f._accFast = 0
        f._accMem = 0
    end

    local function StartUpdates()
        -- Ikke oppdater i det hele tatt om den er skjult
        if not f:IsShown() then
            StopUpdates()
            return
        end

        f:SetScript("OnUpdate", function(self, elapsed)
            -- Hvis den blir skjult mellom frames
            if not self:IsShown() then
                StopUpdates()
                return
            end

            self._accFast = self._accFast + elapsed
            self._accMem  = self._accMem + elapsed

            if self._accFast >= FAST_INTERVAL then
                self._accFast = 0
                self:UpdateNow(false)
            end

            if self._accMem >= MEM_INTERVAL then
                self._accMem = 0
                local mem = gcinfo()
                if mem ~= self._lastMem then
                    self._lastMem = mem
                    local memColor = GetColor(mem, 25000, 40000, true)
                    local txt = memColor .. FormatMem(mem)
                    if txt ~= self._lastMemText then
                        self._lastMemText = txt
                        memBlock:SetText(txt)
                    end
                end
            end
        end)
    end

    f:SetScript("OnShow", function()
        StartUpdates()
        f:UpdateNow(true)
    end)

    f:SetScript("OnHide", function()
        StopUpdates()
    end)

    -- Kickstart
    f:UpdateNow(true)
    if f:IsShown() then
        StartUpdates()
    end

    self:UpdateLock()

    if not self.settingsFrame then
        self:CreateSettingsFrame()
    end
end

SLASH_MSSET1 = "/msset"
SlashCmdList.MSSET = function()
    if not ns.ms.settingsFrame then ns.ms:CreateSettingsFrame() end
    ns.ms.settingsFrame:SetShown(not ns.ms.settingsFrame:IsShown())
end

-- Hook into BPanel Initialize
if R.BPanel then
    hooksecurefunc(R.BPanel, "Initialize", function()
        ns.ms:Initialize()
    end)
end
