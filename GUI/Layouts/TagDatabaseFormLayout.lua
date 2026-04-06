local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}
ns.GUI.Layouts.TagDatabase = ns.GUI.Layouts.TagDatabase or {}

--[[
Declarative form layout for the Tag Database popup.

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
ns.GUI.Layouts.TagDatabase.Form = {
    {
        section = "Root",
        properties = {
            sectionKind = "root",
            type = "root",
            variant = "scroll_content",
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
                derivedFrom = "title + intro + spacing",
            },
        },
        items = {
            { id = "title", widget = "label", itemVariant = "page_title_hero", textKey = "INFO_TAG_DATABASE_TITLE" },
            { id = "intro", widget = "label", itemVariant = "page_intro_soft", textKey = "INFO_TAG_DATABASE_DESCRIPTION_SHORT" },
        },
    },
    {
        section = "ColumnContainer",
        properties = {
            parentSection = "Root",
            sectionKind = "widget_group",
            type = "column_container",
            variant = "flow_row",
            padding = {
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "parent",
            },
            heightInfo = {
                source = "content",
                min = 120,
                derivedFrom = "LeftColumn + RightColumn flow row",
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
            variant = "fixed_list",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "explicit",
                value = 332,
                derivedFrom = "FormElements.Sections.column.fixed_list.width",
            },
            heightInfo = {
                source = "content",
                min = 120,
                derivedFrom = "category section title + label + dropdown",
            },
        },
        items = {
            { id = "categoryTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TAG_DATABASE_CATEGORY_PICK" },
            { id = "categoryLabel", widget = "label", itemVariant = "field_label", textKey = "INFO_TAG_DATABASE_CATEGORY_LABEL" },
            { id = "categorySelect", widget = "dropdown", itemVariant = "fixed_width_field", label = "", fitGroupWidth = true, groupWidthFallback = 332 },
        },
    },
    {
        section = "RightColumn",
        properties = {
            parentSection = "ColumnContainer",
            sectionKind = "widget_group",
            type = "column",
            variant = "fixed_list",
            padding = {
                left = 10,
                right = 10,
                top = 8,
                bottom = 8,
            },
            widthInfo = {
                source = "explicit",
                value = 332,
                derivedFrom = "FormElements.Sections.column.fixed_list.width",
            },
            heightInfo = {
                source = "content",
                min = 120,
                derivedFrom = "tag section title + label + dropdown",
            },
        },
        items = {
            { id = "tagTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TAG_DATABASE_TAG_PICK" },
            { id = "tagLabel", widget = "label", itemVariant = "field_label", textKey = "INFO_TAG_DATABASE_TAG_LABEL" },
            { id = "tagSelect", widget = "dropdown", itemVariant = "fixed_width_field", label = "", fitGroupWidth = true, groupWidthFallback = 332 },
        },
    },
    {
        section = "Footer",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "details_stack",
            gapBefore = 8,
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
                min = 180,
                derivedFrom = "details labels + values + usage hint stack",
            },
        },
        items = {
            { id = "detailsTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TAG_DATABASE_DETAILS" },
            { id = "tokenLabel", widget = "label", itemVariant = "field_label", textKey = "INFO_TAG_DATABASE_COL_TAG" },
            { id = "tokenValue", widget = "label", itemVariant = "value_display_small", text = "-" },
            { id = "detailsSpacer1", widget = "label", itemVariant = "spacer_xsmall", text = " " },
            { id = "descriptionLabel", widget = "label", itemVariant = "field_label", textKey = "INFO_TAG_DATABASE_COL_DESC" },
            { id = "descriptionValue", widget = "label", itemVariant = "body_text", text = "-" },
            { id = "detailsSpacer2", widget = "label", itemVariant = "spacer_xsmall", text = " " },
            { id = "exampleLabel", widget = "label", itemVariant = "field_label", textKey = "INFO_TAG_DATABASE_COL_EXAMPLE" },
            { id = "exampleValue", widget = "label", itemVariant = "value_text", text = "-" },
            { id = "detailsSpacer3", widget = "label", itemVariant = "spacer_small", text = " " },
            { id = "hintTitle", widget = "label", itemVariant = "section_title", textKey = "INFO_TAG_DATABASE_USAGE_HINT_TITLE" },
            { id = "hintValue", widget = "label", itemVariant = "hint_text_body", textKey = "INFO_TAG_DATABASE_USAGE_HINT" },
        },
    },
    {
        section = "EmptyState",
        properties = {
            parentSection = "Root",
            sectionKind = "section",
            type = "section",
            variant = "note_block",
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
                derivedFrom = "emptyState label",
            },
        },
        items = {
            { id = "emptyState", widget = "label", itemVariant = "hint_text_body", text = "", hideInitially = true },
        },
    },
}
