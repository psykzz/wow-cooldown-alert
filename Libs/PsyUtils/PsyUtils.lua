-- PsyUtils.lua
-- Small collection of framework-agnostic helpers shared across PsyKzz's WoW
-- addons. Copy this file (and its folder) into any addon that needs these
-- helpers -- each addon gets its own private copy, so there's no load-order
-- coupling between addons. If this grows large enough to be worth sharing a
-- single source of truth, promote it to a standalone Lib* addon and load it
-- via ## RequiredDeps instead of copy-pasting.

PsyUtils = PsyUtils or {}

-- ── Math ─────────────────────────────────────────────────────────────────────
PsyUtils.Math = PsyUtils.Math or {}

--- Returns the display alpha (0.0-1.0) for `timeSinceTrigger` seconds after an
--- alert fired, given how long it should stay fully visible (`holdTime`) and
--- how long it should then fade out (`fadeOutTime`). Returns nil once the
--- alert has fully expired, signalling to the caller that it should hide it.
function PsyUtils.Math.ComputeFadeAlpha(timeSinceTrigger, holdTime, fadeOutTime)
    local totalDuration = holdTime + fadeOutTime
    if timeSinceTrigger >= totalDuration then
        return nil
    elseif fadeOutTime > 0 and timeSinceTrigger > holdTime then
        return 1 - (timeSinceTrigger - holdTime) / fadeOutTime
    else
        return 1
    end
end

-- ── Formatting ───────────────────────────────────────────────────────────────
PsyUtils.Format = PsyUtils.Format or {}

--- Formats `remainingSeconds` as a countdown string according to `preset`:
---   "auto3"   - integer above 3s, one decimal below (default)
---   "auto1"   - integer above 1s, one decimal below
---   "decimal" - always one decimal place
---   "integer" - always a whole number
function PsyUtils.Format.Countdown(remainingSeconds, preset)
    remainingSeconds = math.max(0, remainingSeconds or 0)
    if preset == "auto1" then
        return remainingSeconds > 1 and string.format("%.0fs", remainingSeconds) or string.format("%.1fs", remainingSeconds)
    elseif preset == "decimal" then
        return string.format("%.1fs", remainingSeconds)
    elseif preset == "integer" then
        return string.format("%.0fs", remainingSeconds)
    else -- "auto3" (default)
        return remainingSeconds > 3 and string.format("%.0fs", remainingSeconds) or string.format("%.1fs", remainingSeconds)
    end
end

--- Formats `totalSeconds` as a human-readable duration, e.g. "45s" or "2m 05s".
--- Rounds to the nearest whole second. Negative/nil input is treated as 0.
function PsyUtils.Format.Duration(totalSeconds)
    totalSeconds = math.max(0, math.floor((totalSeconds or 0) + 0.5))
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    if minutes > 0 then
        return string.format("%dm %02ds", minutes, seconds)
    else
        return string.format("%ds", seconds)
    end
end

-- ── Saved Variables ──────────────────────────────────────────────────────────
PsyUtils.SavedVariables = PsyUtils.SavedVariables or {}

--- Fills any keys missing from `db` with the corresponding value from
--- `defaults`, mutating `db` in place and returning it. Existing keys/values
--- are left untouched, so upgrades never clobber a user's saved settings.
function PsyUtils.SavedVariables.ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value
        end
    end
    return db
end

-- ── Secrets ──────────────────────────────────────────────────────────────────
PsyUtils.Secrets = PsyUtils.Secrets or {}

--- Returns true if `value` is a "secret" value that cannot be used in normal
--- arithmetic/comparisons without throwing an error (WoW's secret-value
--- mechanism for certain sensitive API results, e.g. some cooldown fields).
--- This is distinct from UI taint. Safe to call on any client, including
--- ones without issecretvalue().
function PsyUtils.Secrets.IsSecret(value)
    if type(issecretvalue) ~= "function" then
        return false
    end
    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end

--- Returns `value` unchanged, or nil if it's a secret value. Handy at read
--- sites (e.g. `local hp = PsyUtils.Secrets.Unwrap(UnitHealth("target"))`) so
--- callers get a plain "no data" nil instead of a value that will throw the
--- moment it's used in arithmetic or a comparison.
function PsyUtils.Secrets.Unwrap(value)
    if PsyUtils.Secrets.IsSecret(value) then
        return nil
    end
    return value
end

-- ── Rolling Window ───────────────────────────────────────────────────────────
PsyUtils.RollingWindow = PsyUtils.RollingWindow or {}

local RollingWindowMethods = {}
local RollingWindowMeta = { __index = RollingWindowMethods }

--- Records `value` (e.g. a damage amount) at `timestamp` (defaults to GetTime()).
function RollingWindowMethods:AddSample(value, timestamp)
    table.insert(self.samples, { value = value, time = timestamp or GetTime() })
end

--- Discards samples older than the window's duration relative to `now`
--- (defaults to GetTime()). Call before reading Sum/ElapsedSeconds so stale
--- samples don't linger and skew the result.
function RollingWindowMethods:Prune(now)
    now = now or GetTime()
    local cutoff = now - self.windowSeconds
    local samples = self.samples
    while samples[1] and samples[1].time < cutoff do
        table.remove(samples, 1)
    end
end

--- Sum of all currently retained sample values.
function RollingWindowMethods:GetSum()
    local sum = 0
    for _, sample in ipairs(self.samples) do
        sum = sum + sample.value
    end
    return sum
end

--- Number of currently retained samples.
function RollingWindowMethods:GetSampleCount()
    return #self.samples
end

--- Timestamp of the oldest retained sample, or nil if empty.
function RollingWindowMethods:GetOldestTimestamp()
    local first = self.samples[1]
    return first and first.time
end

--- Seconds between the oldest retained sample and `now` (defaults to
--- GetTime()). Returns 0 when there are no samples yet -- callers computing a
--- rate should treat that as "not enough data" rather than divide by it.
function RollingWindowMethods:GetElapsedSeconds(now)
    local oldest = self:GetOldestTimestamp()
    if not oldest then return 0 end
    return (now or GetTime()) - oldest
end

--- Removes all samples, resetting the window to empty.
function RollingWindowMethods:Clear()
    self.samples = {}
end

--- Creates a new rolling window that retains samples for `windowSeconds`.
--- Generic enough for any "rate over recent time" tracking -- damage taken,
--- casts per second, resource generation, etc.
function PsyUtils.RollingWindow.New(windowSeconds)
    return setmetatable({ windowSeconds = windowSeconds, samples = {} }, RollingWindowMeta)
end

-- ── Bags ─────────────────────────────────────────────────────────────────────
PsyUtils.Bags = PsyUtils.Bags or {}

--- Scans all bag slots (0-4) and returns a table mapping spellId -> itemId for
--- every "use" item currently carried (e.g. trinkets, potions). Useful for
--- resolving an item-triggered spell cast back to the item that caused it.
function PsyUtils.Bags.ScanForItemSpells()
    local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    local GetItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell

    local itemSpells = {}
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local itemId = GetContainerItemID(bag, slot)
            if itemId then
                local _, spellId = GetItemSpell(itemId)
                if spellId then itemSpells[spellId] = itemId end
            end
        end
    end
    return itemSpells
end
