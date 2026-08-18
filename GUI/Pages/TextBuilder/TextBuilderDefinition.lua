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
        section = "TemplatePreview",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "compact_dual_column",
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            layoutTable = {
                columns = {
                    { weight = 7 },
                    { weight = 3 },
                },
                spaceH = 14,
                spaceV = 0,
                align = "TOPLEFT",
                alignV = "start",
                alignH = "start",
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 92,
                derivedFrom = "max(Template.heightInfo, Preview.heightInfo)",
            },
        },
        items = {},
    },
    {
        section = "Template",
        properties = {
            parentSection = "TemplatePreview",
            sectionKind = "section",
            type = "section",
            variant = "compact_input_stack",
            surfaceStyle = "status_panel",
            padding = {
                left = 8,
                right = 8,
                top = 5,
                bottom = 5,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 78,
                derivedFrom = "section title + example + editBox + updateButton + spacing",
            },
        },
        items = {
            { id = "templateTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATE" },
            { id = "templateExample", widget = "computed_label", itemVariant = "example_text_muted", builder = "templateExample" },
            { id = "templateEdit", widget = "editbox", itemVariant = "builder_field", labelKey = "INFO_TEXT_BUILDER_TEMPLATE", stateKey = "template", normalize = "template" },
            { id = "tagDatabaseButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TAG_LIBRARY_TITLE", width = 240, fullWidth = false },
            { id = "updateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_APPLY", width = 240, fullWidth = false },
        },
    },
    {
        section = "Preview",
        properties = {
            parentSection = "TemplatePreview",
            sectionKind = "section",
            type = "section",
            variant = "result_stack",
            surfaceStyle = "result_panel",
            padding = {
                left = 8,
                right = 8,
                top = 5,
                bottom = 5,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 78,
                derivedFrom = "section title + previewValue",
            },
        },
        items = {
            { id = "previewTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_PREVIEW" },
            { id = "previewValue", widget = "label", itemVariant = "result_value_hero", text = " " },
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
                top = 5,
                bottom = 5,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "section title + TemplatesColumns + Actions + CopyAction + TemplatesNote + spacing",
            },
        },
        items = {
            { id = "templatesTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATES" },
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
                top = 3,
                bottom = 3,
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
                top = 3,
                bottom = 3,
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
            { id = "templateOwnerLabel", widget = "label", itemVariant = "section_description", text = " " },
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
                top = 3,
                bottom = 3,
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
            type = "action_row",
            variant = "four_button",
            padding = {
                left = 4,
                right = 4,
                top = 1,
                bottom = 1,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 32,
                derivedFrom = "newTemplateButton + saveButton + updateTemplateButton + deleteTemplateButton",
            },
        },
        items = {
            { id = "newTemplateButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_NEW_TEMPLATE" },
            { id = "saveButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_CREATE_TEMPLATE" },
            { id = "updateTemplateButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_RENAME_TEMPLATE" },
            { id = "deleteTemplateButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_TEXT_BUILDER_DELETE" },
        },
    },
    {
        section = "CopyAction",
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
                    section = "CopyAction",
                },
                footer = {
                    present = true,
                    optional = false,
                    section = "TemplatesNote",
                },
            },
            type = "action_row",
            variant = "single_button",
            gapBefore = 2,
            padding = {
                left = 4,
                right = 4,
                top = 1,
                bottom = 1,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 26,
                derivedFrom = "copyTemplateButton",
            },
        },
        items = {
            { id = "copyTemplateButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_COPY_TO_CURRENT_PROFILE", fullWidth = true },
        },
    },
    {
        section = "TemplatesNote",
        properties = {
            parentSection = "Templates",
            sectionKind = "widget_group_footer",
            structureSlot = "footer",
            widgetGroup = "CopyAction",
            type = "info_block",
            variant = "note_text",
            padding = {
                left = 6,
                right = 6,
                top = 1,
                bottom = 1,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 38,
                derivedFrom = "libraryHint label",
            },
        },
        items = {
            { id = "libraryHint", widget = "label", itemVariant = "footer_hint_muted", role = "label", size = 12, colorKey = "hint", justifyH = "LEFT", textKey = "INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT" },
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
                top = 5,
                bottom = 5,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 82,
                derivedFrom = "section title + usageLead + UsageColumns + ApplyRow + spacing",
            },
        },
        items = {
            { id = "usageTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TEXT_BUILDER_TEMPLATE_USAGE" },
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
                top = 3,
                bottom = 3,
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
                top = 3,
                bottom = 3,
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

ns.GUI.Layouts.TextBuilder.DeleteConfirm = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 10,
                bottom = 14,
            },
        },
        items = {},
    },
    {
        section = "Message",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "status_panel",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            heightInfo = {
                source = "content",
                min = 100,
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_DELETE_CONFIRM_TITLE" },
            { id = "message", widget = "label", itemVariant = "description_text_body", stateKey = "message" },
        },
    },
    {
        section = "ActionRow",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "dual_button",
            padding = {
                left = 8,
                right = 8,
                top = 4,
                bottom = 4,
            },
            gapBefore = 8,
            heightInfo = {
                source = "content",
                min = 32,
            },
        },
        items = {
            { id = "deleteConfirmButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_TEXT_BUILDER_DELETE_CONFIRM_BUTTON" },
            { id = "cancelButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CANCEL" },
        },
    },
}

ns.GUI.Layouts.TextBuilder.UnsavedApplyConfirm = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 10,
                bottom = 14,
            },
        },
        items = {},
    },
    {
        section = "Message",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "status_panel",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            heightInfo = {
                source = "content",
                min = 110,
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "section_title_large", textKey = "INFO_TEXT_BUILDER_UNSAVED_APPLY_TITLE" },
            { id = "message", widget = "label", itemVariant = "description_text_body", textKey = "INFO_TEXT_BUILDER_UNSAVED_APPLY_PROMPT" },
        },
    },
    {
        section = "ActionRow",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "triple_button",
            padding = {
                left = 8,
                right = 8,
                top = 4,
                bottom = 4,
            },
            gapBefore = 8,
            heightInfo = {
                source = "content",
                min = 32,
            },
        },
        items = {
            { id = "saveApplyButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_TEXT_BUILDER_UNSAVED_SAVE_APPLY" },
            { id = "applyStoredButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_TEXT_BUILDER_UNSAVED_APPLY_STORED" },
            { id = "cancelButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CANCEL" },
        },
    },
}
