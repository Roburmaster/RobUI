-- RobUI Database / Profile System
-- NOTE: Ikke rot med databasen. Legg til – ikke fjern ting unødvendig.
-- Update:
--  - New locked profile: RobUIStandard (runtime-only, never saved/overwritten)
--  - List click = SELECT only (no auto-load). Use "Load Selected".
--  - Buttons: Load Selected + Delete Selected (delete is reliable)
--  - Copy Profile (warn if empty)
--  - Export / Import profile (strip hidden/control chars)
--  - Fix: spec-binding override guard (prevents instant bounce-back)
--  - Visual cleanup: proper spacing, no overlap, two-column layout

local AddonName, ns = ...
local R = ns
R.Database = R.Database or {}
local DB = R.Database

-- ------------------------------------------------------------
-- 1) CONSTANTS / NAMES
-- ------------------------------------------------------------
DB.STANDARD_PROFILE_NAME = "RobUIStandard" -- locked, runtime-only
DB.DEFAULT_PROFILE_NAME  = "Default"

-- ------------------------------------------------------------
-- 2) DEFAULTS & STATIC PROFILES
-- ------------------------------------------------------------
DB.StaticProfiles = DB.StaticProfiles or {
    ["Master: Tank"]   = { general = { scale = 1.0 }, actionbars = { style = "Dark Mode" } },
    ["Master: Healer"] = { general = { scale = 0.9 }, actionbars = { style = "Glass" } },
    ["Master: DPS"]    = { general = { scale = 0.8 }, actionbars = { style = "Meta" } },
}

