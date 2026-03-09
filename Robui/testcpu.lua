-- ============================================================================
-- Robui/Tools/cpu_probe.lua
-- RobuiCPU - CPU sampler that actually works in practice
--
-- What it DOES:
--  1) Lets you wrap functions: CPU.Probe("tag", fn)
--  2) Lets you wrap frames automatically: CPU.WrapFrame(frame, "tag")
--     - wraps OnEvent and/or OnUpdate if present
--  3) Can show total addon CPU (requires scriptProfile):
--     /console scriptProfile 1  -> /reload
--
-- Commands:
--   /robuicpu                 -> top 30 tags
--   /robuicpu 60              -> top 60 tags
--   /robuicpu reset           -> clear tag stats
--   /robuicpu dump            -> dump all tags
--   /robuicpu addon           -> print total CPU for Robui* addons (scriptProfile required)
-- ============================================================================

local ADDON, ns = ...
local R = _G.Robui

_G.RobuiCPU = _G.RobuiCPU or {}
local CPU = _G.RobuiCPU
CPU.data = CPU.data or {}

local function NowMS()
    if debugprofilestop then return debugprofilestop() end
    return (GetTime() or 0) * 1000
end

local function GetRow(tag)
    local d = CPU.data
    local row = d[tag]
    if not row then
        row = { t = 0, n = 0, max = 0, last = 0 }
        d[tag] = row
    end
    return row
end

-- Wrap a function and accumulate time
function CPU.Probe(tag, fn)
    if type(tag) ~= "string" or tag == "" then tag = "untagged" end
    if type(fn) ~= "function" then
        error("RobuiCPU.Probe(tag, fn): fn must be a function", 2)
    end

    return function(...)
        local t0 = NowMS()
        local ok, r1, r2, r3, r4, r5, r6, r7, r8 = pcall(fn, ...)
        local dt = NowMS() - t0

        local row = GetRow(tag)
        row.t = row.t + dt
        row.n = row.n + 1
        row.last = dt
        if dt > row.max then row.max = dt end

        if ok then
            return r1, r2, r3, r4, r5, r6, r7, r8
        end
        error(r1, 0)
    end
end

-- Wrap OnEvent / OnUpdate on a frame (this is what makes it "do something")
function CPU.WrapFrame(frame, tagBase)
    if not frame or type(frame) ~= "table" then return false end
    tagBase = (type(tagBase) == "string" and tagBase ~= "") and tagBase or "frame"

    local did = false

    local curOnEvent = frame.GetScript and frame:GetScript("OnEvent")
    if type(curOnEvent) == "function" and not frame.__robuiCPU_OnEvent then
        frame.__robuiCPU_OnEvent = curOnEvent
        frame:SetScript("OnEvent", CPU.Probe(tagBase .. ":OnEvent", curOnEvent))
        did = true
    end

    local curOnUpdate = frame.GetScript and frame:GetScript("OnUpdate")
    if type(curOnUpdate) == "function" and not frame.__robuiCPU_OnUpdate then
        frame.__robuiCPU_OnUpdate = curOnUpdate
        frame:SetScript("OnUpdate", CPU.Probe(tagBase .. ":OnUpdate", curOnUpdate))
        did = true
    end

    return did
end

function CPU.Mark(tag, ms)
    if type(tag) ~= "string" or tag == "" then tag = "untagged" end
    ms = tonumber(ms) or 0
    if ms <= 0 then return end

    local row = GetRow(tag)
    row.t = row.t + ms
    row.n = row.n + 1
    row.last = ms
    if ms > row.max then row.max = ms end
end

function CPU.Reset()
    CPU.data = {}
end

local function PrintTop(limit)
    limit = tonumber(limit) or 30
    if limit < 1 then limit = 30 end

    local list = {}
    for tag, row in pairs(CPU.data) do
        list[#list + 1] = {
            tag = tag,
            t = row.t or 0,
            n = row.n or 0,
            max = row.max or 0,
            last = row.last or 0
        }
    end

    table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)

    print("|cff00ff00RobuiCPU|r top", math.min(limit, #list), "tags (total ms):")
    for i = 1, math.min(limit, #list) do
        local it = list[i]
        local avg = (it.n > 0) and (it.t / it.n) or 0
        print(string.format(
            "%2d) %-34s  total=%8.1f  calls=%7d  avg=%6.2f  max=%7.2f  last=%7.2f",
            i, it.tag, it.t, it.n, avg, it.max, it.last
        ))
    end
end

local function DumpAll()
    print("|cff00ff00RobuiCPU|r dump all tags:")
    for tag, row in pairs(CPU.data) do
        local avg = (row.n and row.n > 0) and (row.t / row.n) or 0
        print(string.format(
            "%-34s  total=%8.1f  calls=%7d  avg=%6.2f  max=%7.2f  last=%7.2f",
            tag, row.t or 0, row.n or 0, avg, row.max or 0, row.last or 0
        ))
    end
end

-- Total addon CPU (requires scriptProfile)
local function PrintAddonTotals()
    if not (UpdateAddOnCPUUsage and GetAddOnCPUUsage and GetNumAddOns and GetAddOnInfo) then
        print("|cffff4444RobuiCPU|r addon CPU APIs not available.")
        return
    end

    -- This does nothing unless /console scriptProfile 1 + /reload
    UpdateAddOnCPUUsage()

    local rows = {}
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name and (name:find("^Robui") or name:find("^RobUI")) then
            local ms = GetAddOnCPUUsage(i) or 0
            rows[#rows+1] = { name = name, ms = ms }
        end
    end

    table.sort(rows, function(a,b) return (a.ms or 0) > (b.ms or 0) end)

    print("|cff00ff00RobuiCPU|r AddOn CPU totals (ms):  (requires scriptProfile)")
    for i = 1, #rows do
        print(string.format("%2d) %-28s  %10.2f ms", i, rows[i].name, rows[i].ms))
    end
end

-- Slash command
SLASH_ROBUICPU1 = "/robuicpu"
SlashCmdList.ROBUICPU = function(msg)
    msg = tostring(msg or ""):lower()

    if msg:find("reset", 1, true) then
        CPU.Reset()
        print("|cff00ff00RobuiCPU|r reset.")
        return
    end

    if msg:find("dump", 1, true) then
        DumpAll()
        return
    end

    if msg:find("addon", 1, true) then
        PrintAddonTotals()
        return
    end

    local n = tonumber(msg)
    if n then
        PrintTop(n)
    else
        PrintTop(30)
    end
end

if type(ns) == "table" then
    ns.CPU = CPU
end

print("|cff00ff00RobuiCPU loaded.|r  Use /robuicpu. For addon totals: /console scriptProfile 1 + /reload then /robuicpu addon")