-- TextDisplay.lua
-- Text-based cooldown display, used on clients that don't support the
-- secret-safe duration-object cooldown APIs (see
-- CooldownAlert.SupportsCooldownDurationObjects). Shows formatted countdown
-- text with a fade-out animation.

CooldownAlert = CooldownAlert or {}
CooldownAlert.TextDisplay = {}

local display = nil
local timeSinceTrigger = 0
local activeSpellID = nil
local activeItemID = nil

--- Formats `remainingSeconds` using the saved textFormat preset.
local function FormatCountdown(remainingSeconds)
    local preset = (CooldownAlertDB and CooldownAlertDB.textFormat) or CooldownAlertDB_Defaults.textFormat
    return PsyUtils.Format.Countdown(remainingSeconds, preset)
end

--- Applies textContent and alpha to frame.text. When alpha is nil the alert
--- has expired: the text alpha is reset to 1 (ready for the next trigger)
--- and the frame is hidden.
local function UpdateElement(frame, textContent, alpha)
    frame.text:SetText(textContent)
    if alpha == nil then
        frame.text:SetAlpha(1)
        frame:Hide()
    else
        frame.text:SetAlpha(alpha)
    end
end

-- Create the text display frame.
function CooldownAlert.TextDisplay.Create()
    if display then return display end

    display = CreateFrame("Frame", "CooldownAlertFrame", UIParent)
    display:SetSize(250, 50)
    display:SetPoint("CENTER", 0, 0)
    display:Hide()

    display.text = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.text:SetPoint("CENTER")
    display.text:SetTextColor(1, 1, 1)
    display.text:SetFont(display.text:GetFont(), 28, "OUTLINE")

    display:SetScript("OnUpdate", function(self, elapsed)
        timeSinceTrigger = timeSinceTrigger + elapsed

        if not activeSpellID and not activeItemID then
            CooldownAlert.TextDisplay.Hide()
            return
        end

        -- Prefer the item's cooldown (when resolvable), falling back to the
        -- spell's if the item has none (e.g. it left the bags).
        local startTime, duration, isSecret = 0, 0, false
        if activeItemID then
            startTime, duration, isSecret = CooldownAlert.GetItemCD(activeItemID)
        end
        if not isSecret and duration == 0 and activeSpellID then
            startTime, duration, isSecret = CooldownAlert.GetSpellCD(activeSpellID)
        end

        local remaining = nil
        if isSecret then
            -- Can't safely read a secret cooldown's remaining time (see
            -- AGENTS.md). Show a generic indicator and let the hold/fade
            -- timer -- based on time since trigger, not remaining cooldown
            -- -- decide when to hide, instead of treating it as "no
            -- cooldown".
            remaining = nil
        elseif duration == 0 then
            CooldownAlert.TextDisplay.Hide()
            return
        else
            remaining = startTime + duration - GetTime()
            if remaining <= 0 then
                CooldownAlert.TextDisplay.Hide()
                return
            end
        end

        local db = CooldownAlertDB
        local holdTime = (db and db.holdTime) or CooldownAlertDB_Defaults.holdTime
        local fadeOutTime = (db and db.fadeOutTime) or CooldownAlertDB_Defaults.fadeOutTime
        local alpha = PsyUtils.Math.ComputeFadeAlpha(timeSinceTrigger, holdTime, fadeOutTime)
        if alpha == nil then
            CooldownAlert.TextDisplay.Hide()
            return
        end

        local textContent = remaining and FormatCountdown(remaining) or "..."
        UpdateElement(self, textContent, alpha)
    end)

    return display
end

-- Get the display frame (creates it if needed).
function CooldownAlert.TextDisplay.Get()
    return display or CooldownAlert.TextDisplay.Create()
end

-- Show the display for the given spell (or, if `itemID` is provided and
-- resolvable, item) and reset the trigger timer.
function CooldownAlert.TextDisplay.Show(spellID, itemID)
    activeSpellID = spellID
    activeItemID = itemID
    timeSinceTrigger = 0
    local frame = CooldownAlert.TextDisplay.Get()
    frame:SetAlpha(1)
    frame:Show()
end

-- Hide the display and clear its state.
function CooldownAlert.TextDisplay.Hide()
    if display then
        display:Hide()
    end
    activeSpellID = nil
    activeItemID = nil
    timeSinceTrigger = 0
end

-- Apply settings (position, font) to the display frame.
function CooldownAlert.TextDisplay.ApplySettings()
    if not display then return end
    local db = CooldownAlertDB
    if not db then return end

    local x = db.posX or 0
    local y = db.posY or 0
    local face = db.fontFace or CooldownAlertDB_Defaults.fontFace
    local size = db.fontSize or CooldownAlertDB_Defaults.fontSize
    local flags = db.fontFlags or CooldownAlertDB_Defaults.fontFlags

    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", x, y)
    display.text:SetFont(face, size, flags)
end
