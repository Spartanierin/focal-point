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
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
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
            variant = "page_header",
            surfaceStyle = "page_header",
            padding = {
                left = 10,
                right = 10,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "title + description + spacing",
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "page_title_hero", textKey = "INFO_TEXT_BUILDER_TITLE" },
            { id = "intro", widget = "label", itemVariant = "page_intro_soft", textKey = "INFO_TEXT_BUILDER_DESCRIPTION_SHORT" },
        },
    },
    {
        section = "Template",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "compact_input_stack",
            surfaceStyle = "status_panel",
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
                min = 64,
                derivedFrom = "section title + example + editBox + updateButton + spacing",
            },
        },
        items = {
            { id = "templateTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATE" },
            { id = "templateExample", widget = "computed_label", itemVariant = "example_text_muted", builder = "templateExample" },
            { id = "templateEdit", widget = "editbox", itemVariant = "builder_field", labelKey = "INFO_TEXT_BUILDER_TEMPLATE", stateKey = "template", normalize = "template" },
            { id = "updateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_APPLY", width = 240, fullWidth = false },
        },
    },
    {
        section = "Preview",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "result_stack",
            surfaceStyle = "result_panel",
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
                min = 68,
                derivedFrom = "section title + previewValue + previewHint + spacing",
            },
        },
        items = {
            { id = "previewTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_PREVIEW" },
            { id = "previewValue", widget = "label", itemVariant = "result_value_hero", text = " " },
            { id = "previewHint", widget = "label", itemVariant = "preview_hint_subtle", textKey = "INFO_TEXT_BUILDER_PREVIEW_HINT_SHORT" },
        },
    },
    {
        section = "Templates",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "management_stack",
            surfaceStyle = "section_panel",
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
                min = 1,
                derivedFrom = "section title + hint + TemplatesColumns + Actions + TemplatesNote + spacing",
            },
        },
        items = {
            { id = "templatesTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATES" },
            { id = "templatesHint", widget = "label", itemVariant = "section_description", textKey = "INFO_TEXT_BUILDER_TEMPLATES_HINT_SHORT" },
        },
    },
    {
        section = "TemplatesColumns",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "compact_dual_column",
            surfaceStyle = "workspace_split",
            padding = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 1,
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
                left = 4,
                right = 4,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "saved templates dropdown",
            },
        },
        items = {
            { id = "templateSelect", widget = "dropdown", itemVariant = "builder_field", labelKey = "INFO_TEXT_BUILDER_SAVED_TEMPLATES" },
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
                left = 4,
                right = 4,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "template name editBox",
            },
        },
        items = {
            { id = "templateNameEdit", widget = "editbox", itemVariant = "builder_field", labelKey = "INFO_TEXT_BUILDER_TEMPLATE_NAME", stateKey = "templateName" },
        },
    },
    {
        section = "Actions",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group",
            structure = {
                header = {
                    present = true,
                    optional = true,
                },
                body = {
                    present = true,
                    section = "Actions",
                },
                footer = {
                    present = true,
                    optional = false,
                    section = "TemplatesNote",
                },
            },
            type = "action_row",
            variant = "triple_button",
            padding = {
                left = 4,
                right = 4,
                top = 2,
                bottom = 2,
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
            { id = "saveButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_SAVE" },
            { id = "updateTemplateButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_UPDATE" },
            { id = "deleteTemplateButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_TEXT_BUILDER_DELETE" },
        },
    },
    {
        section = "TemplatesNote",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group_footer",
            structureSlot = "footer",
            widgetGroup = "Actions",
            type = "info_block",
            variant = "note_text",
            padding = {
                left = 6,
                right = 6,
                top = 2,
                bottom = 2,
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
            { id = "libraryHint", widget = "label", itemVariant = "footer_hint_muted", textKey = "INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT" },
        },
    },
    {
        section = "UsageSection",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "usage_stack",
            surfaceStyle = "status_panel",
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
                min = 96,
                derivedFrom = "section title + usageHint + usageLead + UsageColumns + ApplyRow + spacing",
            },
        },
        items = {
            { id = "usageTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATE_USAGE" },
            { id = "usageHint", widget = "label", itemVariant = "section_description", textKey = "INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT" },
            { id = "usageLead", widget = "label", itemVariant = "usage_label", textKey = "INFO_TEXT_BUILDER_USAGE_LEAD" },
        },
    },
    {
        section = "UsageColumns",
        properties = {
            parentSection = "UsageSection",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "four_column",
            padding = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 44,
                derivedFrom = "four-column usage grid for linked units",
            },
        },
        items = {
            { id = "usagePlayer", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "player" },
            { id = "usageTarget", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "target" },
            { id = "usageTargetTarget", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "targettarget" },
            { id = "usagePet", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "pet" },
            { id = "usageFocus", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "focus" },
            { id = "usageFocusTarget", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "focustarget" },
            { id = "usageBoss", widget = "checkbox", itemVariant = "usage_toggle_grid", unitKey = "boss" },
        },
    },
    {
        section = "ApplyRow",
        properties = {
            parentSection = "UsageSection",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "single_button",
            gapBefore = 4,
            padding = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4,
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
            { id = "applyTemplateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_APPLY_TEMPLATE", fullWidth = true },
        },
    },
}
