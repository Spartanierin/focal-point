local _, Portrait = ...

function Portrait:SetupSlashCommands()
    if self.slashCommandsInitialized then
        return
    end

    SLASH_PORTRAIT1 = "/portrait"
    SLASH_PORTRAIT2 = "/port"

    SlashCmdList["PORTRAIT"] = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

        if msg == "" or msg == "config" then
            Portrait:OpenConfig()
        elseif msg == "test" then
            Portrait:SpawnUnitFrame("player")
        else
            if Portrait.Info then
                Portrait:Info("/port, /port config, /port test")
            end
        end
    end

    self.slashCommandsInitialized = true
end
