local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local AceGUI = LibStub("AceGUI-3.0")

local MediaLibraryPreview = {}
ns.GUI.Editor.MediaLibrary.MediaLibraryPreview = MediaLibraryPreview

local STATUSBAR = "statusbar"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"

local function IsNonEmptyString(value)
    return type(value) == "string" and value:gsub("^%s+", ""):gsub("%s+$", "") ~= ""
end

local function ResolveStatusBarAsset(item)
    local Registry = ns.MediaRegistry
    local fallbackUsed = false
    local resolvedAsset = item and item.resolvedAsset or nil

    if IsNonEmptyString(resolvedAsset) and not (item and item.missing == true) then
        return resolvedAsset, fallbackUsed
    end

    if Registry and Registry.ResolveReference then
        local result = Registry.ResolveReference(item and item.value or nil, STATUSBAR, DEFAULT_STATUSBAR_REFERENCE)
        if result and IsNonEmptyString(result.resolvedAsset) then
            fallbackUsed = result.fallbackUsed == true or item == nil or item.missing == true
            return result.resolvedAsset, fallbackUsed
        end
    end

    return "Interface\\TargetingFrame\\UI-StatusBar", true
end

function MediaLibraryPreview.Create(parent)
    local preview = AceGUI:Create("FocalPointMediaPreview")
    preview:SetFullWidth(true)

    if parent and parent.AddChild then
        parent:AddChild(preview)
    end

    return preview
end

function MediaLibraryPreview.Clear(preview)
    if preview and preview.ClearPreview then
        preview:ClearPreview()
    end
end

function MediaLibraryPreview.SetItem(preview, item)
    if not preview then
        return
    end

    if not item or item.mediaType ~= STATUSBAR then
        if preview.SetNoPreview then
            preview:SetNoPreview()
        end
        return
    end

    local asset, fallbackUsed = ResolveStatusBarAsset(item)
    if preview.SetStatusBarPreview then
        preview:SetStatusBarPreview(item, asset, fallbackUsed)
    end
end

return MediaLibraryPreview
