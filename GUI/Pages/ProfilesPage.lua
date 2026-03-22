local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local TextStyles = ns.GUI.Helpers.TextStyles

local ProfilesPage = {}
ns.GUI.Pages.Profiles = ProfilesPage

function ProfilesPage.Build(container, deps)
    local GetGUIState = deps.GetGUIState
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddPageHeading = deps.AddPageHeading
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

    local function StyleGroupTitle(widget)
        if TextStyles and TextStyles.ApplyWidgetText then
            TextStyles.ApplyWidgetText(widget, "sectionHeader", { size = 13 })
        end
    end

    ResetFlowContainer(container)

    local db = ns.db
    if not db then
        BuildPlaceholderPage(container, L["NAV_PROFILES"] or "Profiles")
        return
    end

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
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
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
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

    AddPageHeading(container, L["NAV_PROFILES"] or "Profiles")
    container:AddChild(CreateSpacer(2))

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    description:SetText(L["INFO_PROFILES_DESCRIPTION"] or "Manage shared settings across characters.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(description, "label", { size = 12 })
    end
    container:AddChild(description)

    container:AddChild(CreateSpacer(4))

    local currentGroup = AceGUI:Create("InlineGroup")
    currentGroup:SetFullWidth(true)
    currentGroup:SetLayout("Flow")
    currentGroup:SetTitle(L["INFO_PROFILES_CURRENT"] or "Current Profile")
    StyleGroupTitle(currentGroup)
    container:AddChild(currentGroup)

    local currentLabel = AceGUI:Create("Label")
    currentLabel:SetFullWidth(true)
    currentLabel:SetText(db:GetCurrentProfile() or "Default")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(currentLabel, "highlight", { size = 12 })
    end
    currentGroup:AddChild(currentLabel)

    local switchGroup = AceGUI:Create("InlineGroup")
    switchGroup:SetFullWidth(true)
    switchGroup:SetLayout("Flow")
    switchGroup:SetTitle(L["INFO_PROFILES_SWITCH"] or "Switch / Manage")
    StyleGroupTitle(switchGroup)
    container:AddChild(switchGroup)

    local profileSelect = AceGUI:Create("Dropdown")
    profileSelect:SetLabel(L["INFO_PROFILES_SAVED"] or "Saved Profiles")
    profileSelect:SetWidth(260)
    profileSelect:SetList(GetProfileList())
    profileSelect:SetValue(state.profiles.selectedProfile or db:GetCurrentProfile())
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(profileSelect, "label", { size = 12 })
    end
    switchGroup:AddChild(profileSelect)

    local activateButton = AceGUI:Create("Button")
    activateButton:SetText(L["INFO_PROFILES_ACTIVATE"] or "Activate")
    activateButton:SetWidth(120)
    switchGroup:AddChild(activateButton)

    local copyButton = AceGUI:Create("Button")
    copyButton:SetText(L["INFO_PROFILES_COPY_FROM"] or "Copy From")
    copyButton:SetWidth(120)
    switchGroup:AddChild(copyButton)

    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText(L["INFO_PROFILES_DELETE"] or "Delete")
    deleteButton:SetWidth(120)
    switchGroup:AddChild(deleteButton)

    local resetButton = AceGUI:Create("Button")
    resetButton:SetText(L["INFO_PROFILES_RESET"] or "Reset")
    resetButton:SetWidth(120)
    switchGroup:AddChild(resetButton)

    switchGroup:AddChild(CreateSpacer(2))

    local createGroup = AceGUI:Create("InlineGroup")
    createGroup:SetFullWidth(true)
    createGroup:SetLayout("Flow")
    createGroup:SetTitle(L["INFO_PROFILES_CREATE"] or "Create / Switch")
    StyleGroupTitle(createGroup)
    container:AddChild(createGroup)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(L["INFO_PROFILES_NAME"] or "Profile Name")
    nameEdit:SetWidth(260)
    nameEdit:DisableButton(true)
    nameEdit:SetText(state.profiles.newProfileName or "")
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(nameEdit, "label", { size = 12 })
    end
    createGroup:AddChild(nameEdit)

    local createButton = AceGUI:Create("Button")
    createButton:SetText(L["INFO_PROFILES_CREATE_AND_SWITCH"] or "Create and Switch")
    createButton:SetWidth(160)
    createGroup:AddChild(createButton)

    profileSelect:SetCallback("OnValueChanged", function(_, _, value)
        state.profiles.selectedProfile = value or db:GetCurrentProfile()
    end)

    nameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.profiles.newProfileName = value or ""
        widget:ClearFocus()
    end)

    nameEdit:SetCallback("OnFocusLost", function(widget)
        state.profiles.newProfileName = widget:GetText() or ""
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
        SetStatus((L["INFO_PROFILES_STATUS_ACTIVATED"] or "Activated profile:") .. " " .. profileName)
    end)

    copyButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        if profileName == db:GetCurrentProfile() then
            SetStatus(L["INFO_PROFILES_STATUS_COPY_SAME"] or "Source and destination profile are identical.")
            return
        end

        db:CopyProfile(profileName)
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_COPIED"] or "Copied profile:") .. " " .. profileName)
    end)

    deleteButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" or profileName == db:GetCurrentProfile() then
            return
        end

        db:DeleteProfile(profileName, true)
        state.profiles.selectedProfile = db:GetCurrentProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_DELETED"] or "Deleted profile:") .. " " .. profileName)
    end)

    resetButton:SetCallback("OnClick", function()
        local currentProfile = db:GetCurrentProfile()
        db:ResetProfile()
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_RESET"] or "Reset profile:") .. " " .. currentProfile)
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
        SetStatus((L["INFO_PROFILES_STATUS_CREATED"] or "Created profile:") .. " " .. profileName)
    end)
end
