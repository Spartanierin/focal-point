local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormLayoutRuntime = ns.GUI.Helpers and ns.GUI.Helpers.FormLayoutRuntime
local ProfileFormLayout = ns.GUI.Layouts and ns.GUI.Layouts.Profile and ns.GUI.Layouts.Profile.Form

local ProfilesPage = {}
ns.GUI.Pages.Profiles = ProfilesPage

local fallbackRootState = {}
local windowContext

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = FormWidgets.StyleDropdown
local StyleEditBox = FormWidgets.StyleEditBox
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local CreateActionButton = FormWidgets.CreateActionButton
local ResolveItemColor = FormWidgets.ResolveItemColor

local function T(key, fallback)
    return (L and L[key]) or fallback or ""
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

    if item.textKey then
        return T(item.textKey)
    end

    return item.text or ""
end

local function CreateItemWidget(group, item, props, state)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" then
        local label = CreateBodyText(
            ResolveItemText(props),
            props.role or "label",
            props.size or 12,
            ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey))
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        StyleDropdown(dropdown, props.fieldVariant or "accented")
        return dropdown
    end

    if props.widget == "editbox" then
        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel(T(props.labelKey))
        if props.fullWidth ~= false then
            editBox:SetFullWidth(true)
        end
        if props.disableButton then
            editBox:DisableButton(true)
        end
        local text = props.stateKey and state and state[props.stateKey] or props.text or ""
        editBox:SetText(text)
        StyleEditBox(editBox, props.fieldVariant)
        return editBox
    end

    if props.widget == "button" then
        return CreateActionButton(ResolveItemText(props), props.buttonVariant, props.width, props.fullWidth)
    end

    return nil
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
        context.activeProfileValue:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.profileSelect:SetList({})
        SyncDropdownValue(context, nil)
        context.profileSelect:SetDisabled(true)
        context.nameEdit:SetDisabled(true)
        context.activateButton:SetDisabled(true)
        context.copyButton:SetDisabled(true)
        context.createButton:SetDisabled(true)
        context.resetButton:SetDisabled(true)
        context.deleteButton:SetDisabled(true)
        context.sourceState:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.maintenanceHint:SetText(T("INFO_COMMON_UNAVAILABLE"))
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
            T("INFO_PROFILES_SELECTED_SOURCE_SHORT"),
            selectedProfile
        ))
    else
        context.sourceState:SetText(T("INFO_PROFILES_SOURCE_SUMMARY_NONE"))
    end

    if sameAsCurrent or not hasSelectedProfile then
        context.maintenanceHint:SetText(T(
            "INFO_PROFILES_MAINTENANCE_IDLE_SHORT",
            "Zuruecksetzen betrifft das aktive Profil. Zum Loeschen erst eine andere Quelle waehlen."
        ))
    else
        context.maintenanceHint:SetText(string.format(
            "%s %s",
            T("INFO_PROFILES_MAINTENANCE_TARGET_SHORT"),
            selectedProfile
        ))
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
    local groups, widgets = FormLayoutRuntime.BuildLayout(window, ProfileFormLayout, {
        state = state,
        createItemWidget = CreateItemWidget,
    })

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
        SetStatus((T("INFO_PROFILES_STATUS_ACTIVATED")) .. " " .. profileName)
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
            SetStatus(T("INFO_PROFILES_STATUS_COPY_SAME"))
            return
        end

        db:CopyProfile(profileName)
        RebuildFramesForProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_COPIED")) .. " " .. profileName)
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
        SetStatus((T("INFO_PROFILES_STATUS_DELETED")) .. " " .. profileName)
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
        SetStatus((T("INFO_PROFILES_STATUS_RESET")) .. " " .. currentProfile)
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
        SetStatus((T("INFO_PROFILES_STATUS_CREATED")) .. " " .. profileName)
    end)
end

local function CreateWindow(state)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("NAV_PROFILES"))
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

return ProfilesPage
