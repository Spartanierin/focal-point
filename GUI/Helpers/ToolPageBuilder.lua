local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local ToolPageUI = ns.GUI.Helpers.ToolPageUI
local ToolLayout = ns.GUI.Layouts.ToolLayout
local ToolSurfaceStyles = ns.GUI.Styles.ToolSurfaceStyles
local TextStyles = ns.GUI.Helpers.TextStyles

local ToolPageBuilder = {}
ns.GUI.Helpers.ToolPageBuilder = ToolPageBuilder

if not ToolPageBuilder._manualLayoutRegistered then
    AceGUI:RegisterLayout("FP_MANUAL", function(content, children)
        for _, child in ipairs(children or {}) do
            if child and child.frame then
                child.frame:Show()
            end
        end

        local height = content.height or content:GetHeight() or 0
        if content.obj and content.obj.LayoutFinished then
            content.obj:LayoutFinished(nil, height)
        end
    end)
    ToolPageBuilder._manualLayoutRegistered = true
end

local function ResetSurface(widget)
    if not widget or not widget.frame or not widget.content then
        return
    end

    local frame = widget.frame
    local content = widget.content

    frame._fpToolStyle = nil

    if widget._fpOriginalLayoutFinished then
        widget.LayoutFinished = widget._fpOriginalLayoutFinished
    end

    for _, textureName in ipairs({
        "_fpToolBg",
        "_fpToolHeader",
        "_fpToolAccent",
        "_fpToolBorderTop",
        "_fpToolBorderBottom",
        "_fpToolBorderLeft",
        "_fpToolBorderRight",
    }) do
        if frame[textureName] and frame[textureName].Hide then
            frame[textureName]:Hide()
        end
    end

    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

local function ApplySurface(widget, style)
    if not widget or not widget.frame or not widget.content then
        return
    end

    local frame = widget.frame
    local content = widget.content
    local spec = ToolSurfaceStyles.Get(style)
    frame._fpToolStyle = style

    if not widget._fpOriginalLayoutFinished then
        widget._fpOriginalLayoutFinished = widget.LayoutFinished
    end

    if spec.content_mode == "box" then
        widget.LayoutFinished = function(self, width, height)
            if self.noAutoHeight then
                return
            end

            local insets = spec.insets or ToolSurfaceStyles.none.insets
            self:SetHeight((height or 0) + (insets.top or 0) + (insets.bottom or 0))
        end
    elseif widget._fpOriginalLayoutFinished then
        widget.LayoutFinished = widget._fpOriginalLayoutFinished
    end

    if spec.background then
        if not frame._fpToolBg then
            frame._fpToolBg = frame:CreateTexture(nil, "BACKGROUND")
            frame._fpToolBg:SetAllPoints()
        end
        frame._fpToolBg:SetColorTexture(unpack(spec.background))
        frame._fpToolBg:Show()
    elseif frame._fpToolBg then
        frame._fpToolBg:Hide()
    end

    if spec.header then
        if not frame._fpToolHeader then
            frame._fpToolHeader = frame:CreateTexture(nil, "BORDER")
            frame._fpToolHeader:SetPoint("TOPLEFT")
            frame._fpToolHeader:SetPoint("TOPRIGHT")
            frame._fpToolHeader:SetHeight(34)
        end
        frame._fpToolHeader:SetColorTexture(unpack(spec.header))
        frame._fpToolHeader:Show()
    elseif frame._fpToolHeader then
        frame._fpToolHeader:Hide()
    end

    if spec.accent then
        if not frame._fpToolAccent then
            frame._fpToolAccent = frame:CreateTexture(nil, "BORDER")
            frame._fpToolAccent:SetPoint("TOPLEFT")
            frame._fpToolAccent:SetPoint("TOPRIGHT")
            frame._fpToolAccent:SetHeight(2)
        end
        frame._fpToolAccent:SetColorTexture(unpack(spec.accent))
        frame._fpToolAccent:Show()
    elseif frame._fpToolAccent then
        frame._fpToolAccent:Hide()
    end

    local function EnsureBorder(name)
        if frame[name] then
            return frame[name]
        end
        frame[name] = frame:CreateTexture(nil, "BORDER")
        return frame[name]
    end

    if spec.border then
        local top = EnsureBorder("_fpToolBorderTop")
        top:SetColorTexture(unpack(spec.border))
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        top:SetHeight(1)
        top:Show()

        local bottom = EnsureBorder("_fpToolBorderBottom")
        bottom:SetColorTexture(unpack(spec.border))
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(1)
        bottom:Show()

        local left = EnsureBorder("_fpToolBorderLeft")
        left:SetColorTexture(unpack(spec.border))
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        left:SetWidth(1)
        left:Show()

        local right = EnsureBorder("_fpToolBorderRight")
        right:SetColorTexture(unpack(spec.border))
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(1)
        right:Show()
    else
        for _, borderName in ipairs({
            "_fpToolBorderTop",
            "_fpToolBorderBottom",
            "_fpToolBorderLeft",
            "_fpToolBorderRight",
        }) do
            if frame[borderName] then
                frame[borderName]:Hide()
            end
        end
    end

    local insets = spec.insets or ToolSurfaceStyles.none.insets
    if spec.content_mode == "box" then
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left or 0, -(insets.top or 0))
        content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(insets.right or 0), insets.bottom or 0)
    elseif spec.content_mode == "dynamic" then
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left or 0, -(insets.top or 0))
        content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(insets.right or 0), -(insets.top or 0))
    end
