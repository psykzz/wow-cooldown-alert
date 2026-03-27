
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

-- WoW Midnight-only APIs; provide safe no-op shims for Classic/TBC/pre-Midnight retail.
local issecretvalue = issecretvalue or function() return false end
local FormatRemainingDuration = FormatRemainingDuration or tostring

local OFFSET = 0.5

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
-- When remaining is a secret Duration Object (WoW Midnight) it cannot be compared,
-- so use FormatRemainingDuration which is designed for secret Duration Objects.
local function FormatTime(remaining)
    if issecretvalue(remaining) then
        return FormatRemainingDuration(remaining)
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

-- Expose FormatTime for use by the settings preview frame
CooldownAlert.FormatTime = FormatTime

-- Returns the display alpha (0.0–1.0) for the given elapsed time since the alert
-- triggered, or nil when the alert has fully expired (frame should be hidden).
-- Shared between the live display and the settings preview.
local function ComputeAlpha(timeSinceTrigger, holdTime, fadeOutTime)
    local totalDuration = holdTime + fadeOutTime
    if timeSinceTrigger >= totalDuration then
        return nil
    elseif fadeOutTime > 0 and timeSinceTrigger > holdTime then
        return 1 - (timeSinceTrigger - holdTime) / fadeOutTime
    else
        return 1
    end
end
CooldownAlert.ComputeAlpha = ComputeAlpha

-- Applies textContent and alpha to frame.text.  When alpha is nil the alert has
-- expired: the text alpha is reset to 1 (ready for the next trigger) and the
-- frame is hidden.  Shared between the live display and the settings preview.
function CooldownAlert.UpdateElement(frame, textContent, alpha)
    frame.text:SetText(textContent)
    if alpha == nil then
        frame.text:SetAlpha(1)
        frame:Hide()
    else
        frame.text:SetAlpha(alpha)
    end
end

-- Apply font and position settings from CooldownAlertDB to the display frame.
-- Also refreshes CooldownAlert.previewFrame if it has been created by the settings module.
function CooldownAlert.ApplySettings()
    local db = CooldownAlertDB
    if not db then return end
    local x     = db.posX    or 0
    local y     = db.posY    or 0
    local face  = db.fontFace  or CooldownAlertDB_Defaults.fontFace
    local size  = db.fontSize  or CooldownAlertDB_Defaults.fontSize
    local flags = db.fontFlags or CooldownAlertDB_Defaults.fontFlags

    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", x, y)
    display.text:SetFont(face, size, flags)

    if CooldownAlert.previewFrame then
        CooldownAlert.previewFrame:ClearAllPoints()
        CooldownAlert.previewFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        CooldownAlert.previewFrame.text:SetFont(face, size, flags)
    end
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

    -- Ignore GCD or very short cooldowns.  Secret durations cannot be compared,
    -- so skip the filter and treat them as real cooldowns worth showing.
    if not issecretvalue(duration) and (not duration or duration <= 1.5) then return end

    -- WoW Midnight secret values are an anti-cheat mechanism: certain cooldown
    -- start/duration values are intentionally hidden from addons.  Unlike UI taint,
    -- this has nothing to do with the secure-frame execution context -- arithmetic on
    -- a secret value always throws a Lua error.  When either value is secret, skip
    -- all arithmetic and show the alert immediately; UNIT_SPELLCAST_FAILED only fires
    -- when the spell is genuinely on cooldown so it is safe to do so.
    if issecretvalue(start) or issecretvalue(duration) then
        timeSinceTrigger = 0
        display:SetAlpha(1)
        display:Show()
        return
    end

    local timeLeft = start + duration - GetTime()

    if timeLeft <= OFFSET then return end

    timeSinceTrigger = 0
    display:SetAlpha(1)
    display:Show()
end)

display:SetScript("OnUpdate", function(self, elapsed)
    timeSinceTrigger = timeSinceTrigger + elapsed

    -- Compute the text to display for the active cooldown
    local textContent = ""
    if activeSpellID then
        -- On WoW Midnight, use the proper secrets API to detect and render secret cooldowns.
        -- C_Secrets is nil on Classic/TBC, so isSecret will be false and the normal path runs.
        local isSecret = C_Secrets and C_Secrets.ShouldSpellCooldownBeSecret and C_Secrets.ShouldSpellCooldownBeSecret(activeSpellID)
        if isSecret then
            local info = C_Spell.GetSpellCooldown(activeSpellID)
            if info and info.startTime ~= 0 then
                textContent = FormatRemainingDuration(info.duration)
            end
        else
            local start, duration = GetSpellCD(activeSpellID)
            if start and duration then
                textContent = FormatTime(math.max(0, start + duration - GetTime()))
            end
        end
    elseif activeItemID then
        local start, duration = GetItemCD(activeItemID)
        if start and duration then
            if issecretvalue(duration) then
                -- duration is a secret Duration Object; FormatRemainingDuration handles it safely.
                textContent = FormatRemainingDuration(duration)
            elseif issecretvalue(start) then
                -- start is secret but duration is a plain number; approximate using elapsed time.
                textContent = FormatTime(math.max(0, duration - timeSinceTrigger))
            else
                textContent = FormatTime(math.max(0, start + duration - GetTime()))
            end
        end
    end

    -- Fade out and hide via the shared helper
    local db          = CooldownAlertDB
    local holdTime    = db and db.holdTime    or CooldownAlertDB_Defaults.holdTime
    local fadeOutTime = db and db.fadeOutTime or CooldownAlertDB_Defaults.fadeOutTime
    CooldownAlert.UpdateElement(self, textContent, ComputeAlpha(timeSinceTrigger, holdTime, fadeOutTime))
end)
