local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local TextStyles = ns.GUI.Helpers.TextStyles

local ProfilesPage = {}
ns.GUI.Pages.Profiles = ProfilesPage

local PAGE_WIDTH = 880
local CARD_BACKGROUND = { 0.07, 0.08, 0.10, 0.74 }
local CARD_BORDER = { 0.16, 0.19, 0.24, 0.92 }
local CARD_HEADER = { 0.10, 0.11, 0.14, 0.48 }
local CARD_ACCENT = { 0.91, 0.77, 0.29, 0.92 }

local function T(key, fallback)
    return (L and L[key]) or fallback
end

local function ApplySectionHeader(widget, size)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, "sectionHeader", { size = size or 13 })
    end
end

local function ApplyLabelStyle(widget, role, size)
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role, { size = size })
    end
end

local function ApplyWidgetStyle(widget, role, size)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role, { size = size })
    end
end

local function CreateSpacer(height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height or 1)
    return spacer
end

local function CreateFlowGroup(fullWidth, width)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    if fullWidth then
        group:SetFullWidth(true)
    elseif width then
        group:SetWidth(width)
    end
    return group
end

local function CreateRow(parent, height)
    local row = CreateFlowGroup(true)
    if height then
        row:SetHeight(height)
    end
    parent:AddChild(row)
    return row
end

local function CreateCard(parent, title, subtitle, options)
    local opts = type(options) == "table" and options or {}

    if (opts.topSpacing or 0) > 0 then
        parent:AddChild(CreateSpacer(opts.topSpacing))
    end

    local card = AceGUI:Create("SimpleGroup")
    card:SetFullWidth(true)
    card:SetLayout("Flow")
    parent:AddChild(card)

    local frame = card.frame
    local content = card.content
    if frame and content then
        if not frame._fpCardBg then
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(unpack(CARD_BACKGROUND))
            frame._fpCardBg = bg
        end

        if not frame._fpCardHeader then
            local header = frame:CreateTexture(nil, "BORDER")
            header:SetPoint("TOPLEFT")
            header:SetPoint("TOPRIGHT")
            header:SetHeight(34)
            header:SetColorTexture(unpack(CARD_HEADER))
            frame._fpCardHeader = header
        end

        if not frame._fpCardAccent then
            local accent = frame:CreateTexture(nil, "BORDER")
            accent:SetPoint("TOPLEFT")
            accent:SetPoint("TOPRIGHT")
            accent:SetHeight(2)
            accent:SetColorTexture(unpack(CARD_ACCENT))
            frame._fpCardAccent = accent
        end

        local function EnsureBorder(name, ...)
            if frame[name] then
                return
            end

            local border = frame:CreateTexture(nil, "BORDER")
            border:SetColorTexture(unpack(CARD_BORDER))
            border:SetPoint(...)
            frame[name] = border
        end

        EnsureBorder("_fpCardBorderTop", "TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpCardBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpCardBorderTop:SetHeight(1)

        EnsureBorder("_fpCardBorderBottom", "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpCardBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpCardBorderBottom:SetHeight(1)

        EnsureBorder("_fpCardBorderLeft", "TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpCardBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpCardBorderLeft:SetWidth(1)

        EnsureBorder("_fpCardBorderRight", "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpCardBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpCardBorderRight:SetWidth(1)

        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
        content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    end

    if title and title ~= "" then
        local titleLabel = AceGUI:Create("Label")
        titleLabel:SetFullWidth(true)
        titleLabel:SetText(title)
        ApplyLabelStyle(titleLabel, "sectionHeader", 13)
        card:AddChild(titleLabel)
    end

    if subtitle and subtitle ~= "" then
        local subtitleLabel = AceGUI:Create("Label")
        subtitleLabel:SetFullWidth(true)
        subtitleLabel:SetText(subtitle)
        ApplyLabelStyle(subtitleLabel, "help", 11)
        card:AddChild(subtitleLabel)
    end

    if title or subtitle then
        card:AddChild(CreateSpacer(6))
    end

    return card
end

local function CreatePageRoot(container)
    local root = CreateFlowGroup(true)
    container:AddChild(root)

    local column = CreateFlowGroup(false, PAGE_WIDTH)
    root:AddChild(column)
    return column
end

local function CreatePageHeader(parent, title, descriptionText)
    local header = CreateFlowGroup(true)
    parent:AddChild(header)

    local eyebrow = AceGUI:Create("Label")
    eyebrow:SetFullWidth(true)
    eyebrow:SetText(T("INFO_TOOLS_WORKSPACE", "Werkzeugansicht"))
    ApplyLabelStyle(eyebrow, "help", 10)
    header:AddChild(eyebrow)

    local titleLabel = AceGUI:Create("Label")
    titleLabel:SetFullWidth(true)
    titleLabel:SetText(title)
    ApplyLabelStyle(titleLabel, "sectionHeader", 17)
    header:AddChild(titleLabel)

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    description:SetText(descriptionText or "")
    ApplyLabelStyle(description, "help", 11)
    header:AddChild(description)
end

local function CreateStatCard(parent, currentProfile)
    local card = CreateCard(
        parent,
        T("INFO_PROFILES_CURRENT", "01 Aktiver Stand"),
        T("INFO_PROFILES_CURRENT_HINT_TOOL", "Das aktive Profil definiert den aktuellen Arbeitsstand fuer Frames, Farben und Texte.")
    )

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    statusLabel:SetText(T("INFO_PROFILES_STATUS_ACTIVE_PROFILE", "Der Editor und alle Werkzeugseiten arbeiten gerade mit diesem Profil."))
    ApplyLabelStyle(statusLabel, "help", 11)
    card:AddChild(statusLabel)

    card:AddChild(CreateSpacer(4))

    local activeProfile = AceGUI:Create("Label")
    activeProfile:SetFullWidth(true)
    activeProfile:SetText(currentProfile or "Default")
    ApplyLabelStyle(activeProfile, "highlight", 18)
    card:AddChild(activeProfile)

    local contextLabel = AceGUI:Create("Label")
    contextLabel:SetFullWidth(true)
    contextLabel:SetText(T("INFO_PROFILES_STATUS_CONTEXT", "Alle folgenden Aktionen beziehen sich auf diesen aktuellen Stand oder auf eine ausgewaehlte Quelle."))
    ApplyLabelStyle(contextLabel, "help", 10)
    card:AddChild(contextLabel)
end

function ProfilesPage.Build(container, deps)
    local GetGUIState = deps.GetGUIState
    local ResetFlowContainer = deps.ResetFlowContainer
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

    ResetFlowContainer(container)

    local db = ns.db
    if not db then
        BuildPlaceholderPage(container, T("NAV_PROFILES", "Profile"))
        return
    end

    local function CreateButton(text, width)
        local button = AceGUI:Create("Button")
        button:SetText(text)
        button:SetWidth(width)
        return button
    end

    local function RefreshProfileUI()
        if ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end
    end

    local function RebuildFramesForProfile()
        if ns.ApplyGeneralSettings then
            ns:ApplyGeneralSettings()
        end

        ns.frames = ns.frames or {}

        for _, unitKey in ipairs(C.UnitOrder) do
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

    local function SetStatus(message)
        if ns.GUI and ns.GUI.SetStatusText then
            ns.GUI:SetStatusText(message)
        end
    end

    local state = GetGUIState()
    state.profiles = state.profiles or {
        selectedProfile = db:GetCurrentProfile(),
        newProfileName = "",
    }

    local function GetProfileList()
        local list = {}
        local profiles = db:GetProfiles({})
        for _, profileName in ipairs(profiles) do
            list[profileName] = profileName
        end
        return list
    end

    local page = CreatePageRoot(container)
    CreatePageHeader(
        page,
        T("NAV_PROFILES", "Profile"),
        T("INFO_PROFILES_DESCRIPTION", "Verwalte geteilte Einstellungen zwischen Charakteren.")
    )

    page:AddChild(CreateSpacer(10))
    CreateStatCard(page, db:GetCurrentProfile())

    local sourceCard = CreateCard(
        page,
        T("INFO_PROFILES_SWITCH", "02 Quelle und Uebernahme"),
        T("INFO_PROFILES_SWITCH_HINT", "Waehle ein gespeichertes Profil als Quelle, aktiviere es direkt oder uebernimm dessen Stand in das aktive Profil."),
        { topSpacing = 8 }
    )

    local sourceLead = AceGUI:Create("Label")
    sourceLead:SetFullWidth(true)
    sourceLead:SetText(T("INFO_PROFILES_SWITCH_LEAD", "Quelle waehlen"))
    ApplyLabelStyle(sourceLead, "label", 12)
    sourceCard:AddChild(sourceLead)

    sourceCard:AddChild(CreateSpacer(3))

    local sourceRow = CreateRow(sourceCard, 64)

    local profileSelect = AceGUI:Create("Dropdown")
    profileSelect:SetLabel(T("INFO_PROFILES_SAVED", "Gespeicherte Profile"))
    profileSelect:SetWidth(500)
    profileSelect:SetList(GetProfileList())
    profileSelect:SetValue(state.profiles.selectedProfile or db:GetCurrentProfile())
    ApplyWidgetStyle(profileSelect, "label", 12)
    sourceRow:AddChild(profileSelect)

    local activateButton = CreateButton(T("INFO_PROFILES_ACTIVATE", "Aktivieren"), 150)
    sourceRow:AddChild(activateButton)

    local copyButton = CreateButton(T("INFO_PROFILES_COPY_FROM", "Als Quelle uebernehmen"), 186)
    sourceRow:AddChild(copyButton)

    local sourceHint = AceGUI:Create("Label")
    sourceHint:SetFullWidth(true)
    sourceHint:SetText(T("INFO_PROFILES_SOURCE_FLOW_HINT", "Aktivieren wechselt komplett auf das ausgewaehlte Profil. Uebernehmen kopiert dessen Stand in das aktuell aktive Profil."))
    ApplyLabelStyle(sourceHint, "help", 10)
    sourceCard:AddChild(sourceHint)

    local createCard = CreateCard(
        page,
        T("INFO_PROFILES_CREATE", "03 Neues Profil anlegen"),
        T("INFO_PROFILES_CREATE_HINT", "Lege einen neuen Arbeitsstand an und wechsle direkt in ihn, wenn du eine neue Richtung ausprobieren willst."),
        { topSpacing = 8 }
    )

    local createLead = AceGUI:Create("Label")
    createLead:SetFullWidth(true)
    createLead:SetText(T("INFO_PROFILES_CREATE_LEAD", "Neuer Profilname"))
    ApplyLabelStyle(createLead, "label", 12)
    createCard:AddChild(createLead)

    createCard:AddChild(CreateSpacer(3))

    local createRow = CreateRow(createCard, 64)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("INFO_PROFILES_NAME", "Profilname"))
    nameEdit:SetWidth(610)
    nameEdit:DisableButton(true)
    nameEdit:SetText(state.profiles.newProfileName or "")
    ApplyWidgetStyle(nameEdit, "label", 12)
    createRow:AddChild(nameEdit)

    local createButton = CreateButton(T("INFO_PROFILES_CREATE_AND_SWITCH", "Erstellen und wechseln"), 210)
    createRow:AddChild(createButton)

    local createHint = AceGUI:Create("Label")
    createHint:SetFullWidth(true)
    createHint:SetText(T("INFO_PROFILES_CREATE_CONTEXT", "Neue Profile sind ideal fuer Varianten, saisonale Layouts oder Experimente, ohne den aktuellen Stand zu verlieren."))
    ApplyLabelStyle(createHint, "help", 10)
    createCard:AddChild(createHint)

    local maintenanceCard = CreateCard(
        page,
        T("INFO_PROFILES_MAINTENANCE", "04 Pflege und Wiederherstellung"),
        T("INFO_PROFILES_MAINTENANCE_HINT", "Seltenere Eingriffe bleiben bewusst am Ende, damit der aktive Arbeitsfluss ruhig und sicher bleibt."),
        { topSpacing = 8 }
    )

    local maintenanceLead = AceGUI:Create("Label")
    maintenanceLead:SetFullWidth(true)
    maintenanceLead:SetText(T("INFO_PROFILES_MAINTENANCE_LEAD", "Ruecksetzen oder aufraeumen"))
    ApplyLabelStyle(maintenanceLead, "label", 12)
    maintenanceCard:AddChild(maintenanceLead)

    maintenanceCard:AddChild(CreateSpacer(3))

    local maintenanceRow = CreateRow(maintenanceCard, 46)
    local resetButton = CreateButton(T("INFO_PROFILES_RESET", "Aktives Profil zuruecksetzen"), 220)
    maintenanceRow:AddChild(resetButton)

    local deleteButton = CreateButton(T("INFO_PROFILES_DELETE", "Ausgewaehltes Profil loeschen"), 220)
    maintenanceRow:AddChild(deleteButton)

    local maintenanceHint = AceGUI:Create("Label")
    maintenanceHint:SetFullWidth(true)
    maintenanceHint:SetText(T("INFO_PROFILES_MAINTENANCE_NOTE", "Das aktive Profil kann nicht geloescht werden. Ruecksetzen betrifft immer nur das aktuell aktive Profil."))
    ApplyLabelStyle(maintenanceHint, "help", 10)
    maintenanceCard:AddChild(maintenanceHint)

    local function RefreshActionState()
        local currentProfile = db:GetCurrentProfile()
        local selectedProfile = state.profiles.selectedProfile or currentProfile
        local sameAsCurrent = selectedProfile == currentProfile
        local hasSelectedProfile = type(selectedProfile) == "string" and selectedProfile ~= ""
        local hasNewProfileName = type((nameEdit:GetText() or "")) == "string" and (nameEdit:GetText() or ""):match("%S") ~= nil

        if activateButton.SetDisabled then
            activateButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
        end

        if copyButton.SetDisabled then
            copyButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
        end

        if deleteButton.SetDisabled then
            deleteButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
        end

        if resetButton.SetDisabled then
            resetButton:SetDisabled(currentProfile == nil or currentProfile == "")
        end

        if createButton.SetDisabled then
            createButton:SetDisabled(not hasNewProfileName)
        end
    end

    profileSelect:SetCallback("OnValueChanged", function(_, _, value)
        state.profiles.selectedProfile = value or db:GetCurrentProfile()
        RefreshActionState()
    end)

    nameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.profiles.newProfileName = value or ""
        widget:ClearFocus()
        RefreshActionState()
    end)

    nameEdit:SetCallback("OnTextChanged", function(_, _, value)
        state.profiles.newProfileName = value or ""
        RefreshActionState()
    end)

    nameEdit:SetCallback("OnFocusLost", function(widget)
        state.profiles.newProfileName = widget:GetText() or ""
        RefreshActionState()
    end)

    activateButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        db:SetProfile(profileName)
        state.profiles.selectedProfile = profileName
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((T("INFO_PROFILES_STATUS_ACTIVATED", "Profil aktiviert:")) .. " " .. profileName)
    end)

    copyButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
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
        SetStatus((T("INFO_PROFILES_STATUS_COPIED", "Profil uebernommen:")) .. " " .. profileName)
    end)

    deleteButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" or profileName == db:GetCurrentProfile() then
            return
        end

        db:DeleteProfile(profileName, true)
        state.profiles.selectedProfile = db:GetCurrentProfile()
        RefreshProfileUI()
        SetStatus((T("INFO_PROFILES_STATUS_DELETED", "Profil geloescht:")) .. " " .. profileName)
    end)

    resetButton:SetCallback("OnClick", function()
        local currentProfile = db:GetCurrentProfile()
        db:ResetProfile()
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((T("INFO_PROFILES_STATUS_RESET", "Profil zurueckgesetzt:")) .. " " .. currentProfile)
    end)

    createButton:SetCallback("OnClick", function()
        local profileName = (nameEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if profileName == "" then
            return
        end

        db:SetProfile(profileName)
        state.profiles.selectedProfile = profileName
        state.profiles.newProfileName = profileName
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((T("INFO_PROFILES_STATUS_CREATED", "Profil erstellt:")) .. " " .. profileName)
    end)

    RefreshActionState()
end
