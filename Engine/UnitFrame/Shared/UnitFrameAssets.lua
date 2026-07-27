local _, FocalPoint = ...

FocalPoint.UnitFrameAssets = FocalPoint.UnitFrameAssets or {}
local Assets = FocalPoint.UnitFrameAssets

-- Asset helpers resolve texture and font inputs into safe defaults.

local DEFAULT_STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"

function Assets.GetStatusBarTexture(path, context)
    local MediaRegistry = FocalPoint.MediaRegistry
    if not (MediaRegistry and MediaRegistry.ResolveReference) then
        return DEFAULT_STATUSBAR_TEXTURE
    end

    local result = MediaRegistry.ResolveReference(path, "statusbar", DEFAULT_STATUSBAR_REFERENCE)
    local resolvedPath = result and result.resolvedAsset or DEFAULT_STATUSBAR_TEXTURE
    if type(resolvedPath) ~= "string" or resolvedPath == "" then
        resolvedPath = DEFAULT_STATUSBAR_TEXTURE
    end

    if MediaRegistry.RecordStatusBarShadow
        and MediaRegistry.IsDebugEnabled
        and MediaRegistry.IsDebugEnabled()
    then
        local legacyPath = type(path) == "string" and path ~= "" and path or DEFAULT_STATUSBAR_TEXTURE
        MediaRegistry.RecordStatusBarShadow(path, legacyPath, context, result)
    end

    return resolvedPath
end

function Assets.GetFontPath(path)
    if type(path) == "string" and path ~= "" then
        return path
    end

    return STANDARD_TEXT_FONT
end

function Assets.BuildFontFlags(config)
    local flags = {}

    if config.outline then
        flags[#flags + 1] = "OUTLINE"
    end

    if config.thickOutline then
        flags[#flags + 1] = "THICKOUTLINE"
    end

    if config.monochrome then
        flags[#flags + 1] = "MONOCHROME"
    end

    return table.concat(flags, ",")
end
