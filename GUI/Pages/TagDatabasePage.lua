local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L
local TextStyles = ns.GUI.Helpers.TextStyles

local TagDatabasePage = {}
ns.GUI.Pages.TagDatabase = TagDatabasePage

function TagDatabasePage.Build(container, deps)
    local GetGUIState = deps.GetGUIState
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

    local function StyleGroupTitle(widget)
        if TextStyles and TextStyles.ApplyWidgetText then
            TextStyles.ApplyWidgetText(widget, "sectionHeader", { size = 13 })
        end
    end

    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    local tagDatabase = ns.UnitFrame and ns.UnitFrame.GetTagDatabase and ns.UnitFrame:GetTagDatabase() or {}
    local grouped = {}
    local categoryOrder = {
        "INFO_TAG_CATEGORY_FORMAT",
        "INFO_TAG_CATEGORY_HEALTH",
        "INFO_TAG_CATEGORY_POWER",
        "INFO_TAG_CATEGORY_CAST",
        "INFO_TAG_CATEGORY_UNIT",
        "INFO_TAG_CATEGORY_STATUS",
    }

    for _, def in ipairs(tagDatabase) do
        grouped[def.category] = grouped[def.category] or {}
        table.insert(grouped[def.category], def)
    end

    local tabs = {}
    for _, categoryKey in ipairs(categoryOrder) do
        if grouped[categoryKey] and #grouped[categoryKey] > 0 then
            table.insert(tabs, {
                text = L[categoryKey] or categoryKey,
                value = categoryKey,
            })
        end
    end

    local firstTab = tabs[1] and tabs[1].value or nil
    if not firstTab then
        BuildPlaceholderPage(container, L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
        return
    end

    state.tagDatabaseTab = state.tagDatabaseTab or firstTab
    state.tagDatabaseScroll = state.tagDatabaseScroll or {}

    local function CreateLocalSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function GetColumnWidths()
        return {
            tag = 150,
            description = 300,
            example = 150,
            applies = 150,
        }
    end

    local function ResolveTagAppliesTo(def)
        local token = type(def.token) == "string" and def.token or ""

        if token == "[guild]" or token == "[realm]" or token == "[race]" then
            return L["INFO_TAG_DATABASE_APPLIES_PLAYERS"] or "Players"
        end

        if token == "[color:class]" or token == "[color:blizz_pwr]" or token == "[color:blizz_yellow]" or token == "[color:blizz_red]" or token == "[color:blizz_green]" or token == "[color:blizz_highlight]" or token == "[color:ffcc00]" or token == "[rc]" then
            return L["INFO_TAG_DATABASE_APPLIES_TEMPLATES"] or "Templates"
        end

        if token == "[color:reaction]" then
            return L["INFO_TAG_DATABASE_APPLIES_REACTION"] or "Units with Reaction"
        end

        if token == "[classification]" or token == "[family]" or token == "[type]" or token == "[creature]" then
            return L["INFO_TAG_DATABASE_APPLIES_NPCS"] or "NPCs / Pets"
        end

        if token == "[cast:name]" or token == "[cast:time]" then
            return L["INFO_TAG_DATABASE_APPLIES_CAST"] or "Casting Units"
        end

        if token == "[resting]" or token == "[combat]" or token == "[pvp]" or token == "[afk]" or token == "[dnd]" or token == "[dead]" or token == "[offline]" or token == "[leader]" or token == "[role]" then
            return L["INFO_TAG_DATABASE_APPLIES_STATUS"] or "Units with State"
        end

        if token == "[altpower:cur]" or token == "[altpower:max]" or token == "[altpower:cur:abbr]" or token == "[altpower:max:abbr]" then
            return L["INFO_TAG_DATABASE_APPLIES_PLAYER_ALT"] or "Player (AltPower)"
        end

        return L["INFO_TAG_DATABASE_APPLIES_ALL"] or "All"
    end

    local root = AceGUI:Create("SimpleGroup")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    root:SetLayout("Flow")
    container:AddChild(root)

    local introGroup = AceGUI:Create("InlineGroup")
    introGroup:SetFullWidth(true)
    introGroup:SetLayout("Flow")
    introGroup:SetTitle(L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
    StyleGroupTitle(introGroup)
    root:AddChild(introGroup)

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    description:SetText(L["INFO_TAG_DATABASE_DESCRIPTION"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(description, "label", { size = 12 })
    end
    introGroup:AddChild(description)

    introGroup:AddChild(CreateLocalSpacer(2))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    hint:SetText(L["INFO_TAG_DATABASE_TEMPLATE_HINT"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(hint, "highlight", { size = 12 })
    end
    introGroup:AddChild(hint)

    root:AddChild(CreateLocalSpacer(2))

    local referenceGroup = AceGUI:Create("InlineGroup")
    referenceGroup:SetFullWidth(true)
    referenceGroup:SetFullHeight(true)
    referenceGroup:SetLayout("Fill")
    referenceGroup:SetTitle(L["INFO_TAG_DATABASE_REFERENCE"] or "Reference")
    StyleGroupTitle(referenceGroup)
    root:AddChild(referenceGroup)

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabs)

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, categoryKey)
        state.tagDatabaseTab = categoryKey
        state.tagDatabaseScroll[categoryKey] = state.tagDatabaseScroll[categoryKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.tagDatabaseScroll[categoryKey], function(content)
            local widths = GetColumnWidths()

            local categoryLabel = AceGUI:Create("Label")
            categoryLabel:SetFullWidth(true)
            categoryLabel:SetText(L[categoryKey] or categoryKey)
            if TextStyles and TextStyles.ApplyLabelWidget then
                TextStyles.ApplyLabelWidget(categoryLabel, "sectionHeader", { size = 13 })
            end
            content:AddChild(categoryLabel)

            content:AddChild(CreateLocalSpacer(2))

            local headerRow = AceGUI:Create("SimpleGroup")
            headerRow:SetFullWidth(true)
            headerRow:SetLayout("Flow")
            content:AddChild(headerRow)

            local function AddHeaderCell(text, width)
                local label = AceGUI:Create("Label")
                label:SetWidth(width)
                label:SetText(text)
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(label, "help", { size = 11 })
                end
                headerRow:AddChild(label)
            end

            AddHeaderCell(L["INFO_TAG_DATABASE_COL_TAG"] or "Tag", widths.tag)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_DESC"] or "Description", widths.description)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_EXAMPLE"] or "Example", widths.example)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_APPLIES"] or "Applies To", widths.applies)

            content:AddChild(CreateLocalSpacer(1))

            for _, def in ipairs(grouped[categoryKey] or {}) do
                local row = AceGUI:Create("SimpleGroup")
                row:SetFullWidth(true)
                row:SetLayout("Flow")
                content:AddChild(row)

                local tokenLabel = AceGUI:Create("Label")
                tokenLabel:SetWidth(widths.tag)
                tokenLabel:SetText(def.token)
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(tokenLabel, "highlight", { size = 12 })
                end
                row:AddChild(tokenLabel)

                local descriptionLabel = AceGUI:Create("Label")
                descriptionLabel:SetWidth(widths.description)
                descriptionLabel:SetText(L[def.description] or def.description)
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(descriptionLabel, "label", { size = 11 })
                end
                row:AddChild(descriptionLabel)

                local exampleLabel = AceGUI:Create("Label")
                exampleLabel:SetWidth(widths.example)
                exampleLabel:SetText(def.example or "")
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(exampleLabel, "highlight", { size = 11 })
                end
                row:AddChild(exampleLabel)

                local appliesLabel = AceGUI:Create("Label")
                appliesLabel:SetWidth(widths.applies)
                appliesLabel:SetText(ResolveTagAppliesTo(def))
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(appliesLabel, "help", { size = 11 })
                end
                row:AddChild(appliesLabel)
            end
        end)
    end)

    referenceGroup:AddChild(tabGroup)
    tabGroup:SelectTab(state.tagDatabaseTab or firstTab)
end
