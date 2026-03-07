local _, Portrait = ...

function Portrait:Init()
    self.frames = self.frames or {}
    self:Info("Portrait loaded.")
end

function Portrait:CreatePositionController()
    if self.positionController then
        return self.positionController
    end

    local frame = CreateFrame("Frame", "PortraitPositionController", UIParent)
    frame:Hide()

    self.positionController = frame
    return frame
end

function Portrait:StartTagTicker()
    if self.tagTicker then
        return
    end

    local interval = self.TAG_UPDATE_INTERVAL or 0.25
    local elapsed = 0

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= interval then
            elapsed = 0
            if Portrait.UpdateAllTags then
                Portrait:UpdateAllTags()
            end
        end
    end)

    self.tagTicker = frame
end

function Portrait:UpdateAllTags()
    -- Platzhalter für spätere Tag-Engine
end

function Portrait:RefreshAllFrames()
    if not self.frames then
        return
    end

    for unit, frame in pairs(self.frames) do
        if frame then
            self:RefreshUnitFrame(unit)
        end
    end
end