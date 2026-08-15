local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}
ns.GUI.Layouts.Profile = ns.GUI.Layouts.Profile or {}

--[[
Declarative form layout for the Profile popup.

Goal:
- keep structure and sizing intent readable without stepping through page code
- separate semantic layout description from widget creation/runtime wiring

Important fields:
- section: stable identifier for this group
- properties: all declarative settings for this section
  parentSection: parent group in this declaration tree
  type: semantic role, for example header, column_container, action_row
  variant: optional structural specialization, for example dual_button
  widget / layout / spacing / sizing flags: usually come from FormElementDefinitions
  gapBefore: extra outer spacing inserted before this section in the parent flow
  width / height: explicit runtime size overrides; only numeric values are applied
  widthInfo / heightInfo: documentation for humans about where the effective size comes from
    source can be explicit, parent, content, or default
    min keeps content-driven sections from collapsing below a readable baseline
    value stores the known effective size when it is stable
    derivedFrom explains the origin of that effective value
- items: widgets that belong to this section, in render order
  itemVariant: semantic widget styling preset resolved through FormElementDefinitions
]]
ns.GUI.Layouts.Profile.Form = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 8,
                bottom = 10,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Window.content.width",
            },
            heightInfo = {
                source = "parent",
                value = 475,
                derivedFrom = "Window.content.height",
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
                top = 5,
                bottom = 5,
            },
            heightInfo = {
                source = "content",
                min = 64,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "title + intro + spacing",
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "page_title_hero", textKey = "LAYOUTS_TITLE" },
            { id = "intro", widget = "label", itemVariant = "page_intro_soft", textKey = "LAYOUTS_DESCRIPTION_SHORT" },
        },
    },
    {
        section = "Subnav",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "action_row",
            variant = "triple_button",
            surfaceStyle = "section_panel",
            padding = {
                left = 8,
                right = 8,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 32,
                derivedFrom = "layouts subnavigation buttons",
            },
        },
        items = {
            { id = "profilesTabButton", widget = "button", itemVariant = "secondary_action", textKey = "LAYOUTS_PROFILES" },
            { id = "presetsTabButton", widget = "button", itemVariant = "secondary_action", textKey = "LAYOUTS_PRESETS" },
            { id = "automationTabButton", widget = "button", itemVariant = "secondary_action", textKey = "LAYOUTS_AUTOMATION" },
        },
    },
    {
        section = "ContentHost",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            border = false,
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "active Layouts subpage content",
            },
        },
        items = {},
    },
    {
        section = "ActiveProfile",
        properties = {
            parentSection = "ContentHost",
            sectionKind = "section",
            type = "info_block",
            variant = "key_value",
            surfaceStyle = "status_panel",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "activeProfileLabel + activeProfileValue + savePresetButton + spacing",
            },
        },
        items = {
            { id = "activeProfileLabel", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_CURRENT_ACTIVE" },
            { id = "activeProfileValue", widget = "label", itemVariant = "status_value", text = "" },
            { id = "savePresetButton", widget = "button", itemVariant = "secondary_action", textKey = "PRESET_SAVE_AS" },
        },
    },
    {
        section = "ColumnContainer",
        properties = {
            parentSection = "ContentHost",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "wide_dual_column",
            surfaceStyle = "workspace_split",
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "max(LeftColumn.heightInfo, RightColumn.heightInfo)",
            },
        },
        items = {},
    },
    {
        section = "LeftColumn",
        properties = {
            parentSection = "ColumnContainer",
            sectionKind = "widget_group",
            type = "column",
            variant = "spacious_form_column",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                value = 350,
                derivedFrom = "(ColumnContainer.widthInfo.value - 36) / 2",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "source title + source hint + dropdown + buttons + sourceState + spacing",
            },
        },
        items = {
            { id = "sourceTitle", widget = "label", itemVariant = "group_title", textKey = "INFO_PROFILES_SOURCE_PICK" },
            { id = "sourceHint", widget = "label", itemVariant = "group_description", textKey = "INFO_PROFILES_SOURCE_PICK_HINT_SHORT" },
            { id = "profileSelect", widget = "dropdown", itemVariant = "profile_field", labelKey = "INFO_PROFILES_SOURCE_PROFILE" },
            { id = "activateButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_PROFILES_ACTIVATE" },
            { id = "copyButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_PROFILES_COPY_FROM" },
            { id = "sourceState", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
    {
        section = "RightColumn",
        properties = {
            parentSection = "ColumnContainer",
            sectionKind = "widget_group",
            type = "column",
            variant = "spacious_form_column",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                value = 350,
                derivedFrom = "(ColumnContainer.widthInfo.value - 36) / 2",
            },
            heightInfo = {
                source = "content",
                min = 100,
                derivedFrom = "create title + create hint + nameEdit + createButton + spacing",
            },
        },
        items = {
            { id = "createTitle", widget = "label", itemVariant = "group_title", textKey = "INFO_PROFILES_CREATE_SIMPLE" },
            { id = "createHint", widget = "label", itemVariant = "group_description", textKey = "INFO_PROFILES_CREATE_SIMPLE_HINT_SHORT" },
            { id = "nameEdit", widget = "editbox", itemVariant = "profile_field", labelKey = "INFO_PROFILES_NAME", stateKey = "newProfileName" },
            { id = "createButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_PROFILES_CREATE_AND_SWITCH" },
            { id = "createState", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
    {
        section = "BottomBlock",
        properties = {
            parentSection = "ContentHost",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "section_panel",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "Root.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "section title + ActionRow + BottomHint + spacing",
            },
        },
        items = {
            { id = "maintenanceTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_MAINTENANCE" },
        },
    },
    {
        section = "ActionRow",
        properties = {
            parentSection = "BottomBlock",
            sectionKind = "widget_group",
            structure = {
                header = {
                    present = true,
                    optional = true,
                },
                body = {
                    present = true,
                    section = "ActionRow",
                },
                footer = {
                    present = true,
                    optional = false,
                    section = "BottomHint",
                },
            },
            type = "action_row",
            variant = "four_button",
            padding = {
                left = 8,
                right = 8,
                top = 4,
                bottom = 4,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "BottomBlock.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 32,
                derivedFrom = "action row: exportButton + importButton + resetButton + deleteButton",
            },
        },
        items = {
            { id = "exportButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_PROFILES_EXPORT" },
            { id = "importButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_PROFILES_IMPORT" },
            { id = "resetButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_PROFILES_RESET" },
            { id = "deleteButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_PROFILES_DELETE_SHORT" },
        },
    },
    {
        section = "BottomHint",
        properties = {
            parentSection = "BottomBlock",
            sectionKind = "widget_group_footer",
            structureSlot = "footer",
            widgetGroup = "ActionRow",
            type = "info_block",
            variant = "note_text",
            padding = {
                left = 8,
                right = 8,
                top = 3,
                bottom = 3,
            },
            widthInfo = {
                source = "parent",
                value = 736,
                derivedFrom = "BottomBlock.widthInfo.value",
            },
            heightInfo = {
                source = "content",
                min = 20,
                derivedFrom = "maintenanceHint label",
            },
        },
        items = {
            { id = "maintenanceHint", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
}

ns.GUI.Layouts.Profile.TransferExport = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 8,
                bottom = 10,
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
                top = 5,
                bottom = 5,
            },
            heightInfo = {
                source = "content",
                min = 64,
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "section_title_large", textKey = "INFO_PROFILES_EXPORT_HEADING" },
            { id = "intro", widget = "label", itemVariant = "page_intro_soft", textKey = "INFO_PROFILES_EXPORT_DESC" },
        },
    },
    {
        section = "ExportBody",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "transfer_body",
            surfaceStyle = "section_panel",
            padding = {
                left = 10,
                right = 10,
                top = 6,
                bottom = 6,
            },
        },
        items = {
            { id = "exportStringTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_EXPORT_STRING" },
            { id = "transferText", widget = "multilineeditbox", itemVariant = "profile_transfer_box", labelKey = "INFO_PROFILES_EXPORT_STRING", stateKey = "transferText", numLines = 9, hideLabel = true },
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
            gapBefore = 6,
            heightInfo = {
                source = "content",
                min = 32,
            },
        },
        items = {
            { id = "selectAllButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_PROFILES_EXPORT_SELECT_STRING" },
            { id = "okButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CLOSE" },
        },
    },
}

