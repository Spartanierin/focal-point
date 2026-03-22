local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Layouts = FocalPoint.GUI.Layouts or {}

local AceGUI = LibStub("AceGUI-3.0")
local TitleStyles = FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.TitleStyles or nil
local TextStyles = FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.TextStyles or nil

local SectionLayout = {}
FocalPoint.GUI.Layouts.SectionLayout = SectionLayout

local function CreateColumn(relativeWidth)
    local column = AceGUI:Create("SimpleGroup")
    column:SetRelativeWidth(relativeWidth or 0.5)
    column:SetLayout("List")
    return column
end

local function StyleHeaderActionButton(button)
    if not button then
        return
    end

    local fontString = button.Text or (button.GetFontString and button:GetFontString()) or nil
    if fontString then
        if TextStyles and TextStyles.ApplyFontString then
            TextStyles.ApplyFontString(fontString, "help", {
                size = 11,
                shadow = true,
            })
        else
            if fontString.SetFont then
                fontString:SetFont(STANDARD_TEXT_FONT, 11, "")
            end
            if fontString.SetTextColor then
                fontString:SetTextColor(0.949, 0.902, 0.788, 1)
            end
            if fontString.SetShadowOffset then
                fontString:SetShadowOffset(1, -1)
            end
            if fontString.SetShadowColor then
                fontString:SetShadowColor(0, 0, 0, 0.75)
            end
        end
    end

    if button.SetHeight then
        button:SetHeight(17)
    end
end

local function ConfigureHeaderAction(section, headerAction)
    if not section or not section.frame or not section.titletext then
        return
    end

    local button = section._focalPointHeaderButton
    if not button then
        button = CreateFrame("Button", nil, section.frame, "UIPanelButtonTemplate")
        section._focalPointHeaderButton = button
    end

    section.titletext:ClearAllPoints()
    section.titletext:SetPoint("TOPLEFT", 14, 0)

    if type(headerAction) == "table" and type(headerAction.onClick) == "function" then
        button:SetText(headerAction.text or RESET or "Reset")
        button:SetWidth(headerAction.width or 112)
        button:SetHeight(headerAction.height or 17)
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", section.frame, "TOPRIGHT", -12, -1)
        button:SetScript("OnClick", headerAction.onClick)
        StyleHeaderActionButton(button)
        button:Show()

        section.titletext:SetPoint("TOPRIGHT", -(headerAction.width or 112) - 20, 0)
    else
        button:SetScript("OnClick", nil)
        button:Hide()
        section.titletext:SetPoint("TOPRIGHT", -14, 0)
    end
end

local function CreateSectionRoot(parent, title, topSpacing, headerAction)
    if topSpacing and topSpacing > 0 then
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(topSpacing)
        parent:AddChild(spacer)
    end

    local section
    if type(title) == "string" and title ~= "" then
        section = AceGUI:Create("InlineGroup")
        section:SetTitle(TitleStyles and TitleStyles.FormatGroup and TitleStyles.FormatGroup(title) or title)
        if section.titletext then
            if TextStyles and TextStyles.ApplyFontString then
                TextStyles.ApplyFontString(section.titletext, "sectionHeader", {
                    size = 13,
                    shadow = true,
                })
            else
                if section.titletext.SetFont then
                    section.titletext:SetFont(STANDARD_TEXT_FONT, 13, "")
                end
                if section.titletext.SetShadowOffset then
                    section.titletext:SetShadowOffset(1, -1)
                end
                if section.titletext.SetShadowColor then
                    section.titletext:SetShadowColor(0, 0, 0, 0.9)
                end
            end
        end
        ConfigureHeaderAction(section, headerAction)
    else
        section = AceGUI:Create("SimpleGroup")
    end

    section:SetFullWidth(true)
    section:SetLayout("Flow")
    parent:AddChild(section)

    return section
end

local function CreateRow()
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    return row
end

local function CreateSingleColumn()
    local column = AceGUI:Create("SimpleGroup")
    column:SetFullWidth(true)
    column:SetLayout("List")
    return column
end

local function CreateSubsectionHeader(text)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(4)
    group:AddChild(spacer)

    local heading = AceGUI:Create("Heading")
    if TitleStyles and TitleStyles.FormatSubsection then
        heading:SetText(TitleStyles.FormatSubsection(text or ""))
    else
        heading:SetText(text or "")
    end
    heading:SetFullWidth(true)
    group:AddChild(heading)

    return group
end

