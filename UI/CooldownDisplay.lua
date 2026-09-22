-- CooldownDisplay.lua
-- Native cooldown-frame display used on clients that support the secret-safe
-- duration-object cooldown APIs (see
-- CooldownAlert.SupportsCooldownDurationObjects). Uses
-- SetCooldownFromDurationObject so no arithmetic is ever performed on
-- (potentially secret) cooldown start/duration values.

CooldownAlert = CooldownAlert or {}
CooldownAlert.CooldownDisplay = {}

local cooldown = nil
local countdownFont = nil
local timeSinceTrigger = 0
local activeSpellID = nil
local activeItemID = nil

-- Returns the duration object for the currently active spell/item, or nil.
-- Prefers the item's cooldown (when resolvable), falling back to the
-- spell's if the item has none (e.g. it left the bags, or never had one).
local function GetActiveDuration()
    if activeItemID and C_Item and C_Item.GetItemCooldownDuration then
        local dur = C_Item.GetItemCooldownDuration(activeItemID)
        if dur then return dur end
    end
    if activeSpellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        return C_Spell.GetSpellCooldownDuration(activeSpellID)
    end
    return nil
end

-- Create the cooldown frame.
function CooldownAlert.CooldownDisplay.Create()
    if cooldown then return cooldown end

    cooldown = CreateFrame("Cooldown", "CooldownAlertCooldownFrame", UIParent, "CooldownFrameTemplate")
    cooldown:Hide()
    cooldown:SetSize(250, 50)
    cooldown:SetScale(2.5)
    cooldown:SetPoint("CENTER", 0, 0)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(false)
    cooldown:SetDrawBling(false)
    cooldown:SetCountdownMillisecondsThreshold(3)

    cooldown:SetScript("OnUpdate", function(self, elapsed)
        timeSinceTrigger = timeSinceTrigger + elapsed

        if not activeSpellID and not activeItemID then
            CooldownAlert.CooldownDisplay.Hide()
            return
        end

        -- Check if the cooldown duration object still has time remaining.
        if not GetActiveDuration() then
            CooldownAlert.CooldownDisplay.Hide()
            return
        end

        local db = CooldownAlertDB
        local holdTime = (db and db.holdTime) or CooldownAlertDB_Defaults.holdTime
        local fadeOutTime = (db and db.fadeOutTime) or CooldownAlertDB_Defaults.fadeOutTime
        local alpha = PsyUtils.Math.ComputeFadeAlpha(timeSinceTrigger, holdTime, fadeOutTime)
        if alpha == nil then
            CooldownAlert.CooldownDisplay.Hide()
        else
            self:SetAlpha(alpha)
        end
    end)

    return cooldown
end

-- Get the cooldown frame (creates it if needed).
function CooldownAlert.CooldownDisplay.Get()
    return cooldown or CooldownAlert.CooldownDisplay.Create()
end

-- Show the display using the given spell's (or, if `itemID` is provided and
-- resolvable, item's) cooldown duration object.
function CooldownAlert.CooldownDisplay.Show(spellID, itemID)
    activeSpellID = spellID
    activeItemID = itemID
    local dur = GetActiveDuration()
    if not dur then
        activeSpellID = nil
        activeItemID = nil
        return
    end

    timeSinceTrigger = 0
    local frame = CooldownAlert.CooldownDisplay.Get()

    frame:SetCooldownFromDurationObject(dur)
    frame:SetAlpha(1)
    frame:Show()
end

-- Hide the display and clear its state.
function CooldownAlert.CooldownDisplay.Hide()
    if cooldown then
        cooldown:Hide()
    end
    activeSpellID = nil
    activeItemID = nil
    timeSinceTrigger = 0
end

-- Apply settings (position, and countdown font where supported) to the
-- cooldown frame. There is no equivalent for `textFormat`: the native
-- Cooldown widget renders its own countdown text from the (potentially
-- secret) duration object, so a custom decimal/auto format can't be computed
-- without secret-value arithmetic -- that's the whole reason this display
-- exists instead of always using TextDisplay.
function CooldownAlert.CooldownDisplay.ApplySettings()
    if not cooldown then return end
    local db = CooldownAlertDB
    if not db then return end

    local x = db.posX or 0
    local y = db.posY or 0

    cooldown:ClearAllPoints()
    cooldown:SetPoint("CENTER", UIParent, "CENTER", x, y)

    -- Best-effort: SetCountdownFont isn't available on every client. Skip
    -- quietly where it isn't rather than erroring.
    if cooldown.SetCountdownFont and CreateFont then
        local face = db.fontFace or CooldownAlertDB_Defaults.fontFace
        local size = db.fontSize or CooldownAlertDB_Defaults.fontSize
        local flags = db.fontFlags or CooldownAlertDB_Defaults.fontFlags

        countdownFont = countdownFont or CreateFont("CooldownAlertCountdownFont")
        countdownFont:SetFont(face, size, flags)
        cooldown:SetCountdownFont("CooldownAlertCountdownFont")
    end
end
