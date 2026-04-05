local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local FormElementDefinitions = ns.GUI.Layouts and ns.GUI.Layouts.FormElements
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local ProfileFormLayout = ns.GUI.Layouts and ns.GUI.Layouts.Profile and ns.GUI.Layouts.Profile.Form

local ProfilesPage = {}
ns.GUI.Pages.Profiles = ProfilesPage

local fallbackRootState = {}
local windowContext

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = function(dropdown)
    return FormWidgets.StyleDropdown(dropdown, "accented")
end
local StyleEditBox = FormWidgets.StyleEditBox
local ApplySectionPadding = FormWidgets.ApplySectionPadding
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local CreateActionButton = function(text, variant)
    return FormWidgets.CreateActionButton(text, variant)
end
local ResolveItemColor = FormWidgets.ResolveItemColor

local function T(key, fallback)
    return (L and L[key]) or fallback
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetProfilesState(deps)
    local rootState = (deps and deps.GetGUIState and deps.GetGUIState()) or fallbackRootState
    rootState.profiles = rootState.profiles or {}

    local state = rootState.profiles
    local db = ns.db

    if state.selectedProfile == nil and db and db.GetCurrentProfile then
        state.selectedProfile = db:GetCurrentProfile()
    end

    if state.newProfileName == nil then
        state.newProfileName = ""
    end

    return state
end

local function SetStatus(message)
    if ns.GUI and ns.GUI.SetStatusText then
        ns.GUI:SetStatusText(message)
    end
end

local function RefreshProfileUI()
    if ns.GUI and ns.GUI.RefreshOptions then
        ns.GUI:RefreshOptions()
    end
end

local function RebuildFramesForProfile()
    local db = ns.db
    if not db then
        return
    end

    if ns.ApplyGeneralSettings then
        ns:ApplyGeneralSettings()
    end

    ns.frames = ns.frames or {}
    for _, unitKey in ipairs(C.UnitOrder or {}) do
        local unitDB = db.profile and db.profile.Units and db.profile.Units[unitKey]
        local enabled = type(unitDB) == "table" and unitDB.enabled ~= false

        if enabled then
            if ns.SpawnUnitFrame then
                ns:SpawnUnitFrame(unitKey)
            end
        elseif ns.frames[unitKey] then
            ns.frames[unitKey]:Hide()
            ns.frames[unitKey] = nil
        end
    end
end

local function GetProfileList(db)
    local list = {}
    if not db or not db.GetProfiles then
        return list
    end

    local profiles = db:GetProfiles({})
    for _, profileName in ipairs(profiles or {}) do
        list[profileName] = profileName
    end

    return list
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.IsShown and not frame:IsShown() then
        CenterWindow(window)
    end

    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function ResolveItemText(item)
    if not item then
        return ""
    end

    if item.textKey or item.textFallback then
        return T(item.textKey, item.textFallback or "")
    end

    return item.text or ""
end

local function FindSectionDefinition(definitions, sectionName)
    for _, definition in ipairs(definitions or {}) do
        if definition.section == sectionName then
            return definition
        end
    end

    return nil
end

local ResolveItemProperties

local function CreateItemWidget(item, state)
    local props = ResolveItemProperties(item)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" then
        return CreateBodyText(
            ResolveItemText(props),
            props.role or "label",
            props.size or 12,
            ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
    end

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey, props.labelFallback or ""))
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        StyleDropdown(dropdown)
        return dropdown
    end

    if props.widget == "editbox" then
        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel(T(props.labelKey, props.labelFallback or ""))
        if props.fullWidth ~= false then
            editBox:SetFullWidth(true)
        end
        if props.disableButton then
            editBox:DisableButton(true)
        end
        local text = props.stateKey and state and state[props.stateKey] or props.text or ""
        editBox:SetText(text)
        StyleEditBox(editBox)
        return editBox
    end

    if props.widget == "button" then
        return CreateActionButton(ResolveItemText(props), props.buttonVariant)
    end

    return nil
end

