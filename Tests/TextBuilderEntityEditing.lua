-- lua54 Tests/TextBuilderEntityEditing.lua
local file=assert(io.open("Tests/TextBuilderDraftSafety.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find('local a, b = Payload("A"), Payload("B")',1,true))
local f=assert(load(source:sub(1,stop-1).."\nreturn f","@R2/Fixture"))()
local ns=f.ns
f.Load("Engine/Text/Shared/TextElementRoles.lua")
f.Load("Engine/Text/Shared/TextTemplateResolver.lua")
f.Load("Engine/Text/Shared/TextTemplateValidation.lua")
f.Load("Data/BuiltInTextTemplates.lua")
f.Load("GUI/Pages/TextBuilder/TextBuilderEntity.lua")
local R2=assert(ns.GUI.Pages.TextBuilder.EntityBuilder)
local L=assert(ns.TextTemplateLibrary)
local A="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":1"
local B="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":2"
local long=string.rep("x",513).."\000\n  end"
local payload={Units={player={Texts={
    localText={tag=long,enabled=true},
    sharedText={templateId=A,enabled=true},
    mainText={templateId=B,enabled=true},
    disabledState={templateId=A,stateTemplateIds={dead=B},enabled=false},
}}}}
local db={char={activeLayoutId="layout:a"},global={TextTemplates={
    [A]={name="Same",content=long},[B]={name="Same",content="B"}},
    UserLayouts={["layout:a"]={payload=payload}}}}
ns.db=db
local generator=assert(L.CreateUserTemplateIdGenerator({time=function()return 10 end,uptime=function()return 1 end,random=function()return 3 end}))
R2.SetIdGenerator(generator)
local function ok(v,reason) assert(v,reason or "failed");return v end
local function open(kind,key)
    return ok(R2.Open({entity=true,kind="object",layoutId="layout:a",unitKey="player",textKey=key},db,"layout:a"))
end
local s=open("object","localText");assert(s.content==long and s.baseline.content==long)
ok(R2.Save(s)); local cap=R2.Capture(s); ok(R2.SetContent(s,long)); assert(not R2.Save(s).changed)
ok(R2.SetContent(s,long.."!")); local r=ok(R2.Save(s));assert(r.changed and payload.Units.player.Texts.localText.tag==long.."!")
assert(payload.Units.player.Texts.localText.templateId==nil)
s=open("object","sharedText");assert(s.content==long)
local before=db.global.TextTemplates[A].content
ok(R2.SetContent(s,"changed shared")); local captured=R2.Capture(s); local pending=ok(R2.Save(s));assert(pending.decisionRequired and db.global.TextTemplates[A].content==before)
s.pendingCapture=captured;ok(R2.Decide(s,"all",captured));assert(db.global.TextTemplates[A].content=="changed shared")
s=open("object","sharedText");ok(R2.SetContent(s,"forked"));captured=R2.Capture(s);s.pendingCapture=captured;r=ok(R2.Decide(s,"copy",captured));assert(r.forked and payload.Units.player.Texts.sharedText.templateId~=A)
local direct=ok(R2.Open({entity=true,kind="shared-template",layoutId="layout:a",templateId=B},db,"layout:a"))
assert(R2.Save(direct).changed==false);ok(R2.SetContent(direct,"direct"));r=ok(R2.Save(direct));assert(r.changed and db.global.TextTemplates[B].content=="direct")
local n=ok(R2.Open({entity=true,kind="new-template",layoutId="layout:a",returnContext={pickerMode="add"}},db,"layout:a"))
ok(R2.SetName(n,"Same"));ok(R2.SetContent(n,"new"));r=ok(R2.Save(n));assert(r.created and r.templateId and n.kind=="shared-template" and n.returnContext.pickerMode=="add")
local usage=R2.Usage(direct);assert(usage.main>=1 and usage.disabled>=1 and usage.state>=1)
local rename=ok(R2.Open({entity=true,kind="shared-template",layoutId="layout:a",templateId=r.templateId},db,"layout:a"))
ok(R2.SetName(rename,"Renamed"));ok(R2.Rename(rename));ok(R2.SetContent(rename,"content after rename"));assert(R2.Save(rename).changed)
local stale=R2.Capture(rename);ok(R2.SetContent(rename,"new draft"));assert(not R2.Valid(rename,stale))
assert(not R2.Delete(direct).ok)
print("PASS: R2 isolated entity builder editing")
