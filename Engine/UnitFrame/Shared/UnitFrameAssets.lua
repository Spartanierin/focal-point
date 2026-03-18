local _, FocalPoint = ...

FocalPoint.UnitFrameAssets = FocalPoint.UnitFrameAssets or {}
local Assets = FocalPoint.UnitFrameAssets

-- Asset helpers resolve texture and font inputs into safe defaults.

function Assets.GetStatusBarTexture(path)
    if type(path) == "string" and path ~= "" then
        return path
    end

    return "Interface\\TargetingFrame\\UI-StatusBar"
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
