local AddonName, ns = ...
local R = _G.Robui

-- Opprett en usynlig ramme som fungerer som "søppelbøtte"
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local function DisableFrame(frame)
    if not frame then return end

    -- Stopp events for å spare CPU
    if frame.UnregisterAllEvents then
        frame:UnregisterAllEvents()
    end

    -- Skjul den
    frame:Hide()

    -- Flytt den til den usynlige rammen.
    -- Siden forelderen (hiddenParent) er skjult, vil barnet (frame) aldri vises.
    frame:SetParent(hiddenParent)

    -- Sørg for at den ikke kan flyttes tilbake (for sikkerhets skyld)
    local hook = function()
        if frame:GetParent() ~= hiddenParent then
            frame:SetParent(hiddenParent)
        end
    end

    -- Vi hooker ikke "Show" lenger da det kan skape "Taint" feil i Dragonflight/War Within
    -- SetParent metoden er den tryggeste.
end

local function Initialize()
    -- Sjekk om vi skal kjøre dette (hvis UnitFrames er slått av i Robui, vil vi kanskje beholde Blizzard?)
    -- For nå antar vi at Robui UnitFrames alltid erstatter Blizzard.
    if not R.Database.profile.unitframes.player.shown then return end

    -- --- PLAYER ---
    DisableFrame(PlayerFrame)

    -- Skjul Class Power Bars (Combo Points, Soul Shards, etc) hvis Robui Pips er på
    -- NB: I modern WoW (EditMode) kan disse være vanskelige å fjerne helt uten taint,
    -- men å fjerne PlayerFrame tar ofte med seg avhengighetene.
    if PlayerFrameBottomManagedFramesContainer then
        DisableFrame(PlayerFrameBottomManagedFramesContainer)
    end

    -- --- TARGET ---
    DisableFrame(TargetFrame)
    DisableFrame(TargetFrameToT) -- Target of Target
    DisableFrame(TargetFrameSpellBar) -- Castbar (valgfritt, fjern denne linjen hvis du vil beholde blizzard castbar)

    -- --- FOCUS ---
    DisableFrame(FocusFrame)
    DisableFrame(FocusFrameSpellBar)
    DisableFrame(FocusFrameToT)

    -- --- PET ---
    DisableFrame(PetFrame)

    -- --- BOSS (Kommer senere i din suite, men greit å vite om) ---
    -- for i = 1, 5 do
    --     DisableFrame(_G["Boss"..i.."TargetFrame"])
    -- end

    -- Fjern "Boss Banner" (Loot/Kill banner som dekker skjermen)
    -- DisableFrame(BossBanner)
end

-- Kjør ved innlogging
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    Initialize()
end)