local function NormalizeLayoutMeta(meta)
    local source = type(meta) == "table" and meta or {}

    local placement = source.placement
    if placement ~= "left" and placement ~= "right" and placement ~= "full" then
        placement = "auto"
    end

    local span = tonumber(source.span) == 2 and 2 or 1
    local rowType = source.rowType
    if rowType ~= "inline"
        and rowType ~= "actions"
        and rowType ~= "preview"
        and rowType ~= "toolbar"
        and rowType ~= "standalone"
    then
        rowType = "default"
    end

    if placement == "full" then
        span = 2
    end

    if rowType == "actions" or rowType == "preview" or rowType == "toolbar" then
        span = 2
    end

    return {
        placement = placement,
        span = span,
        rowType = rowType,
        subsection = type(source.subsection) == "string" and source.subsection ~= "" and source.subsection or nil,
    }
end

function SectionLayout.CreateTwoColumn(parent, title, topSpacing, headerAction)
    if not parent then
        return nil
    end

    local section = CreateSectionRoot(parent, title, topSpacing, headerAction)

    local currentRow = nil
    local currentLeft = nil
    local currentRight = nil
    local rowHasLeft = false
    local rowHasRight = false
    local nextColumn = 1
    local currentSubsection = nil

    local layout = {}

    local function ResetRowState()
        currentRow = nil
        currentLeft = nil
        currentRight = nil
        rowHasLeft = false
        rowHasRight = false
        nextColumn = 1
    end

    local function AddSubsection(text)
        ResetRowState()

        local row = CreateRow()
        local column = CreateSingleColumn()
        row:AddChild(column)
        column:AddChild(CreateSubsectionHeader(text))
        section:AddChild(row)

        ResetRowState()
    end

    local function EnsureTwoColumnRow()
        if currentRow and currentLeft and currentRight then
            return
        end

        local row = CreateRow()
        local left = CreateColumn(0.5)
        local right = CreateColumn(0.5)

        row:AddChild(left)
        row:AddChild(right)
        section:AddChild(row)

        currentRow = row
        currentLeft = left
        currentRight = right
        rowHasLeft = false
        rowHasRight = false
    end

    local function AddFullWidth(handle)
        ResetRowState()

        local row = CreateRow()
        local column = CreateSingleColumn()
        row:AddChild(column)
        column:AddChild(handle.group)
        section:AddChild(row)

        ResetRowState()
    end

    local function StartFreshRow()
        ResetRowState()
        EnsureTwoColumnRow()
    end

    function layout:Add(handle, meta)
        if not handle or not handle.group then
            return nil
        end

        local resolvedMeta = NormalizeLayoutMeta(meta or handle.layoutMeta)
        if resolvedMeta.subsection ~= currentSubsection then
            if resolvedMeta.subsection then
                AddSubsection(resolvedMeta.subsection)
            end
            currentSubsection = resolvedMeta.subsection
        end

        if resolvedMeta.span == 2 then
            AddFullWidth(handle)
            return handle
        end

        if resolvedMeta.rowType == "standalone" then
            if rowHasLeft or rowHasRight then
                StartFreshRow()
            else
                EnsureTwoColumnRow()
            end

            local target = resolvedMeta.placement == "right" and currentRight or currentLeft
            target:AddChild(handle.group)
            ResetRowState()
            return handle
        end

        local target = nil
        if resolvedMeta.placement == "left" then
            if rowHasLeft then
                StartFreshRow()
            else
                EnsureTwoColumnRow()
            end
            target = currentLeft
            rowHasLeft = true
            nextColumn = rowHasRight and 1 or 2
        elseif resolvedMeta.placement == "right" then
            if rowHasRight then
                StartFreshRow()
            else
                EnsureTwoColumnRow()
            end
            target = currentRight
            rowHasRight = true
            nextColumn = rowHasLeft and 1 or 1
        else
            if rowHasLeft and rowHasRight then
                StartFreshRow()
            else
                EnsureTwoColumnRow()
            end

            target = nextColumn == 1 and currentLeft or currentRight
            if nextColumn == 1 then
                rowHasLeft = true
                nextColumn = rowHasRight and 1 or 2
            else
                rowHasRight = true
                nextColumn = rowHasLeft and 1 or 2
            end
        end

        target:AddChild(handle.group)
        return handle
    end

    function layout:Reset()
        ResetRowState()
        currentSubsection = nil
    end

    layout.group = section

    return layout
end

return SectionLayout
