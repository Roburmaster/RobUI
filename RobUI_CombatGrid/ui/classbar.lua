-- ============================================================================
-- classbar.lua
-- RobUI CombatGrid - ClassBar module (separate file)
--
-- DB: ns.DB:GetConfig("classbar")  (RobUI profile-backed via driver.lua)
-- GridCore plugin:
--   PluginId: ct_classbar
--   Grid owns position/size/scale when attached / edit mode
-- Standalone drag/save only when NOT grid driving.
-- ============================================================================

local ADDON, ns = ...
ns = _G[ADDON] or ns or {}
_G[ADDON] = ns

ns.ClassBar = ns.ClassBar or {}
local CB = ns.ClassBar

local CreateFrame = CreateFrame
local UIParent = UIParent
local tonumber = tonumber

local PLUGIN_ID = "ct_classbar"

local DEFAULTS = {
    enabled = false,

    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -200,

    w = 240,
    h = 18,
    scale = 1.0,

    locked = false,
}

local function GetDB()
if not (ns.DB and ns.DB.GetConfig) then
    CB._tmp = CB._tmp or {}
    for k, v in pairs(DEFAULTS) do
        if CB._tmp[k] == nil then CB._tmp[k] = v end
            end
            return CB._tmp
            end

            ns.DB:RegisterDefaults("classbar", DEFAULTS)
            return ns.DB:GetConfig("classbar")
            end

            local function IsGridDriving()
            if ns.GridCore and ns.GridCore.IsPluginAttached and ns.GridCore:IsPluginAttached(PLUGIN_ID) then
                return true
                end
                if ns.GridCore and ns.GridCore.IsEditMode and ns.GridCore:IsEditMode() then
                    return true
                    end
                    return false
                    end

                    function CB:ApplyLayout()
                    local db = GetDB()
                    if not self.root or not db then return end

                        self.root:SetScale(db.scale or 1)
                        self.root:SetSize(db.w or 240, db.h or 18)
                        self.root:ClearAllPoints()
                        self.root:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
                        end

                        function CB:UpdateLock()
                        local db = GetDB()
                        if not self.mover or not db then return end
                            local unlocked = (ctDB and ctDB.unlocked) or false
                            local canMove = (not db.locked) and (unlocked or not IsGridDriving())
                            self.mover:EnableMouse(canMove)
                            self.mover:SetAlpha(canMove and 0.9 or 0)
                            end

                            function CB:UpdateVisibility()
                            local db = GetDB()
                            if not self.root or not db then return end
                                if db.enabled or (ctDB and ctDB.unlocked) or IsGridDriving() then
                                    self.root:Show()
                                    else
                                        self.root:Hide()
                                        end
                                        end

                                        function CB:Initialize()
                                        if self.root then
                                            self:ApplyLayout()
                                            self:UpdateLock()
                                            self:UpdateVisibility()
                                            return
                                            end

                                            local db = GetDB()

                                            local root = CreateFrame("Frame", "CT_ClassBar", UIParent, "BackdropTemplate")
                                            self.root = root
                                            root:SetBackdrop({
                                                bgFile = "Interface\\Buttons\\WHITE8x8",
                                                edgeFile = "Interface\\Buttons\\WHITE8x8",
                                                edgeSize = 1,
                                                insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                            })
                                            root:SetBackdropColor(0, 0, 0, 0.35)
                                            root:SetBackdropBorderColor(0, 0, 0, 0.85)

                                            local bar = CreateFrame("StatusBar", nil, root)
                                            self.bar = bar
                                            bar:SetAllPoints(root)
                                            bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
                                            bar:SetMinMaxValues(0, 1)
                                            bar:SetValue(0.5)

                                            local mover = CreateFrame("Frame", nil, root)
                                            self.mover = mover
                                            mover:SetAllPoints(root)
                                            mover:EnableMouse(true)
                                            mover:RegisterForDrag("LeftButton")

                                            local txt = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                            txt:SetPoint("CENTER")
                                            txt:SetText("Drag ClassBar")

                                            root:SetMovable(true)
                                            mover:SetScript("OnDragStart", function()
                                            if InCombatLockdown() then return end
                                                if IsGridDriving() then return end
                                                    root:StartMoving()
                                                    end)
                                            mover:SetScript("OnDragStop", function()
                                            root:StopMovingOrSizing()
                                            if IsGridDriving() then return end
                                                local point, _, relPoint, x, y = root:GetPoint()
                                                db.point = point
                                                db.relPoint = relPoint
                                                db.x = x
                                                db.y = y
                                                CB:ApplyLayout()
                                                end)

                                            self:ApplyLayout()
                                            self:UpdateLock()
                                            self:UpdateVisibility()
                                            end

                                            local function RegisterGridPlugin()
                                            if CB._gridRegistered then return end
                                                if not (ns.GridCore and type(ns.GridCore.RegisterPlugin) == "function") then return end

                                                    ns.GridCore:RegisterPlugin(PLUGIN_ID, {
                                                        name = "ClassBar",
                                                        default = { gx = 0, gy = -80, scaleWithGrid = false, label = "ClassBar" },
                                                        build = function()
                                                        CB:Initialize()
                                                        return CB.root
                                                        end,
                                                        standard = { position = true, size = true, scale = true },
                                                        setSize = function(frame, w, h)
                                                        local db = GetDB()
                                                        w = tonumber(w) or db.w or 240
                                                        h = tonumber(h) or db.h or 18
                                                        db.w = w
                                                        db.h = h
                                                        CB:ApplyLayout()
                                                        end,
                                                        setScale = function(frame, scale)
                                                        local db = GetDB()
                                                        scale = tonumber(scale) or db.scale or 1
                                                        db.scale = scale
                                                        CB:ApplyLayout()
                                                        end,
                                                        apply = function(frame)
                                                        CB:ApplyLayout()
                                                        CB:UpdateLock()
                                                        CB:UpdateVisibility()
                                                        end,
                                                    })

                                                    CB._gridRegistered = true
                                                    end

                                                    local f = CreateFrame("Frame")
                                                    f:RegisterEvent("PLAYER_LOGIN")
                                                    f:SetScript("OnEvent", function()
                                                    CB:Initialize()
                                                    RegisterGridPlugin()
                                                    end)