-- Factory baseline (used for RobUIStandard + seeding new profiles).
local defaults = {
    profile = {
        general = { scale = 1.0 },

        actionbars = {
            enabled = true,
            style = "Meta",
            showKeybinds = true,
            customColor = {0.2, 0.2, 0.2, 1},
            fader = {
                enabled = false,
                hiddenAlpha = 0.1,
                fadeInTime = 0.15,
                fadeOutTime = 0.3,
                hoverLinger = 0.5,
                showInCombat = true,
                bars = {
                    MainMenuBar = true,
                    MultiBarBottomLeft = true,
                    MultiBarBottomRight = true,
                    MultiBarRight = true,
                    MultiBarLeft = true,
                    PetActionBar = true,
                    StanceBar = true,
                }
            }
        },

        datapanel = {
            enabled = true,

            system = { enabled = true, locked = false, visible = true, point = "BOTTOMLEFT", x = 10, y = 10 },
            durability = { enabled = true, locked = false, autoHide = true, point = "BOTTOMLEFT", x = 120, y = 30 },
            specloot = { enabled = true, locked = false, visible = true, point = "BOTTOMLEFT", x = 150, y = 0 },

            gold = {
                enabled = true, locked = false, visible = true,
                point = "BOTTOMRIGHT", x = -38, y = 4,
                autoRepair = true, guildRepair = true, autoSell = false,
            },

            instance = { enabled = true, locked = false, point = "CENTER", x = 0, y = 0 }
        },

        toppanel = {
            enabled = true,
            clock24 = true,
            useLocalTime = false,
            fontSize = 36,
            hideInCombat = true,
            scale = 1.0,
            hover = false,
            point = "TOP", x = 0, y = -30,
        },

        unitframes = {
            player = {
                shown = true, locked = false,
                point = "CENTER", x = -280, y = 120,
                w = 320, hpH = 26, powerH = 12, pipH = 14, gap = 4,

                showName = true, showHPText = true, showPowerText = true, showPower = true, pipEnabled = true,

                nameSize = 12, hpSize = 11, powerSize = 10,
                nameOffX=0, nameOffY=0, hpOffX=0, hpOffY=0, powOffX=0, powOffY=0,

                nameR=1, nameG=1, nameB=1,
                hpTextR=1, hpTextG=1, hpTextB=1,
                powTextR=1, powTextG=1, powTextB=1,

                showIncomingHeals=true, showHealAbsorb=true, showAbsorb=true,

                useTexture=true, texturePath="Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
                noColorOverride=false, tintOnlyOnBase=true,
                useClassColor=true, useCustomHP=false, hpR=0.2, hpG=0.8, hpB=0.2,
                useCustomPower=false, powR=0.2, powG=0.4, powB=1.0,
            },

            target = {
                shown = true, locked = false,
                point = "CENTER", x = 280, y = 120,
                w = 320, hpH = 26, powerH = 12, gap = 4,

                showName = true, showHPText = true, showPowerText = true, showPower = true,
                showLevel = true, showClassTag = true,

                nameSize = 12, hpSize = 11, powerSize = 10, lvlSize = 11, tagSize = 10,
                nameOffX=0, nameOffY=0, hpOffX=0, hpOffY=0, powOffX=0, powOffY=0,
                lvlOffX=0, lvlOffY=0, tagOffX=0, tagOffY=0,

                nameR=1, nameG=1, nameB=1,
                hpTextR=1, hpTextG=1, hpTextB=1,
                powTextR=1, powTextG=1, powTextB=1,
                lvlTextR=1, lvlTextG=1, lvlTextB=1,
                tagTextR=1, tagTextG=1, tagTextB=1,

                showIncomingHeals=true, showHealAbsorb=true, showAbsorb=true,

                useTexture=true, baseTexturePath="Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
                noColorOverride=true, tintOnlyOnBase=true,
                useClassColor=true, useCustomHP=false, hpR=0.2, hpG=0.8, hpB=0.2,
                useCustomPower=false, powR=0.2, powG=0.4, powB=1.0,
            },

            targettarget = {
                shown = true, locked = false,
                point = "CENTER", x = 540, y = 70,
                w = 260, hpH = 22, powerH = 10, gap = 4,

                showName = true, showHPText = true, showPowerText = false, showPower = true,

                nameSize = 11, hpSize = 10, powerSize = 9,
                nameOffX=0, nameOffY=0, hpOffX=0, hpOffY=0, powOffX=0, powOffY=0,

                nameR=1, nameG=1, nameB=1,
                hpTextR=1, hpTextG=1, hpTextB=1,
                powTextR=1, powTextG=1, powTextB=1,

                showIncomingHeals=true, showHealAbsorb=true, showAbsorb=true,

                useTexture=true, baseTexturePath="Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
                noColorOverride=true, tintOnlyOnBase=true,
                useClassColor=true, useCustomHP=false, hpR=0.2, hpG=0.8, hpB=0.2,
                useCustomPower=false, powR=0.2, powG=0.4, powB=1.0,
            },

            focus = {
                shown = true, locked = false,
                point = "CENTER", x = 540, y = 120,
                w = 300, hpH = 24, powerH = 11, gap = 4,

                showName = true, showHPText = true, showPowerText = true, showPower = true,

                nameSize = 12, hpSize = 11, powerSize = 10,
                nameOffX=0, nameOffY=0, hpOffX=0, hpOffY=0, powOffX=0, powOffY=0,

                nameR=1, nameG=1, nameB=1,
                hpTextR=1, hpTextG=1, hpTextB=1,
                powTextR=1, powTextG=1, powTextB=1,

                showIncomingHeals=true, showHealAbsorb=true, showAbsorb=true,

                useTexture=true, baseTexturePath="Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
                noColorOverride=true, tintOnlyOnBase=true,
                useClassColor=true, useCustomHP=false, hpR=0.2, hpG=0.8, hpB=0.2,
                useCustomPower=false, powR=0.2, powG=0.4, powB=1.0,
            },

            pet = {
                shown = true, locked = false,
                point = "CENTER", x = -540, y = 60,
                w = 260, hpH = 22, powerH = 10, gap = 4,

                showName = true, showHPText = true, showPowerText = true, showPower = true,

                nameSize = 12, hpSize = 11, powerSize = 10,
                nameOffX=0, nameOffY=0, hpOffX=0, hpOffY=0, powOffX=0, powOffY=0,

                nameR=1, nameG=1, nameB=1,
                hpTextR=1, hpTextG=1, hpTextB=1,
                powTextR=1, powTextG=1, powTextB=1,

                showIncomingHeals=true, showHealAbsorb=true, showAbsorb=true,

                useTexture=true, baseTexturePath="Interface\\AddOns\\"..AddonName.."\\media\\base.tga",
                noColorOverride=true, tintOnlyOnBase=true,
                useCustomHP=false, hpR=0.2, hpG=0.8, hpB=0.2,
                useCustomPower=false, powR=0.2, powG=0.4, powB=1.0,
            }
        },

        classbar = { enabled = true },

        autosell = {
            enabled = false,
            threshold = 10,
            sellGray = true,
            sellWarbound = false,
            shiftClickEnabled = false,
            logSales = true,
        },

        minimap = { enabled = true, shape = "square" },

        windows = {},

        auras = {
            enabled = true,
            attachTopPad = 6,
            attachBottomPad = 14,
            attachBottomPadTarget = 14,
            playerDebuffs = { shown = true, locked = false, size = 22, gap = 4, max = 16, onlyMine = false, whitelist = {}, blacklist = {}, userMoved = false, point = "CENTER", relPoint = "CENTER", x = -360, y = -40 },
            playerBuffs   = { shown = true, locked = false, size = 22, gap = 4, max = 16, onlyMine = false, whitelist = {}, blacklist = {}, userMoved = false, point = "CENTER", relPoint = "CENTER", x = -360, y = -95 },
            targetDebuffs = { shown = true, locked = false, size = 22, gap = 4, max = 16, onlyMine = true,  whitelist = {}, blacklist = {}, userMoved = false, point = "CENTER", relPoint = "CENTER", x = 360, y = -40 },
            targetBuffs   = { shown = true, locked = false, size = 22, gap = 4, max = 16, onlyMine = true,  whitelist = {}, blacklist = {}, userMoved = false, point = "CENTER", relPoint = "CENTER", x = 360, y = -95 },
        },

        castbar = {
            global = { enabled = true, font = "Fonts\\FRIZQT__.TTF", texture = "Interface\\Buttons\\WHITE8x8", unlocked = false },
            player       = { enabled = true, width = 220, height = 24, x = -200, y = 200, color = {0.2, 0.6, 1, 1}, showIcon = true,  showLatency = true  },
            target       = { enabled = true, width = 220, height = 24, x =  200, y = 200, color = {1, 0.8, 0, 1}, interruptColor = {1, 0.2, 0.2, 1}, shieldColor = {0.6, 0.6, 0.6, 1}, showIcon = true },
            player_mini  = { enabled = true, width = 150, height = 14, x =    0, y = 300, color = {0.2, 1, 0.2, 1}, showIcon = false, showLatency = false },
            target_mini  = { enabled = true, width = 150, height = 14, x =    0, y = 330, color = {1, 0.5, 0, 1}, interruptColor = {1, 0, 0, 1}, shieldColor = {0.5, 0.5, 0.5, 1}, showIcon = false },
            player_extra = { enabled = true, width = 270, height = 20, x =    0, y = 400, color = {0.2, 0.6, 1, 1}, showIcon = true,  showLatency = true  },
            target_extra = { enabled = true, width = 270, height = 20, x =    0, y = 430, color = {1, 0.8, 0, 1}, interruptColor = {1, 0, 0, 1}, shieldColor = {0.5, 0.5, 0.5, 1}, showIcon = true },
        },

        markers = { enabled = true, point = "BOTTOM", relPoint = "BOTTOM", xOfs = 0, yOfs = 0, locked = false, visible = true },
        media = { useCustom = false, fontKey = "Default" },

        livestats = {
            enabled = true,
            point = "TOPLEFT", x = 20, y = -200,
            barWidth = 140, barHeight = 14,
            barTexture = "Interface\\Buttons\\WHITE8x8",
            showBars = true,
            colors = {
                Crit        = { r=0.80, g=0.20, b=0.20 },
                Haste       = { r=0.20, g=0.80, b=0.20 },
                Mastery     = { r=0.20, g=0.60, b=0.95 },
                Versatility = { r=0.85, g=0.65, b=0.10 },
                Leech       = { r=0.35, g=0.85, b=0.85 },
                Avoidance   = { r=0.75, g=0.55, b=0.90 },
                Speed       = { r=0.95, g=0.50, b=0.25 },
                Dodge       = { r=0.55, g=0.85, b=0.55 },
                Parry       = { r=0.85, g=0.55, b=0.55 },
                Strength    = { r=0.90, g=0.25, b=0.40 },
                Stamina     = { r=0.20, g=0.60, b=0.80 },
                Armor       = { r=0.50, g=0.60, b=0.70 },
                Agility     = { r=0.30, g=0.80, b=0.50 },
                Intellect   = { r=0.60, g=0.40, b=0.95 },
            },
            stats = {
                Crit=true, Haste=true, Mastery=true, Versatility=true,
                Leech=false, Avoidance=false, Speed=false,
                Dodge=false, Parry=false,
                Strength=false, Agility=false, Stamina=false, Intellect=false, Armor=false
            }
        },

        characterStats = { enabled = true },
        mythicgear = { pos = {"CENTER", "UIParent", "CENTER", 0, 0} },
    },

    global = { autosellLists = { whitelist = {}, blacklist = {} } },
    char   = { specBindings = {} }
}

