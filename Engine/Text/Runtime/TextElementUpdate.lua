local _, FocalPoint = ...

FocalPoint.TextElementUpdate = FocalPoint.TextElementUpdate or {}

local Update = FocalPoint.TextElementUpdate
local Preview = FocalPoint.UnitFramePreview or {}
local Presence = FocalPoint.UnitFramePresence or {}
local TextState = FocalPoint.TextElementState or {}
local Status = FocalPoint.TextElementStatus or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}
local Roles = FocalPoint.TextElementRoles or {}
local TextPreview = FocalPoint.TextElementPreview or {}
local VisualPolicy = FocalPoint.EditorVisualPolicy or {}
local TextUtils = FocalPoint.TextElementUtils or {}
local IsSecret = TextUtils.IsSecret

local function SafeSetText(textObject, textValue, preferLastKnownGood)
    if not textObject or not textObject.SetText then
        return false
    end

    local nextValue = type(textValue) == "string" and textValue or ""
    local ok = xpcall(function()
        textObject:SetText(nextValue)
    end, function(message)
        return tostring(message)
    end)

    if ok then
        textObject._focalPointLastKnownText = nextValue
        return true
    end

    if preferLastKnownGood and type(textObject._focalPointLastKnownText) == "string" then
        xpcall(function()
            textObject:SetText(textObject._focalPointLastKnownText)
        end, function(message)
            return tostring(message)
        end)
    end

    return false
end

local function IsTextOwnerAllowed(frame, textConfig)
    return not Status.IsRuntimeOwnerAllowed
        or Status.IsRuntimeOwnerAllowed(textConfig, frame and frame.config)
end

local function IsSelectedTextPreview(frame, key)
    return VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(frame, {
        kind = "text",
        unit = frame and frame._fpUnit,
        textKey = key,
    }) == true
end

local function IsTextEffectivePresent(frame, key, textConfig, deps)
    if type(textConfig) ~= "table" or textConfig.enabled == false then
        return false
    end

    local binding = TextState.GetCompositionBinding and TextState.GetCompositionBinding(frame, key) or nil
    if type(binding) == "table" then
        return binding.effectivePresent == true
    end

    local resolver = deps and deps.IsTextEffectivePresent
    if type(resolver) == "function" then
        return resolver(frame, key, textConfig) == true
    end

    return true
end

local function EnsureTextRuntimeBinding(frame, key, textConfig, deps)
    if TextState.GetCompositionBinding and TextState.GetCompositionBinding(frame, key) ~= nil then
        return
    end

    local materialize = deps and (deps.MaterializeTextRuntimeBinding or deps.MaterializeTextDependencies)
    if type(materialize) == "function" then
        materialize(frame, key, textConfig)
    end
end

local function ClearAndHideText(textObject)
    SafeSetText(textObject, "", false)
    if textObject and textObject.Hide then
        textObject:Hide()
    end
end

local function IsTextEditPreviewMode()
    local interactionMode = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    return interactionMode
        and interactionMode.IsTextMode
        and interactionMode.IsTextMode()
        or false
end

local function ShouldRenderTextEditorPreview(frame, key)
    if IsSelectedTextPreview(frame, key) then
        return true
    end

    if Preview.ShouldRepresentInEditor then
        local shouldRepresent = Preview.ShouldRepresentInEditor(frame and frame._fpUnit, {
            kind = "text",
            textKey = key,
        })
        if shouldRepresent ~= nil then
            return shouldRepresent == true
        end
    end

    return IsTextEditPreviewMode()
end

local function IsTextEditPreviewAvailable(frame, key, textConfig)
    if type(textConfig) ~= "table" or textConfig.enabled == false then
        return false
    end

    if IsSelectedTextPreview(frame, key) then
        return true
    end

    if Status.IsEditorRenderable then
        return Status.IsEditorRenderable(textConfig, {
            textKey = key,
            unitConfig = frame and frame.config,
            db = FocalPoint.db,
        })
    end

    return type(textConfig) == "table" and textConfig.enabled ~= false
end

local function GetClassificationIndicatorEffect(frame)
    local unit = frame and frame._fpUnit
    local unitConfig = UnitUtils.GetUnitDB and UnitUtils.GetUnitDB(unit)
    local indicatorConfig = unitConfig and unitConfig.ClassificationIndicator

    if indicatorConfig == nil then
        return "PORTRAIT_OVERLAY"
    end

    if type(indicatorConfig) ~= "table" then
        return "PORTRAIT_OVERLAY"
    end

    if indicatorConfig.enabled == false then
        return "NONE"
    end

    return indicatorConfig.effect or "PORTRAIT_OVERLAY"
