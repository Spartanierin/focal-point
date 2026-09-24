local _, ns = ...

-- Experimental presentation-only runtime. Widgets/regions never cross the public API.
local Composition = {}
ns.GUI.PresentationCompositionPreview = Composition
local API = { version = 1 }
ns.Ace.PresentationCompositionPreview = API

local MAX_LAYERS = 10
local TARGET_ORDER = { "inspector_section", "inspector_shell", "sidebar_shell" }
local targetInfo = {
    inspector_section = {
        label = "Inspector section",
        area = "Inspector",
        conflicts = {
            inspector_section_surface = true,
            inspector_section_border = true,
            inspector_section_accent = true,
        },
        previewConflictReason = "section_color_preview_active",
        compositionConflictReason = "section_composition_active",
    },
    inspector_shell = {
        label = "Inspector shell",
        area = "Inspector",
        conflicts = { inspector_shell = true },
        previewConflictReason = "shell_color_preview_active",
        compositionConflictReason = "shell_composition_active",
        surfaceInsets = { left = 12, right = 12, top = 12, bottom = 12 },
    },
    sidebar_shell = {
        label = "Shell",
        area = "Sidebar",
        conflicts = { sidebar_shell = true },
        previewConflictReason = "sidebar_shell_color_preview_active",
        compositionConflictReason = "sidebar_shell_composition_active",
    },
}

local states, owners = {}, {}
for _, target in ipairs(TARGET_ORDER) do
    states[target] = { descriptor = nil, nextId = 0 }
    owners[target] = setmetatable({}, { __mode = "k" })
end

