local ADDON_NAME, ns = ...
local CB = ns.CB
local R = ns.R

local pairs = pairs
local type = type

local DEFAULT_DB = {
    global = {
        enabled = true,
        font = "Fonts\\FRIZQT__.TTF",
        texture = "Interface\\Buttons\\WHITE8x8",
    },

    player = {
        enabled = true,
        width = 260,
        height = 18,
        x = -220,
        y = 140,
        color = {0.20, 0.70, 1.00, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = true,
        showLatency = true,
        textSize = 12,
        timeSize = 12,
        iconSize = 0,
    },

    player_mini = {
        enabled = true,
        width = 200,
        height = 14,
        x = -220,
        y = 110,
        color = {0.20, 0.70, 1.00, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = false,
        showLatency = false,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
    },

    player_extra = {
        enabled = true,
        width = 240,
        height = 14,
        x = -220,
        y = 80,
        color = {0.20, 0.70, 1.00, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = false,
        showLatency = false,
        vertical = false,
        textX = 0,
        textY = 0,
        timeX = 0,
        timeY = 0,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
        textBoxW = 160,
        textBoxH = 18,
        timeBoxW = 60,
        timeBoxH = 18,
    },

    target = {
        enabled = true,
        width = 260,
        height = 18,
        x = 220,
        y = 140,
        color = {1.00, 0.30, 0.30, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = true,
        showLatency = false,
        textSize = 12,
        timeSize = 12,
        iconSize = 0,
    },

    target_mini = {
        enabled = true,
        width = 200,
        height = 14,
        x = 220,
        y = 110,
        color = {1.00, 0.30, 0.30, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = false,
        showLatency = false,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
    },

    target_extra = {
        enabled = true,
        width = 240,
        height = 14,
        x = 220,
        y = 80,
        color = {1.00, 0.30, 0.30, 1},
        shieldColor = {0.50, 0.50, 0.50, 1},
        showIcon = false,
        showLatency = false,
        vertical = false,
        textX = 0,
        textY = 0,
        timeX = 0,
        timeY = 0,
        textSize = 11,
        timeSize = 11,
        iconSize = 0,
        textBoxW = 160,
        textBoxH = 18,
        timeBoxW = 60,
        timeBoxH = 18,
    },
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(dst[k], v)
        else
            if dst[k] == nil then
                dst[k] = v
            end
        end
    end
end

function CB:GetDB()
    if not (R and R.Database and R.Database.profile) then return nil end
    R.Database.profile.castbar = R.Database.profile.castbar or {}
    local db = R.Database.profile.castbar
    CopyDefaults(db, DEFAULT_DB)
    return db
end

function CB:GetDefaults()
    return DEFAULT_DB
end