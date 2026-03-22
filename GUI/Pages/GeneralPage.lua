local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local Checkbox = ns.GUI.Widgets.Checkbox

local GeneralPage = {}
ns.GUI.Pages.General = GeneralPage

function GeneralPage.Build(container, deps)
    local ResetFlowContainer = deps.ResetFlowContainer
    local GetAddonVersionText = deps.GetAddonVersionText
    local CreateSection = deps.CreateSection

    ResetFlowContainer(container)

    local version = GetAddonVersionText()
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\Icon.tga"

    local function StyleLabelFont(widget, size, r, g, b)
        local fontString = widget and widget.label
        if not fontString then
            return
        end

        if fontString.SetFont then
            fontString:SetFont(STANDARD_TEXT_FONT, size or 12, "")
        end

        if fontString.SetTextColor then
            fontString:SetTextColor(r or 1, g or 1, b or 1, 1)
        end

        if fontString.SetShadowOffset then
            fontString:SetShadowOffset(1, -1)
        end

        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0.75)
        end

        if widget.SetText then
            widget:SetText(fontString:GetText() or "")
        end
    end

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function CreateStyledGeneralOption(config)
        local handle = Checkbox.Create(config)
        if not handle or not handle.group then
            return handle
        end

        if handle.checkbox then
            handle.checkbox:SetWidth(240)
            if handle.checkbox.text then
                if handle.checkbox.text.SetFontObject then
                    handle.checkbox.text:SetFontObject(GameFontHighlight)
                end
                if handle.checkbox.text.SetFont then
                    handle.checkbox.text:SetFont(STANDARD_TEXT_FONT, 12, "")
                end
                if handle.checkbox.text.SetShadowOffset then
                    handle.checkbox.text:SetShadowOffset(1, -1)
                end
                if handle.checkbox.text.SetShadowColor then
                    handle.checkbox.text:SetShadowColor(0, 0, 0, 0.75)
                end
            end
        end

        local children = handle.group.children or {}
        local row = children[1]
        local description = children[2]
        if row and row.SetFullWidth then
            row:SetFullWidth(true)
        end

        if description and description.SetText then
            description:SetText("    " .. (config.description or ""))
            if description.SetFont then
                description:SetFont(STANDARD_TEXT_FONT, 10, "")
            end
            if description.label and description.label.SetTextColor then
                description.label:SetTextColor(0.56, 0.60, 0.64, 1)
            end
            if description.label and description.label.SetShadowOffset then
                description.label:SetShadowOffset(1, -1)
            end
            if description.label and description.label.SetShadowColor then
                description.label:SetShadowColor(0, 0, 0, 0.75)
            end
        end

        handle.group:AddChild(CreateSpacer(6))
        return handle
    end

    local function ResetGroupTitle(widget, size)
        if not widget or not widget.titletext then
            return
        end

        if widget.titletext.SetFont then
            widget.titletext:SetFont(STANDARD_TEXT_FONT, size or 12, "")
        end

        if widget.titletext.SetTextColor then
            widget.titletext:SetTextColor(0.95, 0.90, 0.79, 1)
        end

        if widget.titletext.SetShadowOffset then
            widget.titletext:SetShadowOffset(1, -1)
        end

        if widget.titletext.SetShadowColor then
            widget.titletext:SetShadowColor(0, 0, 0, 0.75)
        end
    end

    local aboutGroup = AceGUI:Create("InlineGroup")
    aboutGroup:SetFullWidth(true)
    aboutGroup:SetLayout("Flow")
    aboutGroup:SetTitle(" ")
    ResetGroupTitle(aboutGroup, 12)
    if aboutGroup.titletext and aboutGroup.titletext.SetText then
        aboutGroup.titletext:SetText(" ")
    end
    container:AddChild(aboutGroup)

    aboutGroup:AddChild(CreateSpacer(6))

    local brandLine = AceGUI:Create("Label")
    brandLine:SetFullWidth(true)
    if brandLine.SetFont then
        brandLine:SetFont(STANDARD_TEXT_FONT, 16, "")
    end
    brandLine:SetText(string.format(
        "|T%s:24:24:0:0|t  |cff6fd2ff%s|r",
        logoPath,
        L["ADDON_NAME"] or C.ADDON_NAME
    ))
    StyleLabelFont(brandLine, 16, 1, 1, 1)
    aboutGroup:AddChild(brandLine)

    local versionLine = AceGUI:Create("Label")
    versionLine:SetFullWidth(true)
    if versionLine.SetFont then
        versionLine:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    versionLine:SetText(string.format(
        "|cffd8c27a%s|r  |cff4cff88%s|r",
        L["INFO_VERSION"] or "Version",
        version
    ))
    StyleLabelFont(versionLine, 12, 1, 1, 1)
    aboutGroup:AddChild(versionLine)

    aboutGroup:AddChild(CreateSpacer(6))

    local welcome = AceGUI:Create("Label")
    welcome:SetFullWidth(true)
    if welcome.SetFont then
        welcome:SetFont(STANDARD_TEXT_FONT, 13, "")
    end
    welcome:SetText(string.format("|cfff2e4b8%s|r", L["INFO_GENERAL_WELCOME"] or "Welcome to Focal Point."))
    StyleLabelFont(welcome, 13, 1, 1, 1)
    aboutGroup:AddChild(welcome)

    aboutGroup:AddChild(CreateSpacer(3))

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format(
        "|cffd7dbe0%s|r",
        L["INFO_GENERAL_DESCRIPTION"] or "Focal Point is a modular unit frame addon with configurable frames, bars, texts, and elements."
    ))
    StyleLabelFont(description, 12, 1, 1, 1)
    aboutGroup:AddChild(description)

    aboutGroup:AddChild(CreateSpacer(5))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    if hint.SetFont then
        hint:SetFont(STANDARD_TEXT_FONT, 11, "")
    end
    hint:SetText(string.format(
        "|cff9ea8b3%s|r",
        L["INFO_GENERAL_HINT"] or "Use the navigation on the left to configure units, bars, texts, colors, and elements."
    ))
    StyleLabelFont(hint, 11, 1, 1, 1)
    aboutGroup:AddChild(hint)

    aboutGroup:AddChild(CreateSpacer(8))

    local modeGroup = AceGUI:Create("InlineGroup")
    modeGroup:SetFullWidth(true)
    modeGroup:SetLayout("Flow")
    modeGroup:SetTitle(L["INFO_GENERAL_MODE"] or "Workflow Mode")
    ResetGroupTitle(modeGroup, 12)
    container:AddChild(modeGroup)

    modeGroup:AddChild(CreateSpacer(6))

    local modeLayout = CreateSection(modeGroup)
    modeLayout:Add(CreateStyledGeneralOption({
        path = { "General", "ExpertMode" },
        label = L["OPTION_EXPERT_MODE"] or "Expert Mode",
        description = L["OPTION_EXPERT_MODE_DESC"] or "Enabled: maximum configurability. Disabled = Quick Mode for a faster path to a good result through a template or theme.",
        fallback = true,
        refreshGUI = true,
        skipTextStyle = true,
    }))

    local settingsGroup = AceGUI:Create("InlineGroup")
    settingsGroup:SetFullWidth(true)
    settingsGroup:SetLayout("Flow")
    settingsGroup:SetTitle(L["INFO_GENERAL_SETTINGS"] or "General Settings")
    ResetGroupTitle(settingsGroup, 12)
    container:AddChild(settingsGroup)

    settingsGroup:AddChild(CreateSpacer(8))

    local settingsLayout = CreateSection(settingsGroup)

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "HideBlizzardFrames" },
        label = L["OPTION_HIDE_BLIZZARD_FRAMES"],
        description = L["OPTION_HIDE_BLIZZARD_FRAMES_DESC"],
        fallback = false,
        skipTextStyle = true,
        onChanged = function()
            if ns.ApplyGeneralSettings then
                ns:ApplyGeneralSettings()
            end

            local hideBlizzardFrames = ns.db
                and ns.db.profile
                and ns.db.profile.General
                and ns.db.profile.General.HideBlizzardFrames == true

            if not hideBlizzardFrames and ns.Info then
                ns:Info(L["INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES"])
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "GlobalClickThrough" },
        label = L["OPTION_GLOBAL_CLICKTHROUGH"],
        description = L["OPTION_GLOBAL_CLICKTHROUGH_DESC"],
        fallback = false,
        skipTextStyle = true,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "MouseEnabled" },
        label = L["OPTION_MOUSE_ENABLED"],
        description = L["OPTION_MOUSE_ENABLED_DESC"],
        fallback = true,
        skipTextStyle = true,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "ClampToScreen" },
        label = L["OPTION_CLAMP_TO_SCREEN"],
        description = L["OPTION_CLAMP_TO_SCREEN_DESC"],
        fallback = true,
        skipTextStyle = true,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))
end
