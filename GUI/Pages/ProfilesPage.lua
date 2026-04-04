local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles
local SidebarShared = ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}

local ProfilesPage = {}
ns.GUI.Pages.Profiles = ProfilesPage

local fallbackRootState = {}
local windowContext

local PANEL_BACKGROUND = { 0.07, 0.08, 0.10, 0.90 }
local PANEL_BORDER = { 0.24, 0.27, 0.31, 0.92 }
local PANEL_HEADER = { 0.10, 0.11, 0.14, 0.70 }
local FIELD_BACKGROUND = { 0.10, 0.11, 0.14, 0.96 }
local FIELD_BORDER = { 0.31, 0.34, 0.39, 0.95 }
local BUTTON_RED = { 0.34, 0.12, 0.12, 0.95 }
local BUTTON_RED_DARK = { 0.23, 0.08, 0.08, 0.98 }
local BUTTON_RED_HIGHLIGHT = { 0.48, 0.18, 0.18, 0.95 }
local BUTTON_RED_DISABLED = { 0.19, 0.12, 0.12, 0.90 }
local HINT_TEXT = { 0.70, 0.73, 0.78 }
local FOOTER_HINT_TEXT = { 0.62, 0.65, 0.70 }
local DESCRIPTION_TEXT = { 0.68, 0.70, 0.75 }
local VALUE_TEXT = { 0.93, 0.90, 0.80 }

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

local function ApplyTextStyle(target, role, size, alpha)
    if not target then
        return
    end

    if TextStyles and TextStyles.ApplyFontString then
        TextStyles.ApplyFontString(target, role, {
            size = size,
            alpha = alpha,
        })
    end
end

local function SetTextureColor(texture, color)
    if texture and texture.SetVertexColor and color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function CreateSectionTitle(text, size)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyTextStyle(label.label, "sectionHeader", size or 13, 1)
    return label
end

local function CreateBodyText(text, role, size, color)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyTextStyle(label.label, role or "label", size or 12, 1)

    if color and label.label and label.label.SetTextColor then
        label.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    return label
end

local function StyleActionButton(button, variant)
    if not button or not button.frame then
        return
    end

    if SidebarShared and SidebarShared.StyleSidebarButton then
        SidebarShared.StyleSidebarButton(button, variant == "danger" and "danger" or "primary")
    end

    button:SetHeight(26)

    if button.text then
        ApplyTextStyle(button.text, variant == "danger" and "danger" or "label", 12, 1)
        if button.text.SetTextColor then
            button.text:SetTextColor(0.95, 0.91, 0.88, 1)
        end
    end

    local frame = button.frame
    local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    local pushed = frame.GetPushedTexture and frame:GetPushedTexture() or nil
    local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
    local disabled = frame.GetDisabledTexture and frame:GetDisabledTexture() or nil

    SetTextureColor(normal, BUTTON_RED)
    SetTextureColor(pushed, BUTTON_RED_DARK)
    SetTextureColor(highlight, BUTTON_RED_HIGHLIGHT)
    SetTextureColor(disabled, BUTTON_RED_DISABLED)
end

local function StyleDropdown(dropdown)
    if not dropdown then
        return
    end

    ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        dropdown.text:SetTextColor(VALUE_TEXT[1], VALUE_TEXT[2], VALUE_TEXT[3], 1)
    end

    if dropdown.dropdown then
        local name = dropdown.dropdown:GetName()
        if name then
            SetTextureColor(_G[name .. "Left"], FIELD_BORDER)
            SetTextureColor(_G[name .. "Middle"], FIELD_BACKGROUND)
            SetTextureColor(_G[name .. "Right"], FIELD_BORDER)
        end
    end

    if dropdown.button then
        local buttonNormal = dropdown.button.GetNormalTexture and dropdown.button:GetNormalTexture() or nil
        local buttonPushed = dropdown.button.GetPushedTexture and dropdown.button:GetPushedTexture() or nil
        local buttonHighlight = dropdown.button.GetHighlightTexture and dropdown.button:GetHighlightTexture() or nil
        SetTextureColor(buttonNormal, FIELD_BORDER)
        SetTextureColor(buttonPushed, BUTTON_RED_DARK)
        SetTextureColor(buttonHighlight, BUTTON_RED_HIGHLIGHT)
    end
end

local function StyleEditBox(editBox)
    if not editBox then
        return
    end

    ApplyTextStyle(editBox.label, "label", 12, 1)

    if editBox.editbox then
        if editBox.editbox.SetTextColor then
            editBox.editbox:SetTextColor(VALUE_TEXT[1], VALUE_TEXT[2], VALUE_TEXT[3], 1)
        end

        for _, region in ipairs({ editBox.editbox:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                SetTextureColor(region, FIELD_BORDER)
            end
        end
    end
end

local function ApplyWindowChrome(window)
    if not window or not window.frame then
        return
    end

    local frame = window.frame
    local content = window.content

    if window.titletext then
        ApplyTextStyle(window.titletext, "sectionHeader", 15, 1)
    end

    if not frame._fpPanelFill then
        frame._fpPanelFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    end
    frame._fpPanelFill:SetColorTexture(unpack(PANEL_BACKGROUND))

    if not frame._fpPanelHeaderFill then
        frame._fpPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
        frame._fpPanelHeaderFill:SetHeight(26)
    end
    frame._fpPanelHeaderFill:SetColorTexture(unpack(PANEL_HEADER))

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(PANEL_BORDER))
        frame[name]:Show()
    end

    EnsureBorder("_fpPanelBorderTop")
    frame._fpPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpPanelBorderBottom")
    frame._fpPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpPanelBorderLeft")
    frame._fpPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpPanelBorderRight")
    frame._fpPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderRight:SetWidth(1)

    if content then
        if not content._fpAccent then
            content._fpAccent = content:CreateTexture(nil, "BORDER")
            content._fpAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpAccent:SetHeight(1)
        end
        content._fpAccent:SetColorTexture(0.83, 0.70, 0.30, 0.35)
    end
end

local function CreateActionButton(text, variant)
    local button = AceGUI:Create("Button")
    button:SetText(text or "")
    button:SetFullWidth(true)
    StyleActionButton(button, variant)
    return button
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
            T("INFO_PROFILES_SELECTED_SOURCE", "Quelle"),
            selectedProfile
        ))
    else
        context.sourceState:SetText(T("INFO_PROFILES_SOURCE_SUMMARY_NONE", "Keine Quelle ausgewaehlt"))
    end

    if sameAsCurrent or not hasSelectedProfile then
        context.maintenanceHint:SetText(T(
            "INFO_PROFILES_MAINTENANCE_IDLE",
            "Zuruecksetzen betrifft das aktive Profil. Zum Loeschen zuerst ein anderes Profil auswaehlen."
        ))
    else
        context.maintenanceHint:SetText(string.format(
            "%s %s",
            T("INFO_PROFILES_MAINTENANCE_TARGET", "Loeschen wuerde entfernen:"),
            selectedProfile
        ))
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
    local root = CreateVerticalGroup(24)
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    window:AddChild(root)

    local headerGroup = CreateVerticalGroup(12)
    root:AddChild(headerGroup)

    local title = CreateSectionTitle(T("NAV_PROFILES", "Profile"), 18)
    headerGroup:AddChild(title)

    local intro = CreateBodyText(T(
        "INFO_PROFILES_DESCRIPTION",
        "Verwalte geteilte Einstellungen zwischen Charakteren. Beim Kopieren ist das aktive Profil das Ziel, das ausgewaehlte Profil die Quelle."
    ), "help", 11, DESCRIPTION_TEXT)
    headerGroup:AddChild(intro)

    local activeGroup = CreateVerticalGroup(6)
    headerGroup:AddChild(activeGroup)

    local activeProfileLabel = CreateBodyText(
        T("INFO_PROFILES_CURRENT_ACTIVE", "Aktives Profil"),
        "sectionHeader",
        13
    )
    activeGroup:AddChild(activeProfileLabel)

    local activeProfileValue = CreateBodyText("", "label", 17, VALUE_TEXT)
    activeGroup:AddChild(activeProfileValue)

    local columns = CreateTwoColumnGroup(28)
    root:AddChild(columns)

    local leftColumn = CreateVerticalGroup(10)
    leftColumn:SetFullWidth(true)
    columns:AddChild(leftColumn)

    local rightColumn = CreateVerticalGroup(10)
    rightColumn:SetFullWidth(true)
    columns:AddChild(rightColumn)

    leftColumn:AddChild(CreateSectionTitle(T("INFO_PROFILES_SOURCE_PICK", "Profil von anderer Unit uebernehmen")))

    local profileSelect = AceGUI:Create("Dropdown")
    profileSelect:SetLabel(T("INFO_PROFILES_SOURCE_PROFILE", "Quellprofil"))
    profileSelect:SetFullWidth(true)
    StyleDropdown(profileSelect)
    leftColumn:AddChild(profileSelect)

    local activateButton = CreateActionButton(T("INFO_PROFILES_ACTIVATE", "Aktivieren"), "primary")
    leftColumn:AddChild(activateButton)

    local copyButton = CreateActionButton(T("INFO_PROFILES_COPY_FROM", "In aktives Profil kopieren"), "primary")
    leftColumn:AddChild(copyButton)

    local sourceState = CreateBodyText("", "help", 9, HINT_TEXT)
    leftColumn:AddChild(sourceState)

    rightColumn:AddChild(CreateSectionTitle(T("INFO_PROFILES_CREATE_SIMPLE", "Neues Profil anlegen")))

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("INFO_PROFILES_NAME", "Profilname"))
    nameEdit:SetFullWidth(true)
    nameEdit:DisableButton(true)
    nameEdit:SetText(state.newProfileName or "")
    StyleEditBox(nameEdit)
    rightColumn:AddChild(nameEdit)

    local createButton = CreateActionButton(T("INFO_PROFILES_CREATE_AND_SWITCH", "Erstellen und wechseln"), "primary")
    rightColumn:AddChild(createButton)

    local footerGroup = CreateVerticalGroup(10)
    root:AddChild(footerGroup)

    footerGroup:AddChild(CreateSectionTitle(T("INFO_PROFILES_MAINTENANCE", "Profilwartung")))

    local maintenanceButtons = CreateTwoColumnGroup(16)
    footerGroup:AddChild(maintenanceButtons)

    local resetButton = CreateActionButton(T("INFO_PROFILES_RESET", "Zuruecksetzen"), "primary")
    maintenanceButtons:AddChild(resetButton)

    local deleteButton = CreateActionButton(T("INFO_PROFILES_DELETE_SHORT", "Loeschen"), "danger")
    maintenanceButtons:AddChild(deleteButton)

    local maintenanceHint = CreateBodyText("", "help", 9, FOOTER_HINT_TEXT)
    footerGroup:AddChild(maintenanceHint)

    return {
        window = window,
        state = state,
        root = root,
        activeProfileValue = activeProfileValue,
        profileSelect = profileSelect,
        nameEdit = nameEdit,
        activateButton = activateButton,
        copyButton = copyButton,
        createButton = createButton,
        resetButton = resetButton,
        deleteButton = deleteButton,
        sourceState = sourceState,
        maintenanceHint = maintenanceHint,
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
