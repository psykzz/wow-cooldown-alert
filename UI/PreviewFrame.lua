-- PreviewFrame.lua
-- Floating preview shown while the Cooldown Alert settings category is open,
-- so font/position/timing changes are visible immediately without needing to
-- fail a cast to see the real alert.

CooldownAlert = CooldownAlert or {}
CooldownAlert.PreviewFrame = {}

local PREVIEW_DURATION = 5

local frame = nil
local previewElapsed = 0

function CooldownAlert.PreviewFrame.Create()
    if frame then return frame end

    frame = CreateFrame("Frame", "CooldownAlertPreviewFrame", UIParent)
    frame:SetSize(250, 50)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("CENTER")
    frame.text:SetTextColor(1, 1, 1)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 6, -4)
    label:SetText("|cffaaaaaa[Preview]|r")

    -- Loops a countdown that mirrors the real alert's hold/fade behaviour so
    -- every setting change is visible immediately.
    frame:SetScript("OnUpdate", function(self, elapsed)
        previewElapsed = previewElapsed + elapsed
        local cycleTime = previewElapsed % PREVIEW_DURATION
        local remaining = PREVIEW_DURATION - cycleTime

        local db = CooldownAlertDB
        local holdTime = db.holdTime or CooldownAlertDB_Defaults.holdTime
        local fadeOutTime = db.fadeOutTime or CooldownAlertDB_Defaults.fadeOutTime
        -- Map remaining countdown time to a simulated elapsed-since-trigger
        -- value so ComputeFadeAlpha drives the preview fade identically to
        -- the real alert.
        local totalVisible = holdTime + fadeOutTime
        local simElapsed = math.max(0, totalVisible - remaining)

        -- "or 1": when totalVisible == 0, ComputeFadeAlpha returns nil; keep
        -- the preview text visible rather than hiding it.
        CooldownAlert.UpdateElement(self, CooldownAlert.FormatCountdown(remaining),
            PsyUtils.Math.ComputeFadeAlpha(simElapsed, holdTime, fadeOutTime) or 1)
    end)

    return frame
end

function CooldownAlert.PreviewFrame.Get()
    return frame or CooldownAlert.PreviewFrame.Create()
end

-- Restarts the countdown loop, e.g. after a setting changes, so the effect is
-- visible right away instead of partway through the previous cycle.
function CooldownAlert.PreviewFrame.ResetTimer()
    previewElapsed = 0
end

function CooldownAlert.PreviewFrame.Show()
    CooldownAlert.PreviewFrame.Get():Show()
end

function CooldownAlert.PreviewFrame.Hide()
    if frame then frame:Hide() end
end

-- Apply settings (position, font) to the preview frame.
function CooldownAlert.PreviewFrame.ApplySettings()
    if not frame then return end
    local db = CooldownAlertDB
    if not db then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.posX or 0, db.posY or 0)
    frame.text:SetFont(
        db.fontFace or CooldownAlertDB_Defaults.fontFace,
        db.fontSize or CooldownAlertDB_Defaults.fontSize,
        db.fontFlags or CooldownAlertDB_Defaults.fontFlags
    )
end