-- ------------------------------------------------------------
-- 3) HELPERS
-- ------------------------------------------------------------
local function CopyTable(src, dest)
    if type(dest) ~= "table" then dest = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = CopyTable(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end

local function DeepClone(src, dest)
    dest = dest or {}
    for k in pairs(dest) do dest[k] = nil end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = DeepClone(v, {})
        else
            dest[k] = v
        end
    end
    return dest
end

local function SafeTrim(s)
    s = tostring(s or "")
    s = s:gsub("[%c]", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function IsReservedProfileName(name)
    return SafeTrim(name) == DB.STANDARD_PROFILE_NAME
end

local function IsValidProfileName(name)
    name = SafeTrim(name)
    if name == "" then return false end
    if #name > 80 then return false end
    return true
end

local function Now()
    return (GetTime and GetTime()) or 0
end

DB._suppressSpecSwitchUntil = DB._suppressSpecSwitchUntil or 0

function DB:GetStandardProfile()
    return CopyTable(defaults.profile, {})
end

-- ------------------------------------------------------------
-- 3B) EXPORT / IMPORT (serializer)
-- ------------------------------------------------------------
local function SerializeValue(v, depth)
    depth = depth or 0
    if depth > 40 then return "nil" end
    local tv = type(v)

    if tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "nil" end
        return tostring(v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif tv == "string" then
        return string.format("%q", v)
    elseif tv == "table" then
        local parts = {}
        table.insert(parts, "{")
        for k, val in pairs(v) do
            local tk = type(k)
            local key
            if tk == "string" then
                if k:match("^[A-Za-z_][A-Za-z0-9_]*$") then
                    key = k .. " = "
                else
                    key = "[" .. string.format("%q", k) .. "] = "
                end
            elseif tk == "number" then
                key = "[" .. tostring(k) .. "] = "
            end
            if key then
                table.insert(parts, key .. SerializeValue(val, depth + 1) .. ",")
            end
        end
        table.insert(parts, "}")
        return table.concat(parts, " ")
    end

    return "nil"
end

function DB:GetProfileTableByName(name)
    name = SafeTrim(name or self.profileName)
    if name == DB.STANDARD_PROFILE_NAME then
        return self:GetStandardProfile()
    end
    local db = RobuiDB
    return db and db.profiles and db.profiles[name] or nil
end

function DB:ExportProfile(name)
    name = SafeTrim(name or self.profileName)
    local prof = self:GetProfileTableByName(name)
    if not prof then return nil, "Profile not found." end

    local body = "return " .. SerializeValue(prof, 0)
    if #body > 200000 then return nil, "Export too large." end
    return body
end

function DB:ImportProfile(newName, exportString)
    newName = SafeTrim(newName)
    exportString = tostring(exportString or "")

    if not IsValidProfileName(newName) then return false, "Invalid profile name." end
    if IsReservedProfileName(newName) then return false, "RobUIStandard is reserved and cannot be imported/overwritten." end
    if #exportString < 10 or #exportString > 200000 then return false, "Import string size invalid." end

    local chunk, err = loadstring(exportString)
    if not chunk then return false, "Import parse failed: " .. tostring(err) end

    local ok, tbl = pcall(chunk)
    if not ok or type(tbl) ~= "table" then return false, "Import data invalid (not a table)." end

    local db = RobuiDB
    db.profiles[newName] = db.profiles[newName] or {}
    DeepClone(tbl, db.profiles[newName])
    CopyTable(defaults.profile, db.profiles[newName])

    self:RefreshPanel()
    return true
end

-- ------------------------------------------------------------
-- 4) CORE LOGIC
-- ------------------------------------------------------------
local function ApplyAllModules()
    if R.UpdateActionBars then R.UpdateActionBars() end
    if R.TopPanel and R.TopPanel.Update then R.TopPanel:Update() end

    if R.Minimap and R.Minimap.Update then R.Minimap:Update() end
    if R.WindowMover and R.WindowMover.ApplyAll then R.WindowMover:ApplyAll() end
    if ns.auras and ns.auras.ApplyAll then ns.auras:ApplyAll() end
    if R.Castbar and R.Castbar.Refresh then R.Castbar:Refresh() end

    if ns.instancetools and ns.instancetools.markers and ns.instancetools.markers.Refresh then
        ns.instancetools.markers:Refresh()
    end

    if ns.media and ns.media.ApplyAll then ns.media:ApplyAll() end
    if ns.livestats and ns.livestats.RefreshLayout then ns.livestats:RefreshLayout() end

    if R.UnitFrames then
        local UF = R.UnitFrames
        if UF.Player and UF.Player.ForceUpdate then UF.Player:ForceUpdate() end
        if UF.Target and UF.Target.ForceUpdate then UF.Target:ForceUpdate() end
        if UF.TargetTarget and UF.TargetTarget.ForceUpdate then UF.TargetTarget:ForceUpdate() end
        if UF.Focus and UF.Focus.ForceUpdate then UF.Focus:ForceUpdate() end
        if UF.Pet and UF.Pet.ForceUpdate then UF.Pet:ForceUpdate() end
    end
end

function DB:Initialize()
    if not RobuiDB then RobuiDB = {} end
    local db = RobuiDB

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}
    db.global = db.global or {}
    db.char = db.char or {}

    self.myKey = UnitName("player") .. " - " .. GetRealmName()

    if not db.char[self.myKey] then db.char[self.myKey] = {} end
    CopyTable(defaults.char, db.char[self.myKey])
    self.char = db.char[self.myKey]

    CopyTable(defaults.global, db.global)
    self.global = db.global

    if not db.profileKeys[self.myKey] then
        db.profileKeys[self.myKey] = DB.DEFAULT_PROFILE_NAME
    end

    -- automatic on login (OK), but list click does NOT load
    self:SetProfile(db.profileKeys[self.myKey])

    self:CreateOptionsPanel()
