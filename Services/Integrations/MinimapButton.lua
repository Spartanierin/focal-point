local _, FocalPoint = ...

-- =========================================================
-- Minimap Icon (LibDataBroker-1.1 + LibDBIcon-1.0)
-- =========================================================
-- This follows the de-facto standard used by many addons (e.g. AskMrRobot).
-- DBIcon stores position in the table passed at :Register() (minimapPos, hide, etc.).

local _LDB = LibStub("LibDataBroker-1.1", true)
local _DBIcon = LibStub("LibDBIcon-1.0", true)
local L = FocalPoint.L or {}

-- Use a stable name as the key for LibDBIcon (do not use a localized title).
local _MINIMAP_ICON_NAME = "FocalPoint"

local function IsConfigVisible()
    local host = FocalPoint and FocalPoint.guiMainHost
    local frame = host and (host.frame or host)
    if not frame then
        return false
    end
    if frame.IsShown then
        return frame:IsShown()
    end
    return true
end

local function EnsureMinimapConfig(addon)
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end

    addon.db.profile.Minimap = type(addon.db.profile.Minimap) == "table" and addon.db.profile.Minimap or {}
    if addon.db.profile.Minimap.hide == nil then
        addon.db.profile.Minimap.hide = false
    end
    return addon.db.profile.Minimap
end

function FocalPoint:SetMinimapButtonVisible(visible)
    local minimapConfig = EnsureMinimapConfig(self)
    if not minimapConfig then
        return false
    end

    minimapConfig.hide = visible == false

    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if not DBIcon then
        return false
    end

    if minimapConfig.hide then
        DBIcon:Hide(_MINIMAP_ICON_NAME)
    else
        DBIcon:Show(_MINIMAP_ICON_NAME)
    end

    return true
end

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
                    if IsConfigVisible() then
                        if FocalPoint.CloseConfig then
                            FocalPoint:CloseConfig()
                        end
                    else
                        FocalPoint:OpenConfig()
                    end
                elseif button == "RightButton" then
                    if FocalPoint.ToggleFrameLock then
                        FocalPoint:ToggleFrameLock()
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(L["ADDON_NAME"] or "Focal Point")
                tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT_CLICK"] or "Left Click: Open config", 1, 1, 1)
                tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT_CLICK"] or "Right Click: Toggle frame lock", 1, 1, 1)
            end,
        })
    end

    DBIcon:Register(_MINIMAP_ICON_NAME, self.launcher, EnsureMinimapConfig(self))
    self.minimapInitialized = true
end
