local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L
local SectionLayout = ns.GUI.Layouts.SectionLayout

local LayoutHelpers = {}
ns.GUI.Helpers.LayoutHelpers = LayoutHelpers

function LayoutHelpers.CreateSection(container)
    return SectionLayout.CreateTwoColumn(container)
end

function LayoutHelpers.AddLayoutHandle(layout, handle, def)
    if not layout or not handle then
        return nil
    end

    local meta = nil
    if type(def) == "table" then
        meta = {
            placement = def.placement,
            span = def.span,
            rowType = def.rowType,
            subsection = LayoutHelpers.ResolveLayoutText(def.subsection),
        }
    end

    return layout:Add(handle, meta)
end

function LayoutHelpers.BuildScrollableTabContent(widget, statusTable, buildFunc)
    widget:ReleaseChildren()
    widget:SetLayout("Fill")

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetStatusTable(statusTable)
    widget:AddChild(scroll)

    buildFunc(scroll)

    if scroll.DoLayout then
        scroll:DoLayout()
    end

    if scroll.FixScroll then
        scroll:FixScroll()
    end

    if widget.DoLayout then
        widget:DoLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end

            if scroll and scroll.FixScroll then
                scroll:FixScroll()
            end

            if widget and widget.DoLayout then
                widget:DoLayout()
            end
        end)
    end
end

function LayoutHelpers.ResolveLayoutText(value)
    if type(value) ~= "string" then
        return value
    end

    return L[value] or value
end

function LayoutHelpers.ResolveLayoutPath(path, unitKey, replacements)
    if type(path) ~= "table" then
        return path
    end

    local resolved = {}

    for i, part in ipairs(path) do
        if part == "$unitKey" then
            resolved[i] = unitKey
        elseif replacements and replacements[part] ~= nil then
            resolved[i] = replacements[part]
        else
            resolved[i] = part
        end
    end

    return resolved
end

function LayoutHelpers.ResolveLayoutList(list)
    if type(list) ~= "table" then
        return list
    end

    local resolved = {}

    for key, value in pairs(list) do
        resolved[key] = LayoutHelpers.ResolveLayoutText(value)
    end

    return resolved
end

function LayoutHelpers.LayoutWidgetRequiresPath(widgetType)
    return widgetType == "checkbox"
        or widgetType == "dropdown"
        or widgetType == "slider"
end

function LayoutHelpers.IsSupportedLayoutWidget(widgetType)
    return widgetType == "checkbox"
        or widgetType == "dropdown"
        or widgetType == "slider"
end

function LayoutHelpers.CanBuildLayoutWidget(def, resolvedList)
    if type(def) ~= "table" then
        return false
    end

    if not LayoutHelpers.IsSupportedLayoutWidget(def.widget) then
        return false
    end

    if LayoutHelpers.LayoutWidgetRequiresPath(def.widget) and type(def.path) ~= "table" then
        return false
    end

    if def.widget == "dropdown" and type(resolvedList) ~= "table" then
        return false
    end

    return true
end
