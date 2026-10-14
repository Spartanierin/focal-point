-- Detached stores and native API doubles: no native pixel or protected-call proof.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local src=Read("Tests/BarBorderContract.lua")
local ns,S,T,N,C,Records,Layout,Target,Generator,Copy,Equal,I=assert(load(src:sub(1,assert(src:find('Test("optional defaults',1,true))-1)..
    "\nreturn ns,S,T,N,C,Records,Layout,Target,Generator,Copy,Equal,I"))()
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("optional root width uses shared validation, Copy and SetUnitField without defaults/presence",function()
    local unit={Texts={},borderColor={.2,.3,.4,0},healthBarBorderWidth=5}
    local before=Copy(unit);assert(S.CopyPayload({Units={player=unit}}).Units.player.frameBorderWidth==nil);Equal(unit,before)
    for width=0,5 do
        assert(I.SetUnitField({unitConfig=unit},"frameBorderWidth",width).ok)
        assert(S.CopyPayload({Units={player=unit}}).Units.player.frameBorderWidth==width)
        Equal(unit.borderColor,before.borderColor);assert(unit.healthBarBorderWidth==5)
    end
    for _,bad in ipairs({-1,6,.5,"1",false,0/0,math.huge,-math.huge})do
        assert(not I.SetUnitField({unitConfig=unit},"frameBorderWidth",bad).ok and unit.frameBorderWidth==5)
        assert(not pcall(S.CopyPayload,{Units={player={frameBorderWidth=bad}}}))
    end
    for _,preset in pairs(ns.Themes)do
        local function Check(t)for k,v in pairs(t)do assert(k~="frameBorderWidth");if type(v)=="table"then Check(v)end end end
        Check(preset)
    end
    local legacy=S.MaterializeLegacyUnit({}, {frameBorderWidth=5}, "player")
    assert(legacy.castBarPresent~=true and legacy.classPowerBarPresent~=true and legacy.powerBarPresent~=true)
end)
Test("legacy/vNext import-export retains nil/0/1..5 and rejects malformed widths atomically",function()
    for _,width in ipairs({false,0,1,2,3,4,5})do
        local db,layout=Layout(Records());local unit=layout.payload.Units.player
        unit.frameBorderWidth=width~=false and width or nil;unit.borderColor={.2,.3,.4,0}
        ns.db=db;db.global.UserLayouts["layout:source"]=layout
        local encoded=assert(T.Export("layout:source"));local target=Target();local ok,id=T.Import(encoded);assert(ok,id)
        Equal(target.global.UserLayouts[id].payload,layout.payload)
        local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Root",payload={Units={player={Texts={},frameBorderWidth=unit.frameBorderWidth,borderColor=unit.borderColor}},TextTemplates={}}}
        target=Target();ok,id=T.Import(assert(C.Encode(legacy)),{generator=Generator()});assert(ok,id)
        local imported=target.global.UserLayouts[id].payload.Units.player
        assert(imported.frameBorderWidth==unit.frameBorderWidth);Equal(imported.borderColor,unit.borderColor)
    end
    for _,version in ipairs({1,2})do
        local doc={transferSchema=version,formatVersion=version,addonVersion="test",name="Invalid",templates={},payload={Units={player={Texts={},frameBorderWidth=6}}}}
        if version==1 then doc.payload.TextTemplates={}end
        local target=Target();local before=Copy(target);assert(not T.Import(assert(C.Encode(doc)),{generator=Generator()}));Equal(target,before)
    end
end)
local r=Read("Tests/BarBorderRendering.lua")
local rn,Region,methods,F,eq,stats=assert(load(r:sub(1,assert(r:find('Test("missing/zero',1,true))-1)..
    "\nreturn ns,Region,methods,F,Equal,function()return createdFrames,createdTextures end"))()
for _,method in ipairs({"RegisterForClicks","SetAttribute","SetScale","SetMouseClickEnabled","SetClampedToScreen"})do methods[method]=function()end end
function methods:SetScript(event,fn)self.scripts[event]=fn end
function methods:SetBackdrop(v)self.backdrop=v end
function methods:SetBackdropColor(...)self.backdropColor={...}end
function methods:SetBackdropBorderColor(...)self.backdropBorderColor={...}end
function methods:GetChildren()return table.unpack(self.children or {})end
function methods:SetScale(value)self.scale=value end
function methods:GetEffectiveScale()return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1)end
local create=CreateFrame
CreateFrame=function(kind,name,parent,...)
    local frame=create(kind,name,parent,...)
    if parent then parent.children=parent.children or {};table.insert(parent.children,frame)end
    return frame
