-- Run from the repository root: lua54 Tests/TextObjectIdentity.lua
local ns = {L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
for _, path in ipairs({
    "Data/Defaults.lua", "Data/Themes.lua", "Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua", "Services/LegacyThemeAdapter.lua", "Services/PresetService.lua",
    "Services/UserLayoutStore.lua", "Services/ActiveLayoutResolver.lua", "Services/LayoutMutations.lua",
    "Services/LayoutTransferCodec.lua", "Services/LayoutTransfer.lua",
    "Engine/Text/Shared/TextTemplateResolver.lua", "Engine/UnitFrame/Shared/UnitFrameUtils.lua",
    "Engine/Text/Shared/TextTemplateMutations.lua", "GUI/Editor/Inspector/InspectorMutations.lua",
}) do Load(path) end
local service, mutations = ns.LayoutService, ns.TextTemplateMutations
local Clone = service.Clone
local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function SameKeys(actual, expected)
    assert(type(actual) == "table", "missing Texts map")
    for k in pairs(expected or {}) do assert(actual[k] ~= nil, "missing text: " .. k) end
    for k in pairs(actual) do assert(expected and expected[k] ~= nil, "extra text: " .. k) end
end
local failed, passed = 0, 0
local function Test(name, run)
    local ok, reason = pcall(run)
    if ok then passed=passed+1; print("PASS: " .. name)
    else failed=failed+1; print("FAIL: " .. name .. ": " .. tostring(reason)) end
end
local function Styled()
    return {enabled=true, templateName="Shared", tag="[name]", font="fp:font:standard",
        fontSize=17, fontStyle="OUTLINE", outline=true, shadowOffsetX=2, shadowOffsetY=-2,
        color={0.8,0.7,0.6,1}, anchorTo="HealthBar", point="RIGHT", relativePoint="RIGHT",
        offsetX=-9, offsetY=3, role="name"}
end
local function Preserve(texts)
    local unit, before, identities = {Texts=texts}, Clone(texts), {}
    for k,v in pairs(texts) do identities[k]=v end
    for _=1,20 do
        ns.UnitFrameUtils.NormalizeUnitTexts(unit)
        assert(unit.Texts == texts, "Texts map replaced")
        assert(Equal(texts, before), "text keys or values changed")
        for k,v in pairs(identities) do assert(texts[k] == v, "object identity changed: " .. k) end
    end
end
Test("identical linked objects / same position, 20 normalizations", function()
    local a=Styled(); Preserve({text_1=a, text_2=Clone(a)})
end)
Test("identical local expressions, 20 normalizations", function()
    local a=Styled(); a.templateName=""; Preserve({text_1=a, text_2=Clone(a)})
end)
for field, value in pairs({fontStyle="THICKOUTLINE", outline=false, shadowOffsetX=5,
    shadowOffsetY=7, color={1,0,0,1}, anchorTo="Frame", role="health",
    stateTemplates={dead="Dead"}}) do
    Test("distinct " .. field, function()
        local a,b=Styled(),Styled(); b[field]=value; Preserve({text_1=a, text_2=b})
    end)
end
Test("empty table, CustomN and CENTER object beside legacy key", function()
    Preserve({text_1={}, Custom1={templateName="Shared"}, Health=Styled(),
        text_2={templateName="Shared", anchorTo="HealthBar", point="CENTER", relativePoint="CENTER"}})
end)
Test("invalid entries removed; resolver candidates invalidated", function()
    local text=Styled(); local unit={Texts={text_1=text, bad=false, number=42, string="invalid"}}
    local context={GetTemplate=function(name) return name end}
    assert(ns.TextTemplateResolver.Resolve(text, nil, context) == "Shared")
    text.templateName="Other"
    ns.UnitFrameUtils.NormalizeUnitTexts(unit)
    assert(ns.TextTemplateResolver.Resolve(text, nil, context) == "Other", "stale resolver cache")
    SameKeys(unit.Texts, {text_1=true}); assert(unit.Texts.text_1 == text)
    ns.UnitFrameUtils.NormalizeUnitTexts(nil); ns.UnitFrameUtils.NormalizeUnitTexts({Texts=false})
end)
local defaults=ns:GetDefaultDB()
local function CheckProjection(payload)
    local before=Clone(payload)
    local projected=service.ProjectUserLayout("layout:test", {name="Test", payload=payload}, defaults).payload
    for unitKey,unit in pairs(projected.Units) do
        SameKeys(unit.Texts, payload.Units[unitKey] and payload.Units[unitKey].Texts)
    end
    assert(Equal(payload,before), "projection mutated source")
    return projected
end
Test("reduced, empty, absent Texts and absent unit; explicit empty fields", function()
    local payload={Units={player={Texts={Health={templateName="",tag=""},text_1=Styled(),text_2=Styled()}},
        target={Texts={}},focus={}}, TextTemplates={Shared="[name]"}}
    local projected=CheckProjection(payload)
    assert(projected.Units.player.Texts.Health.templateName == "")
    assert(projected.Units.player.Texts.Health.tag == "")
    assert(projected.Units.player.width == defaults.profile.Units.player.width, "other defaults lost")
end)
Test("Spartanierin-like reduced composition across all units", function()
    local payload={Units={},TextTemplates={Shared="[name]"}}
    for unitKey in pairs(defaults.profile.Units) do
        payload.Units[unitKey]={Texts={Name={templateName="",tag="[name]"},text_1=Styled()}}
    end
    CheckProjection(payload)
end)
Test("Demo-like six objects; existing field inheritance preserved", function()
    local payload={Units={player={Texts={Name={tag="[name]"},text_1=Styled(),text_2=Styled(),text_3=Styled()}},
        target={Texts={Name={tag="[name]"},Health={templateName="",tag="[hp:cur]"}}}},TextTemplates={}}
    for unitKey in pairs(defaults.profile.Units) do
        payload.Units[unitKey]=payload.Units[unitKey] or {enabled=false,present=false,Texts={}}
    end
    local projected=CheckProjection(payload)
    assert(projected.Units.target.Texts.Health.stateTemplates.dead == "Dead Target")
end)
local function Source()
    local a=Styled()
    local payload={Units={player={Texts={text_1=a,text_2=Clone(a)}}},TextTemplates={Shared="[name]"}}
    ns.db={profile={},char={activeLayoutId="layout:original"},global={UserLayouts={
        ["layout:original"]={name="Original",formatVersion=1,payload=payload}}}}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    return payload
end
local function CheckPair(actual, source)
    assert(Equal(actual.Units.player.Texts,source.Units.player.Texts), "pair keys/values changed")
    for unitKey,unit in pairs(actual.Units) do
        if unitKey ~= "player" then SameKeys(unit.Texts,{}) end
    end
end
Test("CopyPayload preserves identical objects and source", function()
    local source=Source(); local before=Clone(source)
    local copy=service.CopyPayload(source); CheckPair(copy,source)
    assert(copy.Units.player.Texts.text_1 ~= source.Units.player.Texts.text_1)
    assert(Equal(source,before))
end)
Test("real export/import preserves identical objects and source", function()
    local source=Source(); local before=Clone(source)
    local encoded,reason=ns.LayoutTransfer.Export("layout:original"); assert(encoded,reason)
    local ok,id=ns.LayoutTransfer.Import(encoded); assert(ok,id)
    CheckPair(ns.db.global.UserLayouts[id].payload,source); assert(Equal(source,before))
end)
Test("full user-layout duplicate preserves identical objects and source", function()
    local source=Source(); local before=Clone(source)
    local ok,id=ns.LayoutMutations.CopyLayout("layout:original","Duplicate",{activate=false}); assert(ok,id)
    CheckPair(ns.db.global.UserLayouts[id].payload,source); assert(Equal(source,before))
end)
Test("builtin-to-user keeps the intended initial composition", function()
    Source()
    local original=assert(ns.ActiveLayoutResolver.ResolveLayout(ns.db,"builtin:default")).payload
    local before=Clone(original)
    local ok,id=ns.LayoutMutations.CopyLayout("builtin:default","Builtin Copy",{activate=false}); assert(ok,id)
    local copy=ns.db.global.UserLayouts[id].payload
    for unitKey,unit in pairs(original.Units) do
        assert(Equal(copy.Units[unitKey].Texts,unit.Texts), "builtin composition changed")
    end
    assert(Equal(original,before))
end)
local function Context(text)
    local unit={Texts={text_1=text,keep={enabled=true,tag="keep"}}}
    return {GetUnitConfig=function() return unit end,
        GetTemplates=function() return {Shared="[name]",Other="other"} end}, unit
end
for _,state in ipairs({false,true}) do
    for _,otherRefs in ipairs({false,true}) do
        Test((state and "state" or "main") .. " unassign, other references=" .. tostring(otherRefs), function()
            local text=Styled()
            if state then text.templateName=otherRefs and "Other" or ""; text.stateTemplates={dead="Shared"}
            elseif otherRefs then text.stateTemplates={dead="Other"} end
            if state and otherRefs then text.stateTemplates.offline="Other" end
            local context,unit=Context(text); local expected=Clone(unit.Texts)
            if state then
                expected.text_1.stateTemplates.dead=nil
                if not otherRefs then expected.text_1.stateTemplates=nil end
            else expected.text_1.templateName="" end
            local result=state and mutations.UnassignStateTemplate(context,"player","text_1","dead")
                or mutations.UnassignTemplate(context,"player","text_1")
            assert(result.ok and result.changed)
            assert(unit.Texts.text_1 == text, "unassign deleted object")
            assert(Equal(unit.Texts,expected), "unassign changed more than requested reference")
        end)
    end
end
Test("unassign empty fallback does not disable named object", function()
    local text=Styled(); text.tag=""
    local context,unit=Context(text); unit.Texts.Named=unit.Texts.text_1; unit.Texts.text_1=nil
    local expected=Clone(text); expected.templateName=""
    assert(mutations.UnassignTemplate(context,"player","Named").ok)
    assert(unit.Texts.Named == text and Equal(text,expected))
end)
Test("bulk unit unassign preserves objects and unrelated references", function()
    local text=Styled(); text.stateTemplates={dead="Shared",offline="Other"}
    local context,unit=Context(text); local expected=Clone(unit.Texts)
    expected.text_1.templateName=""; expected.text_1.stateTemplates.dead=""
    assert(mutations.ApplyTemplateToUnits(context,{selectedTemplateName="Shared",unitsToRemove={"player"}}).ok)
    assert(unit.Texts.text_1 == text and Equal(unit.Texts,expected))
    text.stateTemplates=nil
    text.templateName="Shared"
    assert(mutations.ApplyTemplateToUnits(context,{selectedTemplateName="Shared",unitsToRemove={"player"}}).ok)
    assert(unit.Texts.text_1 == text and text.enabled == true and text.tag == "[name]")
end)
Test("explicit Inspector delete removes only selected object", function()
    local text=Styled(); local _,unit=Context(text)
    unit.Texts.text_2=Clone(text); local other=unit.Texts.text_2; local expected=Clone(unit.Texts)
    expected.text_1=nil
    local result=ns.InspectorMutations.DeleteTextInstance({unitKey="player",getEditableUnitConfig=function() return unit end},"text_1")
    assert(result.ok and result.changed and result.oldValue == text)
    assert(Equal(unit.Texts,expected) and unit.Texts.text_2 == other)
end)
print(string.format("Text object identity: %d passed, %d failed",passed,failed))
assert(failed == 0, "text object identity regressions")
