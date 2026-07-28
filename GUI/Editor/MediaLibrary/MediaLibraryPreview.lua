local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local AceGUI = LibStub("AceGUI-3.0")

local MediaLibraryPreview = {}
ns.GUI.Editor.MediaLibrary.MediaLibraryPreview = MediaLibraryPreview

local STATUSBAR = "statusbar"
local FONT = "font"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_FONT_REFERENCE = "fp:font:standard"

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

local function ResolveFontAsset(item)
    local Registry = ns.MediaRegistry
    local fallbackUsed = false
    local resolvedAsset = item and item.resolvedAsset or nil

    if IsNonEmptyString(resolvedAsset) and not (item and item.missing == true) then
        return resolvedAsset, fallbackUsed
    end

    if Registry and Registry.ResolveReference then
        local result = Registry.ResolveReference(item and item.value or nil, FONT, DEFAULT_FONT_REFERENCE)
        if result and IsNonEmptyString(result.resolvedAsset) then
            fallbackUsed = result.fallbackUsed == true or item == nil or item.missing == true
            return result.resolvedAsset, fallbackUsed
        end
    end

    return STANDARD_TEXT_FONT, true
end

local function FormatBool(value)
    return value and "true" or "false"
end

local function FormatMaybeBool(value)
    if value == nil then
        return "n/a"
    end
    return FormatBool(value == true)
end

local function FormatNumber(value)
    value = tonumber(value)
    if not value then
        return "n/a"
    end
    return string.format("%.2f", value)
end

local function FormatColor(r, g, b, a)
    return string.format(
        "%s/%s/%s/%s",
        FormatNumber(r),
        FormatNumber(g),
        FormatNumber(b),
        FormatNumber(a)
    )
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

    if not item then
        MediaLibraryPreview.lastPreviewDiagnostics = nil
        if preview.SetNoPreview then
            preview:SetNoPreview()
        end
        return
    end

    if item.mediaType == STATUSBAR then
        MediaLibraryPreview.lastPreviewDiagnostics = nil
        local asset, fallbackUsed = ResolveStatusBarAsset(item)
        if preview.SetStatusBarPreview then
            preview:SetStatusBarPreview(item, asset, fallbackUsed)
        end
        return
    end

    if item.mediaType == FONT then
        local asset, fallbackUsed = ResolveFontAsset(item)
        if preview.SetFontPreview then
            preview:SetFontPreview(item, asset, {
                fallbackUsed = fallbackUsed,
            })
            MediaLibraryPreview.lastPreviewDiagnostics = preview.lastFontPreviewDiagnostics
        end
        return
    end

    MediaLibraryPreview.lastPreviewDiagnostics = nil
    if preview.SetNoPreview then
        preview:SetNoPreview()
    end
end

function MediaLibraryPreview.BuildDebugReport()
    local detail = MediaLibraryPreview.lastPreviewDiagnostics
    if type(detail) ~= "table" then
        return {
            "Media Library preview diagnostics",
            "  none",
        }
    end

    return {
        "Media Library preview diagnostics",
        string.format("  value=%s", tostring(detail.itemValue or "n/a")),
        string.format("  name=%s source=%s", tostring(detail.itemName or "n/a"), tostring(detail.itemSource or "n/a")),
        string.format("  resolvedAsset=%s", tostring(detail.resolvedAsset or "n/a")),
        string.format(
            "  selectionSequence=%s attempt=%s finalPreviewKind=%s",
            tostring(detail.selectionSequence or "n/a"),
            tostring(detail.attempt or "n/a"),
            tostring(detail.finalPreviewKind or "n/a")
        ),
        string.format(
            "  retryScheduled=%s retryExecuted=%s retryStillCurrent=%s",
            FormatBool(detail.retryScheduled == true),
            FormatBool(detail.retryExecuted == true),
            detail.retryStillCurrent == nil and "n/a" or FormatBool(detail.retryStillCurrent == true)
        ),
        string.format(
            "  pcallOk=%s setFontApplied=%s fallbackAttempted=%s fallbackApplied=%s",
            FormatBool(detail.pcallOk == true),
            FormatBool(detail.setFontApplied == true),
            FormatBool(detail.fallbackAttempted == true),
            FormatBool(detail.fallbackApplied == true)
        ),
        string.format(
            "  widget shown=%s width=%.2f height=%.2f",
            FormatBool(detail.widgetShown == true),
            tonumber(detail.widgetWidth) or 0,
            tonumber(detail.widgetHeight) or 0
        ),
        string.format(
            "  container shown=%s width=%.2f height=%.2f",
            FormatBool(detail.fontContainerShown == true),
            tonumber(detail.fontContainerWidth) or 0,
            tonumber(detail.fontContainerHeight) or 0
        ),
        string.format(
            "  fontString shown=%s width=%.2f height=%.2f",
            FormatBool(detail.fontStringShown == true),
            tonumber(detail.fontStringWidth) or 0,
            tonumber(detail.fontStringHeight) or 0
        ),
        string.format(
            "  stringWidth immediate=%.2f afterLayout=%.2f final=%.2f",
            tonumber(detail.immediateStringWidth) or 0,
            tonumber(detail.afterLayoutStringWidth) or 0,
            tonumber(detail.finalStringWidth) or 0
        ),
        string.format(
            "  font before=%s after=%s",
            tostring(detail.fontBeforeSetFont or "n/a"),
            tostring(detail.fontAfterSetFont or "n/a")
        ),
        string.format(
            "  text before=%s after=%s identical=%s",
            tostring(detail.textBefore or ""),
            tostring(detail.textAfter or ""),
            FormatBool(detail.textWasIdentical == true)
        ),
        string.format(
            "  refreshMethod=%s refreshExecuted=%s fontObjectSame=%s",
            tostring(detail.refreshMethod or "n/a"),
            FormatBool(detail.refreshExecuted == true),
            FormatBool(detail.fontObjectSame == true)
        ),
        string.format(
            "  visible=%s alpha=%s effectiveAlpha=%s textColor=%s",
            FormatBool(detail.isVisible == true),
            FormatNumber(detail.alpha),
            FormatNumber(detail.effectiveAlpha),
            FormatColor(detail.textColorR, detail.textColorG, detail.textColorB, detail.textColorA)
        ),
        string.format(
            "  clipsChildren=%s frameLevel=%s containerLevel=%s strata=%s",
            FormatMaybeBool(detail.containerClipsChildren),
            tostring(detail.widgetFrameLevel or "n/a"),
            tostring(detail.containerFrameLevel or "n/a"),
            tostring(detail.widgetFrameStrata or "n/a")
        ),
        string.format("  text=%s", tostring(detail.fontStringText or "")),
    }
end

return MediaLibraryPreview
