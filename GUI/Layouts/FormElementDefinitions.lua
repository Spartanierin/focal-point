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
            panelBackground = { 0.07, 0.08, 0.10, 0.90 },
            panelBorder = { 1.00, 1.00, 1.00, 1.00 },
            panelHeader = { 0.10, 0.11, 0.14, 0.70 },
            fieldBackground = { 0.10, 0.11, 0.14, 0.96 },
            fieldBorder = { 0.31, 0.34, 0.39, 0.95 },
            accent = { 0.83, 0.70, 0.30, 0.35 },
            sectionBorder = { 0.31, 0.34, 0.39, 0.70 },
        },
        Buttons = {
            primary = { 0.34, 0.12, 0.12, 0.95 },
            pressed = { 0.23, 0.08, 0.08, 0.98 },
            highlight = { 0.48, 0.18, 0.18, 0.95 },
            disabled = { 0.19, 0.12, 0.12, 0.90 },
            text = { 0.95, 0.91, 0.88, 1.00 },
        },
        ItemColors = {
            description = { 0.68, 0.70, 0.75 },
            hint = { 0.70, 0.73, 0.78 },
            footerHint = { 0.62, 0.65, 0.70 },
            value = { 0.93, 0.90, 0.80 },
            checkbox = { 0.94, 0.90, 0.82, 1.00 },
            checkboxDisabled = { 0.50, 0.50, 0.50, 1.00 },
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
            },
            scroll_content = {
                widget = "ScrollFrame",
                layout = "RootContent",
            },
        },
        header = {
            spacious_info_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 8,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            compact_info_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 8,
                heightInfo = {
                    source = "content",
                    min = 80,
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
            usage_stack = {
                widget = "SimpleGroup",
                layout = "VerticalGroup",
                spacing = 4,
                heightInfo = {
                    source = "content",
                    min = 120,
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
                spacing = 20,
                heightInfo = {
                    source = "content",
                    min = 85,
                },
            },
            four_column = {
                widget = "SimpleGroup",
                layout = "FourColumnGroup",
                spacing = 16,
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
            page_intro = {
                role = "help",
                size = 11,
                colorKey = "description",
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
            section_description = {
                role = "help",
                size = 10,
                colorKey = "description",
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
            status_hint = {
                role = "help",
                size = 9,
                colorKey = "hint",
            },
            footer_hint = {
                role = "help",
                size = 8,
                colorKey = "footerHint",
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
        },
        button = {
            primary_action = {
                buttonVariant = "primary",
            },
            danger_action = {
                buttonVariant = "danger",
            },
        },
        dropdown = {
            form_field = {
                fullWidth = true,
            },
            fixed_width_field = {},
        },
        editbox = {
            form_field = {
                fullWidth = true,
                disableButton = true,
            },
        },
        checkbox = {
            unit_toggle = {
                checked = false,
                disabled = true,
                fullWidth = true,
            },
        },
    },
}
