local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorRefreshPolicy = {}
FocalPoint.InspectorRefreshPolicy = InspectorRefreshPolicy
FocalPoint.GUI.Editor.Inspector.RefreshPolicy = InspectorRefreshPolicy

local FIELD_POLICIES = {
    unit = {
        useClassColorHealth = { scope = "section", sectionKey = "health" },
        useReactionColorNpcHealth = { scope = "section", sectionKey = "health" },
        healthBackground = { scope = "section", sectionKey = "health" },
        showPowerBar = { scope = "section", sectionKey = "power" },
        useClassColorPower = { scope = "section", sectionKey = "power" },
        powerBackground = { scope = "section", sectionKey = "power" },
        showAlternativePowerBar = { scope = "section", sectionKey = "alternativePower" },
        alternativePowerBackground = { scope = "section", sectionKey = "alternativePower" },
        showClassPowerBar = { scope = "section", sectionKey = "classPower" },
        showCastBar = { scope = "section", sectionKey = "cast" },
        mouseEnabled = { scope = "section", sectionKey = "visibility" },
    },
    text = {
        enabled = { scope = "section", sectionKey = "texts" },
    },
    indicator = {
        enabled = { scope = "section", sectionKey = "indicators" },
        placement = { scope = "section", sectionKey = "indicators" },
    },
    aura = {
        enabled = { scope = "section", sectionKey = "auras" },
        placement = { scope = "section", sectionKey = "auras" },
        hideLongAuras = { scope = "section", sectionKey = "auras" },
    },
}

local function CopyPolicy(policy)
    if type(policy) ~= "table" then
        return { scope = "live" }
    end

    return {
        scope = policy.scope or "live",
        sectionKey = policy.sectionKey,
    }
end

function InspectorRefreshPolicy.Resolve(targetKind, fieldName)
    if type(targetKind) ~= "string" or targetKind == "" then
        return { scope = "none" }
    end
    if type(fieldName) ~= "string" or fieldName == "" then
        return { scope = "none" }
    end

    local targetPolicies = FIELD_POLICIES[targetKind]
    if type(targetPolicies) ~= "table" then
        return { scope = "none" }
    end

    return CopyPolicy(targetPolicies[fieldName])
end

return InspectorRefreshPolicy
