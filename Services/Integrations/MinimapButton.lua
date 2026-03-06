local _, Portrait = ...

-- =========================================================
-- Minimap Icon (LibDataBroker-1.1 + LibDBIcon-1.0)
-- =========================================================
-- This follows the de-facto standard used by many addons (e.g. AskMrRobot).
-- DBIcon stores position in the table passed at :Register() (minimapPos, hide, etc.).

local _LDB = LibStub("LibDataBroker-1.1", true)
local _DBIcon = LibStub("LibDBIcon-1.0", true)

-- Use a stable name as the key for LibDBIcon (do not use a localized title).
local _MINIMAP_ICON_NAME = "Portrait"

local _PortraitLDBObj

local _, Portrait = ...

function Portrait:InitMinimapIcon()
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
        self.launcher = LDB:NewDataObject("Portrait", {
            type = "launcher",
            text = "Portrait",
            icon = "Interface\\AddOns\\Portrait\\Media\\icon",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    Portrait:OpenConfig()
                elseif button == "RightButton" then
                    Portrait:SpawnUnitFrame("player")
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Portrait")
                tooltip:AddLine("Left Click: Open config", 1, 1, 1)
                tooltip:AddLine("Right Click: Spawn test frame", 1, 1, 1)
            end,
        })
    end

    DBIcon:Register("Portrait", self.launcher, self.db.profile.Minimap)
    self.minimapInitialized = true
end