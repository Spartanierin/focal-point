local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local TagDatabasePage = {}
ns.GUI.Pages.TagDatabase = TagDatabasePage

function TagDatabasePage.Build(container, deps)
    local GetGUIState = deps.GetGUIState
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

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
    root:AddChild(introGroup)

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format("|cffcfd5dd%s|r", L["INFO_TAG_DATABASE_DESCRIPTION"] or ""))
    introGroup:AddChild(description)

    introGroup:AddChild(CreateLocalSpacer(2))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    if hint.SetFont then
        hint:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    hint:SetText(string.format("|cff6fd2ff%s|r", L["INFO_TAG_DATABASE_TEMPLATE_HINT"] or ""))
    introGroup:AddChild(hint)

    root:AddChild(CreateLocalSpacer(2))

    local referenceGroup = AceGUI:Create("InlineGroup")
    referenceGroup:SetFullWidth(true)
    referenceGroup:SetFullHeight(true)
    referenceGroup:SetLayout("Fill")
    referenceGroup:SetTitle(L["INFO_TAG_DATABASE_REFERENCE"] or "Reference")
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
            local categoryLabel = AceGUI:Create("Label")
            categoryLabel:SetFullWidth(true)
            if categoryLabel.SetFont then
                categoryLabel:SetFont(STANDARD_TEXT_FONT, 13, "")
            end
            categoryLabel:SetText(string.format("|cffe6d6a8%s|r", L[categoryKey] or categoryKey))
            content:AddChild(categoryLabel)

            content:AddChild(CreateLocalSpacer(2))

            local headerRow = AceGUI:Create("SimpleGroup")
            headerRow:SetFullWidth(true)
            headerRow:SetLayout("Flow")
            content:AddChild(headerRow)

            local function AddHeaderCell(text, width)
                local label = AceGUI:Create("Label")
                label:SetWidth(width)
                if label.SetFont then
                    label:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                label:SetText(string.format("|cff9a9a9a%s|r", text))
                headerRow:AddChild(label)
            end

            AddHeaderCell(L["INFO_TAG_DATABASE_COL_TAG"] or "Tag", 170)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_DESC"] or "Description", 320)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_EXAMPLE"] or "Example", 120)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_APPLIES"] or "Applies To", 160)

            content:AddChild(CreateLocalSpacer(1))

            for _, def in ipairs(grouped[categoryKey] or {}) do
                local row = AceGUI:Create("SimpleGroup")
                row:SetFullWidth(true)
                row:SetLayout("Flow")
                content:AddChild(row)

                local tokenLabel = AceGUI:Create("Label")
                tokenLabel:SetWidth(170)
                if tokenLabel.SetFont then
                    tokenLabel:SetFont(STANDARD_TEXT_FONT, 12, "")
                end
                tokenLabel:SetText(string.format("|cff6fd2ff%s|r", def.token))
                row:AddChild(tokenLabel)

                local descriptionLabel = AceGUI:Create("Label")
                descriptionLabel:SetWidth(320)
                if descriptionLabel.SetFont then
                    descriptionLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                descriptionLabel:SetText(string.format("|cffd7d2c8%s|r", L[def.description] or def.description))
                row:AddChild(descriptionLabel)

                local exampleLabel = AceGUI:Create("Label")
                exampleLabel:SetWidth(120)
                if exampleLabel.SetFont then
                    exampleLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                exampleLabel:SetText(string.format("|cffe6d6a8%s|r", def.example or ""))
                row:AddChild(exampleLabel)

                local appliesLabel = AceGUI:Create("Label")
                appliesLabel:SetWidth(160)
                if appliesLabel.SetFont then
                    appliesLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                appliesLabel:SetText(string.format("|cff9a9a9a%s|r", ResolveTagAppliesTo(def)))
                row:AddChild(appliesLabel)
            end
        end)
    end)

    referenceGroup:AddChild(tabGroup)
    tabGroup:SelectTab(state.tagDatabaseTab or firstTab)
end
