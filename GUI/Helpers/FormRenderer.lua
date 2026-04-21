local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")

local FormRenderer = {}
ns.GUI.Helpers.FormRenderer = FormRenderer

local function IsWidgetGroupKind(sectionKind)
    return type(sectionKind) == "string" and sectionKind:find("widget_group", 1, true) ~= nil
end

local function CanRelayout(container)
    if not container or not container.DoLayout then
        return false
    end

    local tableLayout = AceGUI:GetLayout("Table")
    if container.LayoutFunc == tableLayout and container.GetUserData then
        return type(container:GetUserData("table")) == "table"
    end

    return true
end

local function RequestRelayout(container)
    local current = container
    while current do
        if CanRelayout(current) then
            current:DoLayout()
        end
        current = current._fpOwnerGroup
    end
end

local function CreateVerticalGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
        },
        spaceH = 0,
        spaceV = spacing or 8,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateTwoColumnGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = spacing or 24,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateFourColumnGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = spacing or 16,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateSimpleListGroup()
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("List")
    return group
end

local function ApplyHorizontalSizing(group, props)
    if not group or type(props) ~= "table" then
        return
    end

    if type(props.width) == "number" then
        if props.fullWidth ~= true then
            group:SetFullWidth(false)
        end
        group:SetWidth(props.width)
        return
    end

    if props.fullWidth then
        group:SetFullWidth(true)
    elseif props.fullWidth == false then
        group:SetFullWidth(false)
    end
end

-- Section gaps are modeled as dedicated spacer containers instead of using the
-- parent layout spacing. This keeps "frame-to-frame" distance explicit and
-- separate from:
-- - section padding: inner distance from a section border to its content
-- - section spacing: distance between children inside a section
-- The spacer must keep a fixed height, so auto-height is disabled.
local function CreateSpacer(height)
    local spacer = AceGUI:Create("SimpleGroup")
    spacer:SetFullWidth(true)
    spacer:SetLayout("List")
    spacer:SetAutoAdjustHeight(false)
    spacer:SetHeight(height)
    spacer._fpIsGapSpacer = true
    return spacer
end

local function GetLastMeaningfulChild(group)
    local children = group and group.children
    if type(children) ~= "table" then
        return nil
    end

    for index = #children, 1, -1 do
        local child = children[index]
        if child and not child._fpIsGapSpacer then
            return child
        end
    end

    return nil
end