end

function DB:SetProfile(name)
    DB._suppressSpecSwitchUntil = Now() + 0.50

    local db = RobuiDB
    name = SafeTrim(name)
    if name == "" then name = DB.DEFAULT_PROFILE_NAME end

    if name == DB.STANDARD_PROFILE_NAME then
        self.profileName = DB.STANDARD_PROFILE_NAME
        self.profile = self:GetStandardProfile()
        db.profileKeys[self.myKey] = DB.STANDARD_PROFILE_NAME

        print("|cff00b3ffRobui|r: Profile set to ["..DB.STANDARD_PROFILE_NAME.."] (Locked)")
        ApplyAllModules()
        if self.panel then self:RefreshPanel() end
        return
    end

    if not db.profiles[name] and DB.StaticProfiles[name] then
        db.profiles[name] = CopyTable(DB.StaticProfiles[name], {})
    end

    if not db.profiles[name] then
        db.profiles[name] = CopyTable(defaults.profile, {})
    end

    CopyTable(defaults.profile, db.profiles[name])

    db.profileKeys[self.myKey] = name
    self.profile = db.profiles[name]
    self.profileName = name

    print("|cff00b3ffRobui|r: Profile set to ["..name.."]")
    ApplyAllModules()
    if self.panel then self:RefreshPanel() end