ns.GUI.Layouts.Profile.TransferImport = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 8,
                bottom = 10,
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
                top = 5,
                bottom = 5,
            },
            heightInfo = {
                source = "content",
                min = 64,
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "section_title_large", textKey = "INFO_PROFILES_IMPORT_HEADING" },
            { id = "intro", widget = "label", itemVariant = "page_intro_soft", textKey = "INFO_PROFILES_IMPORT_DESC" },
        },
    },
    {
        section = "ImportBody",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "transfer_body",
            surfaceStyle = "section_panel",
            padding = {
                left = 10,
                right = 10,
                top = 6,
                bottom = 6,
            },
        },
        items = {
            { id = "importStringTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_IMPORT_STRING" },
            { id = "transferText", widget = "multilineeditbox", itemVariant = "profile_transfer_box", labelKey = "INFO_PROFILES_IMPORT_STRING", stateKey = "transferText", numLines = 8, hideLabel = true },
            { id = "profileNameEdit", widget = "editbox", itemVariant = "profile_field", labelKey = "INFO_PROFILES_IMPORT_PROFILE_NAME", stateKey = "profileName" },
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
            gapBefore = 6,
            heightInfo = {
                source = "content",
                min = 32,
            },
        },
        items = {
            { id = "okButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_COMMON_OK" },
            { id = "cancelButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CLOSE" },
        },
    },
    {
        section = "BottomHint",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "info_block",
            variant = "note_text",
            padding = {
                left = 8,
                right = 8,
                top = 3,
                bottom = 3,
            },
            heightInfo = {
                source = "content",
                min = 20,
            },
        },
        items = {
            { id = "statusText", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
}

ns.GUI.Layouts.Profile.TransferOverwriteConfirm = {
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
                min = 120,
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "section_title_large", textKey = "INFO_PROFILES_IMPORT_OVERWRITE_TITLE" },
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
            { id = "overwriteButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_PROFILES_IMPORT_OVERWRITE_CONFIRM" },
            { id = "cancelButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CANCEL" },
        },
    },
}

ns.GUI.Layouts.Profile.SavePreset = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 12,
                right = 12,
                top = 8,
                bottom = 10,
            },
        },
        items = {},
    },
    {
        section = "Body",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "transfer_body",
            surfaceStyle = "section_panel",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
        },
        items = {
            { id = "profileNameEdit", widget = "editbox", itemVariant = "profile_field", labelKey = "PRESET_NAME", stateKey = "profileName" },
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
            gapBefore = 6,
            heightInfo = {
                source = "content",
                min = 32,
            },
        },
        items = {
            { id = "okButton", widget = "button", itemVariant = "primary_action", textKey = "PRESET_SAVE_AS" },
            { id = "cancelButton", widget = "button", itemVariant = "secondary_action", textKey = "INFO_COMMON_CANCEL" },
        },
    },
    {
        section = "BottomHint",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "info_block",
            variant = "note_text",
            padding = {
                left = 8,
                right = 8,
                top = 3,
                bottom = 3,
            },
            heightInfo = {
                source = "content",
                min = 20,
            },
        },
        items = {
            { id = "statusText", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
}