local function CreateRootContent(host)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Fill")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    host:AddChild(scroll)

    local content = AceGUI:Create("SimpleGroup")
    content:SetFullWidth(true)
    content:SetLayout("Table")
    content:SetUserData("table", {
        columns = {
            { weight = 1 },
        },
        spaceH = 0,
        spaceV = 8,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    scroll:AddChild(content)

    return content
end

function FormRenderer.CloneLayoutValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = FormRenderer.CloneLayoutValue(entry)
    end
    return copy
end

function FormRenderer.MergeLayoutValue(target, source)
    if type(source) ~= "table" then
        return FormRenderer.CloneLayoutValue(source)
    end

    target = type(target) == "table" and target or {}
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            target[key] = FormRenderer.MergeLayoutValue(target[key], value)
        else
            target[key] = FormRenderer.CloneLayoutValue(value)
        end
    end

    return target
end

function FormRenderer.ResolveItemProperties(item)
    if not item then
        return nil
    end

    local resolved = {}
    local formElements = ns.GUI.Layouts and ns.GUI.Layouts.FormElements
    local itemDefinitions = formElements and formElements.Items and formElements.Items[item.widget] or nil
    local variantDefinition = itemDefinitions and itemDefinitions[item.itemVariant] or nil

    resolved = FormRenderer.MergeLayoutValue(resolved, variantDefinition)
    resolved = FormRenderer.MergeLayoutValue(resolved, item)

    return resolved
end

function FormRenderer.ResolveSectionProperties(definition)
    local props = definition and (definition.properties or definition) or nil
    if not props then
        return nil
    end

    local resolved = {}
    local formElements = ns.GUI.Layouts and ns.GUI.Layouts.FormElements
    local typeDefinitions = formElements and formElements.Sections and formElements.Sections[props.type] or nil
    local variantDefinition = typeDefinitions and typeDefinitions[props.variant] or nil

    resolved = FormRenderer.MergeLayoutValue(resolved, variantDefinition)
    resolved = FormRenderer.MergeLayoutValue(resolved, props)
    if resolved.sectionRole == nil then
        if resolved.type == "header" then
            resolved.sectionRole = "header"
        elseif resolved.type == "footer" then
            resolved.sectionRole = "footer"
        else
            resolved.sectionRole = "content"
        end
    end
    if resolved.sectionKind == nil then
        if resolved.type == "column_container" or resolved.type == "column" or resolved.type == "action_row" then
            resolved.sectionKind = "widget_group"
        elseif resolved.type == "root" then
            resolved.sectionKind = "root"
        else
            resolved.sectionKind = "section"
        end
    end
    if resolved.structure == nil then
        if resolved.sectionKind == "widget_group" then
            resolved.structure = {
                header = {
                    present = true,
                    optional = true,
                },
                body = {
                    present = true,
                    section = resolved.section,
                },
                footer = {
                    present = true,
                    optional = true,
                },
            }
        elseif resolved.sectionKind == "root" then
            resolved.structure = {
                body = {
                    present = true,
                },
            }
        else
            resolved.structure = {
                header = {
                    present = true,
                    section = resolved.section,
                },
                body = {
                    present = true,
                    section = resolved.section,
                },
                footer = {
                    present = true,
                    optional = true,
                },
            }
        end
    end
    if resolved.structureSlot == nil then
        if resolved.sectionKind == "widget_group_header" then
            resolved.structureSlot = "header"
        elseif resolved.sectionKind == "widget_group_footer" then
            resolved.structureSlot = "footer"
        else
            resolved.structureSlot = "body"
        end
    end

    return resolved
end

function FormRenderer.BuildSectionChildrenIndex(definitions)
    local index = {
        __root = {},
    }

    for _, definition in ipairs(definitions or {}) do
        local props = definition.properties or definition
        local parentKey = props.parentSection or "__root"
        index[parentKey] = index[parentKey] or {}
        index[parentKey][#index[parentKey] + 1] = definition
    end

    return index
end

local function GetVerticalPadding(padding)
    if type(padding) == "number" then
        return padding * 2
    end

    if type(padding) == "table" then
        local top = padding.top or padding.y or 0
        local bottom = padding.bottom or padding.y or 0
        return top + bottom
    end

    return 0
end

local function ApplyGroupHeightRules(group, props)
    local minHeight = props and props.heightInfo and props.heightInfo.min
    local paddingHeight = GetVerticalPadding(props and props.padding)
    local hasMinHeight = type(minHeight) == "number" and minHeight > 0
    if (not hasMinHeight and paddingHeight <= 0) or props.height or props.fullHeight then
        return
    end

    local initialHeight = 1
    if hasMinHeight then
        initialHeight = math.max(initialHeight, minHeight)
    end
    if paddingHeight > 0 then
        initialHeight = math.max(initialHeight, paddingHeight + 1)
    end

    if group.GetHeight and group:GetHeight() < initialHeight then
        group:SetHeight(initialHeight)
    end

    local originalLayoutFinished = group.LayoutFinished
    if type(originalLayoutFinished) ~= "function" then
        return
    end

    group.LayoutFinished = function(self, width, height)
        if self.noAutoHeight then
            return originalLayoutFinished(self, width, height)
        end

        local resolvedHeight = (height or 0) + paddingHeight
        if hasMinHeight and resolvedHeight < minHeight then
            resolvedHeight = minHeight
        end

        return originalLayoutFinished(self, width, resolvedHeight)
    end
end

function FormRenderer.CreateLayoutGroup(host, definition)
    if not definition then
        return nil
    end

    local props = FormRenderer.ResolveSectionProperties(definition)
    local function CreateConcreteGroup(groupProps)
        local concreteWidgetType = groupProps.widget or "SimpleGroup"
        local concreteGroup

        if concreteWidgetType == "ScrollFrame" and groupProps.layout == "RootContent" then
            return CreateRootContent(host)
        end

        if concreteWidgetType ~= "SimpleGroup" then
            return nil
        end

        if groupProps.layout == "VerticalGroup" then
            concreteGroup = CreateVerticalGroup(groupProps.spacing)
        elseif groupProps.layout == "TwoColumnGroup" then
            concreteGroup = CreateTwoColumnGroup(groupProps.spacing)
        elseif groupProps.layout == "FourColumnGroup" then
            concreteGroup = CreateFourColumnGroup(groupProps.spacing)
        elseif groupProps.layout == "SimpleGroup" then
            concreteGroup = AceGUI:Create("SimpleGroup")
            concreteGroup:SetLayout(groupProps.layoutMode or "List")
        end

        if not concreteGroup then
            return nil
        end

        if groupProps.layoutTable then
            concreteGroup:SetUserData("table", groupProps.layoutTable)
        end

        ApplyHorizontalSizing(concreteGroup, groupProps)

        return concreteGroup
    end

    local group
    if props.sectionKind == "widget_group" then
        group = CreateVerticalGroup(props.structureSpacing or 6)
        local bodyProps = FormRenderer.CloneLayoutValue(props)
        bodyProps.sectionKind = "widget_group_body"
        bodyProps.border = false
        bodyProps.padding = nil
        bodyProps.height = nil
        bodyProps.heightInfo = nil

        local headerHost = CreateSimpleListGroup()
        local bodyHost = CreateConcreteGroup(bodyProps)
        local footerHost = CreateSimpleListGroup()

        if not bodyHost then
            return nil
        end

        group._fpHeaderHost = headerHost
        group._fpBodyHost = bodyHost
        group._fpFooterHost = footerHost
        headerHost._fpOwnerGroup = group
        bodyHost._fpOwnerGroup = group
        footerHost._fpOwnerGroup = group

        group:AddChild(headerHost)
        group:AddChild(bodyHost)
        group:AddChild(footerHost)
    else
        group = CreateConcreteGroup(props)
    end

    if not group then
        return nil
    end

    group.Type = props.type
    group.Variant = props.variant
    group.SectionRole = props.sectionRole
    group.SectionKind = props.sectionKind
    group.StructureSlot = props.structureSlot
    group.Structure = props.structure

    ApplyHorizontalSizing(group, props)
    if props.fullHeight then
        group:SetFullHeight(true)
    end
    if props.height then
        group:SetHeight(props.height)
    elseif not props.fullHeight and group.SetHeight then
        group:SetHeight(1)
    end
    local formWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
    local formSectionSurfaceRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormSectionSurfaceRenderer
    local applySectionBorder = formSectionSurfaceRenderer and formSectionSurfaceRenderer.ApplySectionBorder
    local applySectionSurface = formSectionSurfaceRenderer and formSectionSurfaceRenderer.ApplySectionSurface
    local applySectionPadding = formSectionSurfaceRenderer and formSectionSurfaceRenderer.ApplySectionPadding
    local resolveSectionStyle = formWidgets and formWidgets.ResolveSectionStyle
    local sectionStyle = resolveSectionStyle and resolveSectionStyle(props.surfaceStyle) or nil
    if applySectionSurface then
        applySectionSurface(group, sectionStyle)
    end
    if applySectionBorder then
        local border = props.border
        if border == nil and sectionStyle and sectionStyle.border ~= nil then
            border = sectionStyle.border
        end
        if border == nil and IsWidgetGroupKind(props.sectionKind) then
            border = false
        end
        applySectionBorder(group, border)
    end
    if applySectionPadding then
        applySectionPadding(group, props.padding)
    end

    ApplyGroupHeightRules(group, props)

    return group
end

function FormRenderer.CreateLayoutGroups(host, definitions)
    local groups = {}

    for _, definition in ipairs(definitions or {}) do
        local group = FormRenderer.CreateLayoutGroup(host, definition)
        if group then
            groups[definition.section] = group
        end
    end

    return groups
end

function FormRenderer.BuildLayout(host, definitions, options)
    options = options or {}

    local groups = FormRenderer.CreateLayoutGroups(host, definitions)
    local widgetsById = {}
    local childIndex = FormRenderer.BuildSectionChildrenIndex(definitions)

    local function ResolveSectionHost(group, slot)
        if not group then
            return nil
        end

        if slot == "header" and group._fpHeaderHost then
            return group._fpHeaderHost
        end
        if slot == "footer" and group._fpFooterHost then
            return group._fpFooterHost
        end
        if group._fpBodyHost then
            return group._fpBodyHost
        end

        return group
    end

    local function RenderSectionItems(group, definition)
        if not group or not definition or type(definition.items) ~= "table" then
            return
        end

        local targetGroup = ResolveSectionHost(group, "body")

        for _, item in ipairs(definition.items) do
            local props = FormRenderer.ResolveItemProperties(item)
            local widget = options.createItemWidget and options.createItemWidget(targetGroup, item, props, options.state, options.context) or nil
            if widget then
                widget._fpOwnerGroup = targetGroup
                targetGroup:AddChild(widget)
                RequestRelayout(targetGroup)
                if item.hideInitially and widget.frame and widget.frame.Hide then
                    widget.frame:Hide()
                end
                if item.id then
                    widgetsById[item.id] = widget
                end
                if options.onWidgetCreated then
                    options.onWidgetCreated(widget, targetGroup, item, props, options.state, options.context, widgetsById, groups)
                end
            end
        end
    end

    local function AssembleLayoutSections(parent, parentSection)
        local children = childIndex[parentSection or "__root"] or {}
        for _, definition in ipairs(children) do
            local group = groups[definition.section]
            local props = FormRenderer.ResolveSectionProperties(definition)
            local targetParent = parent
            if props.widgetGroup and groups[props.widgetGroup] then
                targetParent = ResolveSectionHost(groups[props.widgetGroup], props.structureSlot)
            elseif parent then
                targetParent = ResolveSectionHost(parent, "body")
            end

            if group and targetParent and targetParent.AddChild then
                if props.layout ~= "RootContent" then
                    local gapBefore = props.gapBefore
                    if gapBefore == nil then
                        local previousSibling = GetLastMeaningfulChild(targetParent)
                        if previousSibling and targetParent.SectionKind == "root" then
                            if previousSibling.SectionRole == "header" and props.sectionRole == "content" then
                                gapBefore = 16
                            else
                                gapBefore = 8
                            end
                        end
                    end
                    if type(gapBefore) == "number" and gapBefore > 0 then
                        local spacer = CreateSpacer(gapBefore)
                        spacer._fpOwnerGroup = targetParent
                        targetParent:AddChild(spacer)
                    end
                    group._fpOwnerGroup = targetParent
                    targetParent:AddChild(group)
                    RequestRelayout(group)
                end
                RenderSectionItems(group, definition)
                AssembleLayoutSections(group, definition.section)
            end
        end
    end

    AssembleLayoutSections(host, nil)

    return groups, widgetsById
end