end

function DB:DeleteProfile(name)
    name = SafeTrim(name)
    if name == "" then return false, "No profile selected." end
    if IsReservedProfileName(name) then return false, "RobUIStandard cannot be deleted." end
    if DB.StaticProfiles[name] then return false, "Static profiles cannot be deleted." end

    local db = RobuiDB
    if not db.profiles[name] then return false, "Profile not found in saved profiles." end

    -- If deleting active profile, switch to Default first
    if self.profileName == name then
        self:SetProfile(DB.DEFAULT_PROFILE_NAME)
    end

    db.profiles[name] = nil

    -- If any character key points to this, reset it (safe)
    for key, prof in pairs(db.profileKeys or {}) do
        if prof == name then
            db.profileKeys[key] = DB.DEFAULT_PROFILE_NAME
        end
    end

    self.selectedProfile = nil
    self:RefreshPanel()
    return true
end

function DB:CopyProfile(srcName, destName)
    srcName = SafeTrim(srcName or self.profileName)
    destName = SafeTrim(destName)

    if not IsValidProfileName(destName) then return false, "Invalid destination name." end
    if IsReservedProfileName(destName) then return false, "RobUIStandard is reserved and cannot be overwritten." end

    local src = self:GetProfileTableByName(srcName)
    if not src then return false, "Source profile not found." end

    local db = RobuiDB
    db.profiles[destName] = db.profiles[destName] or {}
    DeepClone(src, db.profiles[destName])
    CopyTable(defaults.profile, db.profiles[destName])

    self:RefreshPanel()
    return true
