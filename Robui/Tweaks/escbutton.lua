-- RobUI – ESC Game Menu Button (Clean, Retail-safe)

local rBtn

local function OpenRobUI()
    -- Prefer direct slash handler
    if SlashCmdList and SlashCmdList.ROBUI then
        SlashCmdList.ROBUI("")
        return
    end

    -- Fallback to chat execution
    if ChatFrame1 and ChatFrame1.EditBox then
        ChatFrame1.EditBox:SetText("/robui")
        ChatFrame1.EditBox:ChatEdit_SendText()
    end
end

local function AllDescendants(root)
    local out = {}
    if not root or not root.GetChildren then return out end

    local queue = { root }
    while #queue > 0 do
        local f = table.remove(queue, 1)
        for _, c in ipairs({ f:GetChildren() }) do
            out[#out + 1] = c
            if c.GetChildren then
                queue[#queue + 1] = c
            end
        end
    end
    return out
end

local function FindButtonByText(root, wantedText)
    for _, f in ipairs(AllDescendants(root)) do
        if f
            and f.GetObjectType
            and f:GetObjectType() == "Button"
            and f.GetText
            and f:IsShown()
            and f:GetText() == wantedText
        then
            return f
        end
    end
end

local function SafeCenter(frame)
    if not frame or not frame.GetCenter then return nil end
    local x, y = frame:GetCenter()
    if not x or not y then return nil end
    return x, y
end

local function EnsureButton(parent, anchor)
    if rBtn or not parent or not anchor then return end

    rBtn = CreateFrame("Button", "RobUIGameMenuButton", parent, "GameMenuButtonTemplate")
    rBtn:SetText("RobUI")
    rBtn:SetSize(anchor:GetWidth(), anchor:GetHeight())
    rBtn:SetFrameLevel(anchor:GetFrameLevel() + 2)
    rBtn:Show()

    rBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            HideUIPanel(GameMenuFrame)
        end
        OpenRobUI()
    end)
end

local function ApplyLayout()
    if InCombatLockdown() then return end
    if not GameMenuFrame or not GameMenuFrame:IsShown() then return end

    local addonsText = (type(ADDONS) == "string" and ADDONS) or "AddOns"
    local anchor =
        FindButtonByText(GameMenuFrame, addonsText) or
        FindButtonByText(GameMenuFrame, "AddOns")

    if not anchor then return end

    if not SafeCenter(anchor) then
        C_Timer.After(0, ApplyLayout)
        return
    end

    local parent = anchor:GetParent()
    if not parent then return end

    EnsureButton(parent, anchor)
    if not rBtn then return end

    -- Collect buttons in same parent
    local buttons = {}
    for _, b in ipairs({ parent:GetChildren() }) do
        if b
            and b:IsShown()
            and b.GetObjectType
            and b:GetObjectType() == "Button"
            and b.GetText
        then
            local _, y = SafeCenter(b)
            if y then
                table.insert(buttons, b)
            end
        end
    end

    -- Sort top → bottom
    table.sort(buttons, function(a, b)
        local _, ay = SafeCenter(a)
        local _, by = SafeCenter(b)
        return ay and by and ay > by
    end)

    local gap = 16
    local prev
    local inserted = false

    for _, b in ipairs(buttons) do
        if b == anchor then
            prev = anchor

            rBtn:ClearAllPoints()
            rBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
            rBtn:SetSize(anchor:GetWidth(), anchor:GetHeight())
            rBtn:Show()

            prev = rBtn
            inserted = true
        elseif inserted and b ~= rBtn then
            local _, by = SafeCenter(b)
            local _, ay = SafeCenter(anchor)
            if by and ay and by < ay then
                b:ClearAllPoints()
                b:SetPoint("TOP", prev, "BOTTOM", 0, -gap)
                prev = b
            end
        end
    end

    if not GameMenuFrame.__robuiBaseHeight then
        GameMenuFrame.__robuiBaseHeight = GameMenuFrame:GetHeight()
        GameMenuFrame:SetHeight(GameMenuFrame.__robuiBaseHeight + 40)
    end
end

local function HookMenu()
    if not GameMenuFrame or GameMenuFrame.__robuiHooked then return end
    GameMenuFrame.__robuiHooked = true

    GameMenuFrame:HookScript("OnShow", function()
        GameMenuFrame.__robuiBaseHeight = nil
        C_Timer.After(0, ApplyLayout)
        C_Timer.After(0.05, ApplyLayout)
        C_Timer.After(0.15, ApplyLayout)
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", HookMenu)
