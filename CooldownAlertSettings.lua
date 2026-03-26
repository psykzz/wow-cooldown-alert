-- CooldownAlertSettings.lua
-- Settings panel and slash commands for Cooldown Alert.
-- Uses the modern Settings API on retail (Dragonflight+); slash commands work on all versions.

local ADDON_NAME = "CooldownAlert"

local FONTS = {
    { name = "FrizQuadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Morpheus",     path = "Fonts\\MORPHEUS.ttf" },
    { name = "Skurri",       path = "Fonts\\skurri.ttf"   },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF"   },
}

local FONT_FLAGS = {
    { name = "Outline",       value = "OUTLINE"      },
    { name = "Thick Outline", value = "THICKOUTLINE" },
    { name = "None",          value = ""             },
}

local TEXT_FORMATS = {
    { name = "Auto (3s threshold)", value = "auto3"   },
    { name = "Auto (1s threshold)", value = "auto1"   },
    { name = "Always decimal",      value = "decimal" },
    { name = "Always integer",      value = "integer" },
}

-- Quick-lookup tables used by slash commands
local FONT_PATH_BY_NAME = {}
for _, f in ipairs(FONTS) do FONT_PATH_BY_NAME[f.name:lower()] = f.path end
-- Short alias for "Arial Narrow"
FONT_PATH_BY_NAME["arial"] = FONT_PATH_BY_NAME["arial narrow"]

local FONT_FLAG_BY_NAME = { outline = "OUTLINE", thick = "THICKOUTLINE", none = "" }

local TEXT_FORMAT_SET = {}
for _, f in ipairs(TEXT_FORMATS) do TEXT_FORMAT_SET[f.value] = true end

-- ── Retail Settings API (Dragonflight / The War Within) ──────────────────────

local function InitRetailSettings()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return false
    end

    local category = Settings.RegisterVerticalLayoutCategory("Cooldown Alert")

    -- Helper: register a proxy setting backed by CooldownAlertDB[varKey]
    local function Proxy(varKey, varType, name, getValue, setValue)
        return Settings.RegisterProxySetting(
            category,
            "CooldownAlert_" .. varKey,
            varType,
            name,
            CooldownAlertDB_Defaults[varKey],
            getValue,
            setValue
        )
    end

    -- Hold Time (0 – 2 s, step 0.05)
    local holdTimeSetting = Proxy(
        "holdTime", Settings.VarType.Number, "Hold Time",
        function()    return CooldownAlertDB.holdTime end,
        function(_, v) CooldownAlertDB.holdTime = v   end
    )
    local holdTimeOpts = Settings.CreateSliderOptions(0, 2, 0.05)
    holdTimeOpts:SetLabelFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(v) return string.format("%.2fs", v) end
    )
    Settings.CreateSlider(category, holdTimeSetting, holdTimeOpts,
        "How long the alert is shown before fading out")

    -- Fade Out Time (0 – 3 s, step 0.1)
    local fadeOutSetting = Proxy(
        "fadeOutTime", Settings.VarType.Number, "Fade Out Time",
        function()    return CooldownAlertDB.fadeOutTime end,
        function(_, v) CooldownAlertDB.fadeOutTime = v   end
    )
    local fadeOutOpts = Settings.CreateSliderOptions(0, 3, 0.1)
    fadeOutOpts:SetLabelFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(v) return string.format("%.1fs", v) end
    )
    Settings.CreateSlider(category, fadeOutSetting, fadeOutOpts,
        "Duration of the fade-out animation")

    -- Font Size (10 – 72, step 1)
    local fontSizeSetting = Proxy(
        "fontSize", Settings.VarType.Number, "Font Size",
        function()    return CooldownAlertDB.fontSize end,
        function(_, v)
            if v == nil then return end
            CooldownAlertDB.fontSize = math.floor(v)
            CooldownAlert.ApplySettings()
        end
    )
    local fontSizeOpts = Settings.CreateSliderOptions(10, 72, 1)
    fontSizeOpts:SetLabelFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(v) return v ~= nil and tostring(math.floor(v)) or "" end
    )
    Settings.CreateSlider(category, fontSizeSetting, fontSizeOpts,
        "Size of the cooldown countdown text")

    -- Font Face (dropdown)
    local fontFaceSetting = Proxy(
        "fontFace", Settings.VarType.String, "Font",
        function()    return CooldownAlertDB.fontFace end,
        function(_, v)
            CooldownAlertDB.fontFace = v
            CooldownAlert.ApplySettings()
        end
    )
    local function GetFontOptions()
        local container = Settings.CreateControlTextContainer()
        for _, f in ipairs(FONTS) do container:Add(f.path, f.name) end
        return container:GetData()
    end
    Settings.CreateDropdown(category, fontFaceSetting, GetFontOptions,
        "Typeface used for the cooldown text")

    -- Font Style (dropdown)
    local fontFlagsSetting = Proxy(
        "fontFlags", Settings.VarType.String, "Font Style",
        function()    return CooldownAlertDB.fontFlags end,
        function(_, v)
            CooldownAlertDB.fontFlags = v
            CooldownAlert.ApplySettings()
        end
    )
    local function GetFontFlagOptions()
        local container = Settings.CreateControlTextContainer()
        for _, f in ipairs(FONT_FLAGS) do container:Add(f.value, f.name) end
        return container:GetData()
    end
    Settings.CreateDropdown(category, fontFlagsSetting, GetFontFlagOptions,
        "Rendering style applied to the font")

    -- Horizontal Position (-500 – 500, step 1)
    local posXSetting = Proxy(
        "posX", Settings.VarType.Number, "Horizontal Position",
        function()    return CooldownAlertDB.posX end,
        function(_, v)
            if v == nil then return end
            CooldownAlertDB.posX = math.floor(v)
            CooldownAlert.ApplySettings()
        end
    )
    local posXOpts = Settings.CreateSliderOptions(-500, 500, 1)
    posXOpts:SetLabelFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(v) return v ~= nil and tostring(math.floor(v)) or "" end
    )
    Settings.CreateSlider(category, posXSetting, posXOpts,
        "Horizontal offset from the centre of the screen")

    -- Vertical Position (-500 – 500, step 1)
    local posYSetting = Proxy(
        "posY", Settings.VarType.Number, "Vertical Position",
        function()    return CooldownAlertDB.posY end,
        function(_, v)
            if v == nil then return end
            CooldownAlertDB.posY = math.floor(v)
            CooldownAlert.ApplySettings()
        end
    )
    local posYOpts = Settings.CreateSliderOptions(-500, 500, 1)
    posYOpts:SetLabelFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(v) return v ~= nil and tostring(math.floor(v)) or "" end
    )
    Settings.CreateSlider(category, posYSetting, posYOpts,
        "Vertical offset from the centre of the screen")

    -- Text Format (dropdown)
    local textFormatSetting = Proxy(
        "textFormat", Settings.VarType.String, "Text Format",
        function()    return CooldownAlertDB.textFormat end,
        function(_, v) CooldownAlertDB.textFormat = v end
    )
    local function GetTextFormatOptions()
        local container = Settings.CreateControlTextContainer()
        for _, f in ipairs(TEXT_FORMATS) do container:Add(f.value, f.name) end
        return container:GetData()
    end
    Settings.CreateDropdown(category, textFormatSetting, GetTextFormatOptions,
        "How the remaining cooldown time is displayed")

    Settings.RegisterAddOnCategory(category)
    return true
end

-- ── Slash commands (all versions) ───────────────────────────────────────────

