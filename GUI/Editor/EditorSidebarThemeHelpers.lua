local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local EditorSidebarThemeHelpers = {}
ns.GUI.Editor.EditorSidebarThemeHelpers = EditorSidebarThemeHelpers

local L = ns.L or {}

local THEME_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

function EditorSidebarThemeHelpers.StyleSidebarButton(button, variant)
    if not button then
        return
    end

    if variant == "active" then
        button:SetHeight(24)
    elseif variant == "danger" then
        button:SetHeight(22)
    elseif variant == "secondary" then
        button:SetHeight(22)
    else
        button:SetHeight(24)
    end

    if button.text and button.text.SetTextColor then
        if variant == "active" then
            button.text:SetTextColor(0.90, 0.84, 0.66, 1)
        elseif variant == "danger" then
            button.text:SetTextColor(0.87, 0.82, 0.80, 1)
        elseif variant == "secondary" then
            button.text:SetTextColor(0.83, 0.86, 0.90, 1)
        else
            button.text:SetTextColor(0.91, 0.92, 0.94, 1)
        end
    end
end

function EditorSidebarThemeHelpers.BuildThemeList(themes)
    local list = {}

    if type(themes) ~= "table" then
        return list
    end

    for _, themeId in ipairs(THEME_ORDER) do
        local theme = themes[themeId]
        if type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    for themeId, theme in pairs(themes) do
        if not list[themeId] and type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    return list
end

function EditorSidebarThemeHelpers.GetFirstThemeId(themeList)
    for _, themeId in ipairs(THEME_ORDER) do
        if themeList[themeId] then
            return themeId
        end
    end

    for themeId in pairs(themeList) do
        return themeId
    end

    return nil
end

return EditorSidebarThemeHelpers