end

local function IsBlankText(value)
    if IsSecret and IsSecret(value) then
        return false
    end

    if type(value) ~= "string" then
        return true
    end
    return value:match("^%s*$") ~= nil
end

local function ShouldSuppressTextForMissingUnit(frame)
    local unit = frame and frame._fpUnit
    if not unit or unit == "player" then
        return false
    end

    if Presence.IsPreviewModeEnabled and Presence.IsPreviewModeEnabled() then
        return false
    end

    local doesUnitSeemPresent = Presence.DoesUnitSeemPresent
    if not doesUnitSeemPresent then
        return false
    end

    return not doesUnitSeemPresent(unit)
end

local function ClampColorComponent(value)
    if type(value) ~= "number" then
        return 0
    end

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function ToColorCode(r, g, b)
    return string.format(
        "|cff%02x%02x%02x",
        math.floor(ClampColorComponent(r) * 255 + 0.5),
        math.floor(ClampColorComponent(g) * 255 + 0.5),
        math.floor(ClampColorComponent(b) * 255 + 0.5)
    )
end

local function GetClassificationLabelStyle(unit)
    local classification = Status.GetUnitClassificationKind and Status.GetUnitClassificationKind(unit) or nil
    if classification == "rare" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Rare",
            color = { 0.38, 0.70, 1.00 },
        }
    elseif classification == "elite" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Elite",
            color = { 0.98, 0.74, 0.26 },
        }
    elseif classification == "rareelite" or classification == "worldboss" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Rare Elite",
            color = { 1.00, 0.88, 0.40 },
        }
    end

    return nil
end

local function ApplyClassificationNameLabel(frame, textRole, renderedText, template, templateContainsToken)
    if textRole ~= "name" or type(renderedText) ~= "string" or (IsSecret and IsSecret(renderedText)) or renderedText == "" then
        return renderedText
    end

    if GetClassificationIndicatorEffect(frame) ~= "NAME_LABEL" then
        return renderedText
    end

    if templateContainsToken and templateContainsToken(template, "classification") then
        return renderedText
    end

    local style = GetClassificationLabelStyle(frame and frame._fpUnit)
    if not style or type(style.label) ~= "string" or style.label == "" then
        return renderedText
    end

    local color = style.color or { 1, 1, 1 }
    return string.format(
        "%s[%s]|r %s",
        ToColorCode(color[1] or 1, color[2] or 1, color[3] or 1),
        style.label,
        renderedText
    )
end

local function EnsureNameFallback(frame, textRole, renderedText)
    if textRole ~= "name" then
        return renderedText
    end

    if not IsBlankText(renderedText) then
        return renderedText
    end

    local unit = frame and frame._fpUnit
    if not unit or not UnitExists or not UnitExists(unit) then
        return renderedText
    end

    local resolvedName = Status.GetResolvedUnitName and Status.GetResolvedUnitName(unit) or nil
    if type(resolvedName) == "string" then
        local ok, hasName = pcall(function()
            return resolvedName ~= ""
        end)
        if ok and hasName then
            return resolvedName
        elseif not ok then
            -- Secret strings can still be renderable; avoid comparing them.
            return resolvedName
        end
    end

    if UnitName then
        local unitName = UnitName(unit)
        if type(unitName) == "string" then
            local ok, hasName = pcall(function()
                return unitName ~= ""
            end)
            if ok and hasName then
                return unitName
            elseif not ok then
                return unitName
            end
        end
    end

    return renderedText
end

local function ResolveRenderableName(frame, renderedText)
    if not IsBlankText(renderedText) then
        return renderedText
    end

    if Presence.IsPreviewModeEnabled and Presence.IsPreviewModeEnabled() then
        local demo = FocalPoint.UnitFrameDemoEnvironment or {}
        local previewValues = (demo.GetUnitValues and demo.GetUnitValues(frame)) or (frame and frame.TestValues) or nil
        local previewName = previewValues and previewValues.name or nil
        if not IsBlankText(previewName) then
            return previewName
        end
    end

    local unit = frame and frame._fpUnit
    local resolvedName = Status.GetResolvedUnitName and Status.GetResolvedUnitName(unit) or nil
    if type(resolvedName) == "string" then
        return resolvedName
    end

    return ""
end

local function RenderNameTextDirect(frame, textObject, renderedText, textConfig)
    if not textObject then
        return
    end

    local finalText = ResolveRenderableName(frame, renderedText)
    SafeSetText(textObject, finalText, true)
    if textObject.SetWidth and textConfig and textConfig.overflowMode ~= "NONE" and textObject.FocalPointOverflowWidth and textObject.FocalPointOverflowWidth > 0 then
        textObject:SetWidth(textObject.FocalPointOverflowWidth)
    end
    textObject:Show()
end

-- Keeps live text refresh logic together while layout/event wiring remains
-- in the orchestrating text module.
local function TokenizeStyledText(text)
    local tokens = {}
    if type(text) ~= "string" or text == "" then
        return tokens
    end

    local index = 1
    local length = #text

    while index <= length do
        local current = text:sub(index, index)
        local nextTwo = text:sub(index, index + 1)

        if nextTwo == "|r" then
            tokens[#tokens + 1] = { text = "|r", visible = false, closesColor = true }
            index = index + 2
        elseif nextTwo == "|c" then
            local colorCode = text:sub(index, index + 9)
            if #colorCode == 10 then
                tokens[#tokens + 1] = { text = colorCode, visible = false, opensColor = true }
                index = index + 10
            else
                tokens[#tokens + 1] = { text = current, visible = true }
                index = index + 1
            end
        elseif nextTwo == "|T" then
            local closeIndex = text:find("|t", index + 2, true)
            if closeIndex then
                tokens[#tokens + 1] = { text = text:sub(index, closeIndex + 1), visible = false }
                index = closeIndex + 2
            else
                tokens[#tokens + 1] = { text = current, visible = true }
                index = index + 1
            end
        else
            local byte = text:byte(index)
            local charLength = 1

            if byte and byte >= 240 then
                charLength = 4
            elseif byte and byte >= 224 then
                charLength = 3
            elseif byte and byte >= 192 then
                charLength = 2
            end

            tokens[#tokens + 1] = {
                text = text:sub(index, math.min(index + charLength - 1, length)),
                visible = true,
            }
            index = index + charLength
        end
    end

    return tokens
end

local function BuildEllipsisCandidate(tokens, visibleLimit)
    local parts = {}
    local visibleCount = 0
    local colorDepth = 0

    for _, token in ipairs(tokens) do
        if token.visible then
            if visibleCount >= visibleLimit then
                break
            end
            visibleCount = visibleCount + 1
            parts[#parts + 1] = token.text
        else
            parts[#parts + 1] = token.text
            if token.opensColor then
                colorDepth = colorDepth + 1
            elseif token.closesColor and colorDepth > 0 then
                colorDepth = colorDepth - 1
            end
        end
    end

    parts[#parts + 1] = "..."
    while colorDepth > 0 do
        parts[#parts + 1] = "|r"
        colorDepth = colorDepth - 1
    end

    return table.concat(parts)
end

local function ApplyOverflow(textObject, renderedText, mode)
    if not textObject then
        return
    end

    local overflowMode = mode or textObject.FocalPointOverflowMode or "NONE"
    local maxWidth = textObject.FocalPointOverflowWidth or 0

    if not SafeSetText(textObject, renderedText or "", true) then
        return
    end

    if IsSecret and IsSecret(renderedText) then
        return
    end

    if overflowMode == "NONE" or maxWidth <= 0 then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if textObject.SetWidth then
        textObject:SetWidth(maxWidth)
    end

    if overflowMode ~= "ELLIPSIS" then
        return
    end

    local currentWidth = 0
    if textObject.GetStringWidth then
        local okWidth, measuredWidth = pcall(textObject.GetStringWidth, textObject)
        if not okWidth or type(measuredWidth) ~= "number" then
            return
        end
        currentWidth = measuredWidth
    end

    local okFitsCurrent, fitsCurrent = pcall(function()
        return currentWidth <= maxWidth
    end)
    if not okFitsCurrent or fitsCurrent then
        return
    end

    local tokens = TokenizeStyledText(renderedText or "")
    local visibleCount = 0
    for _, token in ipairs(tokens) do
        if token.visible then
            visibleCount = visibleCount + 1
        end
    end

    for limit = math.max(visibleCount - 1, 0), 0, -1 do
        local candidate = limit > 0 and BuildEllipsisCandidate(tokens, limit) or "..."
        if not SafeSetText(textObject, candidate, true) then
            return
        end
        local candidateWidth = 0
        if textObject.GetStringWidth then
            local okWidth, measuredWidth = pcall(textObject.GetStringWidth, textObject)
            if not okWidth or type(measuredWidth) ~= "number" then
                return
            end
            candidateWidth = measuredWidth
        end

        local okFitsCandidate, fitsCandidate = pcall(function()
            return candidateWidth <= maxWidth
        end)
        if not okFitsCandidate then
            return
        end

        if fitsCandidate then
            return
        end
    end
end

local function RenderTextEditPreview(frame, key, textObject, textConfig, template, textRole, unpackColor)
    if not TextPreview.BuildTextElementPreview then
        return false
    end

    local r, g, b, a = unpackColor and unpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1
    textObject:SetTextColor(r, g, b, a)

    local previewText = TextPreview.BuildTextElementPreview(textConfig, {
        frame = frame,
        unit = frame and frame._fpUnit,
        textKey = key,
        textRole = textRole,
        template = template,
    })
    SafeSetText(textObject, previewText, true)
    textObject:Show()
    return true
end

function Update.UpdateElement(frame, key, deps)
    local ok, err = xpcall(function()
        deps = deps or {}

        local ResolveConfiguredTemplate = deps.ResolveConfiguredTemplate
        local UnpackColor = deps.UnpackColor
        local GetLiveValue = deps.GetLiveValue
        local ToSafeNumber = deps.ToSafeNumber
        local TemplateContainsToken = deps.TemplateContainsToken
        local GetClassTextColor = deps.GetClassTextColor
        local ApplyDirectTemplate = deps.ApplyDirectTemplate
        local ResolveTextTemplate = deps.ResolveTextTemplate

        if not frame or not frame.Texts or not frame.Texts[key] then
            return
        end

        local textObject = frame.Texts[key]
        local textConfig = frame.config and frame.config.Texts and frame.config.Texts[key]
        EnsureTextRuntimeBinding(frame, key, textConfig, deps)
        if not IsTextEffectivePresent(frame, key, textConfig, deps) then
            ClearAndHideText(textObject)
            return
        end

        local template = ResolveConfiguredTemplate and ResolveConfiguredTemplate(frame, textConfig) or ""
        local textRole = Roles.Resolve and Roles.Resolve(key, textConfig) or nil

        if ShouldRenderTextEditorPreview(frame, key) then
            if not IsTextEditPreviewAvailable(frame, key, textConfig) then
                ClearAndHideText(textObject)
                return
            end

            if RenderTextEditPreview(frame, key, textObject, textConfig, template, textRole, UnpackColor) then
                return
            end
        end

        if Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame) then
            ClearAndHideText(textObject)
            return
        end

        if ShouldSuppressTextForMissingUnit(frame) then
            ClearAndHideText(textObject)
            return
        end

        local r, g, b, a = UnpackColor and UnpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1

        if not IsTextOwnerAllowed(frame, textConfig) then
            ClearAndHideText(textObject)
            return
        end

        -- Resource roles own availability, not content. Render their configured
        -- entity/local expression through the same resolver as other text objects.
        if textRole == "altpower" then
            local visible = GetLiveValue and GetLiveValue(frame, "altPowerVisible", false)
            local powerType = GetLiveValue and GetLiveValue(frame, "altPowerType", nil)
            local safeMax = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerMaxSafe", 0) or 0) or 0
            local rawMax = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerMaxRaw", 0) or 0) or 0
            if not ((visible and safeMax > 0) or (powerType ~= nil and rawMax > 0)) then
                ClearAndHideText(textObject)
                return
            end
        elseif textRole == "classpower" then
            local visible = GetLiveValue and GetLiveValue(frame, "classPowerVisible", false)
            local max = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "classPowerMaxSafe", 0) or 0) or 0
            if not visible or max <= 0 then
                ClearAndHideText(textObject)
                return
            end
        end

        if textRole == "class" or (TemplateContainsToken and TemplateContainsToken(template, "class")) then
            local classR, classG, classB, classA = GetClassTextColor and GetClassTextColor(frame._fpUnit, frame)
            if classR and classG and classB then
                r, g, b, a = classR, classG, classB, classA or 1
            end
        elseif textRole == "level" then
            r, g, b, a = 1.00, 0.82, 0.00, 1.00
        end
        textObject:SetTextColor(r, g, b, a)

        if ApplyDirectTemplate and ApplyDirectTemplate(frame, textObject, frame._fpUnit, template, textConfig.color) then
            local renderedText = textObject:GetText() or ""
            renderedText = EnsureNameFallback(frame, textRole, renderedText)
            renderedText = ApplyClassificationNameLabel(frame, textRole, renderedText, template, TemplateContainsToken)
            ApplyOverflow(textObject, renderedText, textConfig.overflowMode)
            textObject:Show()
            return
        end

        local renderedText = ResolveTextTemplate and ResolveTextTemplate(frame, frame._fpUnit, template) or ""
        renderedText = EnsureNameFallback(frame, textRole, renderedText)
        renderedText = ApplyClassificationNameLabel(frame, textRole, renderedText, template, TemplateContainsToken)
        ApplyOverflow(
            textObject,
            renderedText,
            textConfig.overflowMode
        )
        textObject:Show()
    end, function(message)
        return tostring(message)
    end)

    if ok then
        return
    end

    if frame and frame.Texts and frame.Texts[key] then
        local textObject = frame.Texts[key]
        local textConfig = frame.config and frame.config.Texts and frame.config.Texts[key]
        local textRole = Roles.Resolve and Roles.Resolve(key, textConfig) or nil
        if textRole == "name" then
            RenderNameTextDirect(frame, textObject, nil, textConfig)
            textObject:Show()
        else
            if not SafeSetText(textObject, "", true) then
                textObject:SetText("")
            end
            textObject:Show()
        end
    end

    frame._focalPointTextErrors = frame._focalPointTextErrors or {}
    if frame._focalPointTextErrors[key] ~= err then
        frame._focalPointTextErrors[key] = err
        if FocalPoint and FocalPoint.Warn then
            FocalPoint:Warn(string.format("Text render failed for %s.%s: %s", tostring(frame._fpUnit or "?"), tostring(key), tostring(err)))
        end
    end
end

local function HasAnyDependency(dependencies)
    if type(dependencies) ~= "table" then
        return false
    end

    for _, enabled in pairs(dependencies) do
        if enabled == true then
            return true
        end
    end

    return false
end

local function ShouldUpdateTextKey(frame, key, changedDependencies)
    if not HasAnyDependency(changedDependencies) then
        return true
    end

    if not TextState.GetDependencies then
        return true
    end

    local dependencies = TextState.GetDependencies(frame, key)
    if not HasAnyDependency(dependencies) then
        return true
    end


    for dependency, enabled in pairs(changedDependencies) do
        if enabled == true and dependencies[dependency] == true then
            return true
        end
    end

    return false
end

local function EnsureDependencyBinding(frame, key, textConfig, deps, changedDependencies)
    if HasAnyDependency(changedDependencies) then
        return
    end

    EnsureTextRuntimeBinding(frame, key, textConfig, deps)
    if not IsTextEffectivePresent(frame, key, textConfig, deps) then
        if TextState.InvalidateDependencies then
            TextState.InvalidateDependencies(frame, key)
        end
        return
    end

    local MaterializeTextDependencies = deps and deps.MaterializeTextDependencies
    if not MaterializeTextDependencies or not TextState.GetDependencies then
        return
    end

    if HasAnyDependency(TextState.GetDependencies(frame, key)) then
        return
    end

    MaterializeTextDependencies(frame, key, textConfig)
end

function Update.UpdateAll(frame, deps, changedDependencies)
    if not frame or not frame.config or not frame.config.Texts then
        return
    end

    local updateElement = deps and deps.UpdateElement
    if not updateElement then
        return
    end

    for key, textConfig in pairs(frame.config.Texts) do
        EnsureTextRuntimeBinding(frame, key, textConfig, deps)
        if not IsTextEffectivePresent(frame, key, textConfig, deps) then
            if TextState.InvalidateDependencies then
                TextState.InvalidateDependencies(frame, key)
            end
            updateElement(frame, key)
        else
            EnsureDependencyBinding(frame, key, textConfig, deps, changedDependencies)
            if ShouldUpdateTextKey(frame, key, changedDependencies) then
                updateElement(frame, key)
            end
        end
    end

    if TextState.MarkRenderApplied then
        TextState.MarkRenderApplied(frame)
    end

    local textEditorOverlay = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.TextEditorOverlay
    if textEditorOverlay and textEditorOverlay.UpdateFrame then
        textEditorOverlay.UpdateFrame(frame)
    end
end
