local _, ns = ...

-- Offline only. Deliberately absent from Init.xml: no startup or live migration.
local Cleanup = {}
ns.LegacyCustomTextSlotCleanup = Cleanup
local customKeys = {Custom1=true, Custom2=true, Custom3=true}

local function Copy(value, visiting)
    if type(value) ~= 'table' then
        local kind = type(value)
        assert(kind == 'nil' or kind == 'string' or kind == 'boolean'
            or (kind == 'number' and value == value and value ~= math.huge and value ~= -math.huge), 'invalid saved value')
        return value
    end
    visiting = visiting or {}
    assert(getmetatable(value) == nil and not visiting[value], 'invalid saved table')
    visiting[value] = true
    local result = {}
    for key, child in pairs(value) do
        assert(type(key) == 'string' or type(key) == 'number', 'invalid saved key')
        result[key] = Copy(child, visiting)
    end
    visiting[value] = nil
    return result
end

local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function Keys(t)
    local keys = {}
    for key in pairs(t) do keys[#keys+1] = key end
    table.sort(keys, function(a,b) return type(a)..tostring(a) < type(b)..tostring(b) end)
    return keys
end

-- Current composition owns text under unit/bar parents, not under other texts.
-- Still keep a candidate if any other stored value names it (object refs,
-- anchorTo, or unrecognized future metadata). False positives only retain data.
local function Referenced(value, candidate, textKey)
    if value == candidate then return false end
    if type(value) ~= 'table' then return value == textKey end
    for _, child in pairs(value) do
        if Referenced(child, candidate, textKey) then return true end
    end
    return false
end

local function Diagnose(result, code, layoutId, unitKey)
    result.diagnostics[#result.diagnostics+1] = {errorCode=code, layoutId=layoutId, unitKey=unitKey}
end

local function Plan(db)
    local result = {ready=false, removals={}, kept={}, diagnostics={},
        stats={layouts=0, texts=0, custom=0, removals=0, byLayout={}, byKey={Custom1=0,Custom2=0,Custom3=0}}}
    local snapshot, roles = ns.LegacyCustomTextSlots, ns.TextElementRoles
    if not (snapshot and snapshot.Get and roles and roles.Resolve) then
        Diagnose(result, 'cleanup-dependencies-unavailable'); return result
    end
    local layouts = type(db) == 'table' and type(db.global) == 'table' and db.global.UserLayouts
    if type(layouts) ~= 'table' then Diagnose(result, 'invalid-user-layouts'); return result end
    for _, layoutId in ipairs(Keys(layouts)) do
        local layout = layouts[layoutId]
        local payload = type(layout) == 'table' and layout.payload
        if type(layoutId) ~= 'string' or layoutId == '' or type(payload) ~= 'table' or type(payload.Units) ~= 'table' then
            Diagnose(result, 'invalid-layout', layoutId)
        else
            result.stats.layouts = result.stats.layouts+1
            local stats = {texts=0, custom=0, removals=0}
            result.stats.byLayout[layoutId] = stats
            for _, unitKey in ipairs(Keys(payload.Units)) do
                local unit = payload.Units[unitKey]
                if type(unitKey) ~= 'string' or type(unit) ~= 'table' or (unit.Texts ~= nil and type(unit.Texts) ~= 'table') then
                    Diagnose(result, 'invalid-unit', layoutId, unitKey)
                else
                    for _, textKey in ipairs(Keys(unit.Texts or {})) do
                        stats.texts = stats.texts+1; result.stats.texts = result.stats.texts+1
                        if customKeys[textKey] then
                            stats.custom = stats.custom+1; result.stats.custom = result.stats.custom+1
                            local text = unit.Texts[textKey]
                            local baseline = snapshot.Get(unitKey, textKey)
                            local reason
                            if not baseline then reason = 'unapproved-pair'
                            elseif type(text) ~= 'table' or not Equal(text, baseline) then reason = 'fingerprint-differs'
                            elseif text.enabled ~= false or (text.templateName ~= nil and text.templateName ~= '')
                                or text.stateTemplates ~= nil or text.role ~= nil then reason = 'configured'
                            elseif roles.Resolve(textKey, text) ~= nil then reason = 'runtime-role'
                            elseif Referenced(layout, text, textKey) then reason = 'referenced' end
                            local entry = {layoutId=layoutId, unitKey=unitKey, textKey=textKey,
                                reason=reason or 'unchanged-v2.1.0-custom-slot'}
                            if reason then result.kept[#result.kept+1] = entry
                            else
                                result.removals[#result.removals+1] = entry
                                stats.removals = stats.removals+1
                                result.stats.removals = result.stats.removals+1
                                result.stats.byKey[textKey] = result.stats.byKey[textKey]+1
                            end
                        end
                    end
                end
            end
        end
    end
    result.ready = #result.diagnostics == 0
    if not result.ready then result.removals = {} end
    return result
end

local function Snapshot(sourceDb)
    local ok, db = pcall(Copy, sourceDb)
    if ok then return db end
    return nil
end

function Cleanup.Prepare(sourceDb)
    local db = Snapshot(sourceDb)
    if not db then return {ready=false, removals={}, kept={}, diagnostics={{errorCode='invalid-source'}}, stats={}} end
    return Plan(db)
end

-- Plan and transform the SAME independent snapshot. No externally editable or
-- stale plan can authorize deletions; calling again on the result is a no-op.
function Cleanup.ApplyCopy(sourceDb)
    local db = Snapshot(sourceDb)
    if not db then return {ready=false, removals={}, kept={}, diagnostics={{errorCode='invalid-source'}}, stats={}} end
    local result = Plan(db)
    if not result.ready then return result end
    for _, entry in ipairs(result.removals) do
        db.global.UserLayouts[entry.layoutId].payload.Units[entry.unitKey].Texts[entry.textKey] = nil
    end
    result.db = db
    return result
end

return Cleanup
