local _, Portrait = ...


local ADDON_PREFIX = "|cfff2e699Portrait|r"   -- gold
local COLORS = {
    info  = "|cff80b4ff",    -- light blue 
    ok    = "|cff00ff98",    -- teal
    warn  = "|cffffcc00",    -- yellow
    error = "|cffff6060",    -- red
}

function Portrait:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. tostring(msg))
end

function Portrait:Info(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.info .. tostring(msg) .. "|r")
end

function Portrait:Success(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.ok .. tostring(msg) .. "|r")
end

function Portrait:Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.warn .. tostring(msg) .. "|r")
end

function Portrait:Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.error .. tostring(msg) .. "|r")
end