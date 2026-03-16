local _, FocalPoint = ...


local ADDON_PREFIX = "|cfff2e699Focal Point|r"   -- gold
local COLORS = {
    info  = "|cff80b4ff",    -- light blue 
    ok    = "|cff00ff98",    -- teal
    warn  = "|cffffcc00",    -- yellow
    error = "|cffff6060",    -- red
}

function FocalPoint:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. tostring(msg))
end

function FocalPoint:Info(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.info .. tostring(msg) .. "|r")
end

function FocalPoint:Success(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.ok .. tostring(msg) .. "|r")
end

function FocalPoint:Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.warn .. tostring(msg) .. "|r")
end

function FocalPoint:Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. ": " .. COLORS.error .. tostring(msg) .. "|r")
end
