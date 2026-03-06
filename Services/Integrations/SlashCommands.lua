local _, Portrait = ...

function Portrait:OpenConfig()
    self:Info("GUI is not connected yet.")
end

function Portrait:SetupSlashCommands()
    if self.slashCommandsInitialized then
        return
    end

    SLASH_PORTRAIT1 = "/portrait"
    SLASH_PORTRAIT2 = "/port"

    SlashCmdList["PORTRAIT"] = function(msg)
        msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

        if msg == "config" or msg == "" then
            Portrait:OpenConfig()
        elseif msg == "test" then
            Portrait:SpawnUnitFrame("player")
        else
            Portrait:Info("/portrait or /port")
        end
    end

    self.slashCommandsInitialized = true
end