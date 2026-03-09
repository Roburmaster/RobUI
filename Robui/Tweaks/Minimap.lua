-- RobUI Minimap (Best-practice: square/round that actually sticks)
-- - Ensures defaults (enabled + shape)
-- - Applies on multiple events (login/entering world/scale changes)
-- - Hooks SetMaskTexture so Blizzard/other addons can't silently override you
-- - Adds a simple settings panel (Enable + Square)
--
-- Requires: _G.Robui + R.Database.profile
-- Optional: R:RegisterModulePanel("Minimap", frame)

local AddonName, ns = ...
local R = _G.Robui
if not R then return end

R.Minimap = R.Minimap or {}
local MM = R.Minimap

-- ------------------------------------------------------------
-- Defaults
-- ------------------------------------------------------------
local function EnsureDefaults()
    if not R.Database or not R.Database.profile then return nil end

    local profile = R.Database.profile
    profile.minimap = profile.minimap or {}

    local cfg = profile.minimap
    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.shape == nil then cfg.shape = "round" end -- "round" | "square"

    return cfg
end

-- ------------------------------------------------------------
-- Internal apply logic
-- ------------------------------------------------------------
local function Apply(cfg)
    if not cfg or cfg.enabled == false then return end

    if cfg.shape == "round" then
        -- Round mask
        Minimap:SetMaskTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")

        -- Show default border/backdrop if present
        if MinimapBorder then MinimapBorder:Show() end
        if MinimapBorderTop then MinimapBorderTop:Show() end
        if MinimapBackdrop then MinimapBackdrop:Show() end

        -- Helps addons that query minimap shape for button clustering
        _G.GetMinimapShape = function() return "ROUND" end
    else
        -- Square mask (more reliable than WHITE8X8)
        Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")

        -- Hide default round border/backdrop if present
        if MinimapBorder then MinimapBorder:Hide() end
        if MinimapBorderTop then MinimapBorderTop:Hide() end
        if MinimapBackdrop then MinimapBackdrop:Hide() end

        _G.GetMinimapShape = function() return "SQUARE" end
    end
end

-- ------------------------------------------------------------
-- Public update
-- ------------------------------------------------------------
function MM:Update()
    local cfg = EnsureDefaults()
    if not cfg then return end
    if cfg.enabled == false then return end

    -- Apply now
    Apply(cfg)

    -- Ensure mousewheel zoom (only once)
    if not Minimap.__robuiWheel then
        Minimap.__robuiWheel = true
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end
        end)
    end

    -- Hook: If Blizzard/other addons try to set a different mask, re-apply ours
    if not Minimap.__robuiMaskHooked then
        Minimap.__robuiMaskHooked = true

        hooksecurefunc(Minimap, "SetMaskTexture", function()
            if Minimap.__robuiIgnoreMaskHook then return end

            C_Timer.After(0, function()
                if not R.Database or not R.Database.profile then return end
                local c = R.Database.profile.minimap
                if not c or c.enabled == false then return end

                -- prevent recursion: our Apply calls SetMaskTexture too
                Minimap.__robuiIgnoreMaskHook = true
                Apply(c)
                Minimap.__robuiIgnoreMaskHook = false
            end)
        end)
    end
end

-- ------------------------------------------------------------
-- Settings GUI
-- ------------------------------------------------------------
function MM:CreateGUI()
    if self.__guiCreated then
        -- refresh checkbox state
        if self.panel and self.panel.cbEnabled and self.panel.cbSquare then
            local cfg = EnsureDefaults()
            if cfg then
                self.panel.cbEnabled:SetChecked(cfg.enabled ~= false)
                self.panel.cbSquare:SetChecked(cfg.shape == "square")
            end
        end
        return
    end
    self.__guiCreated = true

    local cfg = EnsureDefaults()
    if not cfg then return end

    local p = CreateFrame("Frame", nil, UIParent)
    p:Hide()
    self.panel = p

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Minimap Settings")

    -- Enabled
    local cbEnabled = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cbEnabled:SetPoint("TOPLEFT", 20, -60)
    cbEnabled.text:SetText("Enable Minimap Module")
    cbEnabled:SetChecked(cfg.enabled ~= false)
    cbEnabled:SetScript("OnClick", function(btn)
        cfg.enabled = btn:GetChecked() and true or false
        MM:Update()
    end)
    p.cbEnabled = cbEnabled

    -- Square
    local cbSquare = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cbSquare:SetPoint("TOPLEFT", 20, -90)
    cbSquare.text:SetText("Square Minimap")
    cbSquare:SetChecked(cfg.shape == "square")
    cbSquare:SetScript("OnClick", function(btn)
        cfg.shape = btn:GetChecked() and "square" or "round"
        MM:Update()
    end)
    p.cbSquare = cbSquare

    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 20, -125)
    hint:SetWidth(520)
    hint:SetJustifyH("LEFT")
    hint:SetText("RobUI will re-apply your chosen shape if Blizzard/Edit Mode/other addons try to override it.")

    -- Integrate into your existing settings host if available
    if R.RegisterModulePanel then
        R:RegisterModulePanel("Minimap", p)
    else
        -- fallback: slash to toggle panel
        SLASH_ROBUIMINIMAP1 = "/robminimap"
        SlashCmdList.ROBUIMINIMAP = function()
            if p:IsShown() then p:Hide() else p:Show() end
        end
    end
end

-- ------------------------------------------------------------
-- Loader: apply at times Blizzard tends to reset minimap
-- ------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UI_SCALE_CHANGED")
loader:RegisterEvent("DISPLAY_SIZE_CHANGED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED") -- sometimes helpful after UI changes
loader:SetScript("OnEvent", function()
    -- tiny delay to let Blizzard finish its own setup
    C_Timer.After(0.1, function()
        MM:Update()
        MM:CreateGUI()
    end)
end)