end

local function CreateBaseGroup(layout, width, height, fullWidth)
    local group = AceGUI:Create("SimpleGroup")
    ResetSurface(group)
    group:SetLayout(layout or "List")
    if fullWidth then
        group:SetFullWidth(true)
    elseif width then
        group:SetWidth(width)
    end
    if height then
        group:SetHeight(height)
        if group.frame and group.frame.SetHeight then
            group.frame:SetHeight(height)
        end
    end
    return group
end

local function LayoutWidgetTree(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        LayoutWidgetTree(child)
    end

    if widget.DoLayout then
        widget:DoLayout()
    end
end

local function GetChildrenHeight(widget)
    if not widget then
        return 0
    end

    local total = 0
    for _, child in ipairs(widget.children or {}) do
        if child and child.frame then
            total = total + (child.frame.height or child.frame:GetHeight() or 0)
        end
    end

    return total
end

local function NormalizeBoxHeights(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        NormalizeBoxHeights(child)
    end

    local frame = widget.frame
    local content = widget.content
    local styleName = frame and frame._fpToolStyle
    if not frame or not content or not styleName then
        return
    end

    local spec = ToolSurfaceStyles.Get(styleName)
    if not spec or spec.content_mode ~= "box" then
        return
    end

    local insets = spec.insets or ToolSurfaceStyles.none.insets
    local innerHeight = GetChildrenHeight(widget)
    local targetHeight = innerHeight + (insets.top or 0) + (insets.bottom or 0)
    if targetHeight > 0 then
        widget:SetHeight(targetHeight)
        if frame.SetHeight then
            frame:SetHeight(targetHeight)
        end
    end
end

local function NormalizeFixedHeights(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        NormalizeFixedHeights(child)
    end

    if not widget._fpFixedHeight then
        return
    end

    widget.noAutoHeight = true
    widget:SetHeight(widget._fpFixedHeight)
    if widget.frame and widget.frame.SetHeight then
        widget.frame:SetHeight(widget._fpFixedHeight)
    end
end

local function NormalizeInfoBlocks(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        NormalizeInfoBlocks(child)
    end

    if not widget._fpInfoLabel or not widget.content then
        return
    end

    local label = widget._fpInfoLabel
    local width = widget.content:GetWidth() or widget.content.width or widget.frame:GetWidth() or 0
    if width > 0 and label.SetWidth then
        label:SetWidth(width)
    end

    local labelFrame = label.frame
    local labelHeight = labelFrame and (labelFrame.height or labelFrame:GetHeight() or 0) or 0
    if labelHeight > 0 then
        widget.noAutoHeight = true
        widget:SetHeight(labelHeight)
        if widget.frame and widget.frame.SetHeight then
            widget.frame:SetHeight(labelHeight)
        end
    end
end

local function GetFrameHeight(widget)
    if not widget then
        return 0
    end

    local insetHeight = 0
    local styleName = widget.frame and widget.frame._fpToolStyle
    if styleName then
        local spec = ToolSurfaceStyles.Get(styleName)
        if spec and spec.content_mode == "box" then
            local insets = spec.insets or ToolSurfaceStyles.none.insets
            insetHeight = (insets.top or 0) + (insets.bottom or 0)
        end
    end

    local maxHeight = 0
    local contentHeight = 0
    if styleName and ToolSurfaceStyles.Get(styleName).content_mode == "box" then
        contentHeight = GetChildrenHeight(widget)
        maxHeight = math.max(maxHeight, contentHeight + insetHeight)
    elseif widget.content and widget.content.GetHeight then
        contentHeight = widget.content:GetHeight() or 0
        maxHeight = math.max(maxHeight, contentHeight + insetHeight)
    end

    local frame = widget.frame or widget
    if frame and frame.GetHeight then
        maxHeight = math.max(maxHeight, frame:GetHeight() or 0)
    end

    if maxHeight <= 0 then
        for _, child in ipairs(widget.children or {}) do
            maxHeight = math.max(maxHeight, GetFrameHeight(child))
        end
        if maxHeight > 0 and insetHeight > 0 then
            maxHeight = maxHeight + insetHeight
        end
    end

    return maxHeight
end

function ToolPageBuilder.CreatePage(container, opts)
    local options = type(opts) == "table" and opts or {}

    local pageWidth = options.pageWidth or 840
    local statusTable = options.statusTable
    local scrollable = options.scrollable ~= false
    local renderToken = {}

    if container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container.SetLayout then
        if scrollable then
            container:SetLayout("Fill")
        else
            container:SetLayout("List")
        end
    end
    container._focalPointUsesOwnSurface = true
    container._focalPointRenderToken = renderToken

    local surfaceInsets = ToolSurfaceStyles.Get(options.surfaceStyle or "page_surface").insets or ToolSurfaceStyles.none.insets
    local surfaceWidth = pageWidth + (surfaceInsets.left or 0) + (surfaceInsets.right or 0)

    local scroll
    if scrollable then
        scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        if type(statusTable) == "table" and scroll.SetStatusTable then
            scroll:SetStatusTable(statusTable)
        end
        container:AddChild(scroll)
    end

    local surfaceParent = scroll or container
    local surface = CreateBaseGroup("List", surfaceWidth, nil, false)
    if not scrollable then
        surface:SetFullWidth(false)
    end
    surfaceParent:AddChild(surface)
    ApplySurface(surface, options.surfaceStyle or "page_surface")

    local page = CreateBaseGroup("List", pageWidth, nil, false)
    surface:AddChild(page)
    ApplySurface(page, options.pageStyle or "page_container")

    if scroll and scroll.DoLayout then
        scroll:DoLayout()
    end
    if scroll and scroll.FixScroll then
        scroll:FixScroll()
    end
    if not scrollable and container.DoLayout then
        container:DoLayout()
    end

    return {
        scroll = scroll,
        surface = surface,
        page = page,
        rows = {},
        surfaceInsets = surfaceInsets,
        container = container,
        renderToken = renderToken,
        pageWidth = pageWidth,
    }
end

function ToolPageBuilder.AddSection(parent, opts)
    local options = type(opts) == "table" and opts or {}
    local section = CreateBaseGroup(
        options.layout or "List",
        options.width,
        options.height,
        options.fullWidth ~= false
    )
    parent:AddChild(section)
    ApplySurface(section, options.style or "panel")

    if options.title and options.title ~= "" then
        local title = AceGUI:Create("Label")
        title:SetFullWidth(true)
        title:SetText(options.title)
        ToolPageUI.ApplyLabelStyle(title, "sectionHeader", 13)
        section:AddChild(title)
    end

    if options.subtitle and options.subtitle ~= "" then
        local subtitle = AceGUI:Create("Label")
        subtitle:SetFullWidth(true)
        subtitle:SetText(options.subtitle)
        ToolPageUI.ApplyLabelStyle(subtitle, "help", 11)
        section:AddChild(subtitle)
    end

    return section
end

function ToolPageBuilder.AddColumns(parent, presetName, opts)
    local options = type(opts) == "table" and opts or {}
    local preset = ToolLayout.GetSection(presetName) or ToolLayout.SECTIONS.single

    local widths = options.widths or preset.widths or {}
    local gap = options.gap or preset.gap or 0
    local columnsSpec = {}
    for index = 1, preset.columns do
        columnsSpec[index] = { width = widths[index] or 0 }
    end

    local row = CreateBaseGroup("Table", nil, options.height, true)
    row:SetUserData("table", {
        columns = columnsSpec,
        spaceH = gap,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    parent:AddChild(row)

    local columns = {}

    for index = 1, preset.columns do
        local width = widths[index]
        local column = CreateBaseGroup("List", width, options.height, false)
        row:AddChild(column)
        columns[index] = column
    end

    row._fpColumns = columns
    row._fpGap = gap

    return row, columns
end

function ToolPageBuilder.AddFormRow(parent, widgets)
    local row = CreateBaseGroup("Flow", nil, nil, true)
    row._fpStableRow = true
    parent:AddChild(row)

    for _, widget in ipairs(widgets or {}) do
        if widget then
            row:AddChild(widget)
        end
    end

    return row
end

function ToolPageBuilder.AddInfoText(parent, text, role, size)
    local block = CreateBaseGroup("List", nil, nil, true)
    parent:AddChild(block)

    local label = AceGUI:Create("Label")
    label:SetFullWidth(false)
    label:SetText(text or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(label, role or "help", { size = size })
    elseif ToolPageUI and ToolPageUI.ApplyLabelStyle then
        ToolPageUI.ApplyLabelStyle(label, role or "help", size)
    end

    block:AddChild(label)
    block._fpInfoLabel = label
    return label, block
end

function ToolPageBuilder.AddSpacer(parent, height)
    local spacerHeight = height or 8
    local spacer = CreateBaseGroup("List", nil, spacerHeight, true)
    spacer._fpFixedHeight = spacerHeight
    spacer.noAutoHeight = true
    spacer.LayoutFinished = function(self)
        self:SetHeight(self._fpFixedHeight)
        if self.frame and self.frame.SetHeight then
            self.frame:SetHeight(self._fpFixedHeight)
        end
    end
    parent:AddChild(spacer)
    return spacer
end

function ToolPageBuilder.AddButtonRow(parent, buttons)
    return ToolPageBuilder.AddFormRow(parent, buttons)
end

function ToolPageBuilder.TrackRow(pageContext, row)
    if not pageContext or not row then
        return
    end

    pageContext.rows = pageContext.rows or {}
    table.insert(pageContext.rows, row)
end

local function NormalizeStableRows(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        NormalizeStableRows(child)
    end

    if not widget._fpStableRow then
        return
    end

    local maxHeight = 0
    for _, child in ipairs(widget.children or {}) do
        if child and child.frame then
            maxHeight = math.max(maxHeight, child.frame.height or child.frame:GetHeight() or 0)
        end
    end

    if maxHeight > 0 then
        widget:SetHeight(maxHeight)
        if widget.frame and widget.frame.SetHeight then
            widget.frame:SetHeight(maxHeight)
        end
    end
end

function ToolPageBuilder.FinalizePage(pageContext)
    if not pageContext then
        return
    end

    local function Apply()
        if not pageContext.container or pageContext.container._focalPointRenderToken ~= pageContext.renderToken then
            return
        end

        if pageContext.page and pageContext.page.IsReleasing and pageContext.page:IsReleasing() then
            return
        end

        local targetPageWidth = pageContext.pageWidth or 840
        local insets = pageContext.surfaceInsets or ToolSurfaceStyles.none.insets
        local targetSurfaceWidth = targetPageWidth + (insets.left or 0) + (insets.right or 0)

        if pageContext.page and pageContext.page.SetWidth then
            pageContext.page:SetWidth(targetPageWidth)
        end
        if pageContext.page and pageContext.page.frame and pageContext.page.frame.SetWidth then
            pageContext.page.frame:SetWidth(targetPageWidth)
        end

        if pageContext.surface and pageContext.surface.SetWidth then
            pageContext.surface:SetWidth(targetSurfaceWidth)
        end
        if pageContext.surface and pageContext.surface.frame and pageContext.surface.frame.SetWidth then
            pageContext.surface.frame:SetWidth(targetSurfaceWidth)
        end

        LayoutWidgetTree(pageContext.page)
        NormalizeFixedHeights(pageContext.page)
        NormalizeInfoBlocks(pageContext.page)
        NormalizeStableRows(pageContext.page)
        NormalizeBoxHeights(pageContext.page)

        for _, row in ipairs(pageContext.rows or {}) do
            if row.SetHeight then
                row:SetHeight(1)
            end
            if row.frame and row.frame.SetHeight then
                row.frame:SetHeight(1)
            end

            for _, column in ipairs(row._fpColumns or {}) do
                if column.SetHeight then
                    column:SetHeight(1)
                end
                if column.frame and column.frame.SetHeight then
                    column.frame:SetHeight(1)
                end
            end

            LayoutWidgetTree(row)

            local maxHeight = 0
            for _, column in ipairs(row._fpColumns or {}) do
                LayoutWidgetTree(column)
                maxHeight = math.max(maxHeight, GetFrameHeight(column))
            end

            if maxHeight > 0 then
                row:SetHeight(maxHeight)
                if row.frame and row.frame.SetHeight then
                    row.frame:SetHeight(maxHeight)
                end

                for _, column in ipairs(row._fpColumns or {}) do
                    if column.DoLayout then
                        column:DoLayout()
                    end
                end
            end
        end

        if type(pageContext.onFinalize) == "function" then
            pageContext.onFinalize(pageContext)
        end

        LayoutWidgetTree(pageContext.page)
        NormalizeFixedHeights(pageContext.page)
        NormalizeInfoBlocks(pageContext.page)
        NormalizeStableRows(pageContext.page)
        NormalizeBoxHeights(pageContext.page)
        LayoutWidgetTree(pageContext.page)

        local pageHeight = GetFrameHeight(pageContext.page)
        local surfaceHeight = pageHeight + (insets.top or 0) + (insets.bottom or 0)

        if pageContext.surface and surfaceHeight > 0 then
            pageContext.surface:SetHeight(surfaceHeight)
            if pageContext.surface.frame and pageContext.surface.frame.SetHeight then
                pageContext.surface.frame:SetHeight(surfaceHeight)
            end
        end

        if pageContext.scroll and pageContext.scroll.DoLayout then
            pageContext.scroll:DoLayout()
        end
        if pageContext.scroll and pageContext.scroll.FixScroll then
            pageContext.scroll:FixScroll()
        end
        if (not pageContext.scroll) and pageContext.surface and pageContext.surface.parent and pageContext.surface.parent.DoLayout then
            pageContext.surface.parent:DoLayout()
        end
    end

    Apply()

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if not pageContext.container or pageContext.container._focalPointRenderToken ~= pageContext.renderToken then
                return
            end

            if pageContext.page and pageContext.page.IsReleasing and pageContext.page:IsReleasing() then
                return
            end

            Apply()
        end)
    end
end

return ToolPageBuilder
