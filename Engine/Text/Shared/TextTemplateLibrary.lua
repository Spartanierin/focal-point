local _, FocalPoint = ...

FocalPoint.TextTemplateLibrary = FocalPoint.TextTemplateLibrary or {}

local Library = FocalPoint.TextTemplateLibrary

-- E1: explicit entity operations only. Legacy library/runtime paths below never
-- call these helpers. Loading this module neither creates stores nor draws IDs.
local MAX_ID_INTEGER = 9007199254740991
local function IsPlainTable(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function IsToken(value)
    return type(value) == "string" and #value == 32 and value:match("^[0-9a-f]+$") ~= nil
end

local function IsIdInteger(value, allowZero)
    if type(value) ~= "string" or #value > 16 or not value:match("^%d+$") then return false end
    if #value > 1 and value:sub(1, 1) == "0" then return false end
    local number = tonumber(value)
    return number ~= nil and number <= MAX_ID_INTEGER and number >= (allowZero and 0 or 1)
end

function Library.GetTemplateIdKind(id)
    if type(id) ~= "string" then return nil end
    if id:match("^tpl:b:[a-z0-9][a-z0-9._%-]*$") then return "builtin" end
    local namespace, seconds, milliseconds, randomToken, counter = id:match(
        "^tpl:u:([0-9a-f]+):(%d+)%-(%d+)%-([0-9a-f]+):(%d+)$")
    if IsToken(namespace) and IsToken(randomToken) and IsIdInteger(seconds, true)
        and IsIdInteger(milliseconds, true) and IsIdInteger(counter, false) then
        return "user"
    end
    return nil
end

-- Persisted data is lossless: content may be empty (as in legacy records).
-- New editor input can impose stricter rules; these helpers never trim content.
-- Extra fields are rejected, rather than silently becoming persisted metadata.
function Library.ValidateTemplateRecord(record)
    if not IsPlainTable(record) then return false, "invalid-template-record" end
    if type(record.name) ~= "string" or not record.name:find("%S") then
        return false, "invalid-template-name"
    end
    if type(record.content) ~= "string" then return false, "invalid-template-content" end
    for key in pairs(record) do
        if key ~= "name" and key ~= "content" then return false, "invalid-template-record" end
    end
    return true
end

function Library.CopyTemplateRecord(record)
    local valid, reason = Library.ValidateTemplateRecord(record)
    if not valid then return nil, reason end
    return {name = record.name, content = record.content}
end

-- Data equality is NOT entity identity. Callers must compare IDs separately.
function Library.TemplateRecordsEqual(left, right)
    return Library.ValidateTemplateRecord(left) and Library.ValidateTemplateRecord(right)
        and left.name == right.name and left.content == right.content or false
end

local function ReadEntityStore(db)
    -- AceDB's DBObject and global section may have defaulting metatables.
    -- Peek through sv without initializing a missing section on a read/failure.
    if type(db) ~= "table" then return nil, nil, "invalid-db" end
    local global = rawget(db, "global")
    if global == nil then
        local saved = rawget(db, "sv")
        global = type(saved) == "table" and rawget(saved, "global") or nil
    end
    if global ~= nil and type(global) ~= "table" then return nil, nil, "invalid-global" end
    local records = global and rawget(global, "TextTemplates")
    if records ~= nil and not IsPlainTable(records) then return nil, nil, "invalid-template-store" end
    return records, global
end

local function EnsureEntityGlobal(db, global)
    if global then return global end
    -- Let AceDB attach its lazy section to SavedVariables before writing.
    global = db.global
    if global == nil then global = {}; db.global = global end
    return global
end

local function RandomToken(random)
    local parts = {}
    for i = 1, 16 do
        local byte = random(0, 255)
        if type(byte) ~= "number" or byte ~= byte or byte < 0 or byte > 255 or byte % 1 ~= 0 then
            error("invalid random source", 0)
        end
        parts[i] = string.format("%02x", byte)
    end
    return table.concat(parts)
end

local function ClockInteger(clock, scale)
    local value = clock()
    if type(value) ~= "number" or value ~= value or value < 0 or value > MAX_ID_INTEGER / scale then
        error("invalid clock source", 0)
    end
    return string.format("%.0f", math.floor(value * scale))
end

-- One generator instance represents one addon runtime. The default instance is
-- retained below, never persisted. Dependency injection uses the same path.
-- WoW sources: time() (also UserLayoutStore), GetTime() (runtime clock),
-- math.random(0,255) (Lua PRNG). No global randomseed and no cryptographic claim.
function Library.CreateUserTemplateIdGenerator(sources)
    sources = sources or {time = time, uptime = GetTime, random = math.random}
    if type(sources) ~= "table" or type(sources.time) ~= "function"
        or type(sources.uptime) ~= "function" or type(sources.random) ~= "function" then
        return nil, "id-source-unavailable"
    end
    local clock, uptime, random = sources.time, sources.uptime, sources.random
    local sessionNonce, counter = nil, 0
    local generator = {}
    function generator:Reserve(db, reserved)
        local records, global, reason = ReadEntityStore(db)
        if reason then return nil, reason end
        if not IsPlainTable(reserved) then return nil, "invalid-id-reservations" end
        local state = global and rawget(global, "TextTemplateIdState")
        if state ~= nil and (not IsPlainTable(state) or not IsToken(state.namespace)) then
            return nil, "invalid-id-state"
        end
        local namespace = state and state.namespace
        local ok, candidateNamespace, candidateNonce = pcall(function()
            local nextNamespace = namespace or RandomToken(random)
            local nextNonce = sessionNonce or (ClockInteger(clock, 1) .. "-"
                .. ClockInteger(uptime, 1000) .. "-" .. RandomToken(random))
            return nextNamespace, nextNonce
        end)
        if not ok then return nil, "id-source-unavailable" end
        sessionNonce = candidateNonce
        -- Bounded collision handling; consumed counters are never rolled back.
        for _ = 1, 128 do
            if counter >= MAX_ID_INTEGER then return nil, "id-counter-exhausted" end
            counter = counter + 1
            local id = "tpl:u:" .. candidateNamespace .. ":" .. sessionNonce .. ":" .. string.format("%.0f", counter)
            if (not records or rawget(records, id) == nil) and rawget(reserved, id) == nil then
                if not state then
                    global = EnsureEntityGlobal(db, global)
                    global.TextTemplateIdState = {namespace = candidateNamespace}
                end
                reserved[id] = true
                return id
            end
        end
        return nil, "id-collision-limit"
    end
    return generator
end

local userIdGenerator
function Library.ReserveUserTemplateId(db, reserved)
    if not userIdGenerator then
        local reason
        userIdGenerator, reason = Library.CreateUserTemplateIdGenerator()
        if not userIdGenerator then return nil, reason end
    end
    return userIdGenerator:Reserve(db or FocalPoint.db, reserved)
end

function Library.GetUserTemplateRecord(id, db)
    if Library.GetTemplateIdKind(id) ~= "user" then return nil, "invalid-user-template-id" end
    local records, _, reason = ReadEntityStore(db or FocalPoint.db)
    if reason then return nil, reason end
    local record = records and rawget(records, id)
    if record == nil then return nil, "template-not-found" end
    return Library.CopyTemplateRecord(record) -- never hand out a mutable store record
end

function Library.CreateUserTemplateRecord(id, record, db)
    if Library.GetTemplateIdKind(id) ~= "user" then return false, "invalid-user-template-id" end
    local copy, reason = Library.CopyTemplateRecord(record)
    if not copy then return false, reason end
    db = db or FocalPoint.db
    local records, global, storeReason = ReadEntityStore(db)
    if storeReason then return false, storeReason end
    if records and rawget(records, id) ~= nil then return false, "template-id-exists" end
    global = EnsureEntityGlobal(db, global)
    if not records then records = {}; global.TextTemplates = records end
    records[id] = copy
    return true
end

function Library.UpdateUserTemplateRecord(id, expectedRecord, changes, db)
    local current, reason = Library.GetUserTemplateRecord(id, db)
    if not current then return false, reason end
    if not Library.TemplateRecordsEqual(current, expectedRecord) then return false, "template-conflict" end
    if not IsPlainTable(changes) then return false, "invalid-template-record" end
    for key, value in pairs(changes) do
        if key ~= "name" and key ~= "content" then return false, "invalid-template-record" end
        current[key] = value
    end
    local valid
    valid, reason = Library.ValidateTemplateRecord(current)
    if not valid then return false, reason end
    local records = ReadEntityStore(db or FocalPoint.db)
    records[id] = current
    return true
end

-- Low-level E1 store primitive; the mutation layer must check whole-graph usage.
function Library.DeleteUserTemplateRecord(id, expectedRecord, db)
    local current, reason = Library.GetUserTemplateRecord(id, db)
    if not current then return false, reason end
    if not Library.TemplateRecordsEqual(current, expectedRecord) then return false, "template-conflict" end
    local records = ReadEntityStore(db or FocalPoint.db)
    records[id] = nil
    return true
end

function Library.CopyUserTemplateRecord(sourceId, newId, db)
    local record, reason = Library.GetUserTemplateRecord(sourceId, db)
    if not record then return false, reason end
    return Library.CreateUserTemplateRecord(newId, record, db)
end

-- E2: isolated catalogs and entity lookup, independent of runtime rendering.
-- An entry list detects duplicate IDs before a Lua map could overwrite them.
local function EntityError(code, id, kind)
    return {errorCode = code, templateId = id, kind = kind}
end

function Library.CreateBuiltInTemplateCatalog(entries)
    if not IsPlainTable(entries) then return nil, EntityError("invalid-builtin-definitions") end
    local count = 0
    for key in pairs(entries) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return nil, EntityError("invalid-builtin-definitions")
        end
        count = count + 1
    end
    local records = {}
    for i = 1, count do
        local entry = entries[i]
        if not IsPlainTable(entry) then return nil, EntityError("invalid-builtin-definitions") end
        local id = entry.templateId
        if Library.GetTemplateIdKind(id) ~= "builtin" then
            return nil, EntityError("invalid-builtin-template-id", id)
        end
        if records[id] ~= nil then return nil, EntityError("duplicate-builtin-template-id", id, "builtin") end
        local record, reason = Library.CopyTemplateRecord(entry.record)
        if not record then return nil, EntityError(reason, id, "builtin") end
        records[id] = record
    end
    -- Canonical records remain private; neither individual nor list reads alias them.
    return {
        GetRecord = function(id)
            if Library.GetTemplateIdKind(id) ~= "builtin" or records[id] == nil then return nil end
            return Library.CopyTemplateRecord(records[id])
        end,
        ListRecords = function()
            local copies = {}
            for id, record in pairs(records) do copies[id] = Library.CopyTemplateRecord(record) end
            return copies
        end,
    }
end

function Library.ResolveTemplateEntity(templateId, db)
    local kind = Library.GetTemplateIdKind(templateId)
    if not kind then return nil, EntityError("invalid-template-id", templateId) end
    local record, reason
    if kind == "builtin" then
        local catalog = FocalPoint.BuiltInTextTemplates
        if type(catalog) ~= "table" or type(catalog.GetRecord) ~= "function" then
            return nil, EntityError("builtin-catalog-unavailable", templateId, kind)
        end
        record = catalog.GetRecord(templateId)
        reason = "builtin-template-not-found"
    else
        record, reason = Library.GetUserTemplateRecord(templateId, db)
        if reason == "template-not-found" then reason = "user-template-not-found" end
    end
    if not record then return nil, EntityError(reason, templateId, kind) end
    return {templateId = templateId, name = record.name, content = record.content,
        kind = kind, readOnly = kind == "builtin"}
end

local function SortKeys(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then
        return leftType < rightType
    end
    return tostring(left) < tostring(right)
end

local function SortedKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)
    return keys
end

-- E5 opt-in view data. Value is identity; label/content are disposable snapshots.
-- Active legacy Library/Inspector/Picker callers below do not use this contract.
Library.Entity = {}
local EntityView = Library.Entity
function EntityView.Selection(db, id)
    if type(db) ~= "table" then return nil, "invalid_context" end
    local entity, reason = Library.ResolveTemplateEntity(id, db)
    if not entity then return nil, reason end
    return {value = id, label = entity.name, content = entity.content, readOnly = entity.readOnly}
end

function EntityView.List(db)
    local records, _, reason = ReadEntityStore(db)
    if reason then return nil, reason end
    local catalog = FocalPoint.BuiltInTextTemplates
    if not (catalog and catalog.ListRecords) then return nil, "builtin-catalog-unavailable" end
    local ids, rows = {}, {}
    for id in pairs(catalog.ListRecords()) do ids[id] = true end
    for id in pairs(records or {}) do
        if Library.GetTemplateIdKind(id) ~= "user" then return nil, "invalid-user-template-id" end
        ids[id] = true
    end
    for _, id in ipairs(SortedKeys(ids)) do
        local row, err = EntityView.Selection(db, id)
        if not row then return nil, err end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.value < b.value
    end)
    return rows
