-- EventHandler.lua
-- Listens for failed casts (to trigger the alert) and bag changes (to keep
-- the item/spell cache fresh).

CooldownAlert = CooldownAlert or {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")

-- Routes to whichever display module is active for this client, chosen the
-- same way Bootstrap.lua chose which one to create.
local function ShowAlert(spellID)
    if CooldownAlert.SupportsCooldownDurationObjects() then
        CooldownAlert.CooldownDisplay.Show(spellID)
    else
        CooldownAlert.TextDisplay.Show(spellID)
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
