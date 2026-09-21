-- ApiWrappers.lua
-- Thin wrappers that normalise retail/classic cooldown APIs to a single
-- (startTime, duration) return shape, insulating the rest of the addon from
-- API differences between clients.

CooldownAlert = CooldownAlert or {}

-- Some clients (including Classic Beta, which shares the retail engine) can
-- return "secret" startTime/duration values that throw if used in arithmetic
-- or comparisons. Callers of these wrappers only ever do raw math with the
-- result, so treat secret values as "unknown" (0, 0) rather than passing them
-- through -- this module is not the secret-safe path (see
-- CooldownAlert.SupportsCooldownDurationObjects for that); it just must never
-- crash the caller.
local function SanitizeCooldown(startTime, duration)
    if PsyUtils.Secrets.IsSecret(startTime) or PsyUtils.Secrets.IsSecret(duration) then
        return 0, 0
    end
    return startTime, duration
end

--- Returns (startTime, duration) for the given spell's cooldown, or (0, 0)
--- when unavailable or secret. Prefers the modern C_Spell API, falling back
--- to the global GetSpellCooldown on older clients.
function CooldownAlert.GetSpellCD(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then return SanitizeCooldown(cd.startTime, cd.duration) end
    else
        return SanitizeCooldown(GetSpellCooldown(spellID))
    end
    return 0, 0
end

--- Returns (startTime, duration) for the given item's cooldown, or (0, 0)
--- when unavailable or secret. Prefers the modern C_Item API, falling back to
--- the global GetItemCooldown on older clients.
function CooldownAlert.GetItemCD(itemID)
    if C_Item and C_Item.GetItemCooldown then
        local cd = C_Item.GetItemCooldown(itemID)
        if cd then return SanitizeCooldown(cd.startTime, cd.duration) end
    else
        return SanitizeCooldown(GetItemCooldown(itemID))
    end
    return 0, 0
end
