# Agent Instructions

## WoW Midnight: secret values vs. UI taint

WoW Midnight introduces **secret values** as an anti-cheat mechanism.
Do **not** confuse them with **UI taint** — they are entirely different concepts:

| Concept | What it is | Consequence |
|---------|-----------|-------------|
| **UI taint** | Insecure Lua code touching the protected UI frame tree | Certain protected actions (e.g. `UseAction`) become blocked for that frame |
| **Secret value** | A number returned by the game engine with its real content deliberately hidden from addons (e.g. cooldown `start`/`duration` for certain spells) | Any arithmetic (`+`, `-`, `*`, `/`, comparisons) on the value **always** throws a Lua error — regardless of execution context |

### Implications for this addon

- `GetSpellCooldown` / `C_Spell.GetSpellCooldown` and the item equivalents can return secret `startTime` and/or `duration` values on WoW Midnight.
- `PsyUtils.Secrets.IsSecret(v)` (defined in `Libs/PsyUtils/PsyUtils.lua`, shimmed to always return `false` on clients without a real `issecretvalue`, e.g. Classic/TBC) must be called on **both** `start` **and** `duration` before performing any arithmetic on them — see `Core/ApiWrappers.lua` and `UI/TextDisplay.lua` for the call sites.
- When a secret value is detected, skip the arithmetic entirely. `UNIT_SPELLCAST_FAILED` only fires when the spell genuinely went on cooldown, so it is safe to show the alert unconditionally in that case.
- Prefer the duration-object cooldown APIs (`CooldownAlert.SupportsCooldownDurationObjects()` in `Core/ClientCapabilities.lua`) when available — they sidestep secret-value arithmetic entirely and must be used over raw `(startTime, duration)` math whenever supported.
