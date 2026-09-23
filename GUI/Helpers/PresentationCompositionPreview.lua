local _, ns = ...

-- Experimental presentation-only runtime. Widgets/regions never cross the public API.
local Composition = {}
ns.GUI.PresentationCompositionPreview = Composition
local API = { version = 1 }
ns.Ace.PresentationCompositionPreview = API
local TARGET, MAX_LAYERS = "inspector_section", 10
local descriptor, nextId = nil, 0
local owners = setmetatable({}, { __mode = "k" })
local sectionTargets = {
    inspector_section_surface = true, inspector_section_border = true, inspector_section_accent = true,
}
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

function Composition.BlocksColorTarget(target)
    return descriptor ~= nil and sectionTargets[target] == true
end

local function CanWrite(target, entering)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if target ~= TARGET then return false, "unknown_target" end
    if entering and not descriptor then
        local preview = ns.Ace.PresentationPreview
        for id in pairs(sectionTargets) do
            if next(preview.GetOverrides(id)) then return false, "section_color_preview_active" end
        end
    end
    return true
end

local function Reapply()
    for owner, apply in pairs(owners) do apply(owner) end
end

local function Empty() return { version = 0, target = TARGET, layers = {} } end
local function Find(id)
    if descriptor and type(id) == "string" then
        for index, layer in ipairs(descriptor.layers) do if layer.id == id then return index, layer end end
    end
end

function API.GetCapabilities()
    return { version = 1, descriptorVersion = 0, transient = true, combatWrites = false,
        target = TARGET, maxLayers = MAX_LAYERS, types = { "surface", "line", "texture" },
        modes = { "stretch" }, insetRange = { 0, 8 }, offsetRange = { 0, 8 }, thicknessRange = { 1, 4 },
        properties = { surface = { "color", "alpha", "insets" },
            line = { "edge", "offset", "thickness", "color", "alpha" },
            texture = { "textureId", "tint", "alpha", "insets", "mode" } } }
end

function API.GetTextureOptions()
    return { { id = "parchment", label = textures.parchment.label }, { id = "blizzard", label = textures.blizzard.label } }
end

function API.GetComposition(target)
    if target ~= TARGET then return nil, "unknown_target" end
    return Copy(descriptor)
end

function API.AddLayer(target, kind, initial)
    local ok, reason = CanWrite(target, true)
    if not ok then return false, reason end
    if type(kind) ~= "string" or not defaults[kind] then return false, "unknown_type" end
    if descriptor and #descriptor.layers >= MAX_LAYERS then return false, "layer_limit" end
    if initial ~= nil and not Plain(initial) then return false, "invalid_initial" end
    local layer = Copy(defaults[kind])
    for property, value in pairs(initial or {}) do
        if not ValidProperty(kind, property, value) then return false, "invalid_property" end
        layer[property] = Copy(value)
    end
    nextId = nextId + 1
    layer.id, layer.type = "layer_" .. nextId, kind
    descriptor = descriptor or Empty()
    descriptor.layers[#descriptor.layers + 1] = layer
    Reapply()
    return true, layer.id
end

function API.RemoveLayer(target, id)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local index = Find(id)
    if not index then return false, "unknown_layer" end
    table.remove(descriptor.layers, index)
    Reapply()
    return true
end

function API.UpdateLayer(target, id, property, value)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local _, layer = Find(id)
    if not layer then return false, "unknown_layer" end
    if not ValidProperty(layer.type, property, value) then return false, "invalid_property" end
    layer[property] = Copy(value)
    Reapply()
    return true
end

function API.MoveLayer(target, id, destination)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    local index, layer = Find(id)
    if not index then return false, "unknown_layer" end
    local count = #descriptor.layers
    if destination == "up" then destination = math.min(count, index + 1)
    elseif destination == "down" then destination = math.max(1, index - 1) end
    if not Number(destination, 1, count) or destination % 1 ~= 0 then return false, "invalid_position" end
    if destination ~= index then
        table.remove(descriptor.layers, index)
        table.insert(descriptor.layers, destination, layer)
        Reapply()
    end
    return true
end

function API.ClearComposition(target)
    local ok, reason = CanWrite(target, true)
    if not ok then return false, reason end
    descriptor = Empty()
    Reapply()
    return true
end

function API.ResetComposition(target)
    local ok, reason = CanWrite(target)
    if not ok then return false, reason end
    if descriptor then descriptor = nil; Reapply() end
    return true
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

local function ClearRegions(owner)
    for _, region in ipairs(owner.frame._fpCompositionRegions or {}) do Neutralize(region) end
end

function Composition.Bind(owner, apply)
    owners[owner] = apply
end

function Composition.Release(owner)
    owners[owner] = nil
    ClearRegions(owner)
end

-- Called only by the Inspector's presentation dispatcher, never by a layout hook.
function Composition.Apply(owner, style, canonicalOnly)
    if canonicalOnly or not descriptor then ClearRegions(owner); return false end
    local renderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
    renderer.ApplySectionSurface(owner, nil)
    renderer.ApplySectionBorder(owner, false)
    local frame = owner.frame
    local slots = frame._fpCompositionRegions or {}
    frame._fpCompositionRegions = slots
    local bounds = style and style.surfaceInsets or {}
    local left, right, top, bottom = bounds.left or 0, bounds.right or 0, bounds.top or 0, bounds.bottom or 0
    for index, layer in ipairs(descriptor.layers) do
        local region = slots[index]
        if not region then region = frame:CreateTexture(nil, "BACKGROUND", nil, index - 9); slots[index] = region end
        Neutralize(region)
        region:SetDrawLayer("BACKGROUND", index - 9)
        if layer.type == "line" then
            local edge, offset = layer.edge, layer.offset
            if edge == "top" or edge == "bottom" then
                local point, y = edge == "top" and "TOP" or "BOTTOM", edge == "top" and -(top + offset) or bottom + offset
                region:SetPoint(point .. "LEFT", frame, point .. "LEFT", left, y)
                region:SetPoint(point .. "RIGHT", frame, point .. "RIGHT", -right, y)
                region:SetHeight(layer.thickness)
            else
                local point, x = edge == "left" and "LEFT" or "RIGHT", edge == "left" and left + offset or -(right + offset)
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
    for index = #descriptor.layers + 1, #slots do Neutralize(slots[index]) end
    return true
end
