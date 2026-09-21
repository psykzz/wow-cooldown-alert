-- ClientCapabilities.lua
-- Detects WoW client capabilities so the rest of the addon can feature-detect
-- instead of branching on build/version numbers, which don't reliably predict
-- API behaviour across the various WoW clients (retail, classic, "Classic
-- Beta" aka wow-forever, etc). In particular, several clients now return
-- "secret" cooldown values from C_Spell.GetSpellCooldown that cannot be used
-- in normal arithmetic -- attempting to do so taints execution and throws in
-- combat. Classic Beta shares the retail engine, so it hit this exact bug
-- even though it isn't a "Midnight" build by version number.

CooldownAlert = CooldownAlert or {}

--- True when GetBuildInfo() reports a WoW Midnight (12.0+) build. Kept for
--- informational/debugging purposes only -- do NOT use this to decide
--- whether secret cooldown values are in play. Use
--- CooldownAlert.SupportsCooldownDurationObjects() for that instead.
function CooldownAlert.IsMidnight()
    return select(4, GetBuildInfo()) > 120000
end

local supportsDurationObjects = nil

--- True when the client exposes the duration-object cooldown APIs
--- (C_Spell.GetSpellCooldownDuration + Cooldown:SetCooldownFromDurationObject).
--- This is the secret-value-safe path and must be preferred over raw
--- (startTime, duration) arithmetic whenever it is available, regardless of
--- which expansion/build is running.
function CooldownAlert.SupportsCooldownDurationObjects()
    if supportsDurationObjects == nil then
        supportsDurationObjects = false
        if C_Spell and C_Spell.GetSpellCooldownDuration then
            local probe = CreateFrame("Cooldown", nil, nil, "CooldownFrameTemplate")
            supportsDurationObjects = type(probe.SetCooldownFromDurationObject) == "function"
        end
    end
    return supportsDurationObjects
end
