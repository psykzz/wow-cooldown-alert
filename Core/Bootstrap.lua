-- Bootstrap.lua
-- Runs once on ADDON_LOADED: initializes saved variables and creates the
-- correct alert display for this client's capabilities.

CooldownAlert = CooldownAlert or {}

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= CooldownAlert.ADDON_NAME then return end

    CooldownAlertDB = CooldownAlertDB or {}
    PsyUtils.SavedVariables.ApplyDefaults(CooldownAlertDB, CooldownAlertDB_Defaults)

    -- Prefer the duration-object display whenever the client supports it --
    -- this is feature-detected, not version-sniffed, because clients that
    -- aren't "Midnight" by build number (e.g. Classic Beta) can still return
    -- secret cooldown values that only the duration-object APIs handle safely.
    if CooldownAlert.SupportsCooldownDurationObjects() then
        CooldownAlert.CooldownDisplay.Create()
    else
        CooldownAlert.TextDisplay.Create()
    end

    CooldownAlert.ApplySettings()
    self:UnregisterEvent("ADDON_LOADED")
end)
