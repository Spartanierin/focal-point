local _, FocalPoint = ...

function FocalPoint:Init()
    self.frames = self.frames or {}
    self:Info("Focal Point loaded.")
end

function FocalPoint:CreatePositionController()
    if self.positionController then
        return self.positionController
    end

    local frame = CreateFrame("Frame", "FocalPointPositionController", UIParent)
    frame:Hide()

    self.positionController = frame
    return frame
end

function FocalPoint:StartTagTicker()
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
            if FocalPoint.UpdateAllTags then
                FocalPoint:UpdateAllTags()
            end
        end
    end)

    self.tagTicker = frame
end

function FocalPoint:UpdateAllTags()
    if not self.frames or not self.UnitFrame then
        return
    end

    for _, frame in pairs(self.frames) do
        if frame and frame:IsShown() then
            if self.UnitFrame.RefreshLiveValues then
                self.UnitFrame:RefreshLiveValues(frame)
            end

            if self.UnitFrame.UpdateTextElements then
                self.UnitFrame:UpdateTextElements(frame)
            end
        end
    end
end

function FocalPoint:RefreshAllFrames()
    if not self.frames then
        return
    end

    for unit, frame in pairs(self.frames) do
        if frame then
            self:RefreshUnitFrame(unit)
        end
    end
end
