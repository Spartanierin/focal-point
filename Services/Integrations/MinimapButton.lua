local _, FocalPoint = ...

-- =========================================================
-- Minimap Icon (LibDataBroker-1.1 + LibDBIcon-1.0)
-- =========================================================
-- This follows the de-facto standard used by many addons (e.g. AskMrRobot).
-- DBIcon stores position in the table passed at :Register() (minimapPos, hide, etc.).

local _LDB = LibStub("LibDataBroker-1.1", true)
local _DBIcon = LibStub("LibDBIcon-1.0", true)

-- Use a stable name as the key for LibDBIcon (do not use a localized title).
local _MINIMAP_ICON_NAME = "FocalPoint"

function FocalPoint:InitMinimapIcon()
    if self.minimapInitialized then
        return
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)

    if not LDB or not DBIcon then
        self:Warn("LibDataBroker or LibDBIcon missing. Minimap icon disabled.")
        return
    end

    if not self.launcher then
        self.launcher = LDB:NewDataObject(_MINIMAP_ICON_NAME, {
            type = "launcher",
            text = "Focal Point",
            icon = "Interface\\AddOns\\FocalPoint\\Media\\Icon.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    FocalPoint:OpenConfig()
                elseif button == "RightButton" then
                    FocalPoint:SpawnUnitFrame("player")
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Focal Point")
                tooltip:AddLine("Left Click: Open config", 1, 1, 1)
                tooltip:AddLine("Right Click: Spawn test frame", 1, 1, 1)
            end,
        })
    end

    DBIcon:Register(_MINIMAP_ICON_NAME, self.launcher, self.db.profile.Minimap)
    self.minimapInitialized = true
end
