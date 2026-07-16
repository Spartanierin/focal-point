local _, FocalPoint = ...

-- These commands are intentional support diagnostics for live troubleshooting.
-- They are runtime-only flags, never SavedVariables, and are off unless a user
-- explicitly enables them in chat.

local function DemoDebugMessage(text)
    local message = "[FP DemoDebug] " .. tostring(text or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
        return
    end
    print(message)
end

local function VisibilityDebugMessage(text)
    local message = "[FP VisibilityDebug] " .. tostring(text or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
        return
    end
    print(message)
end

local function CountKnownFrames()
    local count = 0
    local frames = FocalPoint and FocalPoint.frames or nil
    if type(frames) ~= "table" then
        return 0
    end
    for _, frame in pairs(frames) do
        if frame then
            count = count + 1
        end
    end
    return count
end

local function ReportDemoDebugOnce()
    local Demo = FocalPoint.UnitFrameDemoEnvironment or nil
    local frames = FocalPoint and FocalPoint.frames or nil
    local reported = 0
    if type(frames) == "table" and Demo and Demo.ReportDebug then
        for _, frame in pairs(frames) do
            if frame then
                frame.FocalPointDemoDebug = frame.FocalPointDemoDebug or {}
                frame.FocalPointDemoDebug.lastReport = 0
                Demo.ReportDebug(frame)
                reported = reported + 1
            end
        end
    end
    DemoDebugMessage(string.format("once reports=%d", reported))
end

local function ResetDemoDebug()
    local Demo = FocalPoint.UnitFrameDemoEnvironment or nil
    if not Demo or not Demo.ResetAllDebug then
        DemoDebugMessage("reset unavailable (DemoEnvironment missing)")
        return
    end
    local count = Demo.ResetAllDebug() or 0
    DemoDebugMessage(string.format("reset frames=%d", count))
end

local function ParseOnOff(value)
    local token = tostring(value or ""):lower()
    if token == "on" then
        return true
    end
    if token == "off" then
        return false
    end
    return nil
end

local function ApplyDemoToggle(key, value)
    local parsed = ParseOnOff(value)
    if parsed == nil then
        DemoDebugMessage(string.format("invalid value for %s: use on/off", tostring(key)))
        return
    end
    FocalPoint[key] = parsed
    DemoDebugMessage(string.format("%s=%s", tostring(key), tostring(parsed)))
end

local function ApplyOnlyUnit(value)
    local token = tostring(value or ""):lower()
    if token == "" or token == "none" then
        FocalPoint.debugDemoOnlyUnit = nil
        DemoDebugMessage("debugDemoOnlyUnit=nil")
        return
    end
    FocalPoint.debugDemoOnlyUnit = token
    DemoDebugMessage(string.format("debugDemoOnlyUnit=%s", token))
end

local function DemoToggleStatus()
    DemoDebugMessage(string.format(
        "toggles castbar=%s auras=%s auratimers=%s texts=%s rangefade=%s smoothing=%s only=%s",
        tostring(FocalPoint.debugDemoDisableCastbar == true),
        tostring(FocalPoint.debugDemoDisableAuras == true),
        tostring(FocalPoint.debugDemoDisableAuraTimers == true),
        tostring(FocalPoint.debugDemoDisableTexts == true),
        tostring(FocalPoint.debugDemoDisableRangeFade == true),
        tostring(FocalPoint.debugDemoDisableBarSmoothing == true),
        tostring(FocalPoint.debugDemoOnlyUnit or "none")
    ))
end

local function GetVisibilityDebugApi()
    return FocalPoint and FocalPoint.UnitFrameVisibility or nil
end

local function ReportVisibilityDebugStatus()
    local Visibility = GetVisibilityDebugApi()
    local status = Visibility and Visibility.GetDecisionDebugStatus and Visibility.GetDecisionDebugStatus() or nil
    if not status then
        VisibilityDebugMessage("status unavailable")
        return
    end
    VisibilityDebugMessage(string.format(
        "enabled=%s comparisons=%d mismatches=%d recent=%d",
        tostring(status.enabled == true),
        tonumber(status.totalComparisons) or 0,
        tonumber(status.totalMismatches) or 0,
        tonumber(status.recentCount) or 0
    ))
end

local function ReportVisibilityDebugSummary()
    local Visibility = GetVisibilityDebugApi()
    local lines = Visibility and Visibility.BuildDecisionDebugReport and Visibility.BuildDecisionDebugReport() or nil
    if type(lines) ~= "table" then
        VisibilityDebugMessage("report unavailable")
        return
    end
    for _, line in ipairs(lines) do
        VisibilityDebugMessage(line)
    end
end

local function ResetVisibilityDebug()
    local Visibility = GetVisibilityDebugApi()
    if Visibility and Visibility.ResetDecisionDebug then
        Visibility.ResetDecisionDebug()
        VisibilityDebugMessage("reset")
    else
        VisibilityDebugMessage("reset unavailable")
    end
end

local function SetVisibilityDebugEnabled(enabled)
    local Visibility = GetVisibilityDebugApi()
    if Visibility and Visibility.SetDecisionDebugEnabled then
        Visibility.SetDecisionDebugEnabled(enabled == true)
        VisibilityDebugMessage("enabled=" .. tostring(enabled == true))
    else
        VisibilityDebugMessage("toggle unavailable")
    end
end

local function HandleVisibilityDebugCommand(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        SetVisibilityDebugEnabled(true)
    elseif msg == "off" then
        SetVisibilityDebugEnabled(false)
    elseif msg == "reset" then
        ResetVisibilityDebug()
    elseif msg == "report" then
        ReportVisibilityDebugSummary()
    elseif msg == "status" or msg == "" then
        ReportVisibilityDebugStatus()
    else
        VisibilityDebugMessage("usage: /fpdebugvisibility on|off|reset|status|report")
    end
end

function FocalPoint:SetupSlashCommands()
    if self.slashCommandsInitialized then
        return
    end

    SLASH_FOCALPOINT1 = "/focalpoint"
    SLASH_FOCALPOINT2 = "/fp"
    SLASH_FPDEBUGDEMO1 = "/fpdebugdemo"
    SLASH_FPDEBUGVISIBILITY1 = "/fpdebugvisibility"
    FocalPoint.debugDemoDisableCastbar = FocalPoint.debugDemoDisableCastbar == true
    FocalPoint.debugDemoDisableAuras = FocalPoint.debugDemoDisableAuras == true
    FocalPoint.debugDemoDisableAuraTimers = FocalPoint.debugDemoDisableAuraTimers == true
    FocalPoint.debugDemoDisableTexts = FocalPoint.debugDemoDisableTexts == true
    FocalPoint.debugDemoDisableRangeFade = FocalPoint.debugDemoDisableRangeFade == true
    FocalPoint.debugDemoDisableBarSmoothing = FocalPoint.debugDemoDisableBarSmoothing == true

    SlashCmdList["FOCALPOINT"] = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

        if msg == "" or msg == "config" then
            FocalPoint:OpenConfig()
        elseif msg == "debug target" then
            FocalPoint.debugTargetVisibility = not FocalPoint.debugTargetVisibility
            if FocalPoint.Info then
                FocalPoint:Info("Target-Debug " .. (FocalPoint.debugTargetVisibility and "aktiv" or "inaktiv"))
            end
        elseif msg == "debug runtime" then
            FocalPoint.debugRuntimeState = not FocalPoint.debugRuntimeState
            if FocalPoint.Info then
                FocalPoint:Info("Runtime-Debug " .. (FocalPoint.debugRuntimeState and "aktiv" or "inaktiv"))
            end
        elseif msg == "diag" or msg == "debug diag" or msg == "debug frames" then
            if FocalPoint.DumpRuntimeDiagnostics then
                FocalPoint:DumpRuntimeDiagnostics()
            end
        elseif msg == "debug visibility" then
            HandleVisibilityDebugCommand("status")
        elseif msg:match("^debug visibility%s+") then
            HandleVisibilityDebugCommand(msg:match("^debug visibility%s+(.+)$"))
        elseif msg == "debugdemo on" then
            FocalPoint.debugDemoRuntime = true
            DemoDebugMessage("enabled=true")
        elseif msg == "debugdemo on reset" then
            FocalPoint.debugDemoRuntime = true
            ResetDemoDebug()
            DemoDebugMessage("enabled=true")
        elseif msg == "debugdemo off" then
            FocalPoint.debugDemoRuntime = false
            DemoDebugMessage("enabled=false")
        elseif msg == "debugdemo status" then
            local demoLoaded = FocalPoint.UnitFrameDemoEnvironment ~= nil
            DemoDebugMessage(string.format("enabled=%s DemoEnvironment=%s frames=%d", tostring(FocalPoint.debugDemoRuntime == true), tostring(demoLoaded), CountKnownFrames()))
            DemoToggleStatus()
        elseif msg == "debugdemo once" then
            ReportDemoDebugOnce()
        elseif msg == "debugdemo reset" then
            ResetDemoDebug()
        elseif msg:match("^debugdemo castbar%s+") then
            ApplyDemoToggle("debugDemoDisableCastbar", msg:match("^debugdemo castbar%s+(%S+)$"))
        elseif msg:match("^debugdemo auras%s+") then
            ApplyDemoToggle("debugDemoDisableAuras", msg:match("^debugdemo auras%s+(%S+)$"))
        elseif msg:match("^debugdemo auratimers%s+") then
            ApplyDemoToggle("debugDemoDisableAuraTimers", msg:match("^debugdemo auratimers%s+(%S+)$"))
        elseif msg:match("^debugdemo texts%s+") then
            ApplyDemoToggle("debugDemoDisableTexts", msg:match("^debugdemo texts%s+(%S+)$"))
        elseif msg:match("^debugdemo rangefade%s+") then
            ApplyDemoToggle("debugDemoDisableRangeFade", msg:match("^debugdemo rangefade%s+(%S+)$"))
        elseif msg:match("^debugdemo smoothing%s+") then
            ApplyDemoToggle("debugDemoDisableBarSmoothing", msg:match("^debugdemo smoothing%s+(%S+)$"))
        elseif msg:match("^debugdemo only%s+") then
            ApplyOnlyUnit(msg:match("^debugdemo only%s+(%S+)$"))
        else
            if FocalPoint.Info then
                FocalPoint:Info("/fp, /fp config, /fp debug target, /fp debug runtime, /fp debug visibility, /fp diag, support diagnostics: /fpdebugdemo on|off|status|once|reset|on reset, /fpdebugvisibility on|off|reset|status|report")
            end
        end
    end

    SlashCmdList["FPDEBUGVISIBILITY"] = function(msg)
        HandleVisibilityDebugCommand(msg)
    end

    SlashCmdList["FPDEBUGDEMO"] = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if msg == "on" then
            FocalPoint.debugDemoRuntime = true
            DemoDebugMessage("enabled=true")
        elseif msg == "on reset" then
            FocalPoint.debugDemoRuntime = true
            ResetDemoDebug()
            DemoDebugMessage("enabled=true")
        elseif msg == "off" then
            FocalPoint.debugDemoRuntime = false
            DemoDebugMessage("enabled=false")
        elseif msg == "status" or msg == "" then
            local demoLoaded = FocalPoint.UnitFrameDemoEnvironment ~= nil
            DemoDebugMessage(string.format("enabled=%s DemoEnvironment=%s frames=%d", tostring(FocalPoint.debugDemoRuntime == true), tostring(demoLoaded), CountKnownFrames()))
            DemoToggleStatus()
        elseif msg == "once" then
            ReportDemoDebugOnce()
        elseif msg == "reset" then
            ResetDemoDebug()
        elseif msg:match("^castbar%s+") then
            ApplyDemoToggle("debugDemoDisableCastbar", msg:match("^castbar%s+(%S+)$"))
        elseif msg:match("^auras%s+") then
            ApplyDemoToggle("debugDemoDisableAuras", msg:match("^auras%s+(%S+)$"))
        elseif msg:match("^auratimers%s+") then
            ApplyDemoToggle("debugDemoDisableAuraTimers", msg:match("^auratimers%s+(%S+)$"))
        elseif msg:match("^texts%s+") then
            ApplyDemoToggle("debugDemoDisableTexts", msg:match("^texts%s+(%S+)$"))
        elseif msg:match("^rangefade%s+") then
            ApplyDemoToggle("debugDemoDisableRangeFade", msg:match("^rangefade%s+(%S+)$"))
        elseif msg:match("^smoothing%s+") then
            ApplyDemoToggle("debugDemoDisableBarSmoothing", msg:match("^smoothing%s+(%S+)$"))
        elseif msg:match("^only%s+") then
            ApplyOnlyUnit(msg:match("^only%s+(%S+)$"))
        else
            DemoDebugMessage("support diagnostics usage: /fpdebugdemo on|off|status|once|reset|on reset|castbar on/off|auras on/off|auratimers on/off|texts on/off|rangefade on/off|smoothing on/off|only <unit|none>")
        end
    end

    self.slashCommandsInitialized = true
end
