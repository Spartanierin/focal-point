local _, FocalPoint = ...

FocalPoint.AuraBlockLayout = FocalPoint.AuraBlockLayout or {}
local AuraBlockLayout = FocalPoint.AuraBlockLayout

-- Grid-based outer layout for Buff and Debuff blocks.

function AuraBlockLayout.CalculateMetrics(visibleCount, config)
    local iconSize = math.max(tonumber(config and config.iconSize) or 30, 1)
    local spacingX = math.max(tonumber(config and config.spacingX) or 0, 0)
    local spacingY = math.max(tonumber(config and config.spacingY) or 0, 0)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    local showTimerText = config and config.showTimerText
    if showTimerText == nil then
        showTimerText = true
    end
    local timerFontScale = math.max(tonumber(config and config.timerFontScale) or 1, 0.5)
    local timerTextHeight = showTimerText and math.max(math.floor((iconSize * 0.34 * timerFontScale) + 0.5), 8) or 0
    local rowHeight = iconSize + (showTimerText and (timerTextHeight + 2) or 0)

    local shownCount = math.max(tonumber(visibleCount) or 0, 0)
    if maxRows > 0 then
        shownCount = math.min(shownCount, iconsPerRow * maxRows)
    end

    local columns = shownCount > 0 and math.min(shownCount, iconsPerRow) or 0
    local rows = shownCount > 0 and math.ceil(shownCount / iconsPerRow) or 0
    local blockWidth = columns > 0 and (columns * iconSize + math.max(columns - 1, 0) * spacingX) or 0
    local blockHeight = rows > 0 and (rows * rowHeight + math.max(rows - 1, 0) * spacingY) or 0

    return {
        shownCount = shownCount,
        columns = columns,
        rows = rows,
        blockWidth = blockWidth,
        blockHeight = blockHeight,
        iconSize = iconSize,
        rowHeight = rowHeight,
        timerTextHeight = timerTextHeight,
        spacingX = spacingX,
        spacingY = spacingY,
        iconsPerRow = iconsPerRow,
        maxRows = maxRows,
    }
end

function AuraBlockLayout.Apply(groupFrame, auraList, config)
    if not groupFrame then
        return AuraBlockLayout.CalculateMetrics(0, config)
    end

    local metrics = AuraBlockLayout.CalculateMetrics(type(auraList) == "table" and #auraList or 0, config)
    groupFrame:SetSize(metrics.blockWidth, metrics.blockHeight)

    local growthX = (config and config.growthX) or "RIGHT"
    local growthY = (config and config.growthY) or "DOWN"
    local pool = groupFrame.pool or {}

    for index = 1, metrics.shownCount do
            local container = pool[index]
            if container then
                local zeroIndex = index - 1
                local row = math.floor(zeroIndex / metrics.iconsPerRow)
                local column = zeroIndex % metrics.iconsPerRow
                local offsetX = column * (metrics.iconSize + metrics.spacingX)
                local offsetY = row * (metrics.rowHeight + metrics.spacingY)
                local textReserve = metrics.timerTextHeight > 0 and (metrics.timerTextHeight + 2) or 0

                container:ClearAllPoints()

                if growthX == "LEFT" and growthY == "UP" then
                    container:SetPoint("BOTTOMRIGHT", groupFrame, "BOTTOMRIGHT", -offsetX, offsetY + textReserve)
                elseif growthX == "LEFT" then
                    container:SetPoint("TOPRIGHT", groupFrame, "TOPRIGHT", -offsetX, -offsetY)
                elseif growthY == "UP" then
                    container:SetPoint("BOTTOMLEFT", groupFrame, "BOTTOMLEFT", offsetX, offsetY + textReserve)
                else
                    container:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", offsetX, -offsetY)
                end
            end
    end

    return metrics
end
