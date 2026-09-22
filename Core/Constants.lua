-- Constants.lua
-- Addon-wide identifiers and default saved-variable values. Loaded first so
-- every other module can rely on these existing.

CooldownAlert = CooldownAlert or {}

CooldownAlert.ADDON_NAME = "CooldownAlert"

-- Default values used for first-time initialization and Settings API defaults.
CooldownAlertDB_Defaults = {
    holdTime    = 0.3,
    fadeOutTime = 0.7,
    fontSize    = 28,
    fontFace    = "Fonts\\FRIZQT__.TTF",
    fontFlags   = "OUTLINE",
    posX        = 0,
    posY        = 0,
    textFormat  = "auto3",
}
