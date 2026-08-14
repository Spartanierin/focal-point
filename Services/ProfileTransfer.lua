local addonName, FocalPoint = ...

local ProfileTransfer = {}
FocalPoint.ProfileTransfer = ProfileTransfer

local EXPORT_PREFIX = "FocalPointProfile:6:"
local SCHEMA_VERSION = 7
local MIN_SUPPORTED_SCHEMA_VERSION = 4
local HEADER_SEPARATOR = "~"
local BASE36_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
local FOCAL_POINT_TEXTURE_PREFIX = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\"

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeImportString(value)
    value = Trim(value)
    value = value:gsub("^\239\187\191", "")
    value = value:gsub("[\r\n\t]", "")
    value = value:gsub("||", "|")
    return value
end

local function SortKeys(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then
        return leftType < rightType
    end
    return tostring(left) < tostring(right)
end

local function CopyPath(path)
    local copy = {}
    for index = 1, #path do
        copy[index] = path[index]
    end
    return copy
end

local function BuildDefaultSchema(value, path, schema)
    schema = schema or {}
    path = path or {}

    if type(value) ~= "table" then
        schema[#schema + 1] = {
            path = CopyPath(path),
            defaultValue = value,
        }
        return schema
    end

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)

    for _, key in ipairs(keys) do
        path[#path + 1] = key
        BuildDefaultSchema(value[key], path, schema)
        path[#path] = nil
    end

    return schema
end

local function GetValueAtPath(root, path)
    local cursor = root
    for index = 1, #path do
        if type(cursor) ~= "table" then
            return nil
        end
        cursor = cursor[path[index]]
    end
    return cursor
end

local function SetValueAtPath(root, path, value)
    if type(root) ~= "table" or type(path) ~= "table" or #path == 0 then
        return
    end

    local cursor = root
    for index = 1, #path - 1 do
        local key = path[index]
        if type(cursor[key]) ~= "table" then
            cursor[key] = {}
        end
        cursor = cursor[key]
    end

    cursor[path[#path]] = value
end

local function ValuesEqual(left, right)
    return left == right
end

local function ToBase36(value)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 then
        return "0"
    end

    local output = {}
    while value > 0 do
        local remainder = (value % 36) + 1
        output[#output + 1] = BASE36_ALPHABET:sub(remainder, remainder)
        value = math.floor(value / 36)
    end

    local reversed = {}
    for index = #output, 1, -1 do
        reversed[#reversed + 1] = output[index]
    end
    return table.concat(reversed)
end

local function FromBase36(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local result = 0
    for index = 1, #value do
        local char = value:sub(index, index):lower()
        local digit = BASE36_ALPHABET:find(char, 1, true)
        if not digit then
            return nil
        end
        result = (result * 36) + digit - 1
    end
    return result
end

local function EscapeText(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    value = value:gsub("~", "%%7E")
    value = value:gsub(";", "%%3B")
    value = value:gsub(":", "%%3A")
    value = value:gsub("\r", "%%0D")
    value = value:gsub("\n", "%%0A")
    return value
end

local function UnescapeText(value)
    value = tostring(value or "")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%0D", "\r")
    value = value:gsub("%%3A", ":")
    value = value:gsub("%%3B", ";")
    value = value:gsub("%%7C", "|")
    value = value:gsub("%%7E", "~")
    value = value:gsub("%%25", "%%")
    return value
end

local function EncodeValue(value)
    local valueType = type(value)
    if valueType == "boolean" then
        return value and "t" or "f"
    end
    if valueType == "number" then
        return "n" .. tostring(value)
    end
    if valueType == "string" then
        if value:sub(1, #FOCAL_POINT_TEXTURE_PREFIX) == FOCAL_POINT_TEXTURE_PREFIX then
            return "m" .. EscapeText(value:sub(#FOCAL_POINT_TEXTURE_PREFIX + 1))
        end
        return "s" .. EscapeText(value)
    end
    if valueType == "nil" then
        return "z"
    end

    return nil
end

local function DecodeValue(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil, false
    end

    local marker = encoded:sub(1, 1)
    local payload = encoded:sub(2)
    if marker == "t" then
        return true, true
    end
    if marker == "f" then
        return false, true
    end
    if marker == "z" then
        return nil, true
    end
    if marker == "n" then
        local numberValue = tonumber(payload)
        return numberValue, numberValue ~= nil
    end
    if marker == "s" then
        return UnescapeText(payload), true
    end
    if marker == "m" then
        return FOCAL_POINT_TEXTURE_PREFIX .. UnescapeText(payload), true
    end

    return nil, false
end

local function GetDefaultProfile()
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    return defaults and defaults.profile or nil
end

local function BuildSchemaRecords(currentProfile, schema)
    local records = {}
    local previousIndex = 0

    for index, entry in ipairs(schema or {}) do
        local currentValue = GetValueAtPath(currentProfile, entry.path)
        if not ValuesEqual(currentValue, entry.defaultValue) then
            local encodedValue = EncodeValue(currentValue)
            if encodedValue then
                records[#records + 1] = ToBase36(index - previousIndex) .. ":" .. encodedValue
                previousIndex = index
            end
        end
    end

    return records
end

local function EscapePathKey(value)
    return EscapeText(value):gsub(",", "%%2C")
end

local function UnescapePathKey(value)
    return UnescapeText((value or ""):gsub("%%2C", ","))
end

local function EncodePathSegment(key)
    local keyType = type(key)
    if keyType == "string" then
        return "s" .. EscapePathKey(key)
    end
    if keyType == "number" then
        return "n" .. tostring(key)
    end
    return nil
end

local function DecodePathSegment(segment)
    if type(segment) ~= "string" or segment == "" then
        return nil, false
    end

    local keyType = segment:sub(1, 1)
    local payload = segment:sub(2)
    if keyType == "s" then
        return UnescapePathKey(payload), true
    end
    if keyType == "n" then
        local numberKey = tonumber(payload)
        if numberKey ~= nil then
            return numberKey, true
        end
    end
    return nil, false
end

local function EncodeProfilePath(path)
    if type(path) ~= "table" or #path == 0 then
        return nil
    end

    local encodedPath = {}
    for index = 1, #path do
        local segment = EncodePathSegment(path[index])
        if not segment then
            return nil
        end
        encodedPath[#encodedPath + 1] = segment
    end

    return table.concat(encodedPath, ",")
end

local function BuildSchemaPathSet(schema)
    local pathSet = {}
    for _, entry in ipairs(schema or {}) do
        local encodedPath = EncodeProfilePath(entry.path)
        if encodedPath then
            pathSet[encodedPath] = true
        end
    end
    return pathSet
end

local function DecodeProfilePath(encodedPath)
    if type(encodedPath) ~= "string" or encodedPath == "" then
        return nil, false
    end

    local path = {}
    for segment in encodedPath:gmatch("[^,]+") do
        local key, ok = DecodePathSegment(segment)
        if not ok then
            return nil, false
        end
        path[#path + 1] = key
    end

    return path, #path > 0
end

local function IsTransientProfileTransferPath(path)
    if type(path) ~= "table" or #path < 2 then
        return false
    end

    -- Internal theme/restore snapshots are not user configuration. Exporting them
    -- massively inflates profile strings and is not required to restore a profile.
    return path[1] == "General"
        and (path[2] == "_CustomThemeSnapshot" or path[2] == "_ThemeRestoreState")
end

local function BuildProfileLeafEntriesRecursive(value, path, entries, schemaPathSet)
    if IsTransientProfileTransferPath(path) then
        return
    end

    if type(value) ~= "table" then
        local encodedPath = EncodeProfilePath(path)
        local encodedValue = EncodeValue(value)
        if encodedPath and encodedValue and (type(schemaPathSet) ~= "table" or not schemaPathSet[encodedPath]) then
            entries[#entries + 1] = {
                path = CopyPath(path),
                value = encodedValue,
            }
        end
        return
    end

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)

    for _, key in ipairs(keys) do
        path[#path + 1] = key
        BuildProfileLeafEntriesRecursive(value[key], path, entries, schemaPathSet)
        path[#path] = nil
    end
end

local function BuildProfileLeafDictionary(entries)
    local keySet = {}
    for _, entry in ipairs(entries or {}) do
        for _, key in ipairs(entry.path or {}) do
            if type(key) == "string" then
                keySet[key] = true
            end
        end
    end

    local keys = {}
    for key in pairs(keySet) do
        keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)

    local keyIndex = {}
    local encodedKeys = {}
    for index, key in ipairs(keys) do
        keyIndex[key] = index
        encodedKeys[#encodedKeys + 1] = EscapePathKey(key)
    end

    return keyIndex, table.concat(encodedKeys, ";")
end

local function EncodeCompactProfilePath(path, keyIndex)
    if type(path) ~= "table" or #path == 0 or type(keyIndex) ~= "table" then
        return nil
    end

    local encodedPath = {}
    for index = 1, #path do
        local key = path[index]
        local keyType = type(key)
        if keyType == "string" then
            local dictionaryIndex = keyIndex[key]
            if not dictionaryIndex then
                return nil
            end
            encodedPath[#encodedPath + 1] = "k" .. ToBase36(dictionaryIndex)
        elseif keyType == "number" then
            encodedPath[#encodedPath + 1] = "n" .. tostring(key)
        else
            return nil
        end
    end

    return table.concat(encodedPath, ",")
end

local function BuildProfileLeafRecords(profile, schemaPathSet)
    if type(profile) ~= "table" then
        return ""
    end

    local entries = {}
    BuildProfileLeafEntriesRecursive(profile, {}, entries, schemaPathSet)
    if #entries == 0 then
        return ""
    end

    local keyIndex, dictionaryPayload = BuildProfileLeafDictionary(entries)
    local records = {}
    for _, entry in ipairs(entries) do
        local encodedPath = EncodeCompactProfilePath(entry.path, keyIndex)
        if encodedPath then
            records[#records + 1] = encodedPath .. ":" .. entry.value
        end
    end

    if #records == 0 then
        return ""
    end

    -- D marks the compact dictionary format. Legacy unmarked extra leaves remain importable.
    return "D" .. dictionaryPayload .. HEADER_SEPARATOR .. table.concat(records, ";")
end

local function DecodeCompactProfilePath(encodedPath, dictionary)
    if type(encodedPath) ~= "string" or encodedPath == "" or type(dictionary) ~= "table" then
        return nil, false
    end

    local path = {}
    for segment in encodedPath:gmatch("[^,]+") do
        local keyType = segment:sub(1, 1)
        local payload = segment:sub(2)
        if keyType == "k" then
            local dictionaryIndex = FromBase36(payload)
            local key = dictionaryIndex and dictionary[dictionaryIndex] or nil
            if type(key) ~= "string" then
                return nil, false
            end
            path[#path + 1] = key
        elseif keyType == "n" then
            local numberKey = tonumber(payload)
            if numberKey == nil then
                return nil, false
            end
            path[#path + 1] = numberKey
        else
            return nil, false
        end
    end

    return path, #path > 0
end

local function ApplyCompactProfileLeafRecords(profile, payload)
    if type(profile) ~= "table" or type(payload) ~= "string" or payload == "" then
        return true
    end

    local dictionarySeparator = payload:find(HEADER_SEPARATOR, 2, true)
    if not dictionarySeparator then
        return false
    end

    local dictionary = {}
    local dictionaryPayload = payload:sub(2, dictionarySeparator - 1)
    if dictionaryPayload ~= "" then
        for encodedKey in dictionaryPayload:gmatch("[^;]+") do
            dictionary[#dictionary + 1] = UnescapePathKey(encodedKey)
        end
    end

    local recordsPayload = payload:sub(dictionarySeparator + 1)
    for record in recordsPayload:gmatch("[^;]+") do
        local separator = record:find(":", 1, true)
        if not separator then
            return false
        end

        local path, pathOk = DecodeCompactProfilePath(record:sub(1, separator - 1), dictionary)
        local value, valueOk = DecodeValue(record:sub(separator + 1))
        if not pathOk or not valueOk then
            return false
        end

        SetValueAtPath(profile, path, value)
    end

    return true
end

local function ApplyLegacyProfileLeafRecords(profile, payload)
    local records = {}
    for record in payload:gmatch("[^;]+") do
        records[#records + 1] = record
    end

    for _, record in ipairs(records) do
        local separator = record:find(":", 1, true)
        if not separator then
            return false
        end

        local path, pathOk = DecodeProfilePath(record:sub(1, separator - 1))
        local value, valueOk = DecodeValue(record:sub(separator + 1))
        if not pathOk or not valueOk then
            return false
        end

        SetValueAtPath(profile, path, value)
    end

    return true
end

local function ApplyProfileLeafRecords(profile, payload)
    if type(profile) ~= "table" or type(payload) ~= "string" or payload == "" then
        return true
    end

    if payload:sub(1, 1) == "D" then
        return ApplyCompactProfileLeafRecords(profile, payload)
    end

    return ApplyLegacyProfileLeafRecords(profile, payload)
end

local function ApplyTextTemplateRecords(profile, payload)
    if type(profile) ~= "table" or type(payload) ~= "string" or payload == "" then
        return true
    end

    profile.TextTemplates = profile.TextTemplates or {}

    for record in payload:gmatch("[^;]+") do
        local separator = record:find(":", 1, true)
        if not separator then
            return false
        end

        local templateName = UnescapeText(record:sub(1, separator - 1))
        local templateValue, ok = DecodeValue(record:sub(separator + 1))
        if templateName == "" or not ok or type(templateValue) ~= "string" then
            return false
        end

        profile.TextTemplates[templateName] = templateValue
    end

    return true
end

local function ApplySchemaRecords(profile, schema, payload)
    if type(profile) ~= "table" or type(payload) ~= "string" or payload == "" then
        return true
    end

    local schemaIndex = 0
    for record in payload:gmatch("[^;]+") do
        local separator = record:find(":", 1, true)
        if not separator then
            return false
        end

        local skip = FromBase36(record:sub(1, separator - 1))
        local value, ok = DecodeValue(record:sub(separator + 1))
        if not skip or not ok then
            return false
        end

        schemaIndex = schemaIndex + skip
        local entry = schema and schema[schemaIndex] or nil
        if not entry then
            return false
        end
        SetValueAtPath(profile, entry.path, value)
    end

    return true
end

local function ParseTransferPayload(payload)
    if type(payload) ~= "string" then
        return nil
    end

    local separator = payload:find(HEADER_SEPARATOR, 1, true) and HEADER_SEPARATOR or "|"

    local firstSeparator = payload:find(separator, 1, true)
    if not firstSeparator then
        return nil
    end

    local secondSeparator = payload:find(separator, firstSeparator + 1, true)
    if not secondSeparator then
        return nil
    end

    local thirdSeparator = payload:find(separator, secondSeparator + 1, true)
    if not thirdSeparator then
        return nil
    end

    local fourthSeparator = payload:find(separator, thirdSeparator + 1, true)
    local fifthSeparator = fourthSeparator and payload:find(separator, fourthSeparator + 1, true) or nil

    return {
        profileName = payload:sub(1, firstSeparator - 1),
        schemaVersion = payload:sub(firstSeparator + 1, secondSeparator - 1),
        schemaCount = payload:sub(secondSeparator + 1, thirdSeparator - 1),
        data = fourthSeparator and payload:sub(thirdSeparator + 1, fourthSeparator - 1) or payload:sub(thirdSeparator + 1),
        textTemplates = fourthSeparator and (fifthSeparator and payload:sub(fourthSeparator + 1, fifthSeparator - 1) or payload:sub(fourthSeparator + 1)) or nil,
        profileLeaves = fifthSeparator and payload:sub(fifthSeparator + 1) or nil,
        firstSeparator = firstSeparator,
        secondSeparator = secondSeparator,
        thirdSeparator = thirdSeparator,
        fourthSeparator = fourthSeparator,
        fifthSeparator = fifthSeparator,
        separator = separator,
    }
end

local function GetByteSummary(value)
    if type(value) ~= "string" or value == "" then
        return "-"
    end

    local bytes = {}
    for index = 1, math.min(#value, 8) do
        bytes[#bytes + 1] = tostring(value:byte(index) or 0)
    end
    return table.concat(bytes, ".")
end

local function BuildPayloadDebug(parts, payload)
    local payloadLength = type(payload) == "string" and #payload or 0
    return string.format(
        "v='%s' vb=%s c='%s' cb=%s sep=%s/%s/%s char='%s' len=%s",
        tostring(parts and parts.schemaVersion or "nil"),
        GetByteSummary(parts and parts.schemaVersion),
        tostring(parts and parts.schemaCount or "nil"),
        GetByteSummary(parts and parts.schemaCount),
        tostring(parts and parts.firstSeparator or "nil"),
        tostring(parts and parts.secondSeparator or "nil"),
        tostring(parts and parts.thirdSeparator or "nil"),
        tostring(parts and parts.separator or "nil"),
        tostring(payloadLength)
    )
end

local function GetProfileList(db)
    local list = {}
    if db and db.GetProfiles then
        for _, profileName in ipairs(db:GetProfiles({}) or {}) do
            list[profileName] = true
        end
    end
    return list
end

local function NormalizeProfileName(baseName)
    baseName = Trim(baseName)
    if baseName == "" then
        baseName = "Imported Profile"
    end

    return baseName
end

local function GetProfileStore(db)
    if not db then
        return nil
    end

    if type(db.profiles) == "table" then
        return db.profiles
    end

    local savedVariables = rawget(db, "sv")
    if type(savedVariables) ~= "table" then
        return nil
    end

    if type(savedVariables.profiles) ~= "table" then
        savedVariables.profiles = {}
    end

    db.profiles = savedVariables.profiles
    return db.profiles
end

function ProfileTransfer.ExportCurrentProfile(db)
    db = db or FocalPoint.db
    if not db or type(db.profile) ~= "table" then
        return nil, "missing-profile"
    end

    local defaultProfile = GetDefaultProfile()
    if type(defaultProfile) ~= "table" then
        return nil, "missing-defaults"
    end

    local schema = BuildDefaultSchema(defaultProfile)
    local records = BuildSchemaRecords(db.profile, schema)
    local schemaPathSet = BuildSchemaPathSet(schema)
    local extraProfileLeafRecords = BuildProfileLeafRecords(db.profile, schemaPathSet)
    local profileName = db.GetCurrentProfile and db:GetCurrentProfile() or "Profile"

    return EXPORT_PREFIX
        .. EscapeText(profileName)
        .. HEADER_SEPARATOR
        .. ToBase36(SCHEMA_VERSION)
        .. HEADER_SEPARATOR
        .. ToBase36(#schema)
        .. HEADER_SEPARATOR
        .. table.concat(records, ";")
        .. HEADER_SEPARATOR
        .. ""
        .. HEADER_SEPARATOR
        .. extraProfileLeafRecords
end

function ProfileTransfer.GetProfileNameFromString(exportString)
    exportString = NormalizeImportString(exportString)
    if exportString == "" or exportString:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "invalid-prefix"
    end

    local payload = exportString:sub(#EXPORT_PREFIX + 1)
    local parts = ParseTransferPayload(payload)
    if not parts then
        return nil, "invalid-profile"
    end

    return UnescapeText(parts.profileName)
end

function ProfileTransfer.ProfileExists(db, profileName)
    profileName = Trim(profileName)
    if not db or profileName == "" then
        return false
    end

    local profileStore = GetProfileStore(db)
    if type(profileStore) == "table" and profileStore[profileName] ~= nil then
        return true
    end

    local profiles = GetProfileList(db)
    return profiles[profileName] ~= nil
end

function ProfileTransfer.ImportProfileString(db, exportString, profileNameOverride, options)
    options = options or {}
    db = db or FocalPoint.db
    exportString = NormalizeImportString(exportString)
    if not db or not db.SetProfile or exportString == "" then
        return nil, "missing-input"
    end

    if exportString:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "invalid-prefix"
    end

    local defaultProfile = GetDefaultProfile()
    if type(defaultProfile) ~= "table" then
        return nil, "missing-defaults"
    end

    local payload = exportString:sub(#EXPORT_PREFIX + 1)
    local parts = ParseTransferPayload(payload)
    if not parts then
        return nil, "invalid-profile"
    end

    local schemaVersion = FromBase36(Trim(parts.schemaVersion))
    if not schemaVersion or schemaVersion < MIN_SUPPORTED_SCHEMA_VERSION or schemaVersion > SCHEMA_VERSION then
        return nil, string.format(
            "invalid-schema expected-%s got-%s %s",
            tostring(SCHEMA_VERSION),
            tostring(schemaVersion or "nil"),
            BuildPayloadDebug(parts, payload)
        )
    end

    local schema = BuildDefaultSchema(defaultProfile)
    local expectedSchemaCount = FromBase36(Trim(parts.schemaCount))
    if expectedSchemaCount ~= #schema then
        return nil, string.format(
            "schema-mismatch expected-%s got-%s %s",
            tostring(#schema),
            tostring(expectedSchemaCount or "nil"),
            BuildPayloadDebug(parts, payload)
        )
    end

    local validationProfile = {}
    if not ApplySchemaRecords(validationProfile, schema, parts.data) then
        return nil, "invalid-profile"
    end
    if not ApplyTextTemplateRecords(validationProfile, parts.textTemplates) then
        return nil, "invalid-text-templates"
    end
    local validationFullProfile = nil
    if parts.profileLeaves ~= nil then
        validationFullProfile = {}
        if not ApplyProfileLeafRecords(validationFullProfile, parts.profileLeaves) then
            return nil, "invalid-full-profile"
        end
    end

    local requestedProfileName = NormalizeProfileName(profileNameOverride)
    if requestedProfileName == "Imported Profile" and Trim(profileNameOverride) == "" then
        requestedProfileName = NormalizeProfileName(UnescapeText(parts.profileName))
    end

    local currentProfileName = db.GetCurrentProfile and db:GetCurrentProfile() or nil
    local profileExists = ProfileTransfer.ProfileExists(db, requestedProfileName)
    if profileExists and not options.overwrite then
        return nil, "profile-exists", requestedProfileName
    end

    local profileStore = GetProfileStore(db)
    if type(profileStore) ~= "table" then
        return nil, "missing-profile-store"
    end

    local importedProfile = {}
    ApplySchemaRecords(importedProfile, schema, parts.data)
    ApplyTextTemplateRecords(importedProfile, parts.textTemplates)

    if validationFullProfile then
        ApplyProfileLeafRecords(importedProfile, parts.profileLeaves)
    end

    profileStore[requestedProfileName] = importedProfile
    if currentProfileName == requestedProfileName then
        db.profile = importedProfile
    elseif FocalPoint and FocalPoint.ActivateProfile then
        FocalPoint:ActivateProfile(requestedProfileName, "profiles-import")
    else
        db:SetProfile(requestedProfileName)
    end

    if type(db.profile) ~= "table" then
        return nil, "profile-create-failed"
    end

    return requestedProfileName
end

return ProfileTransfer
