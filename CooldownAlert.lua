
local GetSpellCD = function(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then return cd.startTime, cd.duration end
    else
        return GetSpellCooldown(spellID)
    end
    return 0, 0
end

local GetItemCD = function(itemID)
    if C_Item and C_Item.GetItemCooldown then
        local cd = C_Item.GetItemCooldown(itemID)
        if cd then return cd.startTime, cd.duration end
    else
        return GetItemCooldown(itemID)
    end
    return 0, 0
end

local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

local OFFSET = 0.5

-- Returns true when v is a "secret" number (WoW Midnight): it exists but
-- cannot be compared with relational operators.  Such values are safe to
-- format with AbbreviatedNumberFormatter but not with string.format/math.max.
-- The type() guard ensures we only attempt comparison on actual numbers;
-- plain Lua numbers never raise errors on comparison unless they are secret.
local function IsSecret(v)
    if type(v) ~= "number" then return false end
    local ok = pcall(function() return v > 0 end)
    return not ok
end

-- Addon namespace shared with CooldownAlertSettings.lua
CooldownAlert = CooldownAlert or {}

-- Default values used for first-time initialization and Settings API defaults
CooldownAlertDB_Defaults = {
    holdTime     = 0.3,
    fadeOutTime  = 0.7,
    fontSize     = 28,
    fontFace     = "Fonts\\FRIZQT__.TTF",
    fontFlags    = "OUTLINE",
    posX         = 0,
    posY         = 0,
    textFormat   = "auto3",
}

local item_spells = {}
local activeSpellID = nil
local activeItemID = nil
local timeSinceTrigger = 0

local display = CreateFrame("Frame", "CooldownAlertFrame", UIParent)
display:SetSize(250, 50)
display:SetPoint("CENTER", 0, 0)
display:Hide()

display.text = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
display.text:SetPoint("CENTER")
display.text:SetTextColor(1, 1, 1)
display.text:SetFont(display.text:GetFont(), 28, "OUTLINE")

-- Format remaining seconds according to the saved textFormat setting.
-- When remaining is a secret number (WoW Midnight) it cannot be compared,
-- so fall back to the game's AbbreviatedNumberFormatter.
local function FormatTime(remaining)
    if IsSecret(remaining) then
        return AbbreviatedNumberFormatter(remaining)
    end
    local fmt = CooldownAlertDB and CooldownAlertDB.textFormat or "auto3"
    if fmt == "auto1" then
        return remaining > 1 and string.format("%.0fs", remaining) or string.format("%.1fs", remaining)
    elseif fmt == "decimal" then
        return string.format("%.1fs", remaining)
    elseif fmt == "integer" then
        return string.format("%.0fs", remaining)
    else -- "auto3" (default)
        return remaining > 3 and string.format("%.0fs", remaining) or string.format("%.1fs", remaining)
    end
end

-- Apply font and position settings from CooldownAlertDB to the display frame
function CooldownAlert.ApplySettings()
    local db = CooldownAlertDB
    if not db then return end
    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", db.posX or 0, db.posY or 0)
    display.text:SetFont(
        db.fontFace  or CooldownAlertDB_Defaults.fontFace,
        db.fontSize  or CooldownAlertDB_Defaults.fontSize,
        db.fontFlags or CooldownAlertDB_Defaults.fontFlags
    )
end

-- Initialise saved variables and apply settings on first load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "CooldownAlert" then return end
    if not CooldownAlertDB then CooldownAlertDB = {} end
    for k, v in pairs(CooldownAlertDB_Defaults) do
        if CooldownAlertDB[k] == nil then CooldownAlertDB[k] = v end
    end
    CooldownAlert.ApplySettings()
    self:UnregisterEvent("ADDON_LOADED")
end)

local function ScanBags()
    wipe(item_spells)
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local itemId = GetContainerItemID(bag, slot)
            if itemId then
                local _, spellId = GetItemSpell(itemId)
                if spellId then item_spells[spellId] = itemId end
            end
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event ~= "UNIT_SPELLCAST_FAILED" then
        ScanBags()
        return
    end

    if unit ~= "player" or not spellID then return end

    -- Handle items
    local itemId = item_spells[spellID]
    local start, duration

    if itemId then
        start, duration = GetItemCD(itemId)
        activeItemID = itemId
        activeSpellID = nil
    else
        start, duration = GetSpellCD(spellID)
        activeSpellID = spellID
        activeItemID = nil
    end

    -- Ignore GCD or very short cooldowns.  When duration is a secret number
    -- the comparison would error, so we skip the filter and treat it as a
    -- real (long enough) cooldown.
    local ok, isShort = pcall(function() return not duration or duration <= 1.5 end)
    if ok and isShort then return end

    local timeLeft = start + duration - GetTime()

    -- Same guard for the timeLeft comparison.  When the value is secret we
    -- cannot verify sign, but UNIT_SPELLCAST_FAILED only fires while the spell
    -- is on cooldown, so treating an unreadable timeLeft as positive is safe.
    local okOffset, isPositive = pcall(function() return timeLeft > OFFSET end)
    if okOffset and not isPositive then return end

    timeSinceTrigger = 0
    display:SetAlpha(1)
    display:Show()
end)

display:SetScript("OnUpdate", function(self, elapsed)
    timeSinceTrigger = timeSinceTrigger + elapsed

    -- Update remaining time text
    local start, duration
    if activeItemID then
        start, duration = GetItemCD(activeItemID)
    elseif activeSpellID then
        start, duration = GetSpellCD(activeSpellID)
    end

    if start and duration then
        local remaining = start + duration - GetTime()
        -- math.max requires comparison; skip the floor at 0 when remaining is secret
        local okMax, floored = pcall(function() return math.max(0, remaining) end)
        self.text:SetText(FormatTime(okMax and floored or remaining))
    end

    -- Fade out using current saved values so changes take effect immediately
    local db = CooldownAlertDB
    local holdTime    = db and db.holdTime    or CooldownAlertDB_Defaults.holdTime
    local fadeOutTime = db and db.fadeOutTime or CooldownAlertDB_Defaults.fadeOutTime
    local totalDuration = holdTime + fadeOutTime

    if timeSinceTrigger > totalDuration then
        self:Hide()
    elseif timeSinceTrigger > holdTime then
        local fadeProgress = (timeSinceTrigger - holdTime) / fadeOutTime
        self:SetAlpha(1 - fadeProgress)
    end
end)
