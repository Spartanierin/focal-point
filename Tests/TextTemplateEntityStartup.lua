-- E6B: real OnInitialize/OnEnable, real AceDB and real E6A. No external SV.
local file=assert(io.open("Tests/TextTemplateEntityCutover.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find("Test('classifies",1,true))
local ns,Load,LegacyDB,Copy,Equal,Generator=assert(load(source:sub(1,stop-1).."\nreturn ns,Load,LegacyDB,Copy,Equal,Generator"))()
strmatch=string.match
function securecallfunction(fn,...)return fn(...)end
function GetRealmName()return "Test realm" end
function UnitName()return "Test player" end
function UnitClass()return "Mage","MAGE" end
function UnitRace()return "Human","Human" end
function UnitFactionGroup()return "Alliance" end
function GetLocale()return "enUS" end
function GetCurrentRegion()return 3 end
function InCombatLockdown()return false end
local frames={}
function CreateFrame()
    local f={events={},scripts={}}
    function f:RegisterEvent(e)self.events[e]=true end
    function f:UnregisterAllEvents()self.events={}end
    function f:SetScript(k,v)self.scripts[k]=v end
    frames[#frames+1]=f;return f
end
dofile("Libraries/LibStub/LibStub.lua")
dofile("Libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Libraries/Ace3/AceDB-3.0/AceDB-3.0.lua")
local locale=LibStub:NewLibrary("AceLocale-3.0",99);function locale:GetLocale()return {}end
local addon=LibStub:NewLibrary("AceAddon-3.0",99);function addon:NewAddon()return {}end
Load("FocalPoint.lua")
Load("Services/LegacyThemeAdapter.lua");Load("Services/PresetService.lua");Load("Services/ActiveLayoutResolver.lua")
Load("Services/LayoutAssignmentService.lua")
local calls={}
local function mark(key)calls[key]=(calls[key] or 0)+1 end
local function ready(key)assert(ns.entityStartupReady==true,key.." before cutover");mark(key)end
for _,name in ipairs({"Init","SetupSlashCommands","CreatePositionController","StartTagTicker","SpawnUnitFrame","ApplyGeneralSettings","InitMinimapIcon"}) do
    ns[name]=function()ready(name)end
end
ns.ProfileAutomation={Initialize=function()ready("automation")end}
local activate=ns.ActiveLayoutResolver.InitializeActiveLayoutId
ns.ActiveLayoutResolver.InitializeActiveLayoutId=function(...)ready("active-layout");return activate(...)end
ns.Error=function(_,message)mark("error");assert(message:find("startup blocked",1,true))end
local prepare=ns.TextTemplateEntityCutover.Prepare
ns.TextTemplateEntityCutover.Prepare=function(db,options)
    assert(ns.entityStartupReady==false and next(calls)==nil,"startup ran before Prepare")
    options.generator=Generator();return prepare(db,options)
end
local function Start(saved)
    FocalPointDB=saved;calls={};frames={};ns.entityStartupReady=nil
    ns.Ace:OnInitialize();ns.Ace:OnEnable()
    return ns.entityStartupDiagnostic
end
local result=Start(LegacyDB())
assert(result.ok and ns.entityStartupReady and calls.automation==1 and calls.StartTagTicker==1 and calls.SpawnUnitFrame==11)
assert(ns.db.global.TextTemplateEntityMigration.complete)
local before=Copy(ns.db.global);local roots=ns.db.global.UserLayouts
calls={};ns.Ace:OnInitialize();ns.Ace:OnEnable()
assert(ns.entityStartupDiagnostic.ok and not ns.entityStartupDiagnostic.changed)
assert(Equal(before,ns.db.global) and roots==ns.db.global.UserLayouts)
for _,name in ipairs({"OnProfileChanged","OnProfileCopied","OnProfileReset"})do
    local count=0;ns.RefreshProfileSettings=function()count=count+1;return true end
    ns.db.callbacks:Fire(name,ns.db);assert(count==1 and Equal(before,ns.db.global))
end
result=Start(nil);assert(result.ok and ns.entityStartupReady and calls.StartTagTicker==1)
result=Start({global={UserLayouts=false}})
assert(not result.ok and ns.entityStartupReady==false and calls.error==1)
assert(calls.Init==nil and calls.automation==nil and calls.SpawnUnitFrame==nil and calls.StartTagTicker==nil)
assert(rawget(ns.db.callbacks.events,"OnProfileChanged")==nil,"failed startup registered profile callbacks")
local count=#frames;ns.Ace:OnEnable();assert(#frames==count and calls.Init==nil)
-- Verify blocked direct entry points with their real bodies, before any rendering.
Load("Engine/Core.lua")
assert(select(2,ns:StartTagTicker())=="entity-startup-blocked")
Load("Engine/UnitFrame.lua")
assert(select(2,ns:ActivateLayout("builtin:default"))=="entity-startup-blocked")
assert(select(2,ns:SpawnUnitFrame("player"))=="entity-startup-blocked")
local gui=LibStub:NewLibrary("AceGUI-3.0",99)
Load("Data/Constants.lua")
Load("GUI/GUIMainController.lua")
assert(select(2,ns:OpenConfig())=="entity-startup-blocked")
assert(select(2,ns:CreateGUI())=="entity-startup-blocked")
assert(not ns.ProfileTransfer and not (ns.GUI.Pages and ns.GUI.Pages.Profiles))
local f=assert(io.open("Init.xml"));local init=f:read("*a");f:close()
assert(not init:find("ProfileTransfer",1,true) and not init:find("ProfilesController",1,true))
FocalPointDB=nil
print("PASS: real AceDB startup, E6A-first, legacy/fresh/reload, validate-only, profile callbacks, fail-closed runtime and GUI")
