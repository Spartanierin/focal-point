local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

--[[
Declarative "how" definitions for reusable form elements.

Goal:
- keep one shared vocabulary for form sections and form items
- let layout files reference semantic IDs instead of page-specific style tables
- allow page-specific exceptions only through explicit dedicated IDs

Usage:
- layout files declare section type + variant and item widget + itemVariant
- page readers resolve those keys against this shared table
- explicit values in layout files override these defaults
- nested info blocks such as heightInfo are merged, so layout files can add
  derivedFrom notes while shared definitions provide baseline defaults such as min

Form baseline rules:
1. Every form page has a header section with a page title and page description.
2. Every section receives a border by default unless it explicitly opts out.
3. Frame-to-frame section gaps are modeled explicitly with spacer containers, not with parent layout spacing.
4. Any section that is not marked as a header or footer is treated as a content section.
5. Every semantic section should expose a section title and a short section description.
6. Content sections can contain widget groups; widget groups never receive a border by default.
7. Every widget group owns a structural header, body, and footer. Header and footer may stay empty, but they remain part of the structure.
8. Sections can explicitly declare whether they belong to a widget group's header, body, or footer.
]]
ns.GUI.Layouts.FormElements = {
    Palette = {
        Chrome = {
            panelBackground = { 0.06, 0.07, 0.09, 0.94 },
            panelBorder = { 0.42, 0.38, 0.26, 0.92 },
            panelInnerBorder = { 0.18, 0.20, 0.24, 0.92 },
            panelHeader = { 0.11, 0.12, 0.15, 0.82 },
            panelTopShade = { 1.00, 1.00, 1.00, 0.05 },
            panelBottomShade = { 0.00, 0.00, 0.00, 0.42 },
            fieldBackground = { 0.10, 0.11, 0.14, 0.96 },
            fieldBorder = { 0.31, 0.34, 0.39, 0.95 },
            fieldBorderFocus = { 0.74, 0.61, 0.26, 0.95 },
            fieldInsetTop = { 1.00, 1.00, 1.00, 0.04 },
            fieldInsetBottom = { 0.00, 0.00, 0.00, 0.28 },
            accent = { 0.83, 0.70, 0.30, 0.22 },
            sectionBorder = { 0.30, 0.33, 0.38, 0.56 },
            sectionFill = { 0.09, 0.10, 0.12, 0.52 },
            sectionFillStrong = { 0.11, 0.12, 0.15, 0.66 },
            sectionInsetTop = { 1.00, 1.00, 1.00, 0.035 },
            sectionInsetBottom = { 0.00, 0.00, 0.00, 0.26 },
            sectionAccent = { 0.83, 0.70, 0.30, 0.26 },
            headerAccent = { 0.90, 0.78, 0.34, 0.42 },
            workspaceDivider = { 0.34, 0.37, 0.42, 0.24 },
        },
        ItemColors = {
            pageIntro = { 0.78, 0.75, 0.69, 1.00 },
            description = { 0.68, 0.70, 0.75 },
            sectionDescription = { 0.65, 0.67, 0.72, 1.00 },
            hint = { 0.70, 0.73, 0.78 },
            statusMuted = { 0.58, 0.61, 0.66, 1.00 },
            footerHint = { 0.62, 0.65, 0.70 },
            footerMuted = { 0.52, 0.55, 0.60, 1.00 },
            value = { 0.93, 0.90, 0.80 },
            valueEmphasis = { 0.97, 0.95, 0.91, 1.00 },
            checkbox = { 0.94, 0.90, 0.82, 1.00 },
            checkboxDisabled = { 0.50, 0.50, 0.50, 1.00 },
        },
    },
    SectionStyles = {
        page_header = {
            border = {
                color = { 0.40, 0.36, 0.24, 0.72 },
                thickness = 1,
                inset = 0,
            },
            surface = {
                fill = { 0.12, 0.13, 0.16, 0.70 },
                topShade = { 1.00, 1.00, 1.00, 0.04 },
                bottomShade = { 0.00, 0.00, 0.00, 0.28 },
                accent = {
                    color = { 0.90, 0.78, 0.34, 0.40 },
                    edge = "bottom",
                    thickness = 1,
                    insetLeft = 10,
                    insetRight = 10,
                },
            },
        },
        status_panel = {
            border = {
                color = { 0.37, 0.35, 0.25, 0.54 },
                thickness = 1,
                inset = 0,
            },
            surface = {
                fill = { 0.10, 0.11, 0.13, 0.58 },
                topShade = { 1.00, 1.00, 1.00, 0.03 },
                bottomShade = { 0.00, 0.00, 0.00, 0.24 },
                accent = {
                    color = { 0.86, 0.74, 0.30, 0.18 },
                    edge = "top",
                    thickness = 1,
                    insetLeft = 10,
                    insetRight = 10,
                },
            },
        },
        section_panel = {
            border = {
                color = { 0.30, 0.33, 0.38, 0.58 },
                thickness = 1,
                inset = 0,
            },
            surface = {
                fill = { 0.09, 0.10, 0.12, 0.48 },
                topShade = { 1.00, 1.00, 1.00, 0.03 },
                bottomShade = { 0.00, 0.00, 0.00, 0.24 },
            },
        },
        result_panel = {
            border = {
                color = { 0.41, 0.37, 0.25, 0.68 },
                thickness = 1,
                inset = 0,
            },
            surface = {
                fill = { 0.11, 0.12, 0.15, 0.62 },
                topShade = { 1.00, 1.00, 1.00, 0.04 },
                bottomShade = { 0.00, 0.00, 0.00, 0.28 },
                accent = {
                    color = { 0.88, 0.76, 0.31, 0.24 },
                    edge = "top",
                    thickness = 1,
                    insetLeft = 10,
                    insetRight = 10,
                },
            },
        },
        workspace_split = {
            border = false,
            surface = {
                divider = {
                    mode = "center_vertical",
                    color = { 0.34, 0.37, 0.42, 0.24 },
                    thickness = 1,
                    insetTop = 12,
                    insetBottom = 12,
                },
            },
        },
    },
    ButtonStyles = {
        primary = {
            sidebarVariant = "primary",
            height = 24,
            textRole = "label",
            textColor = { 0.96, 0.92, 0.84, 1.00 },
            normal = { 0.42, 0.29, 0.10, 0.98 },
            pushed = { 0.29, 0.20, 0.08, 0.98 },
            highlight = { 0.56, 0.39, 0.14, 0.98 },
            disabled = { 0.18, 0.15, 0.11, 0.82 },
        },
        secondary = {
            sidebarVariant = "secondary",
            height = 22,
            textRole = "label",
            textColor = { 0.87, 0.89, 0.92, 1.00 },
            normal = { 0.16, 0.18, 0.21, 0.96 },
            pushed = { 0.11, 0.13, 0.16, 0.98 },
            highlight = { 0.24, 0.27, 0.31, 0.98 },
            disabled = { 0.11, 0.12, 0.14, 0.82 },
        },
        danger = {
            sidebarVariant = "danger",
            height = 22,
            textRole = "danger",
            textColor = { 0.95, 0.88, 0.88, 1.00 },
            normal = { 0.41, 0.07, 0.07, 0.98 },
            pushed = { 0.27, 0.04, 0.04, 0.98 },
            highlight = { 0.56, 0.10, 0.10, 0.98 },
            disabled = { 0.17, 0.08, 0.08, 0.82 },
        },
    },
    FieldStyles = {
        accented = {
            background = { 0.10, 0.11, 0.14, 0.96 },
            border = { 0.31, 0.34, 0.39, 0.95 },
            borderFocus = { 0.48, 0.18, 0.18, 0.95 },
            valueColor = { 0.93, 0.90, 0.80, 1.00 },
            buttonNormal = { 0.31, 0.34, 0.39, 0.95 },
            buttonPushed = { 0.23, 0.08, 0.08, 0.98 },
            buttonHighlight = { 0.48, 0.18, 0.18, 0.95 },
        },
        neutral = {
            background = { 0.10, 0.11, 0.14, 0.96 },
            border = { 0.31, 0.34, 0.39, 0.95 },
            borderFocus = { 0.44, 0.47, 0.52, 0.95 },
            valueColor = { 0.93, 0.90, 0.80, 1.00 },
            buttonNormal = { 0.31, 0.34, 0.39, 0.95 },
            buttonPushed = { 0.31, 0.34, 0.39, 0.95 },
            buttonHighlight = { 0.31, 0.34, 0.39, 0.95 },
        },
        editor_inset = {
            background = { 0.07, 0.08, 0.10, 0.98 },
            border = { 0.31, 0.29, 0.20, 0.92 },
            borderFocus = { 0.74, 0.61, 0.26, 0.95 },
            valueColor = { 0.95, 0.93, 0.89, 1.00 },
            buttonNormal = { 0.31, 0.29, 0.20, 0.92 },
            buttonPushed = { 0.23, 0.18, 0.08, 0.98 },
            buttonHighlight = { 0.46, 0.36, 0.14, 0.98 },
            insetTop = { 1.00, 1.00, 1.00, 0.04 },
            insetBottom = { 0.00, 0.00, 0.00, 0.30 },
        },
    },
    Sections = {
        stack_block = {
            window_content = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 0,
                fullWidth = true,
                fullHeight = true,
            },
            section_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 8,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
        },
        root = {
            window_content = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 0,
                fullWidth = true,
                fullHeight = true,
                border = false,
            },
            scroll_content = {
                widget = "ScrollFrame",
                layout = "RootContent",
                border = false,
            },
        },
        header = {
            page_header = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 8,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
        },
        info_block = {
            key_value = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 4,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            note_text = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 0,
                heightInfo = {
                    source = "content",
                    min = 20,
                },
            },
        },
        section = {
            editor_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 4,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            preview_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 3,
                heightInfo = {
                    source = "content",
                    min = 80,
                },
            },
            compact_input_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 2,
                heightInfo = {
                    source = "content",
                    min = 72,
                },
            },
            management_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 4,
                heightInfo = {
                    source = "content",
                    min = 84,
                },
            },
            result_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 3,
                heightInfo = {
                    source = "content",
                    min = 68,
                },
            },
            usage_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 3,
                heightInfo = {
                    source = "content",
                    min = 96,
                },
            },
            note_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 0,
                heightInfo = {
                    source = "content",
                    min = 20,
                },
            },
            note_block = {
                widget = "SimpleGroup",
                layout = "SimpleGroup",
                layoutMode = "List",
                fullWidth = true,
                heightInfo = {
                    source = "content",
                    min = 20,
                },
            },
            details_stack = {
                widget = "SimpleGroup",
                layout = "SimpleGroup",
                layoutMode = "List",
                fullWidth = true,
                heightInfo = {
                    source = "content",
                    min = 180,
                },
            },
        },
        column_container = {
            wide_dual_column = {
                widget = "SimpleGroup",
                layout = "TwoColumnGroup",
                spacing = 36,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            compact_dual_column = {
                widget = "SimpleGroup",
                layout = "TwoColumnGroup",
                spacing = 16,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            four_column = {
                widget = "SimpleGroup",
                layout = "FourColumnGroup",
                spacing = 10,
                heightInfo = {
                    source = "content",
                    min = 28,
                },
            },
            flow_row = {
                widget = "SimpleGroup",
                layout = "SimpleGroup",
                layoutMode = "Flow",
                fullWidth = true,
                heightInfo = {
                    source = "content",
                    min = 120,
                },
            },
        },
        column = {
            spacious_form_column = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 8,
                fullWidth = true,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            compact_form_column = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 6,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            fixed_list = {
                widget = "SimpleGroup",
                layout = "SimpleGroup",
                layoutMode = "List",
                width = 332,
                heightInfo = {
                    source = "content",
                    min = 120,
                },
            },
        },
        action_row = {
            single_button = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 0,
                heightInfo = {
                    source = "content",
                    min = 32,
                },
            },
            dual_button = {
                widget = "SimpleGroup",
                layout = "TwoColumnGroup",
                spacing = 12,
                heightInfo = {
                    source = "content",
                    min = 32,
                },
            },
            triple_button = {
                widget = "SimpleGroup",
                layout = "SimpleGroup",
                layoutMode = "Table",
                fullWidth = true,
                layoutTable = {
                    columns = {
                        { weight = 1 },
                        { weight = 1 },
                        { weight = 1 },
                    },
                    spaceH = 12,
                    spaceV = 0,
                    align = "TOPLEFT",
                    alignV = "start",
                    alignH = "start",
                },
                heightInfo = {
                    source = "content",
                    min = 32,
                },
            },
        },
    },
    Items = {
        label = {
            page_title = {
                role = "sectionHeader",
                size = 18,
            },
            page_title_hero = {
                role = "sectionHeader",
                size = 18,
            },
            page_intro = {
                role = "help",
                size = 11,
                colorKey = "description",
                fullWidth = true,
            },
            page_intro_soft = {
                role = "help",
                size = 11,
                colorKey = "pageIntro",
                fullWidth = true,
            },
            example_text_muted = {
                role = "help",
                size = 9,
                colorKey = "footerMuted",
                fullWidth = true,
            },
            section_title = {
                role = "sectionHeader",
                size = 13,
            },
            section_title_large = {
                role = "sectionHeader",
                size = 14,
            },
            group_title = {
                role = "sectionHeader",
                size = 13,
            },
            section_description = {
                role = "help",
                size = 10,
                colorKey = "description",
            },
            group_description = {
                role = "help",
                size = 10,
                colorKey = "sectionDescription",
            },
            description_text = {
                role = "help",
                size = 11,
                colorKey = "description",
            },
            description_text_body = {
                role = "label",
                size = 11,
                colorKey = "description",
            },
            field_help = {
                role = "help",
                size = 10,
                colorKey = "description",
            },
            field_label = {
                role = "label",
                size = 12,
                colorKey = "description",
            },
            field_label_subtle = {
                role = "label",
                size = 11,
                colorKey = "sectionDescription",
            },
            status_hint = {
                role = "help",
                size = 9,
                colorKey = "hint",
            },
            status_hint_subtle = {
                role = "help",
                size = 8,
                colorKey = "statusMuted",
            },
            footer_hint = {
                role = "help",
                size = 8,
                colorKey = "footerHint",
            },
            footer_hint_muted = {
                role = "help",
                size = 8,
                colorKey = "footerMuted",
            },
            preview_hint_subtle = {
                role = "help",
                size = 9,
                colorKey = "sectionDescription",
            },
            hint_text = {
                role = "help",
                size = 10,
                colorKey = "hint",
            },
            hint_text_body = {
                role = "label",
                size = 11,
                colorKey = "hint",
            },
            value_display = {
                role = "highlight",
                size = 18,
                colorKey = "value",
            },
            status_value = {
                role = "highlight",
                size = 22,
                colorKey = "valueEmphasis",
                justifyH = "LEFT",
            },
            detail_value_primary = {
                role = "highlight",
                size = 24,
                colorKey = "valueEmphasis",
                justifyH = "LEFT",
            },
            detail_value_secondary = {
                role = "highlight",
                size = 20,
                colorKey = "value",
                justifyH = "LEFT",
            },
            result_value_hero = {
                role = "highlight",
                size = 24,
                colorKey = "valueEmphasis",
                justifyH = "LEFT",
            },
            value_display_large = {
                role = "highlight",
                size = 20,
                colorKey = "value",
                justifyH = "LEFT",
            },
            value_display_small = {
                role = "highlight",
                size = 15,
                colorKey = "value",
            },
            value_text = {
                role = "highlight",
                size = 12,
                colorKey = "value",
            },
            usage_label = {
                role = "label",
                size = 12,
                colorKey = "value",
            },
            body_text = {
                role = "label",
                size = 12,
            },
            spacer_small = {
                role = "label",
                size = 6,
            },
            spacer_xsmall = {
                role = "label",
                size = 4,
            },
        },
        computed_label = {
            hint_text = {
                role = "help",
                size = 10,
                colorKey = "hint",
            },
            example_text_muted = {
                role = "help",
                size = 9,
                colorKey = "footerMuted",
                fullWidth = true,
            },
        },
        button = {
            primary_action = {
                buttonVariant = "primary",
            },
            secondary_action = {
                buttonVariant = "secondary",
            },
            danger_action = {
                buttonVariant = "danger",
            },
        },
        dropdown = {
            form_field = {
                fullWidth = true,
            },
            profile_field = {
                fullWidth = true,
                fieldVariant = "editor_inset",
            },
            builder_field = {
                fullWidth = true,
                fieldVariant = "editor_inset",
            },
            fixed_width_field = {
                fullWidth = true,
                fieldVariant = "editor_inset",
            },
        },
        editbox = {
            form_field = {
                fullWidth = true,
                disableButton = true,
            },
            profile_field = {
                fullWidth = true,
                disableButton = true,
                fieldVariant = "editor_inset",
            },
            builder_field = {
                fullWidth = true,
                disableButton = true,
                fieldVariant = "editor_inset",
            },
        },
        checkbox = {
            unit_toggle = {
                checked = false,
                disabled = true,
                fullWidth = true,
            },
            usage_toggle = {
                checked = false,
                disabled = true,
                fullWidth = false,
                width = 160,
            },
            usage_toggle_grid = {
                checked = false,
                disabled = true,
                fullWidth = true,
            },
        },
    },
}
