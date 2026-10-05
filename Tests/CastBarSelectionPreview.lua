local function Load(path, ns)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    assert(load(source, "@" .. path))("FocalPoint", ns)
end

local selectedObject
local now = 1.5
local liveCast = false

local ns = {
    guiTestModeEnabled = false,
    framesUnlocked = true,
    UnitFramePresence = {},
    UnitFrameRuntimeActivity = {},
    UnitFramePreview = {},
    UnitFrameUtils = {
        UnpackColor = function(color, fallback)
            color = color or fallback
            return color[1], color[2], color[3], color[4]
        end,
        ResolveInterruptState = function(notInterruptible)
            return notInterruptible and "UNINTERRUPTIBLE" or "INTERRUPTIBLE"
        end,
    },
    TextElementRoles = {},
    GUI = {
        Editor = {
            ObjectSelection = {
                GetSelectedObject = function()
                    return selectedObject
                end,
            },
            InteractionMode = {
                IsTextMode = function()
                    return false
                end,
            },
        },
    },
}

function ns:IsEditorActive()
    return self.editorActive == true
end

ns.UnitFrameRuntimeActivity.ShouldRunComponent = function()
    return true
end
ns.UnitFramePresence.IsPreviewModeEnabled = function()
    return ns.guiTestModeEnabled == true
end

Load("Engine/UnitFrame/Shared/EditorVisualPolicy.lua", ns)
Load("Engine/UnitFrame/Bars/UnitFrameCastBar.lua", ns)

GetTime = function()
    return now
end
UnitCastingInfo = function(unit)
    if not liveCast then
        return nil
    end
    return "Live Cast", nil, 98765, 1000, 3000, nil, nil, false, nil, 42
end
UnitChannelInfo = function()
    return nil
end

local function Noop() end

local function MakeTexture()
    local texture = { shown = false }
    function texture:SetTexture(value) self.texture = value end
    function texture:SetVertexColor(...) self.vertexColor = { ... } end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:ClearAllPoints() self.points = {} end
    function texture:SetPoint(...) self.point = { ... } end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    return texture
end

local function MakeCastBar()
    local cast = {
        bg = MakeTexture(),
        icon = MakeTexture(),
        shown = false,
        isCasting = false,
        isPreview = false,
    }
    function cast:ClearAllPoints() self.points = {} end
    function cast:SetFrameStrata(value) self.frameStrata = value end
    function cast:SetFrameLevel(value) self.frameLevel = value end
    function cast:SetStatusBarTexture(value) self.statusTexture = value end
    function cast:SetStatusBarColor(...) self.statusColor = { ... } end
    function cast:SetAlpha(value) self.alpha = value end
    function cast:SetPoint(...) self.point = { ... } end
    function cast:SetWidth(value) self.width = value end
    function cast:SetHeight(value) self.height = value end
    function cast:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function cast:SetValue(value) self.value = value end
    function cast:Show() self.shown = true end
    function cast:Hide() self.shown = false end
    return cast
end

local function MakeFrame(config)
    local castBar = MakeCastBar()
    local frame = {
        _fpUnit = "target",
        config = config,
        Elements = { CastBar = castBar },
        Texts = {},
        frameStrata = "MEDIUM",
        frameLevel = 10,
    }
    function frame:GetFrameStrata() return self.frameStrata end
    function frame:GetFrameLevel() return self.frameLevel end
    return frame
end

local function Options(config)
    return {
        width = 220,
        borderInset = 1,
        castBarPoint = "BOTTOMLEFT",
        castBarRelativePoint = "TOPLEFT",
        castBarOffsetX = 0,
        castBarOffsetY = 4,
        castBarHeight = 20,
        showCastBar = config.showCastBar ~= false,
        showCastBarIcon = config.showCastBarIcon ~= false,
        castTexture = "configured-texture",
        castBarColor = { 1, 0.7, 0.2, 1 },
        castBarInterruptibleColor = { 0.6, 0.6, 0.6, 1 },
    }
end

local function SelectCastBar()
    selectedObject = { kind = "bar", unit = "target", objectKey = "CastBar" }
end

local function SelectOtherObject()
    selectedObject = { kind = "bar", unit = "target", objectKey = "HealthBar" }
end

