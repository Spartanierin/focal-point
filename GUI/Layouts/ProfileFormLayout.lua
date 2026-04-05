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
                top = 10,
                bottom = 16,
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
            variant = "spacious_info_stack",
            padding = {
                left = 10,
                right = 10,
                top = 6,
                bottom = 6,
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
            { id = "title", widget = "label", itemVariant = "page_title", textKey = "NAV_PROFILES", textFallback = "Profile" },
            { id = "intro", widget = "label", itemVariant = "page_intro", textKey = "INFO_PROFILES_DESCRIPTION_SHORT", textFallback = "Aktives Profil sehen, Quelle uebernehmen oder ein neues Profil anlegen." },
        },
    },
    {
        section = "ActiveProfile",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "info_block",
            variant = "key_value",
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
                derivedFrom = "activeProfileLabel + activeProfileValue + spacing",
            },
        },
        items = {
            { id = "activeProfileLabel", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_CURRENT_ACTIVE", textFallback = "Aktives Profil" },
            { id = "activeProfileValue", widget = "label", itemVariant = "value_display", text = "" },
        },
    },
    {
        section = "ColumnContainer",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "wide_dual_column",
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
            { id = "sourceTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_SOURCE_PICK", textFallback = "Profil von anderer Unit uebernehmen" },
            { id = "sourceHint", widget = "label", itemVariant = "section_description", textKey = "INFO_PROFILES_SOURCE_PICK_HINT_SHORT", textFallback = "Quelle waehlen und in das aktive Profil uebernehmen." },
            { id = "profileSelect", widget = "dropdown", itemVariant = "form_field", labelKey = "INFO_PROFILES_SOURCE_PROFILE", labelFallback = "Quellprofil" },
            { id = "activateButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_PROFILES_ACTIVATE", textFallback = "Aktivieren" },
            { id = "copyButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_PROFILES_COPY_FROM", textFallback = "In aktives Profil kopieren" },
            { id = "sourceState", widget = "label", itemVariant = "status_hint", text = "" },
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
            { id = "createTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_CREATE_SIMPLE", textFallback = "Neues Profil anlegen" },
            { id = "createHint", widget = "label", itemVariant = "section_description", textKey = "INFO_PROFILES_CREATE_SIMPLE_HINT_SHORT", textFallback = "Namen vergeben und direkt in das neue Profil wechseln." },
            { id = "nameEdit", widget = "editbox", itemVariant = "form_field", labelKey = "INFO_PROFILES_NAME", labelFallback = "Profilname", stateKey = "newProfileName" },
            { id = "createButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_PROFILES_CREATE_AND_SWITCH", textFallback = "Erstellen und wechseln" },
        },
    },
    {
        section = "BottomBlock",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
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
            { id = "maintenanceTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_PROFILES_MAINTENANCE", textFallback = "Profilwartung" },
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
            variant = "dual_button",
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
                derivedFrom = "single action row: resetButton + deleteButton",
            },
        },
        items = {
            { id = "resetButton", widget = "button", itemVariant = "primary_action", textKey = "INFO_PROFILES_RESET", textFallback = "Zuruecksetzen" },
            { id = "deleteButton", widget = "button", itemVariant = "danger_action", textKey = "INFO_PROFILES_DELETE_SHORT", textFallback = "Loeschen" },
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
            { id = "maintenanceHint", widget = "label", itemVariant = "footer_hint", text = "" },
        },
    },
}