end

local function LabelReferences(references, db)
    for _, reference in ipairs(references) do
        local entity = Library.ResolveTemplateEntity(reference.templateId, db)
        reference.label = entity and entity.name or nil
        reference.isMissing = entity == nil
    end
    return references
end

function EntityView.Usage(layouts, db, id)
    if type(db) ~= "table" or not Library.GetTemplateIdKind(id) then return nil, "invalid_context" end
    return LabelReferences(FocalPoint.TextTemplateUsage.ScanEntities(layouts, id), db)
end

function EntityView.InspectText(layouts, db, layoutId, unitKey, textKey)
    if type(layouts) ~= "table" or type(db) ~= "table" then return nil, "invalid_context" end
    local record = layouts[layoutId]
    local units = type(record) == "table" and type(record.payload) == "table" and record.payload.Units
    local unit = type(units) == "table" and units[unitKey]
    if type(unit) ~= "table" or type(unit.Texts) ~= "table" or type(unit.Texts[textKey]) ~= "table" then
        return nil, "text_element_not_found"
    end
    local references, issues = {}, {}
    for _, ref in ipairs(FocalPoint.TextTemplateUsage.ScanEntities({[layoutId] = record})) do
        if ref.unitKey == unitKey and ref.textKey == textKey then references[#references + 1] = ref end
    end
    local validation = FocalPoint.TextTemplateValidation.ValidateEntityLayouts({[layoutId] = record}, db)
    for _, issue in ipairs(validation.issues) do
        if issue.unitKey == nil or (issue.unitKey == unitKey and (issue.textKey == nil or issue.textKey == textKey)) then
            issues[#issues + 1] = issue
        end
    end
    return {references = LabelReferences(references, db), issues = issues}
end

local function ResolveThemeLabel(themeId, theme)
    if type(theme) ~= "table" then
        return tostring(themeId or "")
    end

    local labelKey = theme.labelKey
    if type(labelKey) == "string" and FocalPoint.L and type(FocalPoint.L[labelKey]) == "string" then
        return FocalPoint.L[labelKey]
    end

    if type(theme.label) == "string" and theme.label ~= "" then
        return theme.label
    end

    return tostring(theme.id or themeId or "")
end

local function AddTemplateEntries(entries, templates, baseEntry)
    if type(entries) ~= "table" or type(templates) ~= "table" or type(baseEntry) ~= "table" then
        return
    end

    for _, templateName in ipairs(SortedKeys(templates)) do
        local templateValue = templates[templateName]
        if type(templateName) == "string" and templateName ~= "" and type(templateValue) == "string" then
            local entry = {}
            for key, value in pairs(baseEntry) do
                entry[key] = value
            end
            entry.templateName = templateName
            entry.templateValue = templateValue
            entries[#entries + 1] = entry
        end
    end
end

local function EscapeKeyPart(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("\031", "%%1F")
    return value
end

local function UnescapeKeyPart(value)
    value = tostring(value or "")
    value = value:gsub("%%1F", "\031")
    value = value:gsub("%%25", "%%")
    return value
end

function Library.GetCurrentProfileName(db)
    db = db or FocalPoint.db
    if not db or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and type(profileName) == "string" and profileName ~= "" then
        return profileName
    end

    return nil
end

function Library.GetProfileStore(db)
    db = db or FocalPoint.db
    if not db then
        return nil
    end

    if type(db.profiles) == "table" then
        return db.profiles
    end

    local savedVariables = rawget(db, "sv")
    if type(savedVariables) == "table" and type(savedVariables.profiles) == "table" then
        return savedVariables.profiles
    end

    return nil
end

function Library.GetProfileByName(db, profileName)
    db = db or FocalPoint.db
    if type(profileName) ~= "string" or profileName == "" then
        return nil
    end

    if profileName == Library.GetCurrentProfileName(db) and type(db.profile) == "table" then
        return db.profile
    end

    local profileStore = Library.GetProfileStore(db)
    local profile = type(profileStore) == "table" and profileStore[profileName] or nil
    if type(profile) == "table" then
        return profile
    end

    return nil
end

function Library.GetProfileNames(db)
    db = db or FocalPoint.db
    local namesByValue = {}

    if db and type(db.GetProfiles) == "function" then
        local ok, profiles = pcall(db.GetProfiles, db, {})
        if ok and type(profiles) == "table" then
            for _, profileName in ipairs(profiles) do
                if type(profileName) == "string" and profileName ~= "" then
                    namesByValue[profileName] = true
                end
            end
        end
    end

    local profileStore = Library.GetProfileStore(db)
    if type(profileStore) == "table" then
        for profileName in pairs(profileStore) do
            if type(profileName) == "string" and profileName ~= "" then
                namesByValue[profileName] = true
            end
        end
    end

    local currentProfileName = Library.GetCurrentProfileName(db)
    if type(currentProfileName) == "string" and currentProfileName ~= "" then
        namesByValue[currentProfileName] = true
    end

    local names = {}
    for profileName in pairs(namesByValue) do
        names[#names + 1] = profileName
    end
    table.sort(names, SortKeys)
    return names
end

function Library.GetProfileTemplates(db, profileName)
    local profile = Library.GetProfileByName(db, profileName)
    if type(profile) ~= "table" or type(profile.TextTemplates) ~= "table" then
        return {}
    end

    return profile.TextTemplates
end

function Library.GetProfileTemplateEntry(db, profileName, templateName)
    if type(profileName) ~= "string" or profileName == "" or type(templateName) ~= "string" or templateName == "" then
        return nil
    end

    db = db or FocalPoint.db
    local templates = Library.GetProfileTemplates(db, profileName)
    local templateValue = templates[templateName]
    if type(templateValue) ~= "string" then
        return nil
    end

    return {
        sourceType = "profile",
        sourceId = profileName,
        sourceLabel = profileName,
        profileName = profileName,
        templateName = templateName,
        templateValue = templateValue,
        readOnly = false,
        isActiveProfile = profileName == Library.GetCurrentProfileName(db),
    }
end

function Library.ListProfileTemplateEntries(db)
    db = db or FocalPoint.db
    local entries = {}
    local currentProfileName = Library.GetCurrentProfileName(db)

    for _, profileName in ipairs(Library.GetProfileNames(db)) do
        AddTemplateEntries(entries, Library.GetProfileTemplates(db, profileName), {
            sourceType = "profile",
            sourceId = profileName,
            sourceLabel = profileName,
            profileName = profileName,
            readOnly = false,
            isActiveProfile = profileName == currentProfileName,
        })
    end

    return entries
end

function Library.ListDefaultTemplateDefinitions()
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local templates = defaults and defaults.profile and defaults.profile.TextTemplates
    local entries = {}

    AddTemplateEntries(entries, templates, {
        sourceType = "default",
        sourceId = "system",
        sourceLabel = "System",
        readOnly = true,
    })

    return entries
end

function Library.ListPresetTemplateDefinitions()
    local themeService = FocalPoint.ThemeService
    local themes = themeService and themeService.GetThemes and themeService.GetThemes() or FocalPoint.Themes
    local entries = {}

    for _, themeId in ipairs(SortedKeys(themes)) do
        local theme = themes[themeId]
        if type(theme) == "table" then
            AddTemplateEntries(entries, theme.textTemplates, {
                sourceType = "preset",
                sourceId = tostring(theme.id or themeId),
                sourceLabel = ResolveThemeLabel(themeId, theme),
                themeId = tostring(theme.id or themeId),
                readOnly = true,
            })
        end
    end

    return entries
end

function Library.ListIntegratedTemplateDefinitions()
    local entries = {}

    for _, entry in ipairs(Library.ListDefaultTemplateDefinitions()) do
        entries[#entries + 1] = entry
    end

    for _, entry in ipairs(Library.ListPresetTemplateDefinitions()) do
        entries[#entries + 1] = entry
    end

    return entries
end

function Library.BuildTemplateEntryKey(entry)
    if type(entry) ~= "table"
        or type(entry.sourceType) ~= "string"
        or entry.sourceType == ""
        or type(entry.sourceId) ~= "string"
        or entry.sourceId == ""
        or type(entry.templateName) ~= "string"
        or entry.templateName == ""
    then
        return nil
    end

    local profileName = type(entry.profileName) == "string" and entry.profileName or ""
    local themeId = type(entry.themeId) == "string" and entry.themeId or ""
    return table.concat({
        EscapeKeyPart(entry.sourceType),
        EscapeKeyPart(entry.sourceId),
        EscapeKeyPart(profileName),
        EscapeKeyPart(themeId),
        EscapeKeyPart(entry.templateName),
    }, "\031")
end

function Library.ParseTemplateEntryKey(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local parts = {}
    for part in key:gmatch("([^\031]*)\031?") do
        parts[#parts + 1] = UnescapeKeyPart(part)
        if #parts == 5 then
            break
        end
    end

    if #parts ~= 5 or parts[1] == "" or parts[2] == "" or parts[5] == "" then
        return nil
    end

    local selection = {
        sourceType = parts[1],
        sourceId = parts[2],
        templateName = parts[5],
    }

    if parts[3] ~= "" then
        selection.profileName = parts[3]
    end
    if parts[4] ~= "" then
        selection.themeId = parts[4]
    end

    return selection
end

function Library.FindTemplateEntryByKey(db, key)
    local selection = Library.ParseTemplateEntryKey(key)
    if not selection then
        return nil
    end

    return Library.FindTemplateEntry(db, selection)
end

function Library.FindTemplateEntry(db, selection)
    if type(selection) ~= "table" then
        return nil
    end

    local sourceType = selection.sourceType
    local sourceId = selection.sourceId
    local templateName = selection.templateName
    if type(sourceType) ~= "string" or sourceType == "" or type(templateName) ~= "string" or templateName == "" then
        return nil
    end

    if sourceType == "profile" then
        return Library.GetProfileTemplateEntry(db, selection.profileName or sourceId, templateName)
    end

    if sourceType == "default" then
        for _, entry in ipairs(Library.ListDefaultTemplateDefinitions()) do
            if entry.sourceId == sourceId and entry.templateName == templateName then
                return entry
            end
        end
        return nil
    end

    if sourceType == "preset" then
        for _, entry in ipairs(Library.ListPresetTemplateDefinitions()) do
            if entry.sourceId == sourceId and entry.templateName == templateName then
                return entry
            end
        end
    end

    return nil
end

return Library
