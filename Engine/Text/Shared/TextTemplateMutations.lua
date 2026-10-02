local _, FocalPoint = ...

FocalPoint.TextTemplateMutations = FocalPoint.TextTemplateMutations or {}

local Mutations = FocalPoint.TextTemplateMutations

local function ResolveLibrary()
    return FocalPoint.TextTemplateLibrary
end

local function GetCurrentProfileName(db)
    local library = ResolveLibrary()
    return library and library.GetCurrentProfileName and library.GetCurrentProfileName(db) or nil
end

local function GetProfileByName(db, profileName)
    local library = ResolveLibrary()
    return library and library.GetProfileByName and library.GetProfileByName(db, profileName) or nil
end

local function FindTemplateEntry(db, selection)
    local library = ResolveLibrary()
    return library and library.FindTemplateEntry and library.FindTemplateEntry(db, selection) or nil
end

local function BuildCopyName(baseName, suffix)
    if suffix == 1 then
        return baseName .. " (Copy)"
    end

    return baseName .. " (Copy " .. tostring(suffix) .. ")"
end

local function ResolveTargetTemplateName(templates, templateName, templateValue)
    if type(templates) ~= "table" or type(templateName) ~= "string" or templateName == "" or type(templateValue) ~= "string" then
        return nil, false, false
    end

    local existingValue = templates[templateName]
    if existingValue == nil then
        return templateName, false, true
    end

    if existingValue == templateValue then
        return templateName, true, false
    end

    local suffix = 1
    while true do
        local candidate = BuildCopyName(templateName, suffix)
        local candidateValue = templates[candidate]
        if candidateValue == nil then
            return candidate, false, true
        end
        if candidateValue == templateValue then
            return candidate, true, false
        end
        suffix = suffix + 1
    end
end

local function Result(ok, fields)
    fields = fields or {}
    fields.ok = ok and true or false
    if fields.success == nil then
        fields.success = fields.ok
    end
    return fields
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local NUMERIC_OR_TIME_TOKENS = {
    ["hp:cur"] = true,
    ["hp:max"] = true,
    ["hp:cur:abbr"] = true,
    ["hp:cur:short"] = true,
    ["hp:max:abbr"] = true,
    ["hp:max:short"] = true,
    ["hp:perc"] = true,
    ["absorb:cur"] = true,
    ["absorb:cur:abbr"] = true,
    ["healabsorb:cur"] = true,
    ["healabsorb:cur:abbr"] = true,
    ["power:cur"] = true,
    ["power:max"] = true,
    ["power:cur:abbr"] = true,
    ["power:cur:short"] = true,
    ["power:max:abbr"] = true,
    ["power:max:short"] = true,
    ["power:perc"] = true,
    ["altpower:cur"] = true,
    ["altPower:cur"] = true,
    ["altpower:max"] = true,
    ["altPower:max"] = true,
    ["altpower:cur:abbr"] = true,
    ["altPower:cur:abbr"] = true,
    ["altpower:max:abbr"] = true,
    ["altPower:max:abbr"] = true,
    ["classpower:cur"] = true,
    ["classpower:max"] = true,
    ["classpower:cur:abbr"] = true,
    ["classpower:max:abbr"] = true,
    ["curhp"] = true,
    ["maxhp"] = true,
    ["curhp:abbr"] = true,
    ["maxhp:abbr"] = true,
    ["perhp"] = true,
    ["curpp"] = true,
    ["maxpp"] = true,
    ["curpp:abbr"] = true,
    ["maxpp:abbr"] = true,
    ["cast:time"] = true,
    ["status:timer"] = true,
    ["dead:timer"] = true,
}

local FORMAT_TOKENS = {
    rc = true,
    powercolor = true,
    raidcolor = true,
    resetcolor = true,
    classcolor = true,
}

local function ResolveInitialTextGrowth(template, role)
    if role == "status" then
        return "CENTER_GROWTH"
    end

    if role == "health" or role == "power" or role == "altpower" or role == "classpower" or role == "cast_time" then
        return "LEFT_GROWTH"
    end

    if type(template) ~= "string" or template == "" then
        return "RIGHT_GROWTH"
    end

    local sawNumericOrTime = false
    local sawNonNumeric = false
    for token in template:gmatch("%[([^%]]+)%]") do
        if not FORMAT_TOKENS[token] and not token:match("^color:") then
            if NUMERIC_OR_TIME_TOKENS[token] then
                sawNumericOrTime = true
            else
                sawNonNumeric = true
            end
        end
    end

    -- Words around a value make the template intentionally mixed, not numeric-only.
    local literalText = template:gsub("%b[]", "")
    if literalText:find("[%a]") then
        sawNonNumeric = true
    end

    if sawNumericOrTime and not sawNonNumeric then
        return "LEFT_GROWTH"
    end

    return "RIGHT_GROWTH"
end

local function ApplyInitialTextGrowthDefaults(textConfig, template, role)
    local growth = ResolveInitialTextGrowth(template, role)
    if growth == "LEFT_GROWTH" then
        textConfig.point = "RIGHT"
        textConfig.justifyH = "RIGHT"
    elseif growth == "CENTER_GROWTH" then
        textConfig.point = "CENTER"
        textConfig.justifyH = "CENTER"
    else
        textConfig.point = "LEFT"
        textConfig.justifyH = "LEFT"
    end
end

local function GetTemplatesFromContext(context)
    if type(context) ~= "table" or type(context.GetTemplates) ~= "function" then
        return nil
    end

    local ok, templates = pcall(context.GetTemplates)
    if ok and type(templates) == "table" then
        return templates
    end

    return nil
end

local function GetUnitsFromContext(context)
    if type(context) ~= "table" then
        return nil
    end

    if type(context.GetUnits) == "function" then
        local ok, units = pcall(context.GetUnits)
        if ok and type(units) == "table" then
            return units
        end
    end

    return nil
end

local function GetUnitConfigFromContext(context, unitKey)
    if type(context) ~= "table" or not IsNonEmptyString(unitKey) then
        return nil
    end

    if type(context.GetUnitConfig) == "function" then
        local ok, unitConfig = pcall(context.GetUnitConfig, unitKey)
        if ok and type(unitConfig) == "table" then
            return unitConfig
        end
        return nil
    end

    local units = GetUnitsFromContext(context)
    local unitConfig = units and units[unitKey] or nil
    return type(unitConfig) == "table" and unitConfig or nil
end

local function GetTextConfig(context, unitKey, textKey)
    local unitConfig = GetUnitConfigFromContext(context, unitKey)
    local texts = unitConfig and unitConfig.Texts or nil
    local textConfig = type(texts) == "table" and texts[textKey] or nil
    return type(textConfig) == "table" and textConfig or nil, texts, unitConfig
end

local function NormalizeUnitTexts(unitConfig)
    local utils = FocalPoint.UnitFrameUtils
    if type(unitConfig) == "table" and type(utils) == "table" and type(utils.NormalizeUnitTexts) == "function" then
        utils.NormalizeUnitTexts(unitConfig)
    end
end

local function NormalizeReferencedUnits(context, references)
    local normalizedUnits = {}
    if type(references) ~= "table" then
        return
    end

    for _, reference in ipairs(references) do
        local unitKey = reference and reference.unitKey
        if IsNonEmptyString(unitKey) and not normalizedUnits[unitKey] then
            NormalizeUnitTexts(GetUnitConfigFromContext(context, unitKey))
            normalizedUnits[unitKey] = true
        end
    end
end

local function RemoveTemplateReferencesFromTextConfig(textConfig, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(templateName) then
        return false
    end

    local changed = false
    if textConfig.templateName == templateName then
        textConfig.templateName = ""
        changed = true
    end

    if type(textConfig.stateTemplates) == "table" then
        for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
            if stateTemplateName == templateName then
                textConfig.stateTemplates[stateKey] = ""
                changed = true
            end
        end
    end

    return changed
end

local function RemovePrimaryTemplateReference(textConfig, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(templateName) or textConfig.templateName ~= templateName then
        return false
    end

    textConfig.templateName = ""
    return true
end

local function RemoveStateTemplateReference(textConfig, stateKey, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(stateKey) or type(textConfig.stateTemplates) ~= "table" then
        return false
    end
    if not IsNonEmptyString(templateName) or textConfig.stateTemplates[stateKey] ~= templateName then
        return false
    end

    textConfig.stateTemplates[stateKey] = nil
    if next(textConfig.stateTemplates) == nil then
        textConfig.stateTemplates = nil
    end
    return true
end

function Mutations.BuildTextElementConfig(template, linkedTemplateName)
    local textConfig = {
        enabled = true,
        tag = template or "",
        templateName = linkedTemplateName or "",
        font = "fp:font:standard",
        fontStyle = "NONE",
        fontSize = 12,
        justifyH = "CENTER",
        anchorTo = "HealthBar",
        point = "CENTER",
        relativePoint = "CENTER",
        offsetX = 0,
        offsetY = 0,
        overflowMode = "NONE",
        shadowEnabled = true,
        shadowColor = { 0, 0, 0, 1 },
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        color = { 1, 1, 1, 1 },
    }

    ApplyInitialTextGrowthDefaults(textConfig, template)
    return textConfig
end

function Mutations.GetNextTextKey(context, unitKey)
    local unitConfig = GetUnitConfigFromContext(context, unitKey)
    local texts = unitConfig and unitConfig.Texts or nil
    local maxIndex = 0

    if type(texts) == "table" then
        for textId in pairs(texts) do
            if type(textId) == "string" then
                local numericId = tonumber(textId:match("^text_(%d+)$"))
                if numericId and numericId > maxIndex then
                    maxIndex = numericId
                end
            end
        end
    end

    local nextIndex = maxIndex + 1
    local candidateId = string.format("text_%d", nextIndex)
    while type(texts) == "table" and texts[candidateId] ~= nil do
        nextIndex = nextIndex + 1
        candidateId = string.format("text_%d", nextIndex)
    end

    return candidateId
end

local function ValidateTemplateName(templateName)
    if not IsNonEmptyString(templateName) then
        return false
    end
    return true
end

local function ValidateTemplateText(templateText)
    return type(templateText) == "string"
end

-- New main-source operations use an explicit expectedLayoutId, not legacy getters.
-- Validation must not materialize defaults or mutate presence fields on failure.
local LegacyMain = {field = "templateName", empty = ""}
local EntityMain = {field = "templateId"}
local function ResolveMainContentTarget(context, unitKey, textKey, contract, stateOperation)
    contract = contract or LegacyMain
    local db = FocalPoint.db
    if contract == EntityMain then db = type(context) == "table" and context.db or nil end
    local layouts = FocalPoint.ActiveLayoutResolver
    local store = FocalPoint.UserLayoutStore
    local roles = FocalPoint.TextElementRoles
    local resolver = FocalPoint.TextTemplateResolver
    if type(context) ~= "table" or not IsNonEmptyString(context.expectedLayoutId)
        or type(db) ~= "table" or (contract == EntityMain and type(context.db) ~= "table")
        or (contract == LegacyMain and (not (layouts and layouts.GetStoredActiveLayoutId)
            or not (store and store.GetRawReadOnly))) or not (roles and roles.Resolve)
        or not (resolver and resolver.Invalidate)
    then
        return nil, "invalid_context"
    end

    local layoutId = context.expectedLayoutId
    local char = rawget(db, "char")
    local activeId
    if contract == EntityMain then activeId = type(char) == "table" and rawget(char, "activeLayoutId")
    else activeId = layouts.GetStoredActiveLayoutId(db) end
    if activeId ~= layoutId then
        return nil, "layout_mismatch"
    end
    if not layoutId:match("^layout:") then
        return nil, "readonly_layout"
    end
    local record
    if contract == EntityMain then
        local global = rawget(db, "global")
        local records = type(global) == "table" and rawget(global, "UserLayouts")
        record = type(records) == "table" and rawget(records, layoutId)
    else record = store.GetRawReadOnly(layoutId, db) end
    local payload = type(record) == "table" and record.payload or nil
    if type(payload) ~= "table" or type(payload.Units) ~= "table" or (contract == LegacyMain and type(payload.TextTemplates) ~= "table")
        or (contract == EntityMain and payload.TextTemplates ~= nil) then
        return nil, "invalid_context"
    end
    local unitConfig = IsNonEmptyString(unitKey) and payload.Units[unitKey] or nil
    if type(unitConfig) ~= "table" then
        return nil, "unit_not_found"
    end
    local texts = unitConfig.Texts
    local textConfig = type(texts) == "table" and IsNonEmptyString(textKey) and texts[textKey] or nil
    if type(textConfig) ~= "table" then
        return nil, "text_element_not_found"
    end
    if contract == EntityMain and (textConfig.templateName ~= nil or textConfig.stateTemplates ~= nil
        or (textConfig.stateTemplateIds ~= nil and type(textConfig.stateTemplateIds) ~= "table")) then
        return nil, "invalid_context"
    end
    local target = {
        context = context, contract = contract, db = db, layoutId = layoutId, record = record, payload = payload,
        units = payload.Units, unitKey = unitKey, unitConfig = unitConfig,
        texts = texts, textKey = textKey, textConfig = textConfig, templates = payload.TextTemplates,
        role = textConfig.role, templateName = textConfig[contract.field], tag = textConfig.tag,
        resolver = resolver,
    }
    if contract == EntityMain then
        target.stateIds = textConfig.stateTemplateIds
        target.stateSnapshot = {}
        for state, id in pairs(target.stateIds or {}) do
            if not IsNonEmptyString(state) or not ResolveLibrary().GetTemplateIdKind(id) then
                return nil, "invalid_context"
            end
            target.stateSnapshot[state] = id
        end
    end
    local role = roles.Resolve(textKey, textConfig)
    if not stateOperation and (role == "altpower" or role == "classpower") then
        return nil, "unsupported_text_role"
    end
    return target
end

local function ReadMainTemplate(target, templateName)
    if target.contract == EntityMain then
        local entity, reason = ResolveLibrary().ResolveTemplateEntity(templateName, target.db)
        if not entity then return nil, reason.errorCode end
        if not entity.content:find("%S") then return nil, "invalid_template_text" end
        target.checkedEntity = entity
        return entity.content
    end
    if not ValidateTemplateName(templateName) or not templateName:find("%S") then
        return nil, "invalid_template_name"
    end
    local expression = target.templates[templateName]
    if expression == nil then
        return nil, "template_not_found"
    end
    if not ValidateTemplateText(expression) or not expression:find("%S") then
        return nil, "invalid_template_text"
    end
    return expression
end

local function ConfirmMainContentTarget(target, templateName, expression)
    -- Final identity check has no context getters, materialization or callbacks.
    local db = FocalPoint.db
    if target.contract == EntityMain then db = target.context.db end
    local char = type(db) == "table" and rawget(db, "char") or nil
    local global = type(db) == "table" and rawget(db, "global") or nil
    local records = type(global) == "table" and rawget(global, "UserLayouts") or nil
    if db ~= target.db or target.context.expectedLayoutId ~= target.layoutId
        or type(char) ~= "table" or rawget(char, "activeLayoutId") ~= target.layoutId
        or type(records) ~= "table" or rawget(records, target.layoutId) ~= target.record
        or target.record.payload ~= target.payload or target.payload.Units ~= target.units
        or target.payload.TextTemplates ~= target.templates
    then
        return false, "layout_mismatch"
    end
    if target.units[target.unitKey] ~= target.unitConfig or target.unitConfig.Texts ~= target.texts
        or target.texts[target.textKey] ~= target.textConfig
    then
        return false, "text_element_not_found"
    end
    if target.textConfig.role ~= target.role or target.textConfig[target.contract.field] ~= target.templateName
        or target.textConfig.tag ~= target.tag or (target.contract == LegacyMain and templateName ~= nil and target.templates[templateName] ~= expression)
    then
        return false, "invalid_context"
    end
    if target.contract == EntityMain then
        if target.textConfig.stateTemplateIds ~= target.stateIds
            or target.textConfig.templateName ~= nil or target.textConfig.stateTemplates ~= nil then
            return false, "invalid_context"
        end
        for state, id in pairs(target.stateSnapshot) do
            if target.stateIds[state] ~= id then return false, "invalid_context" end
        end
        for state, id in pairs(target.stateIds or {}) do
            if target.stateSnapshot[state] ~= id then return false, "invalid_context" end
        end
        -- E2 already resolved the entity. Final commit guard only inspects raw
        -- User storage; Built-in records are immutable private catalog snapshots.
        local entity = target.checkedEntity
        if entity and entity.kind == "user" then
            local templates = rawget(global, "TextTemplates")
            local record = type(templates) == "table" and rawget(templates, entity.templateId)
            if type(record) ~= "table" or record.name ~= entity.name or record.content ~= entity.content then
                return false, "invalid_context"
            end
        end
    end
    return true
end

-- Read the bound main expression only: no state resolution, rendering or tag fallback.
local function GetMainTemplateExpression(contract, context, unitKey, textKey)
    local target, reason = ResolveMainContentTarget(context, unitKey, textKey, contract)
    if not target then return Result(false, { errorCode = reason }) end
    local expression
    expression, reason = ReadMainTemplate(target, target.templateName)
    if not expression then return Result(false, { errorCode = reason }) end
    local current
    current, reason = ConfirmMainContentTarget(target, target.templateName, expression)
    if not current then return Result(false, { errorCode = reason }) end
    return Result(true, { layoutId = target.layoutId, unitKey = unitKey, textKey = textKey,
        [contract.field] = target.templateName, expression = expression })
end

local function CommitMainContent(target, checkedTemplate, checkedExpression, templateName, expression)
    local current, reason = ConfirmMainContentTarget(target, checkedTemplate, checkedExpression)
    if not current then return Result(false, { errorCode = reason }) end
    local textConfig = target.textConfig
    local changed = textConfig[target.contract.field] ~= templateName or textConfig.tag ~= expression
    if changed then
        textConfig[target.contract.field] = templateName
        textConfig.tag = expression
    end
    local result = Result(true, { layoutId = target.layoutId, unitKey = target.unitKey,
        textKey = target.textKey, [target.contract.field] = templateName, changed = changed })
    if changed then
        -- Data is committed. A later refresh failure must not report a failed mutation.
        local ok, err = pcall(target.resolver.Invalidate, textConfig)
        result.cacheInvalidated = ok
        if not ok then result.cacheInvalidationError = tostring(err) end
    end
    -- As with the existing mutations, the caller runs its normal live/Inspector refresh.
    return result
end

local function SetLocalMainContent(contract, context, unitKey, textKey, expression)
    local target, reason = ResolveMainContentTarget(context, unitKey, textKey, contract)
    if not target then return Result(false, { errorCode = reason }) end
    if type(expression) ~= "string" or not expression:find("%S") then
        return Result(false, { errorCode = "invalid_local_content" })
    end
    if target.templateName == nil or (contract == LegacyMain and target.templateName == "") then
        -- Local content has no main template to validate; keep all target checks.
        return CommitMainContent(target, nil, nil, contract.empty, expression)
    end
    local sourceExpression
    sourceExpression, reason = ReadMainTemplate(target, target.templateName)
    if not sourceExpression then return Result(false, { errorCode = reason }) end
    return CommitMainContent(target, target.templateName, sourceExpression, contract.empty, expression)
end

local function AssignMainTemplate(contract, context, unitKey, textKey, templateName)
    local target, reason = ResolveMainContentTarget(context, unitKey, textKey, contract)
    if not target then return Result(false, { errorCode = reason }) end
    local expression
    expression, reason = ReadMainTemplate(target, templateName)
    if not expression then return Result(false, { errorCode = reason }) end
    return CommitMainContent(target, templateName, expression, templateName, "")
end

-- Temporary explicit E4 boundary. E6 retains Entity and removes LegacyMain
-- and these legacy wrappers once the active callers and persisted graph cut over.
Mutations.Entity = {}
local Entity = Mutations.Entity
local function BindMain(contract, target)
    target.GetMainTemplateExpression = function(context, unit, key)
        return GetMainTemplateExpression(contract, context, unit, key)
    end
    target.SetLocalMainContent = function(context, unit, key, expression)
        return SetLocalMainContent(contract, context, unit, key, expression)
    end
    target.AssignMainTemplate = function(context, unit, key, id)
        return AssignMainTemplate(contract, context, unit, key, id)
    end
end
BindMain(LegacyMain, Mutations)
BindMain(EntityMain, Entity)

local function ChangeEntityState(context, unitKey, textKey, stateKey, id, remove)
    if not IsNonEmptyString(stateKey) then return Result(false, {errorCode = "state_key_invalid"}) end
    local target, reason = ResolveMainContentTarget(context, unitKey, textKey, EntityMain, true)
    if not target then return Result(false, {errorCode = reason}) end
    if not remove then
        local entity, err = ResolveLibrary().ResolveTemplateEntity(id, target.db)
        if not entity then return Result(false, {errorCode = err.errorCode}) end
        target.checkedEntity = entity
    end
    local valid
    valid, reason = ConfirmMainContentTarget(target)
    if not valid then return Result(false, {errorCode = reason}) end
    local text = target.textConfig
    local states = text.stateTemplateIds
    local old = states and states[stateKey]
    local changed = old ~= id
    if changed then
        if not states then states = {}; text.stateTemplateIds = states end
        states[stateKey] = id
        if next(states) == nil then text.stateTemplateIds = nil end
    end
    local result = Result(true, {changed = changed, layoutId = target.layoutId,
        unitKey = unitKey, textKey = textKey, stateKey = stateKey, templateId = id})
    if changed then
        local ok, err = pcall(target.resolver.Invalidate, text)
        result.cacheInvalidated = ok
        if not ok then result.cacheInvalidationError = tostring(err) end
    end
    return result
end
function Entity.AssignStateTemplate(context, unit, key, state, id)
    return ChangeEntityState(context, unit, key, state, id, false)
end
function Entity.UnassignStateTemplate(context, unit, key, state)
    return ChangeEntityState(context, unit, key, state, nil, true)
end

-- Entity record operations reuse E1 validation, optimistic snapshots and ID
-- generation. Only Delete adds the required whole-graph usage check.
function Entity.CreateTemplate(db, name, content, generator)
    local library = ResolveLibrary()
    local record = {name = name, content = content}
    local valid, reason = library.ValidateTemplateRecord(record)
    if not valid or type(db) ~= "table" then return Result(false, {errorCode = reason or "invalid_context"}) end
    local id
    if generator then id, reason = generator:Reserve(db, {})
    else id, reason = library.ReserveUserTemplateId(db, {}) end
    if not id then return Result(false, {errorCode = reason}) end
    valid, reason = library.CreateUserTemplateRecord(id, record, db)
    return Result(valid, {errorCode = reason, templateId = id, changed = valid})
end
local function ChangeEntityRecord(db, id, expected, changes)
    if type(db) ~= "table" then return Result(false, {errorCode = "invalid_context"}) end
    local ok, reason = ResolveLibrary().UpdateUserTemplateRecord(id, expected, changes, db)
    return Result(ok, {errorCode = reason, templateId = id, changed = ok})
end
function Entity.UpdateTemplate(db, id, expected, content)
    if type(content) ~= "string" then return Result(false, {errorCode = "invalid-template-content"}) end
    return ChangeEntityRecord(db, id, expected, {content = content})
end
function Entity.RenameTemplate(db, id, expected, name)
    if type(name) ~= "string" then return Result(false, {errorCode = "invalid-template-name"}) end
    return ChangeEntityRecord(db, id, expected, {name = name})
end
function Entity.CopyTemplate(db, id, generator)
    if type(db) ~= "table" then return Result(false, {errorCode = "invalid_context"}) end
    local entity, reason = ResolveLibrary().ResolveTemplateEntity(id, db)
    if not entity then return Result(false, {errorCode = reason.errorCode}) end
    return Entity.CreateTemplate(db, entity.name, entity.content, generator)
end
function Entity.DeleteTemplate(db, id, expected)
    local library = ResolveLibrary()
    if type(db) ~= "table" then return Result(false, {errorCode = "invalid_context"}) end
    local record, reason = library.GetUserTemplateRecord(id, db)
    if not record then return Result(false, {errorCode = reason}) end
    if not library.TemplateRecordsEqual(record, expected) then return Result(false, {errorCode = "template-conflict"}) end
    local global = rawget(db, "global")
    local layouts = type(global) == "table" and rawget(global, "UserLayouts")
    -- Missing/malformed/legacy graphs are not evidence of zero usage.
    if not FocalPoint.TextTemplateValidation.ValidateEntityLayouts(layouts, db).valid then
        return Result(false, {errorCode = "invalid_context"})
    end
    local count = #FocalPoint.TextTemplateUsage.ScanEntities(layouts, id)
    if count > 0 then return Result(false, {errorCode = "template_in_use", affectedReferences = count}) end
    local ok
    ok, reason = library.DeleteUserTemplateRecord(id, expected, db)
    return Result(ok, {errorCode = reason, templateId = id, changed = ok})
end

local function ForEachTemplateReference(context, templateName, callback)
    local usage = FocalPoint.TextTemplateUsage
    local references = usage and usage.FindReferences and usage.FindReferences(context, templateName) or {}
    if type(references) ~= "table" then
        return 0
    end

    local processed = 0
    local unresolved = 0
    for _, reference in ipairs(references) do
        local textConfig = GetTextConfig(context, reference.unitKey, reference.textKey)
        if callback and type(textConfig) == "table" then
            local field = reference.referenceKind == "state" and "stateTemplates" or "templateName"
            callback(reference.unitKey, reference.textKey, textConfig, field, reference.stateKey)
            processed = processed + 1
        elseif callback then
            unresolved = unresolved + 1
        end
    end

    if callback then
        return processed, unresolved
    end
    return #references, 0
end

function Mutations.CountTemplateReferences(context, templateName)
    local usage = FocalPoint.TextTemplateUsage
    if usage and usage.CountReferences then
        return usage.CountReferences(context, templateName)
    end

    return ForEachTemplateReference(context, templateName, nil)
end

function Mutations.CreateProfileContext(profile)
    if type(profile) ~= "table" then
        return nil
    end

    return {
        GetTemplates = function()
            profile.TextTemplates = type(profile.TextTemplates) == "table" and profile.TextTemplates or {}
            return profile.TextTemplates
        end,
        GetUnits = function()
            return type(profile.Units) == "table" and profile.Units or nil
        end,
        GetUnitConfig = function(unitKey)
            return type(profile.Units) == "table" and profile.Units[unitKey] or nil
        end,
    }
end

function Mutations.CreateActiveLayoutContext(db)
    local resolver = FocalPoint.ActiveLayoutResolver
    if not (resolver and resolver.EnsureEditableActiveLayout) then
        return nil
    end

    local function GetPayload()
        local payload = resolver.EnsureEditableActiveLayout(db or FocalPoint.db)
        return type(payload) == "table" and payload or nil
    end

    return {
        GetTemplates = function()
            local payload = GetPayload()
            local templates = type(payload) == "table" and payload.TextTemplates or nil
            if type(templates) ~= "table" and type(payload) == "table" then
                payload.TextTemplates = {}
                templates = payload.TextTemplates
            end
            return templates
        end,
        GetUnits = function()
            local payload = GetPayload()
            local units = type(payload) == "table" and payload.Units or nil
            return type(units) == "table" and units or nil
        end,
        GetUnitConfig = function(unitKey)
            local payload = GetPayload()
            local units = type(payload) == "table" and payload.Units or nil
            return type(units) == "table" and units[unitKey] or nil
        end,
    }
end

function Mutations.CreateTemplate(context, templateName, templateText)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if templates[templateName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = templateName })
    end

    templates[templateName] = templateText
    return Result(true, { templateName = templateName, changed = true })
end

function Mutations.UpdateTemplate(context, templateName, templateText)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local changed = templates[templateName] ~= templateText
    templates[templateName] = templateText
    return Result(true, { templateName = templateName, changed = changed })
end

function Mutations.RenameTemplate(context, oldName, newName, templateText)
    if not ValidateTemplateName(oldName) or not ValidateTemplateName(newName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if templateText ~= nil and not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end
    if oldName == newName then
        return Result(true, { templateName = oldName, changed = false, affectedReferences = 0 })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[oldName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = oldName })
    end
    if templates[newName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = newName })
    end

    local references = {}
    local affected, unresolved = ForEachTemplateReference(context, oldName, function(unitKey, textKey, textConfig, field, stateKey)
        references[#references + 1] = {
            unitKey = unitKey,
            textConfig = textConfig,
            field = field,
            stateKey = stateKey,
        }
    end)
    if unresolved and unresolved > 0 then
        return Result(false, { errorCode = "invalid_context", templateName = oldName })
    end

    templates[newName] = templateText ~= nil and templateText or templates[oldName]
    templates[oldName] = nil
    for _, reference in ipairs(references) do
        if reference.field == "templateName" then
            reference.textConfig.templateName = newName
        elseif reference.field == "stateTemplates" and type(reference.textConfig.stateTemplates) == "table" then
            reference.textConfig.stateTemplates[reference.stateKey] = newName
        end
    end
    NormalizeReferencedUnits(context, references)

    return Result(true, { templateName = newName, oldName = oldName, changed = true, affectedReferences = affected })
end

function Mutations.DeleteTemplate(context, templateName)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local affected = ForEachTemplateReference(context, templateName, nil)
    if affected > 0 then
        return Result(false, { errorCode = "template_in_use", templateName = templateName, affectedReferences = affected })
    end

    templates[templateName] = nil
    return Result(true, { templateName = templateName, changed = true, affectedReferences = 0 })
end

function Mutations.CopyTemplate(sourceContext, targetContext, sourceName, targetName)
    if not ValidateTemplateName(sourceName) or not ValidateTemplateName(targetName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local sourceTemplates = GetTemplatesFromContext(sourceContext)
    local targetTemplates = GetTemplatesFromContext(targetContext)
    if type(sourceTemplates) ~= "table" or type(targetTemplates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local templateText = sourceTemplates[sourceName]
    if type(templateText) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = sourceName })
    end
    if targetTemplates[targetName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = targetName })
    end

    targetTemplates[targetName] = templateText
    return Result(true, { sourceName = sourceName, templateName = targetName, templateValue = templateText, changed = true })
end

function Mutations.MaterializeTemplateEntry(context, sourceEntry)
    if type(sourceEntry) ~= "table" then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templateName = sourceEntry.templateName
    local templateValue = sourceEntry.templateText or sourceEntry.templateValue
    if not ValidateTemplateName(templateName) or type(templateValue) ~= "string" then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local targetTemplateName, reusedExisting, createdNew = ResolveTargetTemplateName(templates, templateName, templateValue)
    if not ValidateTemplateName(targetTemplateName) then
        return Result(false, { errorCode = "template_materialization_failed" })
    end

    if createdNew then
        templates[targetTemplateName] = templateValue
    end

    return Result(true, {
        templateName = targetTemplateName,
        templateValue = templateValue,
        reusedExisting = reusedExisting and true or false,
        createdNew = createdNew and true or false,
        changed = createdNew and true or false,
    })
end

function Mutations.AssignTemplate(context, unitKey, textKey, templateName)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    local changed = textConfig.templateName ~= templateName
    textConfig.templateName = templateName
    if changed then
        NormalizeUnitTexts(unitConfig)
    end
    return Result(true, { templateName = templateName, unitKey = unitKey, textKey = textKey, changed = changed })
end

function Mutations.ResolveTextAnchorTarget(context, objectRef)
    if type(objectRef) ~= "table" then
        return "Frame"
    end

    if objectRef.kind == "bar" and IsNonEmptyString(objectRef.objectKey) then
        return objectRef.objectKey
    end

    if objectRef.kind == "text" then
        local unitConfig = GetUnitConfigFromContext(context, objectRef.unit)
        local associations = FocalPoint.LegacyAssociationMap
        local parentRef = associations and associations.ResolveTextParent and associations.ResolveTextParent(unitConfig, objectRef) or nil
        if type(parentRef) == "table" and parentRef ~= objectRef then
            return Mutations.ResolveTextAnchorTarget(context, parentRef)
        end
    end

    return "Frame"
end

function Mutations.CreateTextFromTemplate(context, unitKey, templateName, options)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local templateText = templates[templateName]
    if type(templateText) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local unitConfig = GetUnitConfigFromContext(context, unitKey)
    if type(unitConfig) ~= "table" then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end

    unitConfig.Texts = type(unitConfig.Texts) == "table" and unitConfig.Texts or {}
    local textKey = type(context.GetNextTextKey) == "function" and context.GetNextTextKey(unitKey) or Mutations.GetNextTextKey(context, unitKey)
    if not IsNonEmptyString(textKey) or unitConfig.Texts[textKey] ~= nil then
        return Result(false, { errorCode = "text_key_unavailable", unitKey = unitKey })
    end

    local textConfig = type(context.CreateTextConfig) == "function"
        and context.CreateTextConfig(unitKey, templateText, templateName)
        or Mutations.BuildTextElementConfig(templateText, templateName)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_unavailable", unitKey = unitKey })
    end

    if type(options) == "table" and type(options.anchorTo) == "string" and options.anchorTo ~= "" then
        textConfig.anchorTo = options.anchorTo
    end

    unitConfig.Texts[textKey] = textConfig
    NormalizeUnitTexts(unitConfig)
    return Result(true, {
        templateName = templateName,
        unitKey = unitKey,
        textKey = textKey,
        changed = true,
    })
end

function Mutations.UnassignTemplate(context, unitKey, textKey)
    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    local templateName = textConfig.templateName
    if not IsNonEmptyString(templateName) then
        return Result(true, { unitKey = unitKey, textKey = textKey, changed = false })
    end

    local changed = RemovePrimaryTemplateReference(textConfig, templateName)
    if changed then
        NormalizeUnitTexts(unitConfig)
    end
    return Result(true, {
        templateName = templateName,
        unitKey = unitKey,
        textKey = textKey,
        changed = changed,
    })
end

function Mutations.AssignStateTemplate(context, unitKey, textKey, stateKey, templateName)
    if not IsNonEmptyString(stateKey) then
        return Result(false, { errorCode = "state_key_invalid" })
    end
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    textConfig.stateTemplates = type(textConfig.stateTemplates) == "table" and textConfig.stateTemplates or {}
    local changed = textConfig.stateTemplates[stateKey] ~= templateName
    textConfig.stateTemplates[stateKey] = templateName
    if changed then
        NormalizeUnitTexts(unitConfig)
    end
    return Result(true, { templateName = templateName, unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = changed })
end

function Mutations.UnassignStateTemplate(context, unitKey, textKey, stateKey)
    if not IsNonEmptyString(stateKey) then
        return Result(false, { errorCode = "state_key_invalid" })
    end

    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end
    if type(textConfig.stateTemplates) ~= "table" then
        return Result(true, { unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = false })
    end

    local templateName = textConfig.stateTemplates[stateKey]
    if not IsNonEmptyString(templateName) then
        local changed = textConfig.stateTemplates[stateKey] ~= nil
        textConfig.stateTemplates[stateKey] = nil
        if next(textConfig.stateTemplates) == nil then
            textConfig.stateTemplates = nil
        end
        if changed then
            NormalizeUnitTexts(unitConfig)
        end
        return Result(true, { unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = changed })
    end

    local changed = RemoveStateTemplateReference(textConfig, stateKey, templateName)
    if changed then
        NormalizeUnitTexts(unitConfig)
    end
    return Result(true, {
        templateName = templateName,
        unitKey = unitKey,
        textKey = textKey,
        stateKey = stateKey,
        changed = changed,
    })
end

function Mutations.ApplyTemplateToUnits(context, options)
    if type(options) ~= "table" or not ValidateTemplateName(options.selectedTemplateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[options.selectedTemplateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = options.selectedTemplateName })
    end

    local appliedUnits = {}
    local removedUnits = {}

    for _, unitKey in ipairs(type(options.unitsToAdd) == "table" and options.unitsToAdd or {}) do
        local unitConfig = GetUnitConfigFromContext(context, unitKey)
        if type(unitConfig) == "table" then
            unitConfig.Texts = unitConfig.Texts or {}
            local textKey = type(context.GetNextTextKey) == "function" and context.GetNextTextKey(unitKey) or Mutations.GetNextTextKey(context, unitKey)
            local textConfig = type(context.CreateTextConfig) == "function"
                and context.CreateTextConfig(unitKey, options.templateText or "", options.linkedTemplateName or "")
                or Mutations.BuildTextElementConfig(options.templateText or "", options.linkedTemplateName or "")
            if IsNonEmptyString(textKey) and type(textConfig) == "table" then
                unitConfig.Texts[textKey] = textConfig
                NormalizeUnitTexts(unitConfig)
                appliedUnits[#appliedUnits + 1] = unitKey
            end
        end
    end

    for _, unitKey in ipairs(type(options.unitsToRemove) == "table" and options.unitsToRemove or {}) do
        local unitConfig = GetUnitConfigFromContext(context, unitKey)
        local texts = unitConfig and unitConfig.Texts or nil
        local unitChanged = false
        if type(texts) == "table" then
            for _, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    local matched = textConfig.templateName == options.selectedTemplateName
                    if not matched and type(textConfig.stateTemplates) == "table" then
                        for _, stateTemplateName in pairs(textConfig.stateTemplates) do
                            if stateTemplateName == options.selectedTemplateName then
                                matched = true
                                break
                            end
                        end
                    end

                    if matched then
                        RemoveTemplateReferencesFromTextConfig(textConfig, options.selectedTemplateName)
                        unitChanged = true
                    end
                end
            end
        end
        if unitChanged then
            NormalizeUnitTexts(unitConfig)
            removedUnits[#removedUnits + 1] = unitKey
        end
    end

    return Result(true, {
        templateName = options.selectedTemplateName,
        linkedTemplateName = options.linkedTemplateName,
        appliedUnits = appliedUnits,
        removedUnits = removedUnits,
        changed = #appliedUnits > 0 or #removedUnits > 0,
    })
end

function Mutations.CopyTemplateEntryToProfile(db, sourceEntry, targetProfileName)
    db = db or FocalPoint.db
    if type(sourceEntry) ~= "table" or sourceEntry.sourceType ~= "profile" then
        return { success = false, reason = "invalid_source" }
    end

    local currentProfileName = GetCurrentProfileName(db)
    if type(targetProfileName) ~= "string" or targetProfileName == "" then
        targetProfileName = currentProfileName
    end
    if type(currentProfileName) ~= "string" or currentProfileName == "" or targetProfileName ~= currentProfileName then
        return { success = false, reason = "invalid_target" }
    end

    local sourceProfileName = sourceEntry.profileName or sourceEntry.sourceId
    local sourceTemplateName = sourceEntry.templateName
    if type(sourceProfileName) ~= "string" or sourceProfileName == "" or type(sourceTemplateName) ~= "string" or sourceTemplateName == "" then
        return { success = false, reason = "invalid_source" }
    end

    local resolvedSource = FindTemplateEntry(db, {
        sourceType = "profile",
        sourceId = sourceProfileName,
        profileName = sourceProfileName,
        templateName = sourceTemplateName,
    })
    if not resolvedSource or type(resolvedSource.templateValue) ~= "string" then
        return { success = false, reason = "source_missing" }
    end

    local targetProfile = GetProfileByName(db, targetProfileName)
    if type(targetProfile) ~= "table" or targetProfile ~= db.profile then
        return { success = false, reason = "invalid_target" }
    end

    targetProfile.TextTemplates = targetProfile.TextTemplates or {}
    local targetTemplates = targetProfile.TextTemplates
    local targetTemplateName, reusedExisting, createdNew = ResolveTargetTemplateName(
        targetTemplates,
        resolvedSource.templateName,
        resolvedSource.templateValue
    )
    if type(targetTemplateName) ~= "string" or targetTemplateName == "" then
        return { success = false, reason = "copy_failed" }
    end

    if createdNew then
        targetTemplates[targetTemplateName] = resolvedSource.templateValue
    end

    return {
        success = true,
        sourceProfileName = sourceProfileName,
        sourceTemplateName = resolvedSource.templateName,
        targetProfileName = targetProfileName,
        targetTemplateName = targetTemplateName,
        templateValue = resolvedSource.templateValue,
        reusedExisting = reusedExisting and true or false,
        createdNew = createdNew and true or false,
    }
end

function Mutations.CopyProfileTemplateToProfile(db, sourceProfileName, templateName, targetProfileName)
    return Mutations.CopyTemplateEntryToProfile(db, {
        sourceType = "profile",
        sourceId = sourceProfileName,
        profileName = sourceProfileName,
        templateName = templateName,
    }, targetProfileName)
end

return Mutations