local function AssertPreview(frame, context)
    local cast = frame.Elements.CastBar
    assert(cast.shown, context .. ": cast bar hidden")
    assert(cast.isTextEditPreview == true, context .. ": static preview missing")
    assert(cast.value == 1.25, context .. ": preview progress missing")
    assert(cast.statusTexture == "configured-texture", context .. ": configured texture missing")
    assert(cast.bg.texture == "configured-texture", context .. ": background texture missing")
    assert(cast.icon.shown and cast.icon.texture == 136048, context .. ": preview icon missing")
end

ns.editorActive = true
SelectCastBar()
local frame = MakeFrame({ showCastBar = true, showCastBarIcon = true })
local state = ns.EditorVisualPolicy.Resolve(frame, "CastBar", { enabled = true, hasLiveData = false })
assert(state == "selection-simulated")
assert(ns.UnitFrameCastBar.ShouldRepresentInEditor(frame))
ns.UnitFrameCastBar.ApplyLayout(frame, Options(frame.config))
AssertPreview(frame, "selection-simulated")

selectedObject = nil
frame = MakeFrame({ showCastBar = true, showCastBarIcon = true })
state = ns.EditorVisualPolicy.Resolve(frame, "CastBar", { enabled = true, hasLiveData = false })
assert(state == "editor-simulated")
assert(ns.UnitFrameCastBar.ShouldRepresentInEditor(frame))
ns.UnitFrameCastBar.ApplyLayout(frame, Options(frame.config))
AssertPreview(frame, "editor-simulated")

ns.guiTestModeEnabled = true
SelectCastBar()
frame = MakeFrame({ showCastBar = true, showCastBarIcon = true })
assert(ns.EditorVisualPolicy.Resolve(frame, "CastBar", { enabled = true, hasLiveData = false }) == "detailed-simulated")
assert(not ns.UnitFrameCastBar.ShouldRepresentInEditor(frame))
ns.UnitFrameCastBar.StartPreview(frame)
local detailedValue = frame.Elements.CastBar.value
assert(frame.Elements.CastBar.isPreview and frame.Elements.CastBar.shown)
ns.UnitFrameCastBar.ApplyLayout(frame, Options(frame.config))
assert(frame.Elements.CastBar.isPreview and frame.Elements.CastBar.value == detailedValue,
    "detailed-simulated: static selection preview overwrote running preview")

ns.guiTestModeEnabled = false
ns.editorActive = true
liveCast = true
frame = MakeFrame({ showCastBar = true, showCastBarIcon = true })
SelectCastBar()
ns.UnitFrameCastBar.Start(frame)
assert(frame.Elements.CastBar.isCasting and not frame.Elements.CastBar.isPreview,
    "live cast: live state missing")
assert(frame.Elements.CastBar.icon.shown and frame.Elements.CastBar.icon.texture == 98765,
    "live cast: live icon overwritten")
liveCast = false

ns.editorActive = true
SelectCastBar()
frame = MakeFrame({ showCastBar = true, showCastBarIcon = false })
ns.UnitFrameCastBar.ApplyLayout(frame, Options(frame.config))
assert(frame.Elements.CastBar.shown and not frame.Elements.CastBar.icon.shown,
    "icon off: preview icon visible")

frame = MakeFrame({ showCastBar = false, showCastBarIcon = true })
ns.UnitFrameCastBar.ApplyLayout(frame, Options(frame.config))
assert(not frame.Elements.CastBar.shown, "show=false: phantom CastBar visible")

SelectCastBar()
frame = MakeFrame({ showCastBar = true, showCastBarIcon = true })
ns.UnitFrameCastBar.ApplyTextEditPreview(frame)
SelectOtherObject()
ns.UnitFrameCastBar.Stop(frame)
assert(frame.Elements.CastBar.shown and frame.Elements.CastBar.isTextEditPreview == true,
    "selection change: editor preview was lost")
SelectCastBar()
assert(ns.UnitFrameCastBar.ApplyTextEditPreview(frame), "selection return: preview not restored")

local absent = { config = { showCastBar = true }, Elements = {}, _fpUnit = "target" }
assert(not ns.UnitFrameCastBar.ApplyTextEditPreview(absent))

print("PASS CastBarSelectionPreview: selection/editor preview contract, detailed/live precedence, icon/visibility, selection changes, absent CastBar")
