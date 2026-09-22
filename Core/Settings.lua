-- Settings.lua
-- Applies persisted CooldownAlertDB values to whichever display module
-- currently exists. Safe to call at any time -- each target module is
-- optional and simply skipped if it hasn't been created yet.

CooldownAlert = CooldownAlert or {}

function CooldownAlert.ApplySettings()
    local db = CooldownAlertDB
    if not db then return end

    if CooldownAlert.TextDisplay and CooldownAlert.TextDisplay.ApplySettings then
        CooldownAlert.TextDisplay.ApplySettings()
    end

    if CooldownAlert.CooldownDisplay and CooldownAlert.CooldownDisplay.ApplySettings then
        CooldownAlert.CooldownDisplay.ApplySettings()
    end
end
