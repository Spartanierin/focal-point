local _, FocalPoint = ...

-- Equipment effects are not unit auras. Keep their snapshot out of AuraCache.
local Weapons = {}
FocalPoint.WeaponEnhancements = Weapons

function Weapons.IsEnabled(frame, groupKey, config)
    return frame and frame._fpUnit == "player" and groupKey == "Buffs"
        and config and config.showWeaponEnhancements == true
end

function Weapons.GetBudget(config)
    local columns = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local rows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    return rows > 0 and columns * rows or 40
end

function Weapons.Invalidate(frame)
    if frame then frame._weaponEnhancements = nil end
end

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function ReadSlot(slot, now)
    local api = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
    if type(api) ~= "function" then return nil end
    local ok, info = pcall(api, slot)
    if not ok or not Plain(info) or type(info) ~= "table" then return nil end
    for _, key in ipairs({"enchantID", "remainingTimeMs", "chargesRemaining", "hasExpirationTime"}) do
        if not Plain(info[key]) then return nil end
    end
    if type(info.enchantID) ~= "number" or type(info.remainingTimeMs) ~= "number"
        or type(info.chargesRemaining) ~= "number" or type(info.hasExpirationTime) ~= "boolean" then return nil end
    local seconds = math.max(info.remainingTimeMs / 1000, 0)
    if info.hasExpirationTime and seconds == 0 then return nil end
    return {
        kind = "weaponEnhancement", inventorySlot = slot, enchantID = info.enchantID,
        tooltipKind = "inventory", icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot),
        count = info.chargesRemaining, duration = seconds,
        expirationTime = info.hasExpirationTime and now + seconds or 0,
        durationState = info.hasExpirationTime and "TIMED" or "PERMANENT",
        -- This is a remaining-time snapshot, not the original enchant duration.
        durationSource = "WEAPON_SNAPSHOT", timerReadable = true,
    }
end

function Weapons.GetEntries(frame, groupKey, config, preview)
    if not Weapons.IsEnabled(frame, groupKey, config) then return {} end
    if preview then
        local now = GetTime and GetTime() or 0
        return {
            {kind="weaponEnhancement", preview=true, inventorySlot=INVSLOT_MAINHAND or 16,
                enchantID=0, icon=134400, count=0, duration=600, expirationTime=now+600, durationState="TIMED"},
            {kind="weaponEnhancement", preview=true, inventorySlot=INVSLOT_OFFHAND or 17,
                enchantID=0, icon=134400, count=3, duration=300, expirationTime=now+300, durationState="TIMED"},
        }
    end
    if not frame._weaponEnhancements then
        local now = GetTime and GetTime() or 0
        local entries = {}
        for _, slot in ipairs({INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17}) do
            local entry = ReadSlot(slot, now)
            if entry then entries[#entries + 1] = entry end
        end
        frame._weaponEnhancements = entries
    end
    return frame._weaponEnhancements
end

function Weapons.GetMask(frame, config)
    if not Weapons.IsEnabled(frame, "Buffs", config) then return 0, 0 end
    local mask, count = 0, 0
    local budget = Weapons.GetBudget(config)
    for _, entry in ipairs(Weapons.GetEntries(frame, "Buffs", config)) do
        if count >= budget then break end
        mask = mask + (entry.inventorySlot == (INVSLOT_MAINHAND or 16) and 1 or 2)
        count = count + 1
    end
    return mask, count
end

-- Called after aura-only filtering/sorting; never deduplicate across sources.
function Weapons.Prepend(frame, groupKey, config, auras, preview)
    if not Weapons.IsEnabled(frame, groupKey, config) then return auras end
    local result, budget = {}, Weapons.GetBudget(config)
    for _, entries in ipairs({Weapons.GetEntries(frame, groupKey, config, preview), auras}) do
        for _, entry in ipairs(entries) do
            if #result >= budget then break end
            result[#result + 1] = entry
        end
    end
    return result
end