end
UIParent=Region()
assert(loadfile("Engine/UnitFrame/Shared/UnitFrameUtils.lua"))("FocalPoint",rn)
assert(loadfile("Engine/UnitFrame/Runtime/UnitFrameLayout.lua"))("FocalPoint",rn)
assert(loadfile("Engine/UnitFrame/Runtime/UnitFrameVisibility.lua"))("FocalPoint",rn)
local frame=F.CreateBaseFrame("player",{})
local function Apply(width,color,scale)
    local config={frameBorderWidth=width,borderColor=color,point="CENTER",relativePoint="CENTER",relativeTo="UIParent",x=0,y=0}
    rn.UnitFrameLayout.ApplyBaseFrame({},frame,config,{width=120,height=20,alpha=.7,scale=scale or 1,frameLevel=2,frameStrata="MEDIUM"})
    F.ApplyFrameBorder(frame,width,{rn.UnitFrameUtils.UnpackColor(color,{.2,.2,.2,1})})
end
Test("factory preallocates hidden root edges; nil stays legacy, 0 affects only root",function()
    assert(frame.FrameBorder and not frame.FrameBorder.shown and not frame.BarBorder)
    assert(frame.backdrop.edgeSize==1 and frame.backdrop.insets.left==0)
    local color={.2,.3,.4,.5};Apply(nil,color);eq(frame.backdropBorderColor,color);assert(not frame.FrameBorder.shown)
    local health=CreateFrame("StatusBar",nil,frame);frame.Elements.HealthBar=health
    F.ApplyBarBorder(health,1,{1,0,0,1});Apply(0,color)
    eq(frame.backdropBorderColor,{0,0,0,0});eq(color,{.2,.3,.4,.5});assert(health.BarBorder.shown and not frame.FrameBorder.shown)
end)
Test("1..5 uses one inner frame, alpha zero, theme colors and owned segment levels",function()
    local health=frame.Elements.HealthBar;health.level=6;health.BarBorder.level=7
    local holder=CreateFrame("Frame",nil,frame);local segment=CreateFrame("StatusBar",nil,holder)
    frame._segmentedBars={byId={test=holder},pool={}}
    holder.Bars={segment}
    segment.level=14;F.ApplyBarBorder(segment,1,{1,1,1,1})
    for width=1,5 do
        Apply(width,{.4,.5,.6,0});assert(frame.FrameBorder.shown and frame.FrameBorder.level==16)
        eq(frame.backdropBorderColor,{0,0,0,0});eq(frame.FrameBorder.edges[1].color,{.4,.5,.6,0})
        assert(frame.FrameBorder.edges[1].height==width and health.BarBorder.shown)
    end
    local tested=0
    local function Colors(t)
        for key,value in pairs(t)do
            if key=="borderColor"then Apply(3,value);eq(frame.FrameBorder.edges[1].color,{rn.UnitFrameUtils.UnpackColor(value)});tested=tested+1
            elseif type(value)=="table"then Colors(value)end
        end
    end
    Colors(ns.Themes);assert(tested>0)
end)
Test("foreign aura children and unknown Elements are opaque to root border layering",function()
    local function Forbidden()error("foreign aura child accessed")end
    local foreign=setmetatable({}, {__index=Forbidden})
    local aura=CreateFrame("Frame",nil,frame);aura.level=30;aura.children={foreign}
    frame.ManagedAuraBackend={Buffs={visualRoot=aura,container=foreign,buttons={[foreign]=true}}}
    frame.Elements.ManagedBuffs=aura;frame.Elements.UnknownNativeChild=foreign
    for width=1,5 do
        Apply(width,{1,1,1,0});assert(frame.FrameBorder.level==31)
    end
    -- No hierarchy enumeration, even when an otherwise safe child is present.
    frame.GetChildren=Forbidden;aura.GetChildren=Forbidden
    local health=frame.Elements.HealthBar
    health.BarBorder.level=40;Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==41)
    health.BarBorder.level=7
    F.CreateClassPowerBar(frame)
    local legacy=frame.Elements.ClassPowerBar;legacy.Bars[1].border.level=42
    Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==43)
    legacy.Bars[1].border.level=2
    local holder=frame._segmentedBars.byId.test
    holder.level=44;Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==45);holder.level=1
    F.ApplyBarBorder(holder,1,{1,1,1,1});holder.BarBorder.level=46
    Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==47);holder.BarBorder.level=2
    local portrait=CreateFrame("Frame",nil,frame);portrait.level=48;frame.Elements.Portrait=portrait
    Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==49);portrait.level=1
    local combat=CreateFrame("Frame",nil,frame);frame.Elements.CombatIndicator=combat
    combat.StatusOverlay=CreateFrame("Frame",nil,combat)
    combat.StatusOverlay.PulseLayer=CreateFrame("Frame",nil,combat.StatusOverlay)
    combat.StatusOverlay.PulseLayer.level=50
    Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==51);combat.StatusOverlay.PulseLayer.level=1
    local decoration=CreateFrame("Frame",nil,frame);decoration.level=52
    frame.DecorationIndicators={test={holder=decoration}}
    Apply(1,{1,1,1,1});assert(frame.FrameBorder.level==53);decoration.level=1
    Apply(0,{1,1,1,1});assert(not frame.FrameBorder.shown)
    Apply(nil,{1,1,1,1});assert(not frame.FrameBorder.shown)