end

function DB:HandleSpecSwitch()
    if Now() < (DB._suppressSpecSwitchUntil or 0) then return end
    local spec = GetSpecialization()
    if not spec then return end
    local bound = self.char.specBindings[spec]
    if bound and bound ~= self.profileName then
        self:SetProfile(bound)
    end
end

-- ------------------------------------------------------------
-- 5) GUI (clean layout, no overlap)
-- ------------------------------------------------------------
function DB:CreateOptionsPanel()
    local p = CreateFrame("Frame", nil, UIParent)
    self.panel = p

    -- Layout constants
    local PAD = 16
    local GAP = 10

    local LEFT_W  = 380
    local RIGHT_W = 420

    local EDIT_W  = 260
    local BTN_W   = 100
    local ROW_H   = 28

    -- Title
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Profile Management")

    -- Active box
    local activeBox = CreateFrame("Frame", nil, p, "BackdropTemplate")
    activeBox:SetSize(LEFT_W, 38)
    activeBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -GAP)
    R:CreateBackdrop(activeBox)

    activeBox.label = activeBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    activeBox.label:SetPoint("CENTER")
    activeBox.label:SetText("Active: Unknown")
    self.panel.activeLabel = activeBox.label

    -- LEFT COLUMN ANCHOR
    local leftAnchor = CreateFrame("Frame", nil, p)
    leftAnchor:SetSize(LEFT_W, 1)
    leftAnchor:SetPoint("TOPLEFT", activeBox, "BOTTOMLEFT", 0, -GAP)

    -- Create row
    local createEdit = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    createEdit:SetSize(EDIT_W, ROW_H)
    createEdit:SetPoint("TOPLEFT", leftAnchor, "TOPLEFT", 0, 0)
    createEdit:SetAutoFocus(false)
    createEdit:SetText("New Profile Name")
    createEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local createBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    createBtn:SetSize(BTN_W, ROW_H)
    createBtn:SetPoint("LEFT", createEdit, "RIGHT", GAP, 0)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        local name = SafeTrim(createEdit:GetText())
        if not IsValidProfileName(name) then
            print("|cffff4040Robui|r: Invalid profile name.")
            return
        end
        if IsReservedProfileName(name) then
            print("|cffff4040Robui|r: RobUIStandard is reserved and cannot be created.")
            return
        end

        RobuiDB.profiles = RobuiDB.profiles or {}
        if not RobuiDB.profiles[name] then
            RobuiDB.profiles[name] = CopyTable(defaults.profile, {})
        end
        CopyTable(defaults.profile, RobuiDB.profiles[name])

        DB.selectedProfile = name
        DB:SetProfile(name)
        createEdit:SetText("")
        DB:RefreshPanel()
    end)

    -- Copy row
    local copyEdit = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    copyEdit:SetSize(EDIT_W, ROW_H)
    copyEdit:SetPoint("TOPLEFT", createEdit, "BOTTOMLEFT", 0, -6)
    copyEdit:SetAutoFocus(false)
    copyEdit:SetText("Copy to Name")
    copyEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local copyBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    copyBtn:SetSize(BTN_W, ROW_H)
    copyBtn:SetPoint("LEFT", copyEdit, "RIGHT", GAP, 0)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        local dest = SafeTrim(copyEdit:GetText())
        if dest == "" then
            print("|cffff4040Robui|r: Type a name in the copy box first.")
            return
        end

        local ok, msg = DB:CopyProfile(DB.profileName, dest)
        if not ok then
            print("|cffff4040Robui|r: " .. tostring(msg))
            return
        end

        DB.selectedProfile = dest
        print("|cff00ff00Robui|r: Copied ["..DB.profileName.."] -> ["..dest.."]")
        copyEdit:SetText("")
        DB:RefreshPanel()
    end)

    -- Scroll list + backdrop
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetSize(LEFT_W, 260)
    scroll:SetPoint("TOPLEFT", copyEdit, "BOTTOMLEFT", 0, -GAP)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(LEFT_W, 500)
    scroll:SetScrollChild(content)

    local listBG = CreateFrame("Frame", nil, p, "BackdropTemplate")
    listBG:SetPoint("TOPLEFT", scroll, -5, 5)
    listBG:SetPoint("BOTTOMRIGHT", scroll, 25, -5)
    R:CreateBackdrop(listBG)
    listBG:SetBackdropColor(0,0,0,0.5)

    self.panel.buttons = {}
    self.panel.content = content
    self.panel.scroll = scroll

    -- Action buttons under list
    local loadBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    loadBtn:SetSize((LEFT_W - GAP) / 2, 26)
    loadBtn:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -GAP)
    loadBtn:SetText("Load Selected")
    loadBtn:SetScript("OnClick", function()
        local name = SafeTrim(DB.selectedProfile)
        if name == "" then
            print("|cffff4040Robui|r: Select a profile first.")
            return
        end
        DB:SetProfile(name)
        DB:RefreshPanel()
    end)
    self.panel.loadBtn = loadBtn

    local delBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    delBtn:SetSize((LEFT_W - GAP) / 2, 26)
    delBtn:SetPoint("LEFT", loadBtn, "RIGHT", GAP, 0)
    delBtn:SetText("Delete Selected")
    delBtn:SetScript("OnClick", function()
        local name = SafeTrim(DB.selectedProfile)
        if name == "" then
            print("|cffff4040Robui|r: Select a profile first.")
            return
        end
        local ok, msg = DB:DeleteProfile(name)
        if not ok then
            print("|cffff4040Robui|r: " .. tostring(msg))
            return
        end
        print("|cff00ff00Robui|r: Deleted profile ["..name.."]")
        DB:RefreshPanel()
    end)
    self.panel.delBtn = delBtn

    -- RIGHT COLUMN ANCHOR
    local rightAnchor = CreateFrame("Frame", nil, p)
    rightAnchor:SetSize(RIGHT_W, 1)
    rightAnchor:SetPoint("TOPLEFT", activeBox, "TOPRIGHT", PAD, 0)

    -- Spec binding block
    local specLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", rightAnchor, "TOPLEFT", 0, 0)
    specLabel:SetText("Bind Spec to Active:")

    self.panel.specBtns = {}
    for i=1, 3 do
        local btn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
        btn:SetSize(260, 26)
        btn:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -8 - ((i-1) * 30))
        btn:SetScript("OnClick", function()
            DB.char.specBindings[i] = DB.profileName
            DB:RefreshPanel()
            print("|cff00ff00Robui|r: Spec " .. i .. " bound to profile: " .. DB.profileName)
        end)
        self.panel.specBtns[i] = btn
    end

    -- Export / Import block (right column, below spec)
    local exLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exLabel:SetPoint("TOPLEFT", self.panel.specBtns[3], "BOTTOMLEFT", 0, -18)
    exLabel:SetText("Export / Import")

    local exportBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    exportBox:SetSize(RIGHT_W - BTN_W - GAP, ROW_H)
    exportBox:SetPoint("TOPLEFT", exLabel, "BOTTOMLEFT", 0, -8)
    exportBox:SetAutoFocus(false)
    exportBox:SetText("Export string appears here")
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.panel.exportBox = exportBox

    local exportBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    exportBtn:SetSize(BTN_W, ROW_H)
    exportBtn:SetPoint("LEFT", exportBox, "RIGHT", GAP, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local data, err = DB:ExportProfile(DB.profileName)
        if not data then
            print("|cffff4040Robui|r: " .. tostring(err))
            return
        end
        exportBox:SetText(data)
        exportBox:HighlightText()
        exportBox:SetFocus()
        print("|cff00ff00Robui|r: Exported profile [" .. DB.profileName .. "]")
    end)

    local importName = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    importName:SetSize(RIGHT_W - BTN_W - GAP, ROW_H)
    importName:SetPoint("TOPLEFT", exportBox, "BOTTOMLEFT", 0, -8)
    importName:SetAutoFocus(false)
    importName:SetText("Import Name")
    importName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.panel.importName = importName

    local importBtn = CreateFrame("Button", nil, p, "GameMenuButtonTemplate")
    importBtn:SetSize(BTN_W, ROW_H)
    importBtn:SetPoint("LEFT", importName, "RIGHT", GAP, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local name = SafeTrim(importName:GetText())
        local data = exportBox:GetText()
        local ok, msg = DB:ImportProfile(name, data)
        if not ok then
            print("|cffff4040Robui|r: " .. tostring(msg))
            return
        end
        print("|cff00ff00Robui|r: Imported profile [" .. name .. "]")
        DB.selectedProfile = name
        importName:SetText("")
        DB:RefreshPanel()
    end)

    R:RegisterModulePanel("Profiles", p)