local function RenderSectionItems(group, definition, state, widgetsById)
    if not group or not definition or type(definition.items) ~= "table" then
        return
    end

    for _, item in ipairs(definition.items) do
        local widget = CreateItemWidget(item, state)
        if widget then
            group:AddChild(widget)
            if item.id then
                widgetsById[item.id] = widget
            end
        end
    end
end

local function BuildSectionChildrenIndex(definitions)
    local index = {
        __root = {},
    }

    for _, definition in ipairs(definitions or {}) do
        local props = definition.properties or definition
        local parentKey = props.parentSection or "__root"
        index[parentKey] = index[parentKey] or {}
        index[parentKey][#index[parentKey] + 1] = definition
    end

    return index
end

local function CreateVerticalGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
        },
        spaceH = 0,
        spaceV = spacing or 8,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateTwoColumnGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = spacing or 24,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CloneLayoutValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = CloneLayoutValue(entry)
    end
    return copy
end

local function MergeLayoutValue(target, source)
    if type(source) ~= "table" then
        return CloneLayoutValue(source)
    end

    target = type(target) == "table" and target or {}
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            target[key] = MergeLayoutValue(target[key], value)
        else
            target[key] = CloneLayoutValue(value)
        end
    end

    return target
end

ResolveItemProperties = function(item)
    if not item then
        return nil
    end

    local resolved = {}
    local itemDefinitions = FormElementDefinitions and FormElementDefinitions.Items and FormElementDefinitions.Items[item.widget] or nil
    local variantDefinition = itemDefinitions and itemDefinitions[item.itemVariant] or nil

    resolved = MergeLayoutValue(resolved, variantDefinition)
    resolved = MergeLayoutValue(resolved, item)

    return resolved
end

local function ResolveSectionProperties(definition)
    local props = definition and (definition.properties or definition) or nil
    if not props then
        return nil
    end

    local resolved = {}
    local typeDefinitions = FormElementDefinitions and FormElementDefinitions.Sections and FormElementDefinitions.Sections[props.type] or nil
    local variantDefinition = typeDefinitions and typeDefinitions[props.variant] or nil

    resolved = MergeLayoutValue(resolved, variantDefinition)
    resolved = MergeLayoutValue(resolved, props)

    return resolved
end

local function ApplyGroupMinHeight(group, props)
    local minHeight = props and props.heightInfo and props.heightInfo.min
    if type(minHeight) ~= "number" or minHeight <= 0 or props.height or props.fullHeight then
        return
    end

    if group.GetHeight and group:GetHeight() < minHeight then
        group:SetHeight(minHeight)
    end

    local originalLayoutFinished = group.LayoutFinished
    if type(originalLayoutFinished) ~= "function" then
        return
    end

    group.LayoutFinished = function(self, width, height)
        if self.noAutoHeight then
            return originalLayoutFinished(self, width, height)
        end

        local resolvedHeight = height or 0
        if resolvedHeight < minHeight then
            resolvedHeight = minHeight
        end

        return originalLayoutFinished(self, width, resolvedHeight)
    end
end

local function CreateLayoutGroup(definition)
    if not definition then
        return nil
    end

    local props = ResolveSectionProperties(definition)
    local widgetType = props.widget or "SimpleGroup"
    local group
    if widgetType == "SimpleGroup" then
        if props.layout == "VerticalGroup" then
            group = CreateVerticalGroup(props.spacing)
        elseif props.layout == "TwoColumnGroup" then
            group = CreateTwoColumnGroup(props.spacing)
        elseif props.layout == "SimpleGroup" then
            group = AceGUI:Create("SimpleGroup")
            group:SetLayout(props.layoutMode or "List")
        else
            return nil
        end
    else
        return nil
    end

    group.Type = props.type
    group.Variant = props.variant

    if props.fullWidth then
        group:SetFullWidth(true)
    end
    if props.fullHeight then
        group:SetFullHeight(true)
    end
    if props.width then
        group:SetWidth(props.width)
    end
    if props.height then
        group:SetHeight(props.height)
    elseif not props.fullHeight and group.SetHeight then
        group:SetHeight(1)
    end

    ApplySectionPadding(group, props.padding)

    ApplyGroupMinHeight(group, props)

    return group
