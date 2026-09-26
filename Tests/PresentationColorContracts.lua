-- lua54 Tests/PresentationColorContracts.lua
-- Exercise the real placeholder boundary and Options checkbox styling.
local ns = {}
assert(loadfile("GUI/GUISkin.lua"))("FocalPoint", ns)
assert(loadfile("Engine/UnitFrame/Shared/UnitFrameDemoEnvironment.lua"))("FocalPoint", ns)
local skins = ns.GUI.Skins
local getColors = ns.UnitFrameDemoEnvironment.GetPlaceholderColors
local function Equal(actual, expected)
    for key, value in pairs(expected) do
        assert(actual[key] == value, key .. ": " .. tostring(actual[key]) .. " ~= " .. tostring(value))
    end
end
local defaults = getColors()
Equal(defaults, { barR=0.29, barG=0.25, barB=0.19, barA=0.62, disabledBarA=0.18,
    bgR=0.045, bgG=0.039, bgB=0.034, bgA=0.30, disabledBgA=0.10 })
ns.GUI = nil
Equal(getColors(), defaults)
ns.GUI = { Skins = skins }
local original = skins.GetCanvasInteractionPresentation
for _, presentation in ipairs({ {}, {placeholder={}}, {placeholder={unitFrame={}}} }) do
    skins.GetCanvasInteractionPresentation = function() return presentation end
    Equal(getColors(), defaults)
end
skins.GetCanvasInteractionPresentation = function()
    return {placeholder={unitFrame={bar={color={[1]=0, [3]=0.8}, enabledAlpha=0},
        background={color={[2]=0.2}, disabledAlpha=0}}}}
end
Equal(getColors(), {barR=0, barG=0.25, barB=0.8, barA=0, disabledBarA=0.18,
    bgR=0.045, bgG=0.2, bgB=0.034, bgA=0.30, disabledBgA=0})
skins.GetCanvasInteractionPresentation = original
Equal(getColors(), defaults)

LibStub = function() return {} end
local options = assert(loadfile("GUI/Editor/EditorOptionsDialog.lua"))("FocalPoint", ns)
local function Closure(fn, target, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for index=1,100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == target then return value end
        if type(value) == "function" then
            local found = Closure(value, target, seen)
            if found then return found end
        end
    end
end
local style = assert(Closure(options.Open, "StyleCheckBox"))
local function Region()
    return {
        SetAtlas=function() end, SetSize=function() end, SetBlendMode=function() end,
        ClearAllPoints=function() end, SetPoint=function() end, SetJustifyH=function() end,
        SetTextColor=function(self, ...) self.color={...} end,
    }
end
local widget = {frame={}, checkbg=Region(), check=Region(), highlight=Region(), text=Region()}
function widget:GetValue() return self.value end
for _, checked in ipairs({false, true}) do
    widget.value = checked
    style(widget, true)
    Equal(widget.text.color, {0.494, 0.459, 0.392, 1})
    style(widget, false)
    Equal(widget.text.color, checked and {0.910, 0.757, 0.400, 0.85} or {0.722, 0.678, 0.584, 1})
end
-- Both supported data forms must preserve zero channels and explicit alpha.
for _, color in ipairs({{0, 0.2, 0.3, 0}, {r=0, g=0.2, b=0.3, a=0}}) do
    skins.GetTextColor = function() return color end
    style(widget, true)
    Equal(widget.text.color, {0, 0.2, 0.3, 0})
end
print("PASS: complete/absent/partial placeholder palettes, zero channels/alpha, checkbox on/off/disabled and both RGB forms")
