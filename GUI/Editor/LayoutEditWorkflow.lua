local _, FocalPoint = ...

FocalPoint.LayoutEditWorkflow = FocalPoint.LayoutEditWorkflow or {}
local Workflow = FocalPoint.LayoutEditWorkflow

local pendingDialog = nil

local function T(key, fallback)
    local L = FocalPoint.L or {}
    return L[key] or fallback or key
end

local function IsBuiltinActive()
    local resolver = FocalPoint.ActiveLayoutResolver or {}
    local layoutId = resolver.GetStoredActiveLayoutId and resolver.GetStoredActiveLayoutId(FocalPoint.db) or nil
    return type(layoutId) == "string" and layoutId:match("^builtin:") and layoutId or nil
end

function Workflow.RequestEditableLayoutForMutation(onReady, options)
    if type(onReady) ~= "function" then
        return false, "invalid-callback"
    end
    if pendingDialog then
        return false, "confirmation-pending"
    end

    local resolver = FocalPoint.ActiveLayoutResolver or {}
    local activeLayoutId = resolver.GetStoredActiveLayoutId and resolver.GetStoredActiveLayoutId(FocalPoint.db) or nil
    if type(activeLayoutId) == "string" and activeLayoutId:match("^layout:") then
        onReady()
        return true, "ready"
    end
    if type(activeLayoutId) ~= "string" or not activeLayoutId:match("^builtin:") then
        return false, "unsupported-layout"
    end
    if InCombatLockdown and InCombatLockdown() then
        if FocalPoint.Info then
            FocalPoint:Info(T("LAYOUT_EDIT_COMBAT_BLOCKED", "Create editable layouts outside combat."))
        end
        return false, "combat-blocked"
    end

    local envelope = resolver.ResolveLayout and resolver.ResolveLayout(FocalPoint.db, activeLayoutId) or nil
    if type(envelope) ~= "table" then
        return false, "layout-not-found"
    end
    local layoutService = FocalPoint.LayoutService or {}
    local displayName = layoutService.GetDisplayName and layoutService.GetDisplayName(envelope) or envelope.name or activeLayoutId
    local FormWidgets = FocalPoint.GUI and FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.FormWidgets or nil
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true) or nil
    if not (FormWidgets and FormWidgets.CreateCompactFormDialog and AceGUI) then
        return false, "dialog-unavailable"
    end

    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_EDIT_CONFIRM_TITLE", "Create Editable Layout?"),
        description = string.format(T("LAYOUT_EDIT_CONFIRM_MESSAGE", "\"%s\" is a read-only template. Create a personal editable layout from it?"), displayName),
        width = 440,
        height = 210,
        bodyHeight = 72,
    })
    if not dialog then
        return false, "dialog-unavailable"
    end

    local closed = false
    local function close()
        if closed then return end
        closed = true
        if pendingDialog == dialog then pendingDialog = nil end
        if dialog.Close then dialog:Close() end
    end

    dialog:SetActions({
        secondary = { text = T("INFO_COMMON_CANCEL", "Cancel"), role = "utility", width = 110, onClick = close },
        primary = {
            text = T("LAYOUT_EDIT_CONFIRM_CREATE", "Create Editable Layout"),
            role = "primary_action",
            width = 170,
            onClick = function()
                if IsBuiltinActive() ~= activeLayoutId then
                    close()
                    return
                end
                local mutations = FocalPoint.LayoutMutations or {}
                local ok, newLayoutId = false, nil
                if mutations.CreateUserLayoutFromSource then
                    ok, newLayoutId = mutations.CreateUserLayoutFromSource(activeLayoutId, nil, { activate = true, reason = "layout-edit-confirm" })
                end
                if not ok or type(newLayoutId) ~= "string" then
                    if dialog.SetStatus then dialog:SetStatus(T("LAYOUT_EDIT_CREATE_FAILED", "Layout could not be created.")) end
                    return
                end
                close()
                onReady()
            end,
        },
    })
    dialog.window:SetCallback("OnClose", function()
        if pendingDialog == dialog then pendingDialog = nil end
    end)
    pendingDialog = dialog
    dialog:Show()
    return false, "confirmation-open"
end

function Workflow.IsConfirmationOpen()
    return pendingDialog ~= nil
end
