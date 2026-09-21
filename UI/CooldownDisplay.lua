-- CooldownDisplay.lua
-- Native cooldown-frame display used on clients that support the secret-safe
-- duration-object cooldown APIs (see
-- CooldownAlert.SupportsCooldownDurationObjects). Uses
-- SetCooldownFromDurationObject so no arithmetic is ever performed on
-- (potentially secret) cooldown start/duration values.

CooldownAlert = CooldownAlert or {}
CooldownAlert.CooldownDisplay = {}

local cooldown = nil
local timeSinceTrigger = 0
local activeSpellID = nil

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

        if not activeSpellID then
            CooldownAlert.CooldownDisplay.Hide()
            return
        end

        -- Check if the cooldown duration object still has time remaining.
        if C_Spell and C_Spell.GetSpellCooldownDuration then
            local dur = C_Spell.GetSpellCooldownDuration(activeSpellID)
            if not dur then
                CooldownAlert.CooldownDisplay.Hide()
                return
            end
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

-- Show the display using the given spell's cooldown duration object.
function CooldownAlert.CooldownDisplay.Show(spellID)
    activeSpellID = spellID
    timeSinceTrigger = 0
    local frame = CooldownAlert.CooldownDisplay.Get()

    if spellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        local dur = C_Spell.GetSpellCooldownDuration(spellID)
        if dur then
            frame:SetCooldownFromDurationObject(dur)
        end
    end

    frame:SetAlpha(1)
    frame:Show()
end

-- Hide the display and clear its state.
function CooldownAlert.CooldownDisplay.Hide()
    if cooldown then
        cooldown:Hide()
    end
    activeSpellID = nil
    timeSinceTrigger = 0
end

-- Apply settings (position) to the cooldown frame.
function CooldownAlert.CooldownDisplay.ApplySettings()
    if not cooldown then return end
    local db = CooldownAlertDB
    if not db then return end

    local x = db.posX or 0
    local y = db.posY or 0

    cooldown:ClearAllPoints()
    cooldown:SetPoint("CENTER", UIParent, "CENTER", x, y)
end
