-- lua54 Tests/CastBarInterruptibleColor.lua
-- Real PR bindings, mutation, renderer, legacy materialization and transfer.
local function Read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local ns,MakeFrame,Options,SelectCastBar=assert(load(Read('Tests/CastBarSelectionPreview.lua')..
    '\nreturn ns,MakeFrame,Options,SelectCastBar','@Tests/CastBarSelectionPreview.lua'))()
local function Load(path)assert(loadfile(path))('FocalPoint',ns)end
for _,path in ipairs({'Data/Defaults.lua','Services/CompositionPresenceStorage.lua','Services/LayoutService.lua','Services/LayoutMutations.lua',
    'Engine/UnitFrame/Shared/UnitFrameUtils.lua','Engine/UnitFrame/Bars/UnitFrameCastBar.lua',
    'GUI/Helpers/OptionPaths.lua','GUI/Helpers/OptionValues.lua','GUI/Editor/Inspector/InspectorMutations.lua',
    'Engine/Text/Shared/TextTemplateLibrary.lua','Data/BuiltInTextTemplates.lua',
    'Engine/Text/Shared/TextTemplateUsage.lua','Engine/Text/Shared/TextTemplateValidation.lua',
    'Services/TextTemplateEntityMigration.lua','Services/LayoutTransferCodec.lua','Services/LayoutTransfer.lua',
    'Services/LayoutTransferVNext.lua'})do Load(path)end
local Copy=ns.LayoutService.Clone
local function Equal(a,b)
    if type(a)~='table' or type(b)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do Equal(v,b[k])end
    for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local source=Read('GUI/Editor/Inspector/InspectorController.lua')
local a=assert(source:find('        local defaultCastBarInterruptibleColor =',1,true))
local b=assert(source:find('        if actionsSection then',a,true))
local block=source:sub(a,b-1)
local function Picker(unit,config,scoped)
    local row
    local function Add(_,label,color,alpha,callback,disabled)row={label=label,color=color,alpha=alpha,callback=callback,disabled=disabled}end
    local env={OptionValues=ns.GUI.Helpers.OptionValues,state={selectedUnit=unit},unitConfig=config,
        usePropertyGroups=scoped,appearanceSection={},L={},AddPropertyColorRow=Add,AddColorPicker=Add,
        SetUnitField=function(key,value)
            assert(key=='castBarInterruptibleColor')
            assert(ns.InspectorMutations.SetUnitField({unitConfig=config},key,value).ok)
            assert(ns.InspectorRefreshPolicy.Resolve('unit',key).scope=='live')
        end}
    assert(load(block,'@Inspector.InterruptibleColor','t',env))();assert(row and row.alpha);return row
end
local function Runtime(config)
    local frame=MakeFrame(config);local cast=frame.Elements.CastBar
    ns.UnitFrameCastBar.ApplyStateColor(cast,'INTERRUPTIBLE',config.castBarColor,
        config.castBarInterruptibleColor or config.castBarUninterruptibleColor)
    return {cast.statusColor[1],cast.statusColor[2],cast.statusColor[3],cast.alpha},frame
end
ns.db=setmetatable({}, {__index=function()error('default lookup must not read AceDB')end})
local cases=0
for _,unit in ipairs({'player','target','focustarget'})do
    for _,scoped in ipairs({false,true})do
        for _,config in ipairs({{}, {castBarUninterruptibleColor={.2,.3,.4,0}},
            {castBarInterruptibleColor={.1,.2,.3,.5},castBarUninterruptibleColor={.9,.8,.7,1}},
            {castBarInterruptibleColor={r=.3,g=.4,b=.5,a=0}}, {showCastBar=false}})do
            local before=Copy(config);local row=Picker(unit,config,scoped);Equal(config,before)
            Equal({ns.UnitFrameUtils.UnpackColor(row.color)},Runtime(config))
            assert(row.disabled==(config.showCastBar==false))
            local chosen={r=.7,g=.4,b=.2,a=0};row.callback(chosen)
            Equal(Picker(unit,Copy(config),scoped).color,chosen)
            local rgba,frame=Runtime(config);Equal(rgba,{.7,.4,.2,0})
            frame._fpUnit='target';SelectCastBar();ns.framesUnlocked=true;ns.guiTestModeEnabled=false
            assert(ns.UnitFrameCastBar.ApplyTextEditPreview(frame))
            Equal({frame.Elements.CastBar.statusColor[1],frame.Elements.CastBar.statusColor[2],frame.Elements.CastBar.statusColor[3],frame.Elements.CastBar.alpha},rgba)
            ns.UnitFrameCastBar.ApplyStateColor(frame.Elements.CastBar,'UNINTERRUPTIBLE',{.8,.6,.1,.9},chosen)
            Equal(frame.Elements.CastBar.statusColor,{.8,.6,.1,1});assert(frame.Elements.CastBar.alpha==.9)
            cases=cases+1
        end
    end
end
print('PASS: '..cases..' Inspector/runtime cases; default/alias/explicit/alpha-zero, both bindings, disabled, preview, reopen')
local defaults=ns:GetDefaultDB().profile.Units.player
local color={.3,.4,.5,0}
for _,case in ipairs({{source={},present=false},
    {source={castBarInterruptibleColor=color},present=true},
    {source={castBarInterruptibleColor=color,castBarPresent=false},present=false},
    {source={castBarInterruptibleColor=color,showCastBar=false},present=true},
    {source={showCastBar=true},present=true},
    {source={castBarColor=color},present=true}})do
    local original=Copy(case.source)
    local result=ns.LayoutService.MaterializeLegacyUnit(defaults,case.source)
    assert(result.castBarPresent==case.present,'legacy presence mismatch')
    if case.source.showCastBar==false then assert(result.showCastBar==false)end
    Equal(case.source,original)
end
local explicitAbsent={castBarPresent=false,castBarInterruptibleColor=color,Texts={}}
assert(ns.LayoutService.MaterializeUnit(defaults,explicitAbsent).castBarPresent==false)
print('PASS: source-only Legacy evidence, explicit absence, disabled presence and Format-2 absence')
C_AddOns={GetAddOnMetadata=function()return 'test' end}
local record={name='PR8',formatVersion=2,payload={Units={player={Texts={},castBarInterruptibleColor=color,castBarColor={.8,.6,.1,.9}}}}}
local db={global={TextTemplates={},UserLayouts={}}}
ns.db=db
local copied=ns.LayoutService.CopyPayload(record.payload)
Equal(copied.Units.player.castBarInterruptibleColor,color)
local encoded=assert(ns.LayoutTransferVNext.Export(record,db))
local result=ns.LayoutTransferVNext.PrepareImport(encoded,db)
assert(result.ready);Equal(result.preparedLayout.payload,record.payload)
local init=Read('Init.xml');assert(init:find('GUI/Helpers/OptionValues.lua',1,true)<init:find('GUI/Editor/Inspector/InspectorController.lua',1,true))
print('PASS: Copy/transfer RGBA retention, no other cast-state color change, OptionValues load order')
