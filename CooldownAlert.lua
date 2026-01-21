
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

local HOLD_TIME = 0.3
local FADE_OUT_TIME = 0.7
local TOTAL_DURATION = FADE_OUT_TIME + HOLD_TIME
local OFFSET = 0.5

local item_spells = {}
local activeSpellID = nil
local activeItemID = nil
local timeSinceTrigger = 0

local display = CreateFrame("Frame", nil, UIParent)
display:SetSize(250, 50)
display:SetPoint("CENTER", 0, 0)
display:Hide()

display.text = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
display.text:SetPoint("CENTER")
display.text:SetTextColor(1, 1, 1) -- white
display.text:SetFont(display.text:GetFont(), 28, "OUTLINE")

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

    --handle items
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

    -- ignore gcd or short cds
    if not duration or duration <= 1.5 then return end
    local timeLeft = start + duration - GetTime()

    if timeLeft > OFFSET then
        timeSinceTrigger = 0
        display:SetAlpha(1)
        display:Show()
    end
end)

display:SetScript("OnUpdate", function(self, elapsed)
    timeSinceTrigger = timeSinceTrigger + elapsed

    -- Update remaining time
    local start, duration
    if activeItemID then
        start, duration = GetItemCD(activeItemID)
    elseif activeSpellID then
        start, duration = GetSpellCD(activeSpellID)
    end

    if start and duration then
        local currentRemaining = math.max(0, start + duration - GetTime())
        if currentRemaining > 3 then
            self.text:SetText(string.format("%.0fs", currentRemaining))
        else 

            self.text:SetText(string.format("%.1fs", currentRemaining))
        end
    end

    -- Fade out loop
    if timeSinceTrigger > TOTAL_DURATION then
        self:Hide()
    elseif timeSinceTrigger > HOLD_TIME then
        local fadeProgress = (timeSinceTrigger - HOLD_TIME) / FADE_OUT_TIME
        self:SetAlpha(1 - fadeProgress)
    end
end)