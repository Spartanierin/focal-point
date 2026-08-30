local _, FocalPoint = ...

FocalPoint.LayoutService = FocalPoint.LayoutService or {}
local LayoutService = FocalPoint.LayoutService
local LAYOUT_SOURCES = {
    PROFILE = "profile",
    BUILTIN = "builtin",
    USER_PRESET = "userPreset",
    USER_LAYOUT = "userLayout",
}
local BUILT_IN_PRESET_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

LayoutService.Sources = LayoutService.Sources or {}
for key, value in pairs(LAYOUT_SOURCES) do
    LayoutService.Sources[key] = value
end

function LayoutService.Clone(value)
    if type(value) ~= "table" then
        return value
    end

    if CopyTable then
        return CopyTable(value)
    end

    local result = {}
    for key, entry in pairs(value) do
        result[key] = LayoutService.Clone(entry)
    end
    return result
end

function LayoutService.MergeInto(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            LayoutService.MergeInto(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

local function NormalizeUnitTexts(unitConfig)
    local utils = FocalPoint.UnitFrameUtils
    if type(utils) == "table" and type(utils.NormalizeUnitTexts) == "function" then
        utils.NormalizeUnitTexts(unitConfig)
    end

    return unitConfig
end

local function NormalizeUnitCompositionPresence(unitConfig)
    local storage = FocalPoint.CompositionPresenceStorage
    if type(storage) == "table" and type(storage.EnsureUnit) == "function" then
        storage.EnsureUnit(unitConfig)
    end

    return unitConfig
end

local function NormalizeUnit(unitConfig)
    NormalizeUnitTexts(unitConfig)
    return NormalizeUnitCompositionPresence(unitConfig)
end

function LayoutService.MaterializeUnit(defaultUnit, unitConfig)
    local materialized = LayoutService.Clone(defaultUnit) or {}
    if type(unitConfig) == "table" then
        LayoutService.MergeInto(materialized, unitConfig)
    end
    return NormalizeUnit(materialized)
end

local function ResolveLayoutDefaults(defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    return {
        Units = defaultProfile and defaultProfile.Units or nil,
        TextTemplates = defaultProfile and defaultProfile.TextTemplates or nil,
    }
end

function LayoutService.NormalizePayload(payload, defaults)
    local layoutDefaults = ResolveLayoutDefaults(defaults)
    local sourceUnits = type(payload) == "table" and payload.Units or nil
    local sourceTemplates = type(payload) == "table" and payload.TextTemplates or nil
    local normalized = {
        Units = {},
        TextTemplates = LayoutService.Clone(layoutDefaults.TextTemplates) or {},
    }

    if type(sourceTemplates) == "table" then
        LayoutService.MergeInto(normalized.TextTemplates, sourceTemplates)
    end

    if type(layoutDefaults.Units) == "table" then
        for unitKey, defaultUnit in pairs(layoutDefaults.Units) do
            normalized.Units[unitKey] = LayoutService.MaterializeUnit(defaultUnit, sourceUnits and sourceUnits[unitKey])
        end
    elseif type(sourceUnits) == "table" then
        normalized.Units = LayoutService.Clone(sourceUnits) or {}
        for _, unitConfig in pairs(normalized.Units) do
            NormalizeUnit(unitConfig)
        end
    end

    local storage = FocalPoint.CompositionPresenceStorage
    if type(storage) == "table" and type(storage.EnsurePayload) == "function" then
        storage.EnsurePayload(normalized)
    end

    return normalized
end

function LayoutService.CopyPayload(payload)
    return LayoutService.NormalizePayload(payload)
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function BuildEnvelope(id, name, source, readOnly, payload, defaults, metadata)
    if not (IsNonEmptyString(id) and IsNonEmptyString(name) and IsNonEmptyString(source)) then
        return nil
    end

    local envelope = {
        id = id,
        name = name,
        source = source,
        readOnly = readOnly == true,
        payload = LayoutService.NormalizePayload(payload, defaults),
    }

    if type(metadata) == "table" then
        if IsNonEmptyString(metadata.labelKey) then
            envelope.labelKey = metadata.labelKey
        end
        if IsNonEmptyString(metadata.description) then
            envelope.description = metadata.description
        end
        if IsNonEmptyString(metadata.descriptionKey) then
            envelope.descriptionKey = metadata.descriptionKey
        end
    end

    return envelope
end

local function BuildSummary(id, name, source, readOnly, metadata)
    if not (IsNonEmptyString(id) and IsNonEmptyString(name) and IsNonEmptyString(source)) then
        return nil
    end

    local summary = {
        id = id,
        name = name,
        source = source,
        readOnly = readOnly == true,
    }

    if type(metadata) == "table" then
        if IsNonEmptyString(metadata.labelKey) then
            summary.labelKey = metadata.labelKey
        end
        if IsNonEmptyString(metadata.description) then
            summary.description = metadata.description
        end
        if IsNonEmptyString(metadata.descriptionKey) then
            summary.descriptionKey = metadata.descriptionKey
        end
    end

    return summary
end

function LayoutService.ProjectProfile(profileName, profile, defaults)
    if not (IsNonEmptyString(profileName) and type(profile) == "table") then
        return nil
    end

    return BuildEnvelope(
        "profile:" .. profileName,
        profileName,
        LAYOUT_SOURCES.PROFILE,
        false,
        {
            Units = profile.Units,
            TextTemplates = profile.TextTemplates,
        },
        defaults
    )
end

function LayoutService.ProjectProfileSummary(profileName, profile)
    if not (IsNonEmptyString(profileName) and type(profile) == "table") then
        return nil
    end

    return BuildSummary(
        "profile:" .. profileName,
        profileName,
        LAYOUT_SOURCES.PROFILE,
        false
    )
end

function LayoutService.ProjectPreset(preset, defaults)
    if type(preset) ~= "table" or type(preset.layout) ~= "table" then
        return nil
    end

    local metadata = type(preset.metadata) == "table" and preset.metadata or {}
    local source = metadata.source
    local envelopeSource = nil
    local idPrefix = nil

    if source == "builtin" then
        envelopeSource = LAYOUT_SOURCES.BUILTIN
        idPrefix = "builtin:"
    elseif source == "user" then
        envelopeSource = LAYOUT_SOURCES.USER_PRESET
        idPrefix = "userPreset:"
    else
        return nil
    end

    local sourceId = IsNonEmptyString(metadata.id) and metadata.id or nil
    if not sourceId then
        return nil
    end

    local name = IsNonEmptyString(metadata.name) and metadata.name
        or IsNonEmptyString(metadata.labelKey) and metadata.labelKey
        or sourceId

    return BuildEnvelope(
        idPrefix .. sourceId,
        name,
        envelopeSource,
        metadata.readOnly == true,
        preset.layout,
        defaults,
        metadata
    )
end

function LayoutService.ProjectPresetSummary(metadata)
    if type(metadata) ~= "table" then
        return nil
    end

    local source = metadata.source
    local envelopeSource = nil
    local idPrefix = nil

    if source == "builtin" then
        envelopeSource = LAYOUT_SOURCES.BUILTIN
        idPrefix = "builtin:"
    elseif source == "user" then
        envelopeSource = LAYOUT_SOURCES.USER_PRESET
        idPrefix = "userPreset:"
    else
        return nil
    end

    local sourceId = IsNonEmptyString(metadata.id) and metadata.id or nil
    if not sourceId then
        return nil
    end

    local name = IsNonEmptyString(metadata.name) and metadata.name
        or IsNonEmptyString(metadata.labelKey) and metadata.labelKey
        or sourceId

    return BuildSummary(
        idPrefix .. sourceId,
        name,
        envelopeSource,
        metadata.readOnly == true,
        metadata
    )
end

function LayoutService.ProjectUserLayout(layoutId, rawRecord, defaults)
    if not (IsNonEmptyString(layoutId) and type(rawRecord) == "table" and type(rawRecord.payload) == "table") then
        return nil
    end

    local name = IsNonEmptyString(rawRecord.name) and rawRecord.name or layoutId
    return BuildEnvelope(
        layoutId,
        name,
        LAYOUT_SOURCES.USER_LAYOUT,
        false,
        rawRecord.payload,
        defaults
    )
end

function LayoutService.ProjectUserLayoutSummary(layoutId, rawRecord)
    if not (IsNonEmptyString(layoutId) and type(rawRecord) == "table") then
        return nil
    end

    local name = IsNonEmptyString(rawRecord.name) and rawRecord.name or layoutId
    return BuildSummary(
        layoutId,
        name,
        LAYOUT_SOURCES.USER_LAYOUT,
        false
    )
end

local function SortedStringKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        if IsNonEmptyString(key) then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function CompareUserLayoutEntries(layouts)
    return function(leftId, rightId)
        local left = type(layouts) == "table" and layouts[leftId] or nil
        local right = type(layouts) == "table" and layouts[rightId] or nil
        local leftName = type(left) == "table" and IsNonEmptyString(left.name) and left.name or leftId
        local rightName = type(right) == "table" and IsNonEmptyString(right.name) and right.name or rightId
        if leftName == rightName then
            return leftId < rightId
        end
        return leftName < rightName
    end
end

local function SortedUserLayoutIds(layouts)
    local ids = SortedStringKeys(layouts)
    table.sort(ids, CompareUserLayoutEntries(layouts))
    return ids
end

local function GetProfileStore(db)
    if type(db) ~= "table" then
        return nil
    end
    if type(db.profiles) == "table" then
        return db.profiles
    end
    local savedVariables = rawget(db, "sv")
    return type(savedVariables) == "table" and type(savedVariables.profiles) == "table" and savedVariables.profiles or nil
end

local function GetProfileNames(db)
    if type(db) ~= "table" or type(db.GetProfiles) ~= "function" then
        return {}
    end

    local ok, profiles = pcall(db.GetProfiles, db, {})
    if not ok or type(profiles) ~= "table" then
        return {}
    end

    table.sort(profiles)
    return profiles
end

local function GetProfileByName(db, profileName)
    if not IsNonEmptyString(profileName) then
        return nil
    end

    if type(db) == "table" and type(db.GetCurrentProfile) == "function" then
        local ok, currentProfile = pcall(db.GetCurrentProfile, db)
        if ok and currentProfile == profileName and type(db.profile) == "table" then
            return db.profile
        end
    end

    local profileStore = GetProfileStore(db)
    return type(profileStore) == "table" and type(profileStore[profileName]) == "table" and profileStore[profileName] or nil
end

local function AppendProjected(target, envelope)
    if type(target) == "table" and type(envelope) == "table" then
        target[#target + 1] = envelope
    end
end

local function AppendSummary(target, summary)
    if type(target) == "table" and type(summary) == "table" then
        target[#target + 1] = summary
    end
end

local function ShouldReadUserPresets(options, db)
    if type(options) == "table" and options.presetService ~= nil then
        return true
    end

    local global = type(db) == "table" and rawget(db, "global") or nil
    return type(global) == "table" and type(global.UserPresets) == "table"
end

local function GetRawUserPresets(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local presets = type(global) == "table" and rawget(global, "UserPresets") or nil
    return type(presets) == "table" and presets or {}
end

local function BuildBuiltinPresetMetadata(presetId)
    local themes = FocalPoint.Themes or {}
    local theme = themes[presetId]
    if type(theme) ~= "table" then
        return nil
    end

    return {
        id = presetId,
        labelKey = theme.labelKey,
        descriptionKey = theme.descriptionKey,
        source = "builtin",
        readOnly = true,
    }
end

local function BuildUserPresetMetadata(presetId, rawPreset)
    if not IsNonEmptyString(presetId) or type(rawPreset) ~= "table" or type(rawPreset.layout) ~= "table" then
        return nil
    end

    local metadata = type(rawPreset.metadata) == "table" and rawPreset.metadata or {}
    return {
        id = presetId,
        name = IsNonEmptyString(metadata.name) and metadata.name or presetId,
        description = IsNonEmptyString(metadata.description) and metadata.description or nil,
        source = "user",
        readOnly = false,
    }
end

function LayoutService.ListLayouts(options)
    options = type(options) == "table" and options or {}

    local db = options.db or FocalPoint.db
    local defaults = options.defaults or (FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB()) or nil
    local presetService = options.presetService or FocalPoint.PresetService or {}
    local userLayoutStore = options.userLayoutStore or FocalPoint.UserLayoutStore or {}
    local layouts = {}

    for _, profileName in ipairs(GetProfileNames(db)) do
        AppendProjected(layouts, LayoutService.ProjectProfile(profileName, GetProfileByName(db, profileName), defaults))
    end

    local builtIns = presetService.GetBuiltInPresets and presetService.GetBuiltInPresets() or {}
    local seenBuiltIns = {}
    for _, presetId in ipairs(BUILT_IN_PRESET_ORDER) do
        seenBuiltIns[presetId] = true
        AppendProjected(layouts, LayoutService.ProjectPreset(builtIns[presetId], defaults))
    end
    for _, presetId in ipairs(SortedStringKeys(builtIns)) do
        if not seenBuiltIns[presetId] then
            AppendProjected(layouts, LayoutService.ProjectPreset(builtIns[presetId], defaults))
        end
    end

    if ShouldReadUserPresets(options, db) then
        local userPresets = presetService.GetUserPresets and presetService.GetUserPresets() or {}
        for _, presetId in ipairs(SortedStringKeys(userPresets)) do
            AppendProjected(layouts, LayoutService.ProjectPreset(userPresets[presetId], defaults))
        end
    end

    local userLayouts = userLayoutStore.ListRawReadOnly and userLayoutStore.ListRawReadOnly(db) or {}
    for _, layoutId in ipairs(SortedUserLayoutIds(userLayouts)) do
        AppendProjected(layouts, LayoutService.ProjectUserLayout(layoutId, userLayouts[layoutId], defaults))
    end

    return layouts
end

function LayoutService.ListLayoutSummaries(options)
    local perf = FocalPoint and FocalPoint.SelectionPerfDebug
    local perfStart = perf and perf.Begin and perf:Begin("LayoutService.ListLayoutSummaries")

    options = type(options) == "table" and options or {}

    local db = options.db or FocalPoint.db
    local userLayoutStore = options.userLayoutStore or FocalPoint.UserLayoutStore or {}
    local summaries = {}

    for _, profileName in ipairs(GetProfileNames(db)) do
        AppendSummary(summaries, LayoutService.ProjectProfileSummary(profileName, GetProfileByName(db, profileName)))
    end

    local themes = FocalPoint.Themes or {}
    local seenBuiltIns = {}
    for _, presetId in ipairs(BUILT_IN_PRESET_ORDER) do
        seenBuiltIns[presetId] = true
        AppendSummary(summaries, LayoutService.ProjectPresetSummary(BuildBuiltinPresetMetadata(presetId)))
    end
    for _, presetId in ipairs(SortedStringKeys(themes)) do
        if not seenBuiltIns[presetId] then
            AppendSummary(summaries, LayoutService.ProjectPresetSummary(BuildBuiltinPresetMetadata(presetId)))
        end
    end

    if ShouldReadUserPresets(options, db) then
        local userPresets = GetRawUserPresets(db)
        for _, presetId in ipairs(SortedStringKeys(userPresets)) do
            AppendSummary(summaries, LayoutService.ProjectPresetSummary(BuildUserPresetMetadata(presetId, userPresets[presetId])))
        end
    end

    local userLayouts = userLayoutStore.ListRawReadOnly and userLayoutStore.ListRawReadOnly(db) or {}
    for _, layoutId in ipairs(SortedUserLayoutIds(userLayouts)) do
        AppendSummary(summaries, LayoutService.ProjectUserLayoutSummary(layoutId, userLayouts[layoutId]))
    end

    if perf and perf.End then
        perf:End("LayoutService.ListLayoutSummaries", perfStart)
    end
    return summaries
end

function LayoutService.MaterializeFromProfile(profile, defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    return LayoutService.NormalizePayload({
        Units = profile and profile.Units or nil,
        TextTemplates = profile and profile.TextTemplates or nil,
    }, defaultProfile)
end

function LayoutService.BuildPreviewUnitConfig(layout, unitKey)
    if type(layout) ~= "table" or type(layout.Units) ~= "table" then
        return nil
    end
    return LayoutService.Clone(layout.Units[unitKey])
end

return LayoutService
