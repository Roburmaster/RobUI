local f = CreateFrame("Frame")
f:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event)
    if not C_ChallengeMode then return end
    if not C_ChallengeMode.GetOwnedKeystoneInfo then return end

    -- Hent keystone-info
    local mapID = C_ChallengeMode.GetOwnedKeystoneInfo()
    if not mapID then return end

    -- Slot frame må finnes
    local slot = _G.ChallengesKeystoneFrame
    if not slot or not slot:IsShown() then return end

    -- Finn keystone i bag
    for bag = 0, NUM_BAG_SLOTS do
        for slotID = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slotID)
            if itemID == 180653 then -- Mythic Keystone itemID
                C_Container.UseContainerItem(bag, slotID)
                return
            end
        end
    end
end)
