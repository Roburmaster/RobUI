local ADDON_NAME, ns = ...
local CB = ns.CB

local pcall = pcall
local type = type

local function GetGridCore()
    local R = ns.R
    local GC = _G.RGridCore
    if GC then return GC end
    if R and R.GridCore then return R.GridCore end
    if ns and ns.GridCore then return ns.GridCore end
    if _G.RobUI and _G.RobUI.GridCore then return _G.RobUI.GridCore end
    return nil
end

function CB:GridIsAttached(pluginId)
    local GC = GetGridCore()
    if not (GC and type(GC.IsPluginAttached) == "function") then return false end
    local ok, v = pcall(GC.IsPluginAttached, GC, pluginId)
    return ok and v and true or false
end

function CB:GridAttach(pluginId)
    local GC = GetGridCore()
    if not (GC and type(GC.AttachPlugin) == "function") then return end
    pcall(GC.AttachPlugin, GC, pluginId)
end

function CB:GridRegister(pluginId, opts)
    local GC = GetGridCore()
    if not (GC and type(GC.RegisterPlugin) == "function") then return end
    pcall(GC.RegisterPlugin, GC, pluginId, opts)
end

function CB:RegisterGridPlugins()
    local GC = GetGridCore()
    if not (GC and type(GC.RegisterPlugin) == "function") then return end

    local function reg(key, name, gx, gy)
        local bar = self.bars[key]
        if not bar then return end

        local pluginId = "robui_castbar_" .. key
        bar.__gridPluginId = pluginId

        self:GridRegister(pluginId, {
            name = name or key,
            default = {
                gx = gx or 0,
                gy = gy or 0,
                group = 1,
                label = name or key,
            },
            build = function()
                return self.bars[key]
            end,
            setScale = function(frame, scale)
                if not frame or not frame.SetScale then return end
                pcall(frame.SetScale, frame, tonumber(scale) or 1)
            end,
        })

        self:GridAttach(pluginId)
        self:UpdateBarLayout(key)
    end

    reg("player",       "Castbar: Player",       -220, 140)
    reg("player_mini",  "Castbar: Player Mini",  -220, 110)
    reg("player_extra", "Castbar: Player Extra", -220, 80)
    reg("target",       "Castbar: Target",        220, 140)
    reg("target_mini",  "Castbar: Target Mini",   220, 110)
    reg("target_extra", "Castbar: Target Extra",  220, 80)
end