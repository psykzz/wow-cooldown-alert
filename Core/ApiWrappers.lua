-- ApiWrappers.lua
-- Thin wrappers that normalise retail/classic cooldown APIs to a single
-- (startTime, duration, isSecret) return shape, insulating the rest of the
-- addon from API differences between clients.

CooldownAlert = CooldownAlert or {}

-- Some clients (including Classic Beta, which shares the retail engine) can
-- return "secret" startTime/duration values that throw if used in arithmetic
-- or comparisons. Callers of these wrappers only ever do raw math with the
-- result, so this never hands a secret value through -- instead it reports
-- isSecret=true and (0, 0), leaving it up to the caller to decide how to
-- behave (per AGENTS.md: skip the arithmetic, but it's still safe to show
-- the alert unconditionally since UNIT_SPELLCAST_FAILED only fires when a
-- cooldown genuinely started). This module is not the secret-safe rendering
-- path (see CooldownAlert.SupportsCooldownDurationObjects for that); it just
-- must never crash the caller, and must never silently report a real
-- (secret) cooldown as "no cooldown".
local function SanitizeCooldown(startTime, duration)
    if PsyUtils.Secrets.IsSecret(startTime) or PsyUtils.Secrets.IsSecret(duration) then
        return 0, 0, true
    end
    -- Some clients/APIs can return a cd table with a nil startTime or
    -- duration field even when not secret; normalize to 0 so callers can
    -- always rely on getting numbers back, matching the documented (0, 0)
    -- "unavailable" fallback below.
    return startTime or 0, duration or 0, false
end

--- Returns (startTime, duration, isSecret) for the given spell's cooldown.
--- (startTime, duration) are (0, 0) when unavailable OR when secret --
--- always check isSecret before treating (0, 0) as "no cooldown". Prefers
--- the modern C_Spell API, falling back to the global GetSpellCooldown on
--- older clients.
function CooldownAlert.GetSpellCD(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then return SanitizeCooldown(cd.startTime, cd.duration) end
    else
        return SanitizeCooldown(GetSpellCooldown(spellID))
    end
    return 0, 0, false
end

--- Returns (startTime, duration, isSecret) for the given item's cooldown.
--- (startTime, duration) are (0, 0) when unavailable OR when secret --
--- always check isSecret before treating (0, 0) as "no cooldown". Prefers
--- the modern C_Item API, falling back to the global GetItemCooldown on
--- older clients.
function CooldownAlert.GetItemCD(itemID)
    if C_Item and C_Item.GetItemCooldown then
        local cd = C_Item.GetItemCooldown(itemID)
        if cd then return SanitizeCooldown(cd.startTime, cd.duration) end
    else
        return SanitizeCooldown(GetItemCooldown(itemID))
    end
    return 0, 0, false
end

-- Cooldowns shorter than this (e.g. the global cooldown) aren't worth
-- alerting on. Cooldowns already this close to expiring by the time we
-- check aren't worth it either. Mirrors the pre-modularization thresholds.
local MIN_ALERT_DURATION = 1.5
local MIN_REMAINING_TIME = 0.5

--- Decides whether a failed cast should trigger the alert at all, given the
--- spell that failed and the item (if any) that resolves back to it. Prefers
--- the item's cooldown, falling back to the spell's when the item has none.
--- Secret cooldowns can't be measured against the thresholds above, so they
--- always show (see SanitizeCooldown's doc comment).
--- This always uses the raw (startTime, duration, isSecret) wrappers, even
--- on duration-object-capable clients: a duration object is opaque by
--- design and exposes no readable magnitude, so there is no duration-object
--- equivalent for a numeric threshold decision like this one (see
--- AGENTS.md's secret-values section).
function CooldownAlert.ShouldShowAlert(spellID, itemID)
    local startTime, duration, isSecret = 0, 0, false
    if itemID then
        startTime, duration, isSecret = CooldownAlert.GetItemCD(itemID)
    end
    if not isSecret and duration == 0 and spellID then
        startTime, duration, isSecret = CooldownAlert.GetSpellCD(spellID)
    end

    if isSecret then return true end
    if duration <= MIN_ALERT_DURATION then return false end

    local timeLeft = startTime + duration - GetTime()
    return timeLeft > MIN_REMAINING_TIME
end
