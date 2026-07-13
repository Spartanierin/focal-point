local _, FocalPoint = ...

FocalPoint.TextTemplateLibrary = FocalPoint.TextTemplateLibrary or {}

local Library = FocalPoint.TextTemplateLibrary

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
