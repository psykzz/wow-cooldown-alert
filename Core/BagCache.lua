-- BagCache.lua
-- Keeps a spellId -> itemId map up to date so item-triggered spells (e.g.
-- trinket procs) can be resolved back to the item that caused them.

CooldownAlert = CooldownAlert or {}

local itemSpells = {}

--- Rescans all bags and rebuilds the spellId -> itemId cache. Call this on
--- BAG_UPDATE / PLAYER_ENTERING_WORLD so the cache stays fresh.
function CooldownAlert.RefreshBagCache()
    itemSpells = PsyUtils.Bags.ScanForItemSpells()
end

--- Returns the itemId that would trigger `spellId` when used, or nil if no
--- carried item is associated with that spell.
function CooldownAlert.GetItemIdForSpell(spellId)
    return itemSpells[spellId]
end