end

local function CreateLayoutGroups(definitions)
    local groups = {}

    for _, definition in ipairs(definitions or {}) do
        local group = CreateLayoutGroup(definition)
        if group then
            groups[definition.section] = group
        end
    end

    return groups
end

local function AssembleLayoutSections(parent, parentSection, definitions, groups, state, widgetsById, childIndex)
    local children = childIndex[parentSection or "__root"] or {}
    for _, definition in ipairs(children) do
        local group = groups[definition.section]
        if group and parent and parent.AddChild then
            parent:AddChild(group)
            RenderSectionItems(group, definition, state, widgetsById)
            AssembleLayoutSections(group, definition.section, definitions, groups, state, widgetsById, childIndex)
        end
    end
end

local function SyncNameEditText(context, text)
    if not context or not context.nameEdit then
        return
    end

    local value = text or ""
    if context.nameEdit:GetText() == value then
        return
    end

    context.suspendNameCallbacks = true
    context.nameEdit:SetText(value)
    context.suspendNameCallbacks = false
end

local function SyncDropdownValue(context, value)
    if not context or not context.profileSelect then
        return
    end

    context.suspendProfileCallbacks = true
    context.profileSelect:SetValue(value)
    context.suspendProfileCallbacks = false
end

local function RefreshWindowState()
    local context = windowContext
    if not context then
        return
    end

    local db = ns.db
    local state = context.state or {}

    if not db then
        context.activeProfileValue:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
        context.profileSelect:SetList({})
        SyncDropdownValue(context, nil)
        context.profileSelect:SetDisabled(true)
        context.nameEdit:SetDisabled(true)
        context.activateButton:SetDisabled(true)
        context.copyButton:SetDisabled(true)
        context.createButton:SetDisabled(true)
        context.resetButton:SetDisabled(true)
        context.deleteButton:SetDisabled(true)
        context.sourceState:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
        context.maintenanceHint:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
        end
        return
    end

    local currentProfile = db:GetCurrentProfile() or "Default"
    local profileList = GetProfileList(db)
    local selectedProfile = state.selectedProfile or currentProfile

    if type(selectedProfile) ~= "string" or selectedProfile == "" or not profileList[selectedProfile] then
        selectedProfile = currentProfile
        state.selectedProfile = selectedProfile
    end

    local newProfileName = Trim(state.newProfileName or context.nameEdit:GetText() or "")
    local sameAsCurrent = selectedProfile == currentProfile
    local hasSelectedProfile = type(selectedProfile) == "string" and selectedProfile ~= ""
    local hasNewProfileName = newProfileName ~= ""

    context.activeProfileValue:SetText(currentProfile)
    context.profileSelect:SetList(profileList)
    context.profileSelect:SetDisabled(false)
    SyncDropdownValue(context, selectedProfile)

    context.nameEdit:SetDisabled(false)
    SyncNameEditText(context, state.newProfileName or "")

    context.activateButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.copyButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.deleteButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.resetButton:SetDisabled(currentProfile == nil or currentProfile == "")
    context.createButton:SetDisabled(not hasNewProfileName)

    if hasSelectedProfile then
        context.sourceState:SetText(string.format(
            "%s: %s",
            T("INFO_PROFILES_SELECTED_SOURCE_SHORT", "Ausgewaehlt"),
            selectedProfile
        ))
    else
        context.sourceState:SetText(T("INFO_PROFILES_SOURCE_SUMMARY_NONE", "Keine Quelle ausgewaehlt"))
    end

    if sameAsCurrent or not hasSelectedProfile then
        context.maintenanceHint:SetText(T(
            "INFO_PROFILES_MAINTENANCE_IDLE_SHORT",
            "Zuruecksetzen betrifft das aktive Profil. Zum Loeschen erst eine andere Quelle waehlen."
        ))
    else
        context.maintenanceHint:SetText(string.format(
            "%s %s",
            T("INFO_PROFILES_MAINTENANCE_TARGET_SHORT", "Loeschen betrifft:"),
            selectedProfile
        ))
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
    local groups = CreateLayoutGroups(ProfileFormLayout)
    local childIndex = BuildSectionChildrenIndex(ProfileFormLayout)
    local widgets = {}

    AssembleLayoutSections(window, nil, ProfileFormLayout, groups, state, widgets, childIndex)

    local root = groups.Root

    return {
        window = window,
        state = state,
        root = root,
        activeProfileValue = widgets.activeProfileValue,
        profileSelect = widgets.profileSelect,
        nameEdit = widgets.nameEdit,
        activateButton = widgets.activateButton,
        copyButton = widgets.copyButton,
        createButton = widgets.createButton,
        resetButton = widgets.resetButton,
        deleteButton = widgets.deleteButton,
        sourceState = widgets.sourceState,
        maintenanceHint = widgets.maintenanceHint,
        suspendNameCallbacks = false,
        suspendProfileCallbacks = false,
    }
