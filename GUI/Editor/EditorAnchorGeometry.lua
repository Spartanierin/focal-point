local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local AnchorGeometry = {}
FocalPoint.GUI.Editor.AnchorGeometry = AnchorGeometry

local AUTO_ANCHOR_PAIRS = {
    top = { left = { "BOTTOMRIGHT", "TOPLEFT" }, center = { "BOTTOM", "TOP" }, right = { "BOTTOMLEFT", "TOPRIGHT" } },
    center = { left = { "RIGHT", "LEFT" }, center = { "CENTER", "CENTER" }, right = { "LEFT", "RIGHT" } },
    bottom = { left = { "TOPRIGHT", "BOTTOMLEFT" }, center = { "TOP", "BOTTOM" }, right = { "TOPLEFT", "BOTTOMRIGHT" } },
}

local GetRectAnchor = FocalPoint.UnitFrameLayout.GetRectAnchor
AnchorGeometry.GetRectAnchor = GetRectAnchor

-- Editor bounds only: cover opposite screen edges plus owner/child extents.
-- Existing offsets remain editable even after resolution/scale changes.
function AnchorGeometry.ResolveCastBarOffsetRange(frame, config, offsetX, offsetY)
    config = config or {}
    local owner = frame or {
        GetEffectiveScale = function()
            return UIParent:GetEffectiveScale() * (tonumber(config.scale) or 1)
        end,
    }
    local screenWidth, screenHeight = FocalPoint.UnitFrameLayout.GetFrameSizeInParent(UIParent, owner)
    local width = tonumber(config.width) or (frame and frame:GetWidth()) or 0
    local height = (frame and frame:GetHeight()) or tonumber(config.height) or 0
    local castHeight = tonumber(config.castBarHeight) or 10
    local iconExtent = config.showCastBarIcon ~= false and (castHeight + 4) or 0
    local castWidth = FocalPoint.UnitFrameCastBar.ResolveStatusBarWidth(width, config, 1)
    local x = math.ceil(math.max(screenWidth + width + castWidth + iconExtent + 1,
        math.abs(tonumber(offsetX) or tonumber(config.castBarOffsetX) or 0)))
    local y = math.ceil(math.max(screenHeight + height + castHeight,
        math.abs(tonumber(offsetY) or tonumber(config.castBarOffsetY) or 0)))
    return -x, x, -y, y
end

function AnchorGeometry.ResolveAutoAnchorGeometry(childRect, ownerRect)
    if type(childRect) ~= "table" or type(ownerRect) ~= "table" then
        return nil
    end
    for _, rect in ipairs({ childRect, ownerRect }) do
        if type(rect.left) ~= "number" or type(rect.right) ~= "number" or type(rect.top) ~= "number" or type(rect.bottom) ~= "number"
            or rect.left >= rect.right or rect.bottom >= rect.top
        then
            return nil
        end
    end

    local centerX = (childRect.left + childRect.right) / 2
    local centerY = (childRect.top + childRect.bottom) / 2
    local width = ownerRect.right - ownerRect.left
    local height = ownerRect.top - ownerRect.bottom
    local horizontal = centerX < ownerRect.left and "left" or centerX > ownerRect.right and "right"
        or centerX < ownerRect.left + width / 3 and "left" or centerX > ownerRect.left + width * 2 / 3 and "right" or "center"
    local vertical = centerY < ownerRect.bottom and "bottom" or centerY > ownerRect.top and "top"
        or centerY < ownerRect.bottom + height / 3 and "bottom" or centerY > ownerRect.bottom + height * 2 / 3 and "top" or "center"
    local pair = AUTO_ANCHOR_PAIRS[vertical][horizontal]
    local childX, childY = GetRectAnchor(childRect, pair[1])
    local ownerX, ownerY = GetRectAnchor(ownerRect, pair[2])
    return {
        point = pair[1],
        relativePoint = pair[2],
        offsetX = childX - ownerX,
        offsetY = childY - ownerY,
    }
end
