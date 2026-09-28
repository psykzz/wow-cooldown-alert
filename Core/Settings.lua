-- Settings.lua
-- Applies persisted CooldownAlertDB values to whichever display module
-- currently exists. Safe to call at any time -- each target module is
-- optional and simply skipped if it hasn't been created yet.

CooldownAlert = CooldownAlert or {}

local preview
local previewTimeLeft = 0

local function ShowFontPreview()
    if not preview then
        preview = CreateFrame("Frame", nil, UIParent)
        preview:SetSize(250, 50)
        preview.text = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        preview.text:SetPoint("CENTER")
        preview:SetScript("OnUpdate", function(self, elapsed)
            previewTimeLeft = previewTimeLeft - elapsed
            if previewTimeLeft <= 0 then
                self:Hide()
            else
                self.text:SetText(math.ceil(previewTimeLeft))
            end
        end)
    end

    local db = CooldownAlertDB
    preview:ClearAllPoints()
    preview:SetPoint("CENTER", UIParent, "CENTER", db.posX, db.posY)
    preview:SetScale(CooldownAlert.SupportsCooldownDurationObjects() and 2.5 or 1)
    preview.text:SetFont(db.fontFace, db.fontSize, db.fontFlags)
    preview.text:SetText("4")
    previewTimeLeft = 4
    preview:Show()
end

function CooldownAlert.ApplySettings()
    local db = CooldownAlertDB
    if not db then return end

    if CooldownAlert.TextDisplay and CooldownAlert.TextDisplay.ApplySettings then
        CooldownAlert.TextDisplay.ApplySettings()
    end

    if CooldownAlert.CooldownDisplay and CooldownAlert.CooldownDisplay.ApplySettings then
        CooldownAlert.CooldownDisplay.ApplySettings()
    end
end

function CooldownAlert.RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory("Cooldown Alert")
    local setting = Settings.RegisterProxySetting(
        category, "COOLDOWN_ALERT_FONT_SIZE", Settings.VarType.Number,
        "Font size", CooldownAlertDB_Defaults.fontSize,
        function() return CooldownAlertDB.fontSize end,
        function(value)
            CooldownAlertDB.fontSize = value
            CooldownAlert.ApplySettings()
            ShowFontPreview()
        end
    )
    local options = Settings.CreateSliderOptions(6, 48, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return tostring(value)
    end)
    Settings.CreateSlider(category, setting, options, "Change the alert font size and preview a four-second countdown.")
    Settings.RegisterAddOnCategory(category)
end