local textures = {
    parchment = { label = "FP window parchment", path = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\fp_window_background.jpg" },
    blizzard = { label = "FP BetterBlizzard", path = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\BetterBlizzard.blp" },
}
local defaults = {
    surface = { color = { 1, 1, 1 }, alpha = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
    line = { color = { 1, 1, 1 }, alpha = 1, edge = "top", offset = 0, thickness = 1 },
    texture = { textureId = "parchment", tint = { 1, 1, 1 }, alpha = 1, mode = "stretch",
        insets = { left = 0, right = 0, top = 0, bottom = 0 } },
}
local sharedCapabilities = {
    maxLayers = MAX_LAYERS,
    types = { "surface", "line", "texture" },
    modes = { "stretch" },
    insetRange = { 0, 8 },
    offsetRange = { 0, 8 },
    thicknessRange = { 1, 4 },
    properties = {
        surface = { "color", "alpha", "insets" },
        line = { "edge", "offset", "thickness", "color", "alpha" },
        texture = { "textureId", "tint", "alpha", "insets", "mode" },
    },
}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Copy(item) end
    return copy
end

local function Number(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end

local function Plain(value) return type(value) == "table" and getmetatable(value) == nil end
local edges = { top = true, bottom = true, left = true, right = true }

local function ValidProperty(kind, property, value)
    if not defaults[kind] or defaults[kind][property] == nil then return false end
    if property == "color" or property == "tint" then
        if not Plain(value) then return false end
        for key in pairs(value) do if key ~= 1 and key ~= 2 and key ~= 3 then return false end end
        return Number(value[1], 0, 1) and Number(value[2], 0, 1) and Number(value[3], 0, 1)
    elseif property == "insets" then
        if not Plain(value) then return false end
        for key in pairs(value) do if not edges[key] then return false end end
        for key in pairs(edges) do if not Number(value[key], 0, 8) then return false end end
        return true
    elseif property == "alpha" then return Number(value, 0, 1)
    elseif property == "offset" then return Number(value, 0, 8)
    elseif property == "thickness" then return Number(value, 1, 4)
    elseif property == "edge" then return type(value) == "string" and edges[value] == true
    elseif property == "textureId" then return type(value) == "string" and textures[value] ~= nil
    elseif property == "mode" then return value == "stretch" end
    return false
end

local function Target(target)
    return type(target) == "string" and targetInfo[target] ~= nil
end

local function State(target)
    return states[target]
end

local function Empty(target) return { version = 0, target = target, layers = {} } end

local function Find(target, id)
    local descriptor = State(target).descriptor
    if descriptor and type(id) == "string" then
        for index, layer in ipairs(descriptor.layers) do
            if layer.id == id then return index, layer end
        end
    end
end

local function TargetMetadata(target)
    local info = targetInfo[target]
    return {
        id = target,
        label = info.label,
        area = info.area,
        maxLayers = MAX_LAYERS,
        types = Copy(sharedCapabilities.types),
        modes = Copy(sharedCapabilities.modes),
        properties = Copy(sharedCapabilities.properties),
    }
end

function API.GetTargets()
    local result = {}
    for _, target in ipairs(TARGET_ORDER) do
        result[#result + 1] = TargetMetadata(target)
    end
    return result
end

local function PreviewConflict(target)
    local info = targetInfo[target]
    local preview = ns.Ace.PresentationPreview
    if not preview or not info then return nil end
    for conflictTarget in pairs(info.conflicts) do
        if next(preview.GetOverrides(conflictTarget) or {}) then
            return info.previewConflictReason
        end
    end
end

local function CanWrite(target, entering)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not Target(target) then return false, "unknown_target" end
    if entering and not State(target).descriptor then
        local reason = PreviewConflict(target)
        if reason then return false, reason end
    end
    return true
end

function Composition.BlocksColorTarget(target)
    for _, compositionTarget in ipairs(TARGET_ORDER) do
        if State(compositionTarget).descriptor and targetInfo[compositionTarget].conflicts[target] then
            return true
        end
    end
    return false
end

function Composition.GetColorConflictReason(target)
    for _, compositionTarget in ipairs(TARGET_ORDER) do
        if State(compositionTarget).descriptor and targetInfo[compositionTarget].conflicts[target] then
            return targetInfo[compositionTarget].compositionConflictReason
        end
    end
end

local function Reapply(target, canonicalOnly)
    for owner, apply in pairs(owners[target]) do apply(owner, canonicalOnly) end
end

local function OwnerFrame(owner)
    return owner and (owner.frame or owner)
end

local function GetSlots(owner, target, create)
    local frame = OwnerFrame(owner)
    if not frame then return nil end
    local byTarget = frame._fpCompositionRegionsByTarget
    if not byTarget and create then
        byTarget = {}
        frame._fpCompositionRegionsByTarget = byTarget
    end
    local slots = byTarget and byTarget[target]
    if not slots and create then
        slots = {}
        byTarget[target] = slots
    end
    -- Preserve the existing internal field for inspector-section diagnostics/tests.
    if target == "inspector_section" then frame._fpCompositionRegions = slots end
    return slots
end

local function Neutralize(region)
    region:Hide()
    region:ClearAllPoints()
    region:SetSize(0, 0)
    region:SetTexture(nil, "CLAMP", "CLAMP")
    region:SetTexCoord(0, 1, 0, 1)
    region:SetHorizTile(false)
    region:SetVertTile(false)
    region:SetBlendMode("BLEND")
    region:SetVertexColor(1, 1, 1, 1)
    region:SetAlpha(1)
    region:SetDrawLayer("BACKGROUND", -8)
end

local function ClearRegions(owner, target)
    for _, region in ipairs(GetSlots(owner, target, false) or {}) do Neutralize(region) end
end

local function NeutralizeSection(owner)
    local renderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
    renderer.ApplySectionSurface(owner, nil)
    renderer.ApplySectionBorder(owner, false)
end

local function ShellRegions(window)
    local frame = OwnerFrame(window)
    local content = window and window.content
    if not frame then return {} end
    local regions = {}
    local function Add(region)
        if region then regions[#regions + 1] = region end
    end
    Add(frame._fpSidebarPanelFill)
    Add(frame._fpSidebarPanelHeaderFill)
    Add(frame._fpSidebarPanelTopShade)
    Add(frame._fpSidebarPanelBottomShade)
    Add(frame._fpSidebarPanelBorderTop)
    Add(frame._fpSidebarPanelBorderBottom)
    Add(frame._fpSidebarPanelBorderLeft)
    Add(frame._fpSidebarPanelBorderRight)
    Add(frame._fpSidebarPanelInnerTop)
    Add(frame._fpSidebarPanelInnerBottom)
    Add(frame._fpSidebarPanelInnerLeft)
    Add(frame._fpSidebarPanelInnerRight)
    Add(frame._editorSidebar)
    Add(frame._editorSidebarBorder)
    Add(content and content._fpSidebarAccent)
    return regions
end

local function NeutralizeShell(window)
    for _, region in ipairs(ShellRegions(window)) do
        if region and region.Hide then region:Hide() end
    end
end

function Composition.Bind(target, owner, apply)
    -- Keep the original internal call shape as a safe compatibility bridge.
    if type(target) ~= "string" then
        apply, owner, target = owner, target, "inspector_section"
    end
    if not Target(target) or not owner or type(apply) ~= "function" then return false end
    owners[target][owner] = apply
    return true
end

function Composition.Release(target, owner)
    if type(target) ~= "string" then owner, target = target, "inspector_section" end
    if not Target(target) then return false end
    owners[target][owner] = nil
    ClearRegions(owner, target)
    return true
end

local function ApplyLayers(target, owner, style, canonicalOnly)
    local state = State(target)
    if canonicalOnly or not state.descriptor then
        ClearRegions(owner, target)
        return false
    end

    if target == "inspector_section" then
        NeutralizeSection(owner)
    elseif target == "inspector_shell" or target == "sidebar_shell" then
        NeutralizeShell(owner)
    end

    local frame = OwnerFrame(owner)
    if not frame then return false end
    local slots = GetSlots(owner, target, true)
    local bounds = (style and style.surfaceInsets) or targetInfo[target].surfaceInsets or {}
    local left, right = bounds.left or 0, bounds.right or 0
    local top, bottom = bounds.top or 0, bounds.bottom or 0
    for index, layer in ipairs(state.descriptor.layers) do
        local region = slots[index]
        if not region then
            region = frame:CreateTexture(nil, "BACKGROUND", nil, index - 9)
            slots[index] = region
        end
        Neutralize(region)
        region:SetDrawLayer("BACKGROUND", index - 9)
        if layer.type == "line" then
            local edge, offset = layer.edge, layer.offset
            if edge == "top" or edge == "bottom" then
                local point = edge == "top" and "TOP" or "BOTTOM"
                local y = edge == "top" and -(top + offset) or bottom + offset
                region:SetPoint(point .. "LEFT", frame, point .. "LEFT", left, y)
                region:SetPoint(point .. "RIGHT", frame, point .. "RIGHT", -right, y)
                region:SetHeight(layer.thickness)
            else
                local point = edge == "left" and "LEFT" or "RIGHT"
                local x = edge == "left" and left + offset or -(right + offset)
                region:SetPoint("TOP" .. point, frame, "TOP" .. point, x, -top)
                region:SetPoint("BOTTOM" .. point, frame, "BOTTOM" .. point, x, bottom)
                region:SetWidth(layer.thickness)
            end
        else
            local inset = layer.insets
            region:SetPoint("TOPLEFT", frame, "TOPLEFT", left + inset.left, -(top + inset.top))
            region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right + inset.right), bottom + inset.bottom)
        end
        if layer.type == "texture" then
            region:SetTexture(textures[layer.textureId].path, "CLAMP", "CLAMP")
            region:SetVertexColor(layer.tint[1], layer.tint[2], layer.tint[3], 1)
        else
            region:SetColorTexture(layer.color[1], layer.color[2], layer.color[3], 1)
        end
        region:SetAlpha(layer.alpha)
        region:Show()
    end
    for index = #state.descriptor.layers + 1, #slots do Neutralize(slots[index]) end
    return true
end

function Composition.Apply(target, owner, style, canonicalOnly)
    -- Keep the original internal call shape as a safe compatibility bridge.
    if type(target) ~= "string" then
        canonicalOnly, style, owner, target = style, owner, target, "inspector_section"
    end
    if not Target(target) then return false end
    return ApplyLayers(target, owner, style, canonicalOnly)
end

function API.GetCapabilities()
    local capabilities = {
        version = 1,
        descriptorVersion = 0,
        transient = true,
        combatWrites = false,
        -- Retained for older clients; new clients should use GetTargets().
        target = "inspector_section",
        targets = API.GetTargets(),
    }
    for key, value in pairs(sharedCapabilities) do capabilities[key] = Copy(value) end
    return capabilities
end

function API.GetTextureOptions()
    return { { id = "parchment", label = textures.parchment.label }, { id = "blizzard", label = textures.blizzard.label } }
end

function API.GetComposition(target)
    if not Target(target) then return nil, "unknown_target" end
    return Copy(State(target).descriptor)
end

function API.AddLayer(target, kind, initial)
    local ok, reason = CanWrite(target, true)
    if not ok then return false, reason end
    if type(kind) ~= "string" or not defaults[kind] then return false, "unknown_type" end
    local state = State(target)
    if state.descriptor and #state.descriptor.layers >= MAX_LAYERS then return false, "layer_limit" end
    if initial ~= nil and not Plain(initial) then return false, "invalid_initial" end
    local layer = Copy(defaults[kind])
    for property, value in pairs(initial or {}) do
        if not ValidProperty(kind, property, value) then return false, "invalid_property" end
        layer[property] = Copy(value)
    end
    state.nextId = state.nextId + 1
    layer.id, layer.type = "layer_" .. state.nextId, kind
    state.descriptor = state.descriptor or Empty(target)
    state.descriptor.layers[#state.descriptor.layers + 1] = layer
    Reapply(target)
    return true, layer.id
end

function API.RemoveLayer(target, id)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local index = Find(target, id)
    if not index then return false, "unknown_layer" end
    table.remove(State(target).descriptor.layers, index)
    Reapply(target)
    return true
end

function API.UpdateLayer(target, id, property, value)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local _, layer = Find(target, id)
    if not layer then return false, "unknown_layer" end
    if not ValidProperty(layer.type, property, value) then return false, "invalid_property" end
    layer[property] = Copy(value)
    Reapply(target)
    return true
end

function API.MoveLayer(target, id, destination)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local index, layer = Find(target, id)
    if not index then return false, "unknown_layer" end
    local count = #State(target).descriptor.layers
    if destination == "up" then destination = math.min(count, index + 1)
    elseif destination == "down" then destination = math.max(1, index - 1) end
    if not Number(destination, 1, count) or destination % 1 ~= 0 then return false, "invalid_position" end
    if destination ~= index then
        table.remove(State(target).descriptor.layers, index)
        table.insert(State(target).descriptor.layers, destination, layer)
        Reapply(target)
    end
    return true
end

function API.ClearComposition(target)
    local ok, reason = CanWrite(target, true)
    if not ok then return false, reason end
    State(target).descriptor = Empty(target)
    Reapply(target)
    return true
end

function API.ResetComposition(target)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    State(target).descriptor = nil
    Reapply(target, true)
    return true
end
