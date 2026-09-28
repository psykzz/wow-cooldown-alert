import unittest
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]

WOW_API = """
UIParent = {}
MinimalSliderWithSteppersMixin = {Label={Right="right"}}
Settings = {VarType={Number="number"}}
function Settings.RegisterVerticalLayoutCategory(name) return name end
function Settings.RegisterProxySetting(category, id, kind, name, default, getter, setter)
    Settings.setting = {get=getter, set=setter, default=default}
    return Settings.setting
end
function Settings.CreateSliderOptions(minimum, maximum, step)
    local options = {min=minimum, max=maximum, step=step}
    function options:SetLabelFormatter(position, fn) self.format=fn end
    return options
end
function Settings.CreateSlider(category, setting, options, tooltip)
    Settings.slider = options
end
function Settings.RegisterAddOnCategory(category) Settings.category = category end
function CreateFrame(kind)
    local frame = {visible=false}
    function frame:SetSize(width, height) end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint() end
        function text:SetFont(face, size, flags)
            self.face, self.size, self.flags = face, size, flags
        end
        function text:SetText(value) self.value = value end
        return text
    end
    function frame:SetScript(event, fn) self[event] = fn end
    function frame:ClearAllPoints() end
    function frame:SetPoint(anchor, parent, relative, x, y) self.x, self.y = x, y end
    function frame:SetScale(scale) self.scale = scale end
    function frame:Show() self.visible = true end
    function frame:Hide() self.visible = false end
    function frame:RegisterEvent(event) end
    function frame:UnregisterEvent(event) end
    if kind == "Frame" then lastFrame = frame end
    return frame
end
PsyUtils = {SavedVariables={ApplyDefaults=function(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
end}}
CooldownAlert = {ADDON_NAME="CooldownAlert"}
CooldownAlert.TextDisplay = {
    Create=function() end,
    ApplySettings=function() textApplies = (textApplies or 0) + 1 end,
}
CooldownAlert.CooldownDisplay = {
    Create=function() end,
    ApplySettings=function() cooldownApplies = (cooldownApplies or 0) + 1 end,
}
CooldownAlert.SupportsCooldownDurationObjects = function() return native end
"""


class FontSettingsTests(unittest.TestCase):
    def load(self, native, saved_size):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(WOW_API)
        lua.globals().native = native
        lua.globals().CooldownAlertDB = lua.table_from({"fontSize": saved_size})
        for path in ("Core/Constants.lua", "Core/Settings.lua", "Core/Bootstrap.lua"):
            lua.execute((ROOT / path).read_text())
        lua.execute('lastFrame.OnEvent(lastFrame, "ADDON_LOADED", "CooldownAlert")')
        return lua

    def test_native_slider_saves_and_previews_four_seconds(self):
        lua = self.load(True, 34)
        lua.execute("""
            assert(Settings.category == "Cooldown Alert")
            assert(Settings.slider.min == 12 and Settings.slider.max == 48)
            assert(Settings.slider.step == 1 and Settings.setting.get() == 34)
            assert(Settings.setting.default == 28)
            Settings.setting.set(40)
            assert(CooldownAlertDB.fontSize == 40)
            assert(textApplies == 2 and cooldownApplies == 2)
            assert(lastFrame.visible and lastFrame.text.value == "4")
            assert(lastFrame.text.size == 40 and lastFrame.scale == 2.5)
            lastFrame.OnUpdate(lastFrame, 1.1)
            assert(lastFrame.text.value == 3)
            Settings.setting.set(32)
            assert(lastFrame.text.value == "4" and lastFrame.text.size == 32)
            lastFrame.OnUpdate(lastFrame, 3.9)
            assert(lastFrame.visible and lastFrame.text.value == 1)
            lastFrame.OnUpdate(lastFrame, 0.2)
            assert(not lastFrame.visible)
        """)

    def test_text_renderer_uses_its_own_scale(self):
        lua = self.load(False, 28)
        lua.execute("""
            Settings.setting.set(18)
            assert(CooldownAlertDB.fontSize == 18)
            assert(lastFrame.text.size == 18 and lastFrame.scale == 1)
        """)


if __name__ == "__main__":
    unittest.main()
