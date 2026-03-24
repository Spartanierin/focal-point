local _, FocalPoint = ...

function FocalPoint:SetupSlashCommands()
    if self.slashCommandsInitialized then
        return
    end

    SLASH_FOCALPOINT1 = "/focalpoint"
    SLASH_FOCALPOINT2 = "/fp"
    SLASH_FOCALPOINT3 = "/portrait"
    SLASH_FOCALPOINT4 = "/port"

    SlashCmdList["FOCALPOINT"] = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

        if msg == "" or msg == "config" then
            FocalPoint:OpenConfig()
        elseif msg == "test" then
            FocalPoint:SpawnUnitFrame("player")
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
        else
            if FocalPoint.Info then
                FocalPoint:Info("/fp, /fp config, /fp test, /fp debug target, /fp debug runtime, /fp diag")
            end
        end
    end

    self.slashCommandsInitialized = true
end
