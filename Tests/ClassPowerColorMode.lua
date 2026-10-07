-- lua54 Tests/ClassPowerColorMode.lua
-- Real bindings, mutations, color renderer and transfer; native rendering needs ingame smoke.
local function Read(path)
    local file=assert(io.open(path));local source=file:read("*a");file:close();return source
end
local ns,f,Paint,Equal=assert(load(Read("Tests/ResourceCorrectness.lua")..
    "\nreturn ns,f,Paint,Equal", "@Tests/ResourceCorrectness.lua"))()
local Load,Copy=f.Load,ns.LayoutService.Clone
Load("Engine/UnitFrame/Shared/UnitFrameColors.lua")
Load("GUI/Editor/Inspector/InspectorRefreshPolicy.lua")
local count=0
local function Test(name,fn) fn();count=count+1;print("PASS: "..name)end
Test("automatic nil/true, fixed false, token priority and alpha across resources",function()
    PowerBarColor={}
    for token,id in pairs({COMBO_POINTS=4,CHI=12,HOLY_POWER=9,ARCANE_CHARGES=16,SOUL_SHARDS=7,ESSENCE=19,RUNES=5})do
        PowerBarColor[token]={r=.9,g=.7,b=.2};PowerBarColor[id]={r=.1,g=.8,b=.9}
        for _,alpha in ipairs({0,.6,1})do
            Equal(Paint(token,id,nil,alpha),{.9,.7,.2,alpha})
            Equal(Paint(token,id,true,alpha),{.9,.7,.2,alpha})
            Equal(Paint(token,id,false,alpha),{.2,.3,.4,alpha})
        end
    end
end)
Test("configured RGBA preserves named authority, numeric forms, zero and defensive fallback",function()
    local unpack=ns.UnitFrameColors.UnpackConfiguredColor
    for _,alpha in ipairs({0,.6,1})do
        for _,color in ipairs({{0,.3,.4,alpha},{r=0,g=.3,b=.4,a=alpha},
            {[1]=1,[2]=1,[3]=1,[4]=1,r=0,g=.3,b=.4,a=alpha}})do
            Equal({unpack(color,{.5,.5,.5,1})},{0,.3,.4,alpha})
        end
    end
    Equal({unpack({r="bad",g=.3,b=.4,a="bad"},{.2,.5,.6,.7})},{.2,.3,.4,.7})
    Equal({unpack(nil,{.2,.3,.4,0})},{.2,.3,.4,0})
end)
Test("live, detailed demo and selection preview honor custom; placeholder stays neutral",function()
    local demo=ns.UnitFrameDemoEnvironment
    local _,frame=Paint("COMBO_POINTS",4,false)
    local apply=ns.UnitFrameClassPower.ApplyLayout
    local options={classPowerBarVisible=true,liveClassPowerMax=1,liveClassPowerCurrent=1,
        liveClassPowerToken="COMBO_POINTS",liveClassPowerType=4,useBlizzardColorClassPower=false,
        classPowerR=.2,classPowerG=.3,classPowerB=.4,classPowerA=.6}
    for _,mode in ipairs({"live","detailed","placeholder"})do
        demo.ApplyFrameSnapshot(nil,frame,{},mode,"color-test")
        apply(frame,options)
        local expected={.2,.3,.4,.6}
        if mode=="placeholder" then
            assert(demo.IsPlaceholder(frame));local c=demo.GetPlaceholderColors();expected={c.barR,c.barG,c.barB,c.barA}
        else assert(not demo.IsPlaceholder(frame)) end
        Equal(frame.Elements.ClassPowerBar.Bars[1].lastSetStatusBarColor,expected)
    end
    local preview=ns.UnitFrameClassPower.ShouldForcePreview
    ns.UnitFrameClassPower.ShouldForcePreview=function()return true end
    local info=assert(ns.UnitFrameClassPower.GetInfo("player"))
    Equal(Paint(info.token,info.typeId,false),{.2,.3,.4,.6})
    ns.UnitFrameClassPower.ShouldForcePreview=preview
end)
Test("both Inspector bindings retain color, toggle picker, preserve alpha and refresh only section",function()
    local source=Read("GUI/Editor/Inspector/InspectorController.lua")
    local marker=assert(source:find('            AddPropertyColorRow(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig.classPowerColor',1,true))
    local a=marker-#'        if usePropertyGroups then\n'
    local b=assert(source:find('        if usePropertyGroups then\n            AddPropertyColorRow(backgroundSection',marker,true))
    local block=source:sub(a,b-1)
    for _,scoped in ipairs({false,true})do
        local config={showClassPowerBar=true,classPowerColor={r=.2,g=.3,b=.4,a=0}}
        local original=config.classPowerColor;local section={};local picker,checkbox
        local function Color(_,_,value,alpha,callback,disabled)
            picker={value=value,alpha=alpha,callback=callback,disabled=disabled}
        end
        local function Check(_,_,value,callback,disabled)
            checkbox={value=value,callback=callback,disabled=disabled}
        end
        local env={usePropertyGroups=scoped,unitConfig=config,appearanceSection=section,rootSection=section,L={},
            AddPropertyColorRow=Color,AddColorPicker=Color,AddPropertyCheckBoxRow=Check,AddCheckBox=Check,
            SetUnitField=function(key,value,target)
                local result=ns.InspectorMutations.SetUnitField({unitConfig=config},key,value)
                assert(result.ok)
                local policy=ns.InspectorRefreshPolicy.Resolve("unit",key)
                if key=="useBlizzardColorClassPower" then
                    assert(target==section and policy.scope=="section" and policy.sectionKey=="class_power")
                else assert(key=="classPowerColor" and policy.scope=="live")end
            end}
        local build=assert(load(block,"@Inspector.ClassPowerColor","t",env))
        build();assert(checkbox.value and not checkbox.disabled and picker.disabled and picker.alpha)
        for _,mode in ipairs({false,true,false})do
            checkbox.callback(mode);build()
            assert(config.useBlizzardColorClassPower==mode and checkbox.value==mode and picker.disabled==mode)
            assert(config.classPowerColor==original);Equal(original,{r=.2,g=.3,b=.4,a=0})
        end
        local chosen={r=.7,g=.2,b=.1,a=.5};picker.callback(chosen);build();assert(picker.value==chosen)
        config.showClassPowerBar=false;build();assert(checkbox.disabled and picker.disabled)
    end
end)
Test("old layout, defaults, Built-ins, create, copy and transfer retain exact mode",function()
    Load("Services/LayoutTransferCodec.lua");Load("Services/LayoutTransfer.lua");Load("Services/LayoutTransferVNext.lua")
    local defaults=ns:GetDefaultDB()
    assert(defaults.profile.Units.player.useBlizzardColorClassPower==true)
    for _,key in ipairs({"default","classic","minimal","modern"})do
        local preset=assert(ns.PresetService.GetPreset(key))
        assert(preset.layout.Units.player.useBlizzardColorClassPower==true)
    end
    local build=assert(f.Upvalue(ns.CreateBlankLayout,"BuildNewLayoutPayload"))
    assert(build(ns).Units.player.useBlizzardColorClassPower==true)
    for _,case in ipairs({{}, {mode=true}, {mode=false}})do
        local unit={Texts={},classPowerColor={r=.2,g=.3,b=.4,a=0},useBlizzardColorClassPower=case.mode}
        local record={name="Color mode",formatVersion=2,payload={Units={player=unit}}}
        ns.db={profile={General={}},char={activeLayoutId="layout:color"},global={TextTemplates={},UserLayouts={["layout:color"]=record}}}
        local before=Copy(record)
        local ok,id=ns.LayoutMutations.CopyLayout("layout:color","Color copy")
        assert(ok,id);local copied=ns.db.global.UserLayouts[id].payload.Units.player
        -- Copy materializes normal defaults; the original sparse record stays untouched.
        assert(copied.useBlizzardColorClassPower==(case.mode~=false))
        Equal({ns.UnitFrameColors.UnpackConfiguredColor(copied.classPowerColor)},{.2,.3,.4,0})
        local text=assert(ns.LayoutTransferVNext.Export(record,ns.db))
        local result=ns.LayoutTransferVNext.PrepareImport(text,{global={TextTemplates={},UserLayouts={}}})
        assert(result.ready);Equal(result.preparedLayout.payload,record.payload);Equal(record,before)
    end
end)
Test("actual UnitFrame ApplyConfig forwards mode and configured RGBA without mutation",function()
    local source=Read("Tests/UnitFrameGeometry.lua")
    local boundary=assert(source:find("local fixtures={",1,true))
    local runtime,Applied=assert(load(source:sub(1,boundary-1).."\nreturn ns,Applied","@Color/GeometryFixture"))()
    -- Capture only the ClassPower apply boundary; execute the full ApplyConfig.
    local captured
    for i=1,100 do
        local name=debug.getupvalue(runtime.UnitFrame.ApplyConfig,i)
        if not name then break end
        if name=="ApplyClassPowerLayout" then
            debug.setupvalue(runtime.UnitFrame.ApplyConfig,i,function(_,options)captured=options end);break
        end
    end
    for _,case in ipairs({{}, {mode=true}, {mode=false}})do
        local config={useBlizzardColorClassPower=case.mode,classPowerColor={r=.2,g=.3,b=.4,a=0,[1]=1,[4]=1}}
        Applied(runtime,config,"player",false)
        assert(captured and captured.useBlizzardColorClassPower==case.mode)
        Equal({captured.classPowerR,captured.classPowerG,captured.classPowerB,captured.classPowerA},{.2,.3,.4,0})
    end
end)
print("Class Power Color Mode: "..count.." groups PASS")
