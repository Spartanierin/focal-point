-- lua54 Tests/ResourceCorrectness.lua
-- Actual mutations, text renderer, build orchestration and color application.
-- Only native widgets/API inputs and unrelated bar build steps are simulated.
local file = assert(io.open("Tests/TextTemplateEntityRuntime.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find('local A="tpl:u:', 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. "\nreturn f", "@Resource/Fixture"))()
local ns, Load = f.ns, f.Load
Load("GUI/Editor/Inspector/InspectorMutations.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameBuild.lua")
Load("Engine/UnitFrame.lua")
local Copy = ns.LayoutService.Clone
local function Equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then assert(a == b, tostring(a).." ~= "..tostring(b)); return end
    for k, v in pairs(a) do Equal(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected key "..tostring(k)) end
end
local function Count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function Test(name, fn) fn(); print("PASS: "..name) end
local id = "tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":1"
local function Fixture()
    local texts = Copy(ns:GetDefaultDB().profile.Units.player.Texts)
    local unit = {enabled=true,showAlternativePowerBar=true,showClassPowerBar=true,
        alternativePowerBarPresent=true,classPowerBarPresent=true,
        Texts={AltPower=texts.AltPower,ClassPower=texts.ClassPower,keep={enabled=true,tag="KEEP"}}}
    ns.db={profile={General={}},char={activeLayoutId="layout:a"},global={TextTemplates={
        [id]={name="Resource test",content="CUSTOM [classpower:cur] + [altpower:cur]"}},UserLayouts={
        ["layout:a"]={name="A",formatVersion=2,payload={Units={player=unit}}},
        ["layout:b"]={name="B",formatVersion=2,payload={Units={player=Copy(unit)}}}}}}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    assert(ns.ActiveLayoutResolver.ResolveRuntimeRoot(ns.db,"layout:b"))
    local frame=CreateFrame("Frame");frame._fpUnit="player";frame.config=unit;frame.Texts={};frame.Tags={}
    for key in pairs(unit.Texts) do frame.Texts[key]=frame:CreateFontString() end
    frame.LiveValues={altPowerVisible=true,altPowerType=0,altPowerMaxRaw=100,altPowerMaxSafe=100,
        altPowerCurrentText="72",altPowerMaxText="100",classPowerVisible=true,classPowerMaxSafe=5,
        classPowerCurrentText="3",classPowerMaxText="5"}
    return unit,frame,{db=ns.db,expectedLayoutId="layout:a"}
end
local function Update(frame,key)
    ns.UnitFrame:UpdateTextElement(frame,key)
    assert(not frame._focalPointTextErrors or not frame._focalPointTextErrors[key],
        frame._focalPointTextErrors and frame._focalPointTextErrors[key])
    return frame.Texts[key]:GetText()
end
for _,key in ipairs({"AltPower","ClassPower"}) do
    Test(key..": default, changed entity, tags, dependencies, preview and stale context",function()
        local unit,frame,ctx=Fixture()
        assert(Update(frame,key)==(key=="AltPower" and "72 / 100" or "3 / 5"))
        local text=unit.Texts[key]; local object=frame.Texts[key]; local count=Count(unit.Texts)
        local original=Copy(text)
        assert(ns.TextTemplateMutations.AssignMainTemplate(ctx,"player",key,id).ok)
        original.templateId=id;original.tag=""
        Equal(text,original)
        assert(unit.Texts[key]==text and Count(unit.Texts)==count)
        -- The picker calls RefreshUnitFrame, whose ApplyConfig reapplies text bindings.
        local applyBinding=f.Upvalue(ns.UnitFrame.ApplyTextElementConfig,"MaterializeTextRuntimeBinding")
        applyBinding(frame,key,text)
        assert(Update(frame,key)=="CUSTOM 3 + 72" and frame.Texts[key]==object)
        ns.UnitFrame:UpdateTextElements(frame)
        local dependencies=ns.TextElementState.GetDependencies(frame,key)
        assert(dependencies.altpower and dependencies.classpower)
        frame.LiveValues.classPowerCurrentText="4"
        ns.UnitFrame:UpdateTextElements(frame,{classpower=true})
        assert(object:GetText()=="CUSTOM 4 + 72")
        assert(ns.TextElementPreview.BuildTextElementPreview(text)=="CUSTOM 4 + 72")
        -- Actual selection-preview branch must consume the configured expression.
        local selected=ns.EditorVisualPolicy.IsSelectionPreview
        ns.EditorVisualPolicy.IsSelectionPreview=function(_,ref)return ref.kind=="text" and ref.textKey==key end
        assert(Update(frame,key)=="CUSTOM 4 + 72")
        ns.EditorVisualPolicy.IsSelectionPreview=selected
        -- Detailed demo/placeholder retain the existing lifecycle policy.
        local demo=ns.UnitFrameDemoEnvironment
        local now=100;GetTime=function()return now end
        ns.guiTestModeEnabled=true
        demo.ApplyFrameSnapshot(nil,frame,{},"detailed","test")
        assert(Update(frame,key):find("CUSTOM",1,true)==1)
        ns.guiTestModeEnabled=false;ns.framesUnlocked=true
        demo.ApplyFrameSnapshot(nil,frame,{},"placeholder","test")
        Update(frame,key);assert(not object:IsShown())
        ns.framesUnlocked=false
        demo.ApplyFrameSnapshot(nil,frame,{},"live","test");now=now+1
        demo.ApplyFrameSnapshot(nil,frame,{},"live","test")
        -- Main-template update does not weaken captured object/layout identity.
        local context=ns.GUI.Pages.TextBuilder.EntityContext
        local request={kind="object",layoutId="layout:a",unitKey="player",textKey=key}
        local snapshot=assert(context.Snapshot(request,ns.db,"layout:a"))
        unit.Texts[key]=Copy(text)
        assert(not context.SameSession(snapshot,assert(context.Snapshot(request,ns.db,"layout:a"))))
        unit.Texts[key]=text
        ns.db.char.activeLayoutId="layout:b"
        local before=Copy(ns.db.global)
        local rejected=ns.TextTemplateMutations.AssignMainTemplate(ctx,"player",key,original.templateId)
        assert(not rejected.ok and rejected.errorCode=="layout_mismatch");Equal(ns.db.global,before)
    end)
    Test(key..": unavailable resource and disabled text stay hidden",function()
        local unit,frame,ctx=Fixture()
        assert(ns.TextTemplateMutations.AssignMainTemplate(ctx,"player",key,id).ok)
        assert(Update(frame,key):find("CUSTOM",1,true)==1)
        frame.LiveValues={}
        assert(Update(frame,key)=="" and not frame.Texts[key]:IsShown())
        unit.Texts[key].enabled=false
        ns.TextElementState.Reset(frame)
        assert(Update(frame,key)=="" and not frame.Texts[key]:IsShown())
    end)
end

-- Run the real Build entry and CreateElements/CreateAll path. Native bar creation,
-- event registration and config application are unrelated to text existence.
local owner=setmetatable({}, {__index=function()return function()end end})
function owner:CreateBaseFrame(unit,config)
    local frame=CreateFrame("Frame");frame._fpUnit=unit;frame.config=config;frame.Texts={};frame.Tags={}
    return frame
end
function owner:CreateTextElements(frame)
    ns.TextElementFactory.CreateAll(frame,{CreateElement=function(fr,key,config)
        ns.TextElementFactory.CreateElement(fr,key,config,{GetTextLayerParent=function()return fr end})
    end})
end
local function Build() return ns.UnitFrame.Build(owner,"player") end
Test("deleted resource texts stay absent across build, layout reentry and saved-state reload",function()
    local unit=Fixture()
    local defaults=ns:GetDefaultDB().profile.Units.player.Texts
    assert(defaults.AltPower and defaults.ClassPower)
    local initial=Build();assert(initial.Texts.AltPower and initial.Texts.ClassPower)
    local context={unitKey="player",getEditableUnitConfig=function()return unit end}
    for _,key in ipairs({"AltPower","ClassPower"}) do
        assert(ns.InspectorMutations.DeleteTextInstance(context,key).ok)
    end
    local before=Copy(ns.db.global)
    for i=1,3 do
        local built=Build();assert(not built.Texts.AltPower and not built.Texts.ClassPower and built.Texts.keep)
        Equal(ns.db.global,before)
        for _=1,10 do assert(ns.UnitFrameUtils.GetUnitDB("player")==unit) end
        Equal(ns.db.global,before)
        ns.db.char.activeLayoutId="layout:b";assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
        assert(Build().Texts.AltPower)
        ns.db.char.activeLayoutId="layout:a";assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
        Equal(ns.db.global,before)
        -- Independent saved-state copy plus invalidated runtime root models reload.
        ns.db=Copy(ns.db);ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
        assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
        unit=ns.UnitFrameUtils.GetUnitDB("player")
    end
    for _,templateId in ipairs({defaults.AltPower.templateId,defaults.ClassPower.templateId}) do
        local result=ns.TextTemplateMutations.CreateTextFromTemplate({db=ns.db,expectedLayoutId="layout:a"},"player",templateId)
        assert(result.ok,result.errorCode)
        assert(Build().Texts[result.textKey] and unit.Texts[result.textKey].templateId==templateId)
    end
    assert(not unit.Texts.AltPower and not unit.Texts.ClassPower and Count(unit.Texts)==3)
end)

Load("Engine/UnitFrame/Bars/UnitFrameClassPower.lua")
local classPower=ns.UnitFrameClassPower
local function Paint(token,typeId,mode,alpha)
    local frame=CreateFrame("Frame");frame._fpUnit="player"
    local holder=CreateFrame("Frame",nil,frame);holder.Bars={CreateFrame("StatusBar",nil,holder)}
    frame.Elements={ClassPowerBar=holder}
    classPower.ApplyLayout(frame,{classPowerBarVisible=true,liveClassPowerCurrent=1,liveClassPowerMax=1,
        useBlizzardColorClassPower=mode,liveClassPowerToken=token,liveClassPowerType=typeId,
        classPowerR=.2,classPowerG=.3,classPowerB=.4,classPowerA=alpha or .6})
    return holder.Bars[1].lastSetStatusBarColor,frame
end
Test("named resource colors win over numeric aliases; alpha and fallbacks remain",function()
    local tokens={COMBO_POINTS=4,CHI=12,HOLY_POWER=9,ARCANE_CHARGES=16,SOUL_SHARDS=7,ESSENCE=19,MAELSTROM=11}
    PowerBarColor={}
    for token,typeId in pairs(tokens) do
        PowerBarColor[token]={r=.9,g=.7,b=.2};PowerBarColor[typeId]={r=.1,g=.8,b=.9}
        Equal(Paint(token,typeId),{.9,.7,.2,.6})
    end
    PowerBarColor.CHI={r=.71,g=1,b=.92};PowerBarColor[4]=PowerBarColor.CHI
    PowerBarColor.COMBO_POINTS={r=1,g=.96,b=.41}
    Equal(Paint("COMBO_POINTS",4),{1,.96,.41,.6})
    Equal(Paint("CHI",12),{.71,1,.92,.6})
    PowerBarColor.SOUL_FRAGMENTS={r=.3,g=.2,b=.7}
    Equal(Paint("SOUL_FRAGMENTS",nil),{.3,.2,.7,.6})
    PowerBarColor.UNKNOWN=nil;PowerBarColor[99]={.4,.5,.6}
    Equal(Paint("UNKNOWN",99),{.4,.5,.6,.6})
    ns.oUF={colors={power={UNKNOWN={.6,.4,.2}}}}
    Equal(Paint("UNKNOWN",98),{.6,.4,.2,.6})
    ns.oUF=nil
    Equal(Paint("UNKNOWN",98),{.2,.3,.4,.6})
    -- In automatic mode, configured RGB remains a fallback; alpha is not replaced.
    -- Both live and simulated GetInfo yield the same canonical color token.
    UnitClass=function()return "Rogue","ROGUE" end
    UnitPower=function()return 3 end;UnitPowerMax=function()return 5 end
    local info=classPower.GetInfo("player");assert(info.token=="COMBO_POINTS")
    Equal(Paint(info.token,info.typeId),{1,.96,.41,.6})
    local preview=classPower.ShouldForcePreview
    classPower.ShouldForcePreview=function()return true end;UnitPowerMax=function()return 0 end
    info=classPower.GetInfo("player");assert(info.token=="COMBO_POINTS")
    Equal(Paint(info.token,info.typeId),{1,.96,.41,.6})
    classPower.ShouldForcePreview=preview
    local demo=ns.UnitFrameDemoEnvironment
    local placeholder=demo.IsPlaceholder;demo.IsPlaceholder=function()return true end
    local colors=demo.GetPlaceholderColors()
    Equal(Paint("COMBO_POINTS",4),{colors.barR,colors.barG,colors.barB,colors.barA})
    demo.IsPlaceholder=placeholder
end)
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("Resource Correctness Block A: PASS")
