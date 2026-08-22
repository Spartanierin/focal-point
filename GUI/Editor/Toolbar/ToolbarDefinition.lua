local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}
ns.GUI.Layouts.Editor = ns.GUI.Layouts.Editor or {}

--[[
Declarative form layout for the persistent editor toolbar.

Goal:
- describe the left editor toolbar as a deterministic vertical form
- keep section order, sizing intent, and workspace geometry readable
- avoid future "grow a widget tree until it works" regressions

Important notes:
- This file is intentionally descriptive first; runtime wiring comes later.
- The workspace area is modeled as a fixed form block, not as nested auto-height
  flow/list/table containers.
- The editor and tool workspace bodies are mutually exclusive at runtime, but
  both are declared here so the structure stays explicit.
]]
ns.GUI.Layouts.Editor.ToolbarForm = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "stack_block",
            variant = "window_content",
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "EditorToolbarHost.width",
            },
            heightInfo = {
                source = "parent",
                derivedFrom = "EditorToolbarHost.height",
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
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 48,
                derivedFrom = "brandLine + versionLine + spacing",
            },
        },
        items = {
            { id = "brandLine", widget = "label", itemVariant = "page_title_hero", text = "" },
            { id = "versionLine", widget = "label", itemVariant = "page_intro_soft", text = "" },
        },
    },
    {
        section = "Composition",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "toolbar_workspace_panel",
            spacing = 6,
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 172,
                derivedFrom = "composition title + tree scroll",
            },
        },
        items = {
            { id = "compositionTitle", widget = "label", itemVariant = "section_title", textKey = "EDITOR_SECTION_COMPOSITION_TREE" },
            { id = "compositionTree", widget = "compositionTree" },
        },
    },
    {
        section = "Workspace",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "toolbar_workspace_panel",
            spacing = 6,
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "workspace title + editor body or tool body + spacing",
            },
        },
        items = {
        },
    },
    {
        section = "WorkspaceEditorBody",
        properties = {
            parentSection = "Workspace",
            sectionKind = "section",
            type = "section",
            variant = "note_stack",
            spacing = 6,
            border = false,
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Workspace.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "unit label + grid + expert checkbox",
            },
            runtime = {
                visibleWhen = "editor_shell_mode",
            },
        },
        items = {
            { id = "unitLabel", widget = "label", itemVariant = "section_title", textKey = "EDITOR_UNIT" },
        },
    },
    {
        section = "UnitGrid",
        properties = {
            parentSection = "WorkspaceEditorBody",
            sectionKind = "section",
            type = "column",
            variant = "compact_form_column",
            border = false,
            spacing = 4,
            structure = {
                mode = "fixed_grid",
                columns = 2,
                rows = 4,
            },
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "WorkspaceEditorBody.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "4 unit rows",
            },
        },
        items = {},
    },
    {
        section = "UnitGridRow1",
        properties = {
            parentSection = "UnitGrid",
            sectionKind = "section",
            type = "action_row",
            variant = "dual_button",
            border = false,
            widthInfo = {
                source = "parent",
                derivedFrom = "UnitGrid.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "fixed unit button row height",
            },
        },
        items = {
            { id = "playerButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_PLAYER" },
            { id = "targetButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_TARGET" },
        },
    },
    {
        section = "UnitGridRow2",
        properties = {
            parentSection = "UnitGrid",
            sectionKind = "section",
            type = "action_row",
            variant = "dual_button",
            border = false,
            widthInfo = {
                source = "parent",
                derivedFrom = "UnitGrid.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "fixed unit button row height",
            },
        },
        items = {
            { id = "targetTargetButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_TARGETTARGET" },
            { id = "petButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_PET" },
        },
    },
    {
        section = "UnitGridRow3",
        properties = {
            parentSection = "UnitGrid",
            sectionKind = "section",
            type = "action_row",
            variant = "dual_button",
            border = false,
            widthInfo = {
                source = "parent",
                derivedFrom = "UnitGrid.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "fixed unit button row height",
            },
        },
        items = {
            { id = "focusButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_FOCUS" },
            { id = "focusTargetButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_FOCUSTARGET" },
        },
    },
    {
        section = "UnitGridRow4",
        properties = {
            parentSection = "UnitGrid",
            sectionKind = "section",
            type = "action_row",
            variant = "dual_button",
            border = false,
            widthInfo = {
                source = "parent",
                derivedFrom = "UnitGrid.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "fixed unit button row height",
            },
        },
        items = {
            { id = "bossButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "UNIT_BOSS" },
            { id = "bossSpacer", widget = "label", itemVariant = "footer_hint_muted", text = "" },
        },
    },
    {
        section = "WorkspaceEditorFooter",
        properties = {
            parentSection = "WorkspaceEditorBody",
            sectionKind = "section",
            type = "section",
            variant = "note_stack",
            border = false,
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "WorkspaceEditorBody.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "single checkbox row",
            },
        },
        items = {
            { id = "expertMode", widget = "checkbox", itemVariant = "default_checkbox", textKey = "OPTION_EXPERT_MODE" },
        },
    },
    {
        section = "WorkspaceToolBody",
        properties = {
            parentSection = "Workspace",
            sectionKind = "widget_group",
            type = "stack_block",
            variant = "section_stack",
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Workspace.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 92,
                derivedFrom = "tool hint + active unit + return button",
            },
            runtime = {
                visibleWhen = "tool_shell_mode",
            },
        },
        items = {
            { id = "toolHint", widget = "label", itemVariant = "group_description", textKey = "EDITOR_TOOL_CONTEXT_HINT" },
            { id = "toolSelectedUnit", widget = "label", itemVariant = "status_value", text = "" },
            { id = "returnToEditor", widget = "button", itemVariant = "primary_action", textKey = "EDITOR_RETURN_TO_EDITOR" },
        },
    },
    {
        section = "Editing",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "toolbar_editing_panel",
            spacing = 6,
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 64,
                derivedFrom = "section title + preview button + preview hint",
            },
        },
        items = {
            { id = "editingTitle", widget = "label", itemVariant = "section_title", textKey = "EDITOR_CONTEXT_PREVIEW" },
            { id = "demoButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "EDITOR_TEST_MODE" },
        },
    },
    {
        section = "EditingHint",
        properties = {
            parentSection = "Editing",
            sectionKind = "section",
            type = "section",
            variant = "note_stack",
            border = false,
            padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Editing.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 1,
                derivedFrom = "preview hint",
            },
        },
        items = {
            { id = "editingHint", widget = "label", itemVariant = "group_description", textKey = "EDITOR_PREVIEW_HINT", size = 11 },
        },
    },
    {
        section = "Global",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "toolbar_global_panel",
            spacing = 6,
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 56,
                derivedFrom = "title + options action",
            },
        },
        items = {
            { id = "globalTitle", widget = "label", itemVariant = "section_title", textKey = "EDITOR_CONTEXT_GLOBAL" },
            { id = "globalOptions", widget = "button", itemVariant = "secondary_action", textKey = "OPTION_OPTIONS" },
        },
    },
    {
        section = "Secondary",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            surfaceStyle = "toolbar_global_panel",
            spacing = 4,
            padding = {
                left = 8,
                right = 8,
                top = 6,
                bottom = 6,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 148,
                derivedFrom = "secondary dialog access buttons",
            },
        },
        items = {
            { id = "toolsTitle", widget = "label", itemVariant = "footer_hint_muted", textKey = "EDITOR_CONTEXT_TOOLS", size = 10 },
            { id = "manageLayoutsButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "NAV_MANAGE_LAYOUTS" },
            { id = "layoutAssignmentsButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "NAV_LAYOUT_ASSIGNMENTS" },
            { id = "profilesButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "NAV_PROFILES" },
            { id = "textBuilderButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "NAV_TEXT_BUILDER" },
            { id = "tagDatabaseButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "INFO_TAG_DATABASE_TITLE" },
        },
    },
    {
        section = "Footer",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "stack_block",
            variant = "section_stack",
            border = false,
            padding = {
                left = 0,
                right = 0,
                top = 2,
                bottom = 0,
            },
            widthInfo = {
                source = "parent",
                derivedFrom = "Root.widthInfo",
            },
            heightInfo = {
                source = "content",
                min = 38,
                derivedFrom = "close action + muted footer note",
            },
        },
        items = {
            { id = "closeButton", widget = "button", itemVariant = "toolbar_secondary_action", textKey = "CLOSE" },
            { id = "footerNote", widget = "label", itemVariant = "footer_hint_muted", textKey = "EDITOR_PREVIEW_NOTE", size = 9 },
        },
    },
}
