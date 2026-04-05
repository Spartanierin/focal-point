local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}
ns.GUI.Layouts.TextBuilder = ns.GUI.Layouts.TextBuilder or {}

--[[
Declarative form layout for the Text Builder popup.

Goal:
- describe structure and sizing intent without embedding widget construction details
- keep page files focused on widget content, callbacks, and behavior

Important fields:
- section: stable identifier for this group
- properties: all declarative settings for this section
  parentSection: parent group in this declaration tree
  type: semantic role of this section
  variant: structural specialization resolved through FormElementDefinitions
  width / height: explicit runtime size overrides; only numeric values are applied
  widthInfo / heightInfo: documentation for humans about where the effective size comes from
    source can be explicit, parent, content, or default
    min keeps content-driven sections from collapsing below a readable baseline
    value stores the known effective size when it is stable
    derivedFrom explains the origin of that effective value
- items: widgets that belong to this section, in render order
  itemVariant: semantic widget styling preset resolved through FormElementDefinitions
]]
ns.GUI.Layouts.TextBuilder.Form = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "root",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 10,
                bottom = 10,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "parent",
            },
        },
        items = {},
    },
    {
        section = "Header",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "header",
            variant = "compact_info_stack",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 80,
                derivedFrom = "title + description + spacing",
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "page_title", textKey = "INFO_TEXT_BUILDER_TITLE", textFallback = "Text Builder" },
            { id = "intro", widget = "label", itemVariant = "page_intro", textKey = "INFO_TEXT_BUILDER_DESCRIPTION_SHORT", textFallback = "Vorlage bauen, Vorschau pruefen, speichern und anwenden." },
        },
    },
    {
        section = "Template",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "editor_stack",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "section title + example + editBox + updateButton + spacing",
            },
        },
        items = {
            { id = "templateTitle", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_TEMPLATE", textFallback = "Vorlage" },
            { id = "templateExample", widget = "computed_label", itemVariant = "hint_text", builder = "templateExample" },
            { id = "templateEdit", widget = "editbox", itemVariant = "form_field", labelKey = "INFO_TEXT_BUILDER_TEMPLATE", labelFallback = "Vorlage", stateKey = "template", normalize = "template" },
            { id = "updateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_APPLY", textFallback = "Vorschau aktualisieren", width = 220, fullWidth = false },
        },
    },
    {
        section = "Preview",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "preview_stack",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 80,
                derivedFrom = "section title + previewValue + previewHint + spacing",
            },
        },
        items = {
            { id = "previewTitle", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_PREVIEW", textFallback = "Vorschau" },
            { id = "previewValue", widget = "label", itemVariant = "value_display_large", text = " " },
            { id = "previewHint", widget = "label", itemVariant = "hint_text", textKey = "INFO_TEXT_BUILDER_PREVIEW_HINT_SHORT", textFallback = "Kurz pruefen, dann speichern oder anwenden." },
        },
    },
    {
        section = "Templates",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "editor_stack",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 140,
                derivedFrom = "section title + hint + TemplatesColumns + Actions + TemplatesNote + spacing",
            },
        },
        items = {
            { id = "templatesTitle", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_TEMPLATES", textFallback = "Vorlagen" },
            { id = "templatesHint", widget = "label", itemVariant = "section_description", textKey = "INFO_TEXT_BUILDER_TEMPLATES_HINT_SHORT", textFallback = "Gespeicherte Vorlagen verwalten." },
        },
    },
    {
        section = "TemplatesColumns",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "compact_dual_column",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "max(TemplatesLeftColumn.heightInfo, TemplatesRightColumn.heightInfo)",
            },
        },
        items = {},
    },
    {
        section = "TemplatesLeftColumn",
        properties = {
            parentSection = "TemplatesColumns",
            sectionKind = "widget_group",
            type = "column",
            variant = "compact_form_column",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "saved templates dropdown",
            },
        },
        items = {
            { id = "templateSelect", widget = "dropdown", itemVariant = "form_field", labelKey = "INFO_TEXT_BUILDER_SAVED_TEMPLATES", labelFallback = "Gespeicherte Vorlagen" },
        },
    },
    {
        section = "TemplatesRightColumn",
        properties = {
            parentSection = "TemplatesColumns",
            sectionKind = "widget_group",
            type = "column",
            variant = "compact_form_column",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "template name editBox",
            },
        },
        items = {
            { id = "templateNameEdit", widget = "editbox", itemVariant = "form_field", labelKey = "INFO_TEXT_BUILDER_TEMPLATE_NAME", labelFallback = "Vorlagenname", stateKey = "templateName" },
        },
    },
    {
        section = "Actions",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "triple_button",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 32,
                derivedFrom = "saveButton + updateTemplateButton + deleteTemplateButton",
            },
        },
        items = {
            { id = "saveButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_SAVE", textFallback = "Speichern" },
            { id = "updateTemplateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_UPDATE", textFallback = "Aktualisieren" },
            { id = "deleteTemplateButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_TEXT_BUILDER_DELETE", textFallback = "Loeschen" },
        },
    },
    {
        section = "TemplatesNote",
        properties = {
            parentSection = "Templates",
            sectionKind = "section",
            type = "section",
            variant = "note_stack",
            padding = {
                left = 8,
                right = 8,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 20,
                derivedFrom = "libraryHint label",
            },
        },
        items = {
            { id = "libraryHint", widget = "label", itemVariant = "hint_text", textKey = "INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT", textFallback = "Vorlagen sichern, aktualisieren oder entfernen." },
        },
    },
    {
        section = "Footer",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "usage_stack",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 120,
                derivedFrom = "section title + usageHint + usageLead + UsageColumns + ApplyRow + spacing",
            },
        },
        items = {
            { id = "usageTitle", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_TEMPLATE_USAGE", textFallback = "Vorlagenverwendung" },
            { id = "usageHint", widget = "label", itemVariant = "section_description", textKey = "INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT", textFallback = "Auswaehlen, dann Vorlage anwenden." },
            { id = "usageLead", widget = "label", itemVariant = "usage_label", textKey = "INFO_TEXT_BUILDER_USAGE_LEAD", textFallback = "Verknuepfte Units" },
        },
    },
    {
        section = "UsageColumns",
        properties = {
            parentSection = "Footer",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "four_column",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 28,
                derivedFrom = "single checkbox row for linked units",
            },
        },
        items = {
            { id = "usagePlayer", widget = "checkbox", itemVariant = "unit_toggle", unitKey = "player" },
            { id = "usageTarget", widget = "checkbox", itemVariant = "unit_toggle", unitKey = "target" },
            { id = "usageFocus", widget = "checkbox", itemVariant = "unit_toggle", unitKey = "focus" },
            { id = "usagePet", widget = "checkbox", itemVariant = "unit_toggle", unitKey = "pet" },
        },
    },
    {
        section = "ApplyRow",
        properties = {
            parentSection = "Footer",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "single_button",
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 32,
                derivedFrom = "applyTemplateButton",
            },
        },
        items = {
            { id = "applyTemplateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_APPLY_TEMPLATE", textFallback = "Vorlage anwenden", width = 220, fullWidth = false },
        },
    },
}
