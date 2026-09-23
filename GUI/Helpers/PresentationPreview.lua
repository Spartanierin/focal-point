local _, ns = ...

-- Internal presentation adapter; only the value API below is public.
local Preview = {}
ns.GUI.PresentationPreview = Preview
local overrides = {}
local owners = setmetatable({}, { __mode = "k" })
local bindingKey = "fpPresentationPreview"

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local function ShellBaseline()
    return ns.GUI.Helpers.FormWidgets.GetSidebarShellFill()
end

local function SectionBaseline(part)
    local binding = ns.GUI.Editor.Inspector.InspectorBinding
    local style = binding.ResolveSectionPresentation()
    -- Texture-backed fallback styles are deliberately outside this contract.
    if not style or not style.surface or style.surface.material == "texture" then return nil end
    if part == "border" then return style.border and style.border.color end
    if part == "accent" then return style.surface.accent and style.surface.accent.color end
    return style.surface.fill
end

local function ThumbBaseline()
    local palette = ns.GUI.Skins.GetFormPalette()
    local color = palette.Navigator and palette.Navigator.navigatorAgedBrass or { 1, 1, 1, 1 }
    local thumb = palette.CompactSlider and palette.CompactSlider.thumb
    if not thumb or type(thumb.alpha) ~= "number" then return nil end
    return { color[1], color[2], color[3], (color[4] or 1) * thumb.alpha }
end

local order = {
    "sidebar_shell", "inspector_shell", "inspector_section_surface",
    "inspector_section_border", "inspector_section_accent", "inspector_slider_thumb",
}
local catalog = {
    sidebar_shell = { label = "Sidebar shell fill", baseline = ShellBaseline },
    inspector_shell = { label = "Inspector shell fill", baseline = ShellBaseline },
    inspector_section_surface = { label = "Inspector section fill", baseline = function() return SectionBaseline("fill") end },
    inspector_section_border = { label = "Inspector section border", baseline = function() return SectionBaseline("border") end },
    inspector_section_accent = { label = "Inspector section accent", baseline = function() return SectionBaseline("accent") end },
    inspector_slider_thumb = { label = "Inspector slider thumb", baseline = ThumbBaseline },
}

local function IsUnitNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 1
end

local function IsTarget(target)
    return type(target) == "string" and catalog[target] ~= nil
end

local function Baseline(target)
    if not IsTarget(target) then return nil, "unknown_target" end
    local color = catalog[target].baseline()
    if type(color) ~= "table" or not IsUnitNumber(color[1]) or not IsUnitNumber(color[2])
        or not IsUnitNumber(color[3]) or (color[4] ~= nil and not IsUnitNumber(color[4])) then
        return nil, "baseline_unavailable"
    end
    return { color = { color[1], color[2], color[3] }, alpha = color[4] or 1 }
end

-- RGB and alpha are independent properties. Never read back rendered regions.
function Preview.ResolveColor(target, canonicalOnly)
    local value = Baseline(target)
    if not value then return nil end
    local override = not canonicalOnly and overrides[target]
    if override then
        value.color = override.color or value.color
        if override.alpha ~= nil then value.alpha = override.alpha end
    end
    return { value.color[1], value.color[2], value.color[3], value.alpha }
end

-- Reapply functions are owned by FP consumers. No external frames or callbacks.
function Preview.Bind(owner, targets, apply)
    local targetSet = {}
    for _, target in ipairs(targets) do targetSet[target] = true end
    owners[owner] = { targets = targetSet, apply = apply }
end

function Preview.Unbind(owner)
    owners[owner] = nil
end

local function ReleaseWidget(widget)
    local binding = widget:GetUserData(bindingKey)
    local owner = owners[widget]
    Preview.Unbind(widget)
    -- Reset while this widget still belongs to FP, before AceGUI pools it.
    if owner then owner.apply(widget, true) end
    if binding and binding.onRelease then binding.onRelease(widget, "OnRelease") end
end

function Preview.BindWidget(widget, targets, apply)
    if not widget:GetUserData(bindingKey) then
        widget:SetUserData(bindingKey, { onRelease = widget.events and widget.events.OnRelease })
        widget:SetCallback("OnRelease", ReleaseWidget)
    end
    Preview.Bind(widget, targets, apply)
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function Reapply(targets)
    for owner, binding in pairs(owners) do
        for target in pairs(binding.targets) do
            if targets[target] then
                binding.apply(owner)
                break -- one section apply can service all three section targets
            end
        end
    end
end

local API = { version = 1 }
ns.Ace.PresentationPreview = API

function API.GetCapabilities()
    return { version = 1, transient = true, combatWrites = false,
        properties = { color = "RGB array, exactly 3 finite numbers in [0,1]", alpha = "number in [0,1]" } }
end

function API.GetTargets()
    local targets = {}
    for _, id in ipairs(order) do
        targets[#targets + 1] = { id = id, label = catalog[id].label, properties = { "color", "alpha" } }
    end
    return targets
end

function API.GetBaseline(target)
    return Baseline(target)
end

function API.GetOverrides(target)
    if target ~= nil and not IsTarget(target) then return nil, "unknown_target" end
    return Copy(target and (overrides[target] or {}) or overrides)
end

function API.Set(target, property, value)
    if InCombat() then return false, "combat" end
    if not IsTarget(target) then return false, "unknown_target" end
    if property == "color" then
        if type(value) ~= "table" or getmetatable(value) ~= nil then return false, "invalid_color" end
        for key in pairs(value) do
            if key ~= 1 and key ~= 2 and key ~= 3 then return false, "invalid_color" end
        end
        if not IsUnitNumber(value[1]) or not IsUnitNumber(value[2]) or not IsUnitNumber(value[3]) then
            return false, "invalid_color"
        end
    elseif property == "alpha" then
        if not IsUnitNumber(value) then return false, "invalid_alpha" end
    else
        return false, "unknown_property"
    end
    local baseline, reason = Baseline(target)
    if not baseline then return false, reason end
    overrides[target] = overrides[target] or {}
    overrides[target][property] = Copy(value)
    Reapply({ [target] = true })
    return true
end

function API.Clear(target, property)
    if InCombat() then return false, "combat" end
    if not IsTarget(target) then return false, "unknown_target" end
    if property ~= nil and property ~= "color" and property ~= "alpha" then return false, "unknown_property" end
    if property and overrides[target] then
        overrides[target][property] = nil
        if not next(overrides[target]) then overrides[target] = nil end
    elseif property == nil then
        overrides[target] = nil
    end
    Reapply({ [target] = true })
    return true
end

function API.ClearAll()
    if InCombat() then return false, "combat" end
    local changed = overrides
    overrides = {}
    Reapply(changed)
    return true
end

function API.Refresh(target)
    if InCombat() then return false, "combat" end
    if target ~= nil and not IsTarget(target) then return false, "unknown_target" end
    Reapply(target and { [target] = true } or catalog)
    return true
end
