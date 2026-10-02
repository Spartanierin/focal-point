local _, FocalPoint = ...

-- E2 identity manifest. These IDs are allocated literals, never computed from
-- source keys, display names, contents or array positions. Never reassign an ID.
--
-- Until E6, Defaults/Themes remain the sole maintained name/content sources.
-- The manifest binds exact CODE definitions (not saved/profile/layout data) to
-- IDs and freezes their records at load. This avoids a second editable source.
-- On source rename, update its selector while keeping the published ID.
-- PresetService/LegacyThemeAdapter only copy these definitions into previews:
-- those copies do not declare additional entities. Inline tags are not templates.
local defaultBindings = {
    {"tpl:b:default-001", "Alt Power"},
    {"tpl:b:default-002", "Class Power"},
    {"tpl:b:default-003", "Unit Name Focus"},
    {"tpl:b:default-004", "Unit Name Target"},
    {"tpl:b:default-005", "Dead/Ghost Timer"},
    {"tpl:b:default-006", "Cast Name"},
    {"tpl:b:default-007", "Power"},
    {"tpl:b:default-008", "Absorb Value"},
    {"tpl:b:default-009", "Healing Absorb Value"},
    {"tpl:b:default-010", "Unit Name Player"},
    {"tpl:b:default-011", "Health"},
    {"tpl:b:default-012", "Player Level and Class"},
    {"tpl:b:default-013", "Cast Time"},
    {"tpl:b:default-014", "Status"},
    {"tpl:b:default-015", "Dead Target"},
    {"tpl:b:default-016", "Focus Level and Class"},
    {"tpl:b:default-017", "Target Level and Class"},
    {"tpl:b:default-018", "Creature"},
}
local classicBindings = {
    {"tpl:b:classic-001", "Health current"},
    {"tpl:b:classic-002", "Health w/o perc"},
    {"tpl:b:classic-003", "Power perc"},
    {"tpl:b:classic-004", "Unit Name w/o status"},
}

local entries = {}
local function AddSource(bindings, templates)
    assert(type(templates) == "table", "Missing built-in template source")
    for _, binding in ipairs(bindings) do
        local id, name = binding[1], binding[2]
        assert(type(templates[name]) == "string", "Missing built-in template source for " .. id)
        entries[#entries + 1] = {templateId = id, record = {name = name, content = templates[name]}}
    end
end
local defaults = FocalPoint:GetDefaultDB()
AddSource(defaultBindings, defaults.profile.TextTemplates)
AddSource(classicBindings, FocalPoint.Themes.classic.textTemplates)
local catalog, reason = FocalPoint.TextTemplateLibrary.CreateBuiltInTemplateCatalog(entries)
assert(catalog, reason and reason.errorCode)
FocalPoint.BuiltInTextTemplates = catalog