end)
Test("hard clear cannot resurrect on resize; 50 clear/reapply/resize/alpha cycles allocate nothing",function()
    local frames,textures=stats();local identity=frame.FrameBorder
    for i=1,50 do
        Apply(5,{1,1,1,.5},i%2==0 and 1.5 or .75)
        assert(identity:GetEffectiveScale()==frame:GetEffectiveScale() and identity.allPoints==frame)
        frame:SetSize(80,4)
        assert(identity.edges[1].height==2 and not identity.edges[3].shown)
        rn.UnitFrameVisibility.ClearFrameVisualState(frame,"test")
        assert(not identity.shown and identity.requestedWidth==0)
        frame:SetSize(120,20);assert(not identity.shown)
        Apply(nil,{.2,.3,.4,1});assert(not identity.shown)
        Apply(i%6,{.1,.2,.3,0});assert(frame.FrameBorder==identity)
        frame:SetAlpha(0);assert(identity:EffectiveAlpha()==0);frame:SetAlpha(.5)
    end
    local afterFrames,afterTextures=stats();assert(frames==afterFrames and textures==afterTextures)
    local before=CreateFrame;CreateFrame=function()error("creation during combat reapply")end
    InCombatLockdown=function()return true end;Apply(5,{1,1,1,1});InCombatLockdown=function()return false end;CreateFrame=before
end)
Test("root apply follows child layouts and keeps shared portrait/segment color variables",function()
    local source=Read("Engine/UnitFrame.lua")
    local root=assert(source:find("Factory.ApplyFrameBorder(frame, config.frameBorderWidth",1,true))
    assert(root>assert(source:find("FocalPoint.UnitFrameSegmentedBars.Apply(frame)",1,true)))
    assert(root<assert(source:find("ClassPower.PresentReady(frame, classPowerHandoff)",root,true)))
    assert(source:find("local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor",1,true))
end)
local inspectorSource=Read("Tests/BarBorderInspector.lua")
local un,Setup,ui,state,selection=assert(load(inspectorSource:sub(1,assert(inspectorSource:find("local cases=",1,true))-1)..
    "\nreturn ns,Setup,ui,state,selection","@FrameBorder/Inspector"))()
un.Ace=ui.ns.Ace
dofile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-InteractiveLabel.lua")
dofile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-Slider.lua")
assert(loadfile("GUI/Editor/Inspector/InspectorBinding.lua"))("FocalPoint",un)
assert(loadfile("GUI/Editor/Inspector/InspectorController.lua"))("FocalPoint",un)
Test("both real Expert Inspector paths show 0..5 beside existing color; Quick has no width",function()
    for _,propertiesOnly in ipairs({false,true})do
        for _,mode in ipairs({"quick","expert"})do
            local _,unit=Setup();state.SetSingleSelection("player");state.SetMode(mode)
            assert(selection.SelectObject({kind="unit",unit="player"}))
            state.SetPropertyScope("unit","frame")
            local function Build()
                local container=ui.ace:Create("SimpleGroup")
                local builder=propertiesOnly and un.GUI.Editor.Inspector.BuildProperties or un.GUI.Editor.Inspector.Build
                builder(container,state.Get(),{})
                local width
                local function Walk(w)
                    if w.GetUserData and w:GetUserData("focalPointAnchorKey")=="frameBorderWidth"then width=w end
                    for _,child in ipairs(w.children or {})do Walk(child)end
                end
                Walk(container);return container,width
            end
            local before=un.LayoutService.Clone(unit);local view,width=Build();Equal(unit,before)
            if mode=="quick"then assert(not width)
            else
                assert(width and width.min==0 and width.max==5 and width.step==1 and width:GetValue()==1)
                for value=0,5 do width:Fire("OnValueChanged",value);assert(unit.frameBorderWidth==value)end
                width:Fire("OnValueChanged",6);assert(unit.frameBorderWidth==5)
                width:Fire("OnValueChanged",0);ui.ace:Release(view);view,width=Build();assert(width:GetValue()==0)
                assert(unit.borderColor==nil and before.borderColor==nil)
            end
            ui.ace:Release(view)
        end
    end
end)
print("Frame Border: "..count.." groups PASS")
