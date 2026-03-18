local _, FocalPoint = ...

FocalPoint.TextElementFactory = FocalPoint.TextElementFactory or {}

local Factory = FocalPoint.TextElementFactory

-- Creates the text font strings and registers them on the owning frame.
function Factory.CreateElement(frame, key, textConfig, deps)
    deps = deps or {}

    local GetTextLayerParent = deps.GetTextLayerParent

    if not textConfig or textConfig.enabled == false or not GetTextLayerParent then
        return
    end

    local parent = GetTextLayerParent(frame)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")

    frame.Texts[key] = text
    frame.Tags[key] = textConfig.tag or ""
end

function Factory.CreateAll(frame, deps)
    if not frame or not frame.config or not frame.config.Texts then
        return
    end

    local createElement = deps and deps.CreateElement
    if not createElement then
        return
    end

    for key, textConfig in pairs(frame.config.Texts) do
        createElement(frame, key, textConfig)
    end
end