end

local function WireWindowCallbacks(context)
    if not context then
        return
    end

    context.profileSelect:SetCallback("OnValueChanged", function(_, _, value)
        local db = ns.db
        if not db then
            return
        end

        if context.suspendProfileCallbacks then
            return
        end

        context.state.selectedProfile = value or db:GetCurrentProfile()
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnTextChanged", function(_, _, value)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = value or ""
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = value or ""
        widget:ClearFocus()
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnFocusLost", function(widget)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = widget:GetText() or ""
        RefreshWindowState()
    end)

    context.activateButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        db:SetProfile(profileName)
        context.state.selectedProfile = profileName
        RebuildFramesForProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_ACTIVATED", "Profil aktiviert:")) .. " " .. profileName)
    end)

    context.copyButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        if profileName == db:GetCurrentProfile() then
            SetStatus(T("INFO_PROFILES_STATUS_COPY_SAME", "Quelle und aktives Profil sind identisch."))
            return
        end

        db:CopyProfile(profileName)
        RebuildFramesForProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_COPIED", "Profil uebernommen:")) .. " " .. profileName)
    end)

    context.deleteButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" or profileName == db:GetCurrentProfile() then
            return
        end

        db:DeleteProfile(profileName, true)
        context.state.selectedProfile = db:GetCurrentProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_DELETED", "Profil geloescht:")) .. " " .. profileName)
    end)

    context.resetButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local currentProfile = db:GetCurrentProfile()
        if not currentProfile or currentProfile == "" then
            return
        end

        db:ResetProfile()
        RebuildFramesForProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_RESET", "Profil zurueckgesetzt:")) .. " " .. currentProfile)
    end)

    context.createButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = Trim(context.nameEdit:GetText() or "")
        if profileName == "" then
            return
        end

        db:SetProfile(profileName)
        context.state.selectedProfile = profileName
        context.state.newProfileName = ""
        RebuildFramesForProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_CREATED", "Profil erstellt:")) .. " " .. profileName)
    end)
end

local function CreateWindow(state)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("NAV_PROFILES", "Profile"))
    window:SetLayout("Fill")
    window:SetWidth(760)
    window:SetHeight(520)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
    CenterWindow(window)

    local context = CreateWindowContent(window, state)
    windowContext = context
    WireWindowCallbacks(context)

    window:SetCallback("OnClose", function()
        if ns.GUI and ns.GUI.ResetStatusText then
            ns.GUI:ResetStatusText()
        end
    end)

    return context
end

function ProfilesPage.OpenWindow(deps)
    local state = GetProfilesState(deps)

    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state)
    else
        windowContext.state = state
    end

    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function ProfilesPage.HideWindow()
    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

function ProfilesPage.Build(container, deps)
    if container and container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container and container.SetLayout then
        container:SetLayout("Fill")
    end

    ProfilesPage.OpenWindow(deps)
end

return ProfilesPage