local function RegisterSlashCommands()
    SLASH_COOLDOWNALERT1 = "/cda"
    SLASH_COOLDOWNALERT2 = "/cooldownalert"

    SlashCmdList["COOLDOWNALERT"] = function(msg)
        local cmd, arg1, arg2 = msg:match("^(%S*)%s*(%S*)%s*(%S*)")
        cmd = cmd:lower()

        if cmd == "" then
            local db = CooldownAlertDB
            local flagName = db.fontFlags == "" and "None" or db.fontFlags
            print("|cff00ff00Cooldown Alert – current settings:|r")
            print(string.format("  Hold Time:   %.2fs  |  Fade Out Time: %.1fs", db.holdTime, db.fadeOutTime))
            print(string.format("  Font Size:   %d     |  Font Style:    %s", db.fontSize, flagName))
            print(string.format("  Font:        %s", db.fontFace))
            print(string.format("  Position:    x=%d, y=%d", db.posX, db.posY))
            print(string.format("  Text Format: %s", db.textFormat))
            print("Type |cffffd700/cda help|r for a list of commands.")

        elseif cmd == "help" then
            print("|cff00ff00Cooldown Alert commands:|r")
            print("  /cda hold <0-2>        – hold time in seconds")
            print("  /cda fade <0-3>        – fade-out duration in seconds")
            print("  /cda fontsize <10-72>  – font size")
            print("  /cda font <name>       – frizquadrata | morpheus | skurri | arial")
            print("  /cda style <style>     – outline | thick | none")
            print("  /cda pos <x> <y>       – offset from screen centre")
            print("  /cda format <preset>   – auto3 | auto1 | decimal | integer")
            print("  /cda reset             – restore all defaults")

        elseif cmd == "hold" then
            local val = tonumber(arg1)
            if val and val >= 0 and val <= 2 then
                CooldownAlertDB.holdTime = val
                print(string.format("Cooldown Alert: hold time set to %.2fs", val))
            else
                print("Cooldown Alert: /cda hold <0-2>")
            end

        elseif cmd == "fade" then
            local val = tonumber(arg1)
            if val and val >= 0 and val <= 3 then
                CooldownAlertDB.fadeOutTime = val
                print(string.format("Cooldown Alert: fade-out time set to %.1fs", val))
            else
                print("Cooldown Alert: /cda fade <0-3>")
            end

        elseif cmd == "fontsize" then
            local val = tonumber(arg1)
            if val and val >= 10 and val <= 72 then
                CooldownAlertDB.fontSize = math.floor(val)
                CooldownAlert.ApplySettings()
                print("Cooldown Alert: font size set to " .. CooldownAlertDB.fontSize)
            else
                print("Cooldown Alert: /cda fontsize <10-72>")
            end

        elseif cmd == "font" then
            local path = FONT_PATH_BY_NAME[arg1:lower()]
            if path then
                CooldownAlertDB.fontFace = path
                CooldownAlert.ApplySettings()
                print("Cooldown Alert: font set to " .. arg1)
            else
                print("Cooldown Alert: unknown font – try frizquadrata, morpheus, skurri, arial")
            end

        elseif cmd == "style" then
            local val = FONT_FLAG_BY_NAME[arg1:lower()]
            if val ~= nil then
                CooldownAlertDB.fontFlags = val
                CooldownAlert.ApplySettings()
                print("Cooldown Alert: font style set to " .. (val == "" and "None" or val))
            else
                print("Cooldown Alert: /cda style outline | thick | none")
            end

        elseif cmd == "pos" then
            local x, y = tonumber(arg1), tonumber(arg2)
            if x and y then
                CooldownAlertDB.posX = x
                CooldownAlertDB.posY = y
                CooldownAlert.ApplySettings()
                print(string.format("Cooldown Alert: position set to x=%d, y=%d", x, y))
            else
                print("Cooldown Alert: /cda pos <x> <y>")
            end

        elseif cmd == "format" then
            if TEXT_FORMAT_SET[arg1] then
                CooldownAlertDB.textFormat = arg1
                print("Cooldown Alert: text format set to " .. arg1)
            else
                print("Cooldown Alert: /cda format auto3 | auto1 | decimal | integer")
            end

        elseif cmd == "reset" then
            for k, v in pairs(CooldownAlertDB_Defaults) do
                CooldownAlertDB[k] = v
            end
            CooldownAlert.ApplySettings()
            print("Cooldown Alert: all settings reset to defaults.")

        else
            print("Cooldown Alert: unknown command '" .. cmd .. "' – type /cda help")
        end
    end
end

-- ── Bootstrap ────────────────────────────────────────────────────────────────

local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then return end
    -- CooldownAlert.lua's ADDON_LOADED handler runs first (registered earlier),
    -- so CooldownAlertDB is already initialised here.
    RegisterSlashCommands()
    InitRetailSettings()
    self:UnregisterEvent("ADDON_LOADED")
end)