end

function DB:RefreshPanel()
    if not self.panel then return end

    self.panel.activeLabel:SetText("Active Profile: |cff00ff00" .. tostring(self.profileName or "?") .. "|r")

    local list = {}

    table.insert(list, DB.STANDARD_PROFILE_NAME)

    for k in pairs(RobuiDB.profiles) do
        if k ~= DB.STANDARD_PROFILE_NAME then
            table.insert(list, k)
        end
    end

    for k in pairs(DB.StaticProfiles) do
        if not RobuiDB.profiles[k] then
            table.insert(list, k)
        end
    end

    table.sort(list)

    local btns = self.panel.buttons
    for _, btn in pairs(btns) do btn:Hide() end

    local selected = SafeTrim(self.selectedProfile)

    for i, name in ipairs(list) do
        if not btns[i] then
            local b = CreateFrame("Button", nil, self.panel.content)
            b:SetSize(350, 20)
            b:SetPoint("TOPLEFT", 6, -(i-1)*20)

            b.sel = b:CreateTexture(nil, "BACKGROUND")
            b.sel:SetAllPoints()
            b.sel:SetColorTexture(1, 1, 1, 0.10)
            b.sel:Hide()

            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 6, 0)

            b:SetScript("OnClick", function()
                DB.selectedProfile = name
                DB:RefreshPanel()
            end)

            btns[i] = b
        end

        local b = btns[i]
        b:Show()

        if name == DB.STANDARD_PROFILE_NAME then
            b.text:SetText(name .. " |cff66e6ff[Locked]|r")
        else
            b.text:SetText(name)
        end

        -- Selection highlight
        if name == selected then
            b.sel:Show()
        else
            b.sel:Hide()
        end

        -- Text color (selected > active > locked > master > normal)
        if name == selected then
            b.text:SetTextColor(1, 1, 1)
        elseif name == self.profileName then
            b.text:SetTextColor(0, 1, 0)
        elseif name == DB.STANDARD_PROFILE_NAME then
            b.text:SetTextColor(0.2, 0.9, 1.0)
        elseif string.find(name, "Master") then
            b.text:SetTextColor(1, 0.8, 0)
        else
            b.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end

    self.panel.content:SetHeight(#list * 20)

    local numSpecs = GetNumSpecializations() or 3
    for i=1, 3 do
        local btn = self.panel.specBtns[i]
        if i <= numSpecs then
            local _, sname = GetSpecializationInfo(i)
            if sname then
                local bound = self.char.specBindings[i]
                local suffix = (bound == self.profileName) and " |cff00ff00[Bound]|r" or ""
                btn:SetText(sname .. suffix)
                btn:Show()
            end
        else
            btn:Hide()
        end
    end
end
