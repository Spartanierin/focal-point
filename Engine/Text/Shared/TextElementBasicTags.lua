local _, FocalPoint = ...

FocalPoint.TextElementBasicTags = FocalPoint.TextElementBasicTags or {}

local BasicTags = FocalPoint.TextElementBasicTags

-- Resolves the basic built-in tags before template parsing falls back to
-- the lower-level token definitions.
function BasicTags.Resolve(frame, unit, token, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local FormatTimeValue = deps.FormatTimeValue
    local ResolveColorTag = deps.ResolveColorTag
    local ResolveUnitClassIdentity = deps.ResolveUnitClassIdentity
        or (FocalPoint.TextElementStatus and FocalPoint.TextElementStatus.ResolveUnitClassIdentity)
    local GetClassificationText = deps.GetClassificationText
    local GetCurrentStatusInfo = deps.GetCurrentStatusInfo
    local GetStatusText = deps.GetStatusText
    local GetGhostText = deps.GetGhostText
    local GetDeadText = deps.GetDeadText
    local GetOfflineText = deps.GetOfflineText
    local GetCombatText = deps.GetCombatText
    local GetRestingText = deps.GetRestingText
    local GetLeaderText = deps.GetLeaderText
    local GetRoleText = deps.GetRoleText
    local GetLiveValue = deps.GetLiveValue
    local FormatStatusTimerValue = deps.FormatStatusTimerValue
    local GetResolvedUnitName = deps.GetResolvedUnitName
    local IsSafeTrue = deps.IsSafeTrue
    local ResolveToken = deps.ResolveToken
    local demo = FocalPoint.UnitFrameDemoEnvironment or {}
    local previewValues = (demo.GetUnitValues and demo.GetUnitValues(frame)) or (frame and frame.TestValues) or nil

    local function CanUseTextValue(value)
        if type(value) ~= "string" then
            return false
        end

        local ok, hasValue = pcall(function()
            return value ~= ""
        end)
        return (ok and hasValue == true) or not ok
    end

    local function IsCastTextAllowed()
        local castBar = frame and frame.Elements and frame.Elements.CastBar
        return frame
            and frame.config
            and frame.config.showCastBar ~= false
            and castBar
            and (castBar.isCasting == true or castBar.isPreview == true)
    end

    if IsPreviewModeEnabled and IsPreviewModeEnabled() and frame and previewValues then
        local preview = previewValues

        if token == "name" then
            return preview.name or ""
        end

        if token == "level" then
            return preview.level and tostring(preview.level) or ""
        end

        if token == "class" then
            local identity = ResolveUnitClassIdentity and ResolveUnitClassIdentity(unit, frame) or nil
            return identity and identity.localizedName or ""
        end

        if token == "race" then
            return preview.race or ""
        end

        if token == "classification" then
            return preview.classification or ""
        end

        if token == "guild" then
            return preview.guild or ""
        end

        if token == "realm" then
            return preview.realm or ""
        end

        if token == "family" then
            return preview.family or preview.creature or ""
        end

        if token == "type" then
            return preview.type or preview.creature or ""
        end

        if token == "creature" then
            return preview.creature or preview.race or ""
        end

        if token == "status" then
            return preview.status or ""
        end

        if token == "status:timer" then
            return preview.statusTimer or ""
        end

        if token == "dead:timer" then
            return preview.deadTimer or ""
        end

        if token == "afk" then
            return preview.afk or ""
        end

        if token == "dnd" then
            return preview.dnd or ""
        end

        if token == "dead" then
            return preview.dead or ""
        end

        if token == "ghost" then
            return preview.ghost or ""
        end

        if token == "offline" then
            return preview.offline or ""
        end

        if token == "pvp" then
            return preview.pvp or ""
        end

        if token == "combat" then
            return preview.combat or ""
        end

        if token == "resting" then
            return preview.resting or ""
        end

        if token == "leader" then
            return preview.leader or ""
        end

        if token == "role" then
            return preview.role or ""
        end

        if token == "cast:name" then
            if not IsCastTextAllowed() then
                return ""
            end
            return preview.castName or ""
        end

        if token == "cast:time" then
            if not IsCastTextAllowed() then
                return ""
            end
            local castBar = frame.Elements and frame.Elements.CastBar
            local now = GetTime and GetTime() or 0
            if castBar and castBar.isCasting and type(castBar.endTime) == "number" and FormatTimeValue then
                return FormatTimeValue(math.max(castBar.endTime - now, 0))
            end

            return type(preview.castDuration) == "number" and FormatTimeValue and FormatTimeValue(preview.castDuration) or ""
        end

        if token == "powercolor" or token == "raidcolor" or token == "resetcolor" or token == "classcolor" or token == "rc" then
            local colorToken = ResolveColorTag and ResolveColorTag(frame, unit, token)
            if colorToken ~= nil then
                return colorToken
            end
            return ""
        end

        if token == "lasthit" then
            return preview.lastHit or ""
        end
    end

    if token == "name" then
        return GetResolvedUnitName and GetResolvedUnitName(unit) or ""
    end

    if token == "level" then
        if unit and UnitLevel then
            local level = UnitLevel(unit)
            if type(level) == "number" and level > 0 then
                return tostring(level)
            end

            if type(level) == "number" and level == -1 then
                return "??"
            end
        end

        return ""
    end

    if token == "class" then
        local identity = ResolveUnitClassIdentity and ResolveUnitClassIdentity(unit, frame) or nil
        if identity and CanUseTextValue(identity.localizedName) then
            return identity.localizedName
        end

        return ""
    end

    if token == "race" then
        if unit and UnitIsPlayer and UnitIsPlayer(unit) and UnitRace then
            local raceName = UnitRace(unit)
            if type(raceName) == "string" then
                return raceName
            end
        end

        return ""
    end

    if token == "classification" then
        return GetClassificationText and GetClassificationText(unit) or ""
    end

    if token == "guild" then
        if unit and GetGuildInfo then
            local guildName = GetGuildInfo(unit)
            if type(guildName) == "string" then
                return guildName
            end
        end

        return ""
    end

    if token == "realm" then
        if unit and UnitFullName then
            local _, realmName = UnitFullName(unit)
            if type(realmName) == "string" then
                return realmName
            end
        end

        return ""
    end

    if token == "family" then
        if unit and UnitCreatureFamily then
            local creatureFamily = UnitCreatureFamily(unit)
            if type(creatureFamily) == "string" then
                return creatureFamily
            end
        end

        return ""
    end

    if token == "type" then
        if unit and UnitCreatureType then
            local creatureType = UnitCreatureType(unit)
            if type(creatureType) == "string" then
                return creatureType
            end
        end

        return ""
    end

    if token == "creature" then
        if unit and UnitCreatureFamily then
            local creatureFamily = UnitCreatureFamily(unit)
            if type(creatureFamily) == "string" then
                return creatureFamily
            end
        end

        if unit and UnitCreatureType then
            local creatureType = UnitCreatureType(unit)
            if type(creatureType) == "string" then
                return creatureType
            end
        end

        return ""
    end

    if token == "status" then
        local statusKey, statusText = "", ""
        if GetCurrentStatusInfo then
            statusKey, statusText = GetCurrentStatusInfo(unit)
        end
        if statusKey == "dead" or statusKey == "ghost" then
            return ""
        end

        return statusText
    end

    if token == "status:timer" then
        local statusKey = GetLiveValue and GetLiveValue(frame, "statusKey", "") or ""
        local statusTimerStart = GetLiveValue and GetLiveValue(frame, "statusTimerStart", nil) or nil
        local now = GetTime and GetTime() or 0

        if statusKey == "" or statusKey == "dead" or statusKey == "ghost" or type(statusTimerStart) ~= "number" then
            return ""
        end

        return FormatStatusTimerValue and FormatStatusTimerValue(now - statusTimerStart) or ""
    end

    if token == "dead:timer" then
        local statusKey = GetLiveValue and GetLiveValue(frame, "statusKey", "") or ""
        local deadTimerStart = GetLiveValue and GetLiveValue(frame, "deadTimerStart", nil) or nil
        local now = GetTime and GetTime() or 0

        if (statusKey ~= "dead" and statusKey ~= "ghost") or type(deadTimerStart) ~= "number" then
            return ""
        end

        return FormatStatusTimerValue and FormatStatusTimerValue(now - deadTimerStart) or ""
    end

    if token == "afk" then
        if UnitIsAFK and unit and IsSafeTrue and IsSafeTrue(UnitIsAFK(unit)) then
            return GetStatusText and GetStatusText(AFK, "AFK") or "AFK"
        end

        return ""
    end

    if token == "dnd" then
        if UnitIsDND and unit and IsSafeTrue and IsSafeTrue(UnitIsDND(unit)) then
            return GetStatusText and GetStatusText(DND, "DND") or "DND"
        end

        return ""
    end

    if token == "dead" then
        if UnitIsDeadOrGhost and unit and IsSafeTrue and IsSafeTrue(UnitIsDeadOrGhost(unit)) then
            if UnitIsGhost and IsSafeTrue(UnitIsGhost(unit)) then
                return GetStatusText and GetStatusText(GetGhostText and GetGhostText(), "Ghost") or "Ghost"
            end
            return GetStatusText and GetStatusText(GetDeadText and GetDeadText(), "Dead") or "Dead"
        end

        return ""
    end

    if token == "ghost" then
        if UnitIsGhost and unit and IsSafeTrue and IsSafeTrue(UnitIsGhost(unit)) then
            return GetStatusText and GetStatusText(GetGhostText and GetGhostText(), "Ghost") or "Ghost"
        end

        return ""
    end

    if token == "offline" then
        if UnitIsConnected and unit and IsSafeTrue and not IsSafeTrue(UnitIsConnected(unit)) then
            return GetStatusText and GetStatusText(GetOfflineText and GetOfflineText(), "Offline") or "Offline"
        end

        return ""
    end

    if token == "pvp" then
        if UnitIsPVP and unit and IsSafeTrue and IsSafeTrue(UnitIsPVP(unit)) then
            return GetStatusText and GetStatusText(PVP, "PvP") or "PvP"
        end

        return ""
    end

    if token == "combat" then
        if UnitAffectingCombat and unit and IsSafeTrue and IsSafeTrue(UnitAffectingCombat(unit)) then
            return GetStatusText and GetStatusText(GetCombatText and GetCombatText(), "Combat") or "Combat"
        end

        return ""
    end

    if token == "resting" then
        if unit == "player" and IsResting and IsSafeTrue and IsSafeTrue(IsResting()) then
            return GetStatusText and GetStatusText(GetRestingText and GetRestingText(), "Resting") or "Resting"
        end

        return ""
    end

    if token == "leader" then
        if UnitIsGroupLeader and unit and IsSafeTrue and IsSafeTrue(UnitIsGroupLeader(unit)) then
            return GetStatusText and GetStatusText(GetLeaderText and GetLeaderText(), "Leader") or "Leader"
        end

        return ""
    end

    if token == "role" then
        return GetStatusText and GetStatusText(GetRoleText and GetRoleText(unit), "") or ""
    end

    if token == "cast:name" then
        if not IsCastTextAllowed() then
            return ""
        end

        if not unit then
            return ""
        end

        if UnitExists and not UnitExists(unit) then
            return ""
        end

        if UnitCastingInfo then
            local castName = UnitCastingInfo(unit)
            if type(castName) == "string" then
                return castName
            end
        end

        if UnitChannelInfo then
            local channelName = UnitChannelInfo(unit)
            if type(channelName) == "string" then
                return channelName
            end
        end

        return ""
    end

    if token == "cast:time" then
        if not IsCastTextAllowed() then
            return ""
        end

        if not unit then
            return ""
        end

        if UnitExists and not UnitExists(unit) then
            return ""
        end

        local now = GetTime and GetTime() or 0
        local castBar = frame and frame.Elements and frame.Elements.CastBar

        if castBar and castBar.isCasting and type(castBar.endTime) == "number" and FormatTimeValue then
            return FormatTimeValue(math.max(castBar.endTime - now, 0))
        end

        if unit == "player" and UnitCastingInfo and FormatTimeValue then
            local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local endTime = endTimeMS / 1000
                return FormatTimeValue(endTime - now)
            end
        end

        if unit == "player" and UnitChannelInfo and FormatTimeValue then
            local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local remaining = (endTimeMS / 1000) - now
                return FormatTimeValue(remaining)
            end
        end

        return ""
    end

    if token == "powercolor" or token == "raidcolor" or token == "resetcolor" or token == "classcolor" or token == "rc" then
        local colorToken = ResolveColorTag and ResolveColorTag(frame, unit, token)
        if colorToken ~= nil then
            return colorToken
        end
        return ""
    end

    if token == "lasthit" then
        return ""
    end

    return ResolveToken and ResolveToken(frame, unit, token) or nil
end
