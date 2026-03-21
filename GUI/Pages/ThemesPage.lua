local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local ThemesPage = {}
ns.GUI.Pages.Themes = ThemesPage

function ThemesPage.Build(container, deps)
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddPageHeading = deps.AddPageHeading
    local CreateSection = deps.CreateSection
    local ThemeService = ns.ThemeService or {}
    local ThemePreview = ns.GUI and ns.GUI.Preview and ns.GUI.Preview.ThemePreview

    ResetFlowContainer(container)

    if AddPageHeading then
        AddPageHeading(container, L["NAV_THEMES"] or "Themes")
    end

    local intro = AceGUI:Create("Label")
    intro:SetFullWidth(true)
    if intro.SetFont then
        intro:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    intro:SetText(string.format(
        "|cffd7dbe0%s|r",
        L["INFO_GENERAL_THEMES_DESC"] or "Apply a strong starting layout. Afterwards everything remains fully editable."
    ))
    container:AddChild(intro)

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(8)
    container:AddChild(spacer)

    local themes = ThemeService.GetThemes and ThemeService.GetThemes() or {}
    local orderedThemeIds = { "classic", "minimal", "modern" }
    local activeThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId
    local selectedThemeId = activeThemeId or orderedThemeIds[1]

    local previewGroup = AceGUI:Create("InlineGroup")
    previewGroup:SetFullWidth(true)
    previewGroup:SetLayout("Flow")
    previewGroup:SetTitle(L["INFO_THEME_PREVIEW_TITLE"] or "Preview")
    container:AddChild(previewGroup)

    local previewHeading = AceGUI:Create("Label")
    previewHeading:SetFullWidth(true)
    if previewHeading.SetFont then
        previewHeading:SetFont(STANDARD_TEXT_FONT, 13, "")
    end
    previewGroup:AddChild(previewHeading)

    local previewDescription = AceGUI:Create("Label")
    previewDescription:SetFullWidth(true)
    if previewDescription.SetFont then
        previewDescription:SetFont(STANDARD_TEXT_FONT, 11, "")
    end
    previewGroup:AddChild(previewDescription)

    local previewHost = AceGUI:Create("SimpleGroup")
    previewHost:SetFullWidth(true)
    previewHost:SetFullHeight(false)
    previewHost:SetHeight(250)
    previewHost:SetLayout("Fill")
    previewGroup:AddChild(previewHost)

    local previewController = ThemePreview and ThemePreview.Attach and ThemePreview.Attach(previewHost, selectedThemeId) or nil

    local function RefreshPreview(themeId)
        local theme = themes[themeId]
        if not theme then
            return
        end

        selectedThemeId = themeId

        local label = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        local description = (theme.descriptionKey and L[theme.descriptionKey]) or ""

        previewHeading:SetText(string.format("|cffe7dcc4%s:|r %s", L["INFO_THEME_PREVIEWING"] or "Previewing", label))
        previewDescription:SetText(string.format("|cff9ea8b3%s|r", description ~= "" and description or (L["INFO_THEME_PREVIEW_DESC"] or "")))

        if previewController and previewController.SetTheme then
            previewController:SetTheme(themeId)
        end
    end

    RefreshPreview(selectedThemeId)

    local previewSpacer = AceGUI:Create("Label")
    previewSpacer:SetText(" ")
    previewSpacer:SetFullWidth(true)
    previewSpacer:SetHeight(8)
    container:AddChild(previewSpacer)

    local themeGroup = AceGUI:Create("InlineGroup")
    themeGroup:SetFullWidth(true)
    themeGroup:SetLayout("Flow")
    themeGroup:SetTitle(L["INFO_GENERAL_THEMES"] or "Themes")
    container:AddChild(themeGroup)

    local themeLayout = CreateSection(themeGroup)

    local function BuildThemeCard(themeId, theme)
        local card = AceGUI:Create("SimpleGroup")
        card:SetFullWidth(true)
        card:SetLayout("Flow")

        local title = AceGUI:Create("Label")
        title:SetFullWidth(true)
        if title.SetFont then
            title:SetFont(STANDARD_TEXT_FONT, 13, "")
        end

        local label = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        local isActive = activeThemeId == theme.id
        local activeSuffix = isActive and string.format("  (%s)", L["INFO_THEME_ACTIVE"] or "Active") or ""
        title:SetText(string.format("%s%s|r", isActive and "|cff72e06a" or "|cffe7dcc4", label .. activeSuffix))
        card:AddChild(title)

        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        if description.SetFont then
            description:SetFont(STANDARD_TEXT_FONT, 11, "")
        end
        description:SetText(string.format("|cff9ea8b3%s|r", (theme.descriptionKey and L[theme.descriptionKey]) or ""))
        card:AddChild(description)

        local actions = AceGUI:Create("SimpleGroup")
        actions:SetFullWidth(true)
        actions:SetLayout("Flow")
        card:AddChild(actions)

        local previewButton = AceGUI:Create("Button")
        previewButton:SetText(L["THEME_PREVIEW"] or "Preview Theme")
        previewButton:SetWidth(140)
        previewButton:SetCallback("OnClick", function()
            RefreshPreview(themeId)
        end)
        actions:AddChild(previewButton)

        local applyButton = AceGUI:Create("Button")
        applyButton:SetText(L["INFO_GENERAL_THEME_APPLY"] or "Apply Theme")
        applyButton:SetWidth(140)
        applyButton:SetCallback("OnClick", function()
            if ThemeService.ApplyTheme and ThemeService.ApplyTheme(themeId) then
                if ns.GUI and ns.GUI.RefreshOptions then
                    ns.GUI:RefreshOptions()
                end
            end
        end)
        actions:AddChild(applyButton)

        return {
            group = card,
        }
    end

    for _, themeId in ipairs({ "classic", "minimal", "modern" }) do
        local theme = themes[themeId]
        if theme then
            themeLayout:Add(BuildThemeCard(themeId, theme))
        end
    end
end
