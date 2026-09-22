-- EventHandler.lua
-- Listens for failed casts (to trigger the alert) and bag changes (to keep
-- the item/spell cache fresh).

CooldownAlert = CooldownAlert or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")

-- Routes to whichever display module is active for this client, chosen the
-- same way Bootstrap.lua chose which one to create. Item-triggered spells
-- (trinkets, potions) are resolved back to their item via the bag cache so
-- the display shows the item's cooldown instead of treating it as a spell.
-- Trivial/near-expired cooldowns (and failures that never started a real
-- cooldown at all) are filtered out by ShouldShowAlert.
local function ShowAlert(spellID)
    local itemID = CooldownAlert.GetItemIdForSpell(spellID)
    if not CooldownAlert.ShouldShowAlert(spellID, itemID) then return end

    if CooldownAlert.SupportsCooldownDurationObjects() then
        CooldownAlert.CooldownDisplay.Show(spellID, itemID)
    else
        CooldownAlert.TextDisplay.Show(spellID, itemID)
    end
end

eventFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event ~= "UNIT_SPELLCAST_FAILED" then
        CooldownAlert.RefreshBagCache()
        return
    end

    if unit ~= "player" or not spellID then return end
    ShowAlert(spellID)
end)
