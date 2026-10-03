-- E6B: real text orchestrator/update, preview/demo and shipped layout contracts.
local file=assert(io.open("Tests/TextBuilderDraftSafety.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find('local a, b = Payload("A"), Payload("B")',1,true))
local f=assert(load(source:sub(1,stop-1).."\nreturn f"))()
local ns,Load=f.ns,f.Load
function UnitExists()return true end
function UnitIsDeadOrGhost()return false end
function UnitIsConnected()return true end
function UnitCanAttack()return true end
function UnitCanAssist()return false end
function InCombatLockdown()return false end
function issecretvalue()return false end
function strsplit(sep,s)local r={};for v in s:gmatch("[^"..sep.."]+")do r[#r+1]=v end;return table.unpack(r)end
ns.UnitFrameDemoEnvironment={}
for _,path in ipairs({
    "Engine/UnitFrame/Shared/UnitFramePresence.lua","Engine/UnitFrame/Shared/UnitFrameRange.lua",
    "Engine/UnitFrame/Shared/UnitFrameDemoEnvironment.lua","Engine/UnitFrame/Shared/UnitFrameUnitWatchPolicy.lua",
    "Engine/UnitFrame/Shared/UnitFramePreview.lua","Engine/UnitFrame/Shared/EditorVisualPolicy.lua",
    "Engine/Text/Shared/TextElementRoles.lua","Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextElementUtils.lua","Engine/Text/Shared/TextElementStatus.lua",
    "Engine/Text/Shared/TextElementColors.lua","Engine/Text/Shared/TextElementPower.lua",
    "Engine/Text/Shared/TextElementBasicTags.lua","Engine/Text/Shared/TextElementTokenResolver.lua",
    "Engine/Text/Shared/TextElementTemplates.lua","Engine/Text/Shared/TextElementPreview.lua",
    "Data/BuiltInTextTemplates.lua","Engine/Text/Shared/TextTemplateValidation.lua",
    "Engine/Text/Shared/TextElementDirectTemplate.lua","Engine/Text/Runtime/TextElementFactory.lua",
    "Engine/Text/Runtime/TextElementState.lua","Engine/Text/Runtime/TextElementUpdate.lua",
    "Engine/Text/Runtime/TextElementEvents.lua","Engine/Text/Runtime/TextElementApply.lua",
    "Engine/Text/Runtime/TextElementLiveValues.lua","Engine/TextElements.lua","Services/LayoutMutations.lua",
})do Load(path)end
local A="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":1"
local B=A:sub(1,-2).."2"
local configs={one={templateId=A,tag="fallback",stateTemplateIds={dead=B},enabled=true},
    two={templateId=A,enabled=true},localText={tag="local",enabled=true},builtin={templateId="tpl:b:classic-004",enabled=true}}
ns.db={profile={General={}},char={activeLayoutId="layout:test"},global={TextTemplates={
    [A]={name="Same",content="USER"},[B]={name="Same",content="DEAD"}},UserLayouts={
    ["layout:test"]={name="Test",formatVersion=2,payload={Units={player={enabled=true,Texts=configs}}}}}}}
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
local frame=CreateFrame("Frame");frame._fpUnit="player";frame.config={enabled=true,Texts=configs};frame.Texts={}
for key in pairs(configs)do frame.Texts[key]=frame:CreateFontString()end
local function Update(key)
    ns.UnitFrame:UpdateTextElement(frame,key)
    assert(not frame._focalPointTextErrors or not frame._focalPointTextErrors[key],frame._focalPointTextErrors and frame._focalPointTextErrors[key])
    return frame.Texts[key]:GetText()
end
assert(Update("one")=="USER");assert(Update("two")=="USER");assert(Update("localText")=="local")
local template=ns.TextElementTemplates
local function Resolve(config,status)return template.ResolveConfigured(frame,config,{db=ns.db,GetLiveValue=function()return status end})end
assert(Resolve(configs.one,"ghost")=="DEAD" and Resolve(configs.one,"dead")=="DEAD")
assert(ns.TextElementPreview.ResolveConfiguredTemplate(configs.one,"ghost")=="DEAD")
local result=ns.TextTemplateMutations.UpdateTemplate(ns.db,A,{name="Same",content="USER"},"SHARED")
assert(result.ok and Update("one")=="SHARED" and Update("two")=="SHARED")
assert(ns.TextElementPreview.BuildTextElementPreview(configs.two)=="SHARED")
assert(ns.TextElementStatus.ResolveEditorRenderableState(configs.one,{db=ns.db})=="active")
local missing={templateId="tpl:b:unknown",templateName="Same",tag="local fallback"}
assert(Resolve(missing,"")=="local fallback")
assert(ns.TextElementStatus.ResolveEditorRenderableState(missing,{db=ns.db})=="invalid")
-- Candidate caching never caches content; dependency refresh observes shared edits.
local deps={db=ns.db,GetBasicTagDependencies=function(t)return t=="hp:cur" and "health" or t=="power:cur" and "power" end}
ns.db.global.TextTemplates[A].content="[hp:cur]"
assert(template.ResolveDependencies(frame,configs.one,deps).health)
ns.db.global.TextTemplates[A].content="[power:cur]"
local d=template.ResolveDependencies(frame,configs.one,deps);assert(d.power and not d.health)
ns.db.global.TextTemplates[A].content="SHARED"
local demo=ns.UnitFrameDemoEnvironment
local now=100
GetTime=function()return now end
local function LeaveDemo()
    ns.guiTestModeEnabled=false;ns.framesUnlocked=false
    demo.ApplyFrameSnapshot(nil,frame,{},"live","test")
    now=now+0.25
    demo.ApplyFrameSnapshot(nil,frame,{},"live","test")
    assert(not demo.IsFrameInDemoMode(frame) and frame.TestValues==nil)
end
for i=1,30 do
    ns.guiTestModeEnabled=true
    demo.ApplyFrameSnapshot(nil,frame,{},"detailed","test");assert(demo.IsDetailed(frame))
    assert(ns.TextElementPreview.ResolveConfiguredTemplate(configs.one)=="SHARED")
    assert(Update("one")=="SHARED")
    LeaveDemo();assert(Update("one")=="SHARED")
end
-- Placeholder visibility, range/alpha and protected UnitWatch policy stay orthogonal to IDs.
ns.framesUnlocked=true;demo.ApplyFrameSnapshot(nil,frame,{},"placeholder","test")
assert(demo.IsPlaceholder(frame));Update("one");assert(not frame.Texts.one:IsShown())
LeaveDemo();assert(Update("one")=="SHARED")
Load("Engine/UnitFrame/Runtime/UnitFrameState.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameVisibility.lua")
frame._fpUnit="target";frame.config.alpha=0.8
ns.RangeCheck={GetRange=function()return 50,60 end}
local range=ns.UnitFrameRange.GetFadeMultiplier(frame);assert(range==0.5)
local alpha=ns.UnitFrameVisibility.ResolveRootAlphaDecision(frame,{rangeMultiplier=range,source="composed"})
assert(alpha.finalAlpha==0.4)
local values=ns.LayoutService.Clone(configs)
frame._rangeCurrentAlpha=1;frame._rangeTargetAlpha=0.4;frame:Show()
local driver=ns.UnitFrameRange.EnsureFadeDriver(frame);driver:Show();driver:Run("OnUpdate",1)
assert(frame:GetAlpha()==0.4);f.Equal(configs,values)
function RegisterUnitWatch()end
function UnregisterUnitWatch()end
frame._fpUnit="focus"
local watch=ns.UnitFrameUnitWatchPolicy
assert(watch.ResolveSync(frame,{previewActive=false,inCombat=false,protectedRoot=true,isRegistered=false}).action=="register")
assert(watch.ResolveSync(frame,{previewActive=false,inCombat=true,protectedRoot=true,isRegistered=false}).action=="blocked")
frame._unitWatchRegistered=true
assert(watch.ResolveSync(frame,{previewActive=true,previewOutsideCombat=true,inCombat=false,protectedRoot=true}).action=="unregister")
f.Equal(configs,values);frame._fpUnit="player"
local function NoLegacy(payload)
    assert(payload.TextTemplates==nil)
    for _,unit in pairs(payload.Units)do for _,text in pairs(unit.Texts or {})do
        assert(text.templateName==nil and text.stateTemplates==nil)
        for _,id in pairs(text.stateTemplateIds or {})do assert(type(id)=="string")end
    end end
end
for _,preset in ipairs({"default","classic","minimal","modern"})do
    local record=assert(ns.ActiveLayoutResolver.ResolveLayout(ns.db,"builtin:"..preset))
    NoLegacy(record.payload)
    assert(ns.TextTemplateValidation.ValidateEntityLayouts({[preset]=record},ns.db).valid)
end
local source=ns.db.global.UserLayouts["layout:test"].payload
local projected=ns.LayoutService.ProjectUserLayout("layout:test",{name="Test",formatVersion=2,payload=source}).payload
assert(projected.Units.player.Texts.localText.templateId==nil and projected.Units.player.Texts.localText.stateTemplateIds==nil)
NoLegacy(projected)
ns.RebuildFramesForActiveProfile=function()end
ns.GUI.RequestRefreshOptions=function()end
local ok,id=ns:CreateBlankLayout("Starter",{activateOptions={silent=true}});assert(ok,id)
local starter=ns.db.global.UserLayouts[id];NoLegacy(starter.payload)
for _,unit in pairs(starter.payload.Units)do for _,text in pairs(unit.Texts or {})do assert(text.templateId==nil and text.stateTemplateIds==nil)end end
print("PASS: actual text runtime, shared live content/dependencies, state fallback, preview/demo cycles, four built-ins, missing FKs and local New layout")
