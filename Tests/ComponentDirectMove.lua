-- Actual Canvas direct-move closures and mutations; native geometry is a model.
local ns = { GUI = { Editor = { SidebarShared = { INDICATOR_META = {
    Portrait = {optionKey="Portrait"}, CombatIndicator = {optionKey="CombatIndicator"},
} } } }, framesUnlocked = true, db = {}, UnitFrameUtils = {} }
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
local function Near(a,b,tolerance) assert(math.abs(a-b) <= (tolerance or 1e-7), tostring(a).." ~= "..tostring(b)) end
local function Find(fn, wanted, seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local children={}
    for i=1,math.huge do
        local name,value=debug.getupvalue(fn,i); if not name then break end
        if name==wanted then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local value=Find(child,wanted,seen);if value then return value end end
end
local units={}
ns.UnitFrameUtils.GetUnitDB=function(unit) return units[unit] end
ns.ActiveLayoutResolver={GetActiveUnits=function()return units end,GetEditableActiveUnits=function()return units end}
ns.LayoutEditWorkflow={RequestEditableLayoutForMutation=function(action)action();return true end}
ns.IsEditorActive=function()return true end
ns.RefreshUnitFrame=function()end
InCombatLockdown=function()return false end
local cursorX,cursorY=0,0
GetCursorPosition=function()return cursorX,cursorY end
UIParent={scale=0.8,GetEffectiveScale=function(self)return self.scale end,
    GetWidth=function()return 1920 end,GetHeight=function()return 1080 end}
Load("Engine/UnitFrame/Runtime/UnitFrameLayout.lua")
Load("Engine/Auras/Layout/AuraBlockLayout.lua")
Load("GUI/Editor/EditorAnchorGeometry.lua")
Load("GUI/Editor/Inspector/InspectorMutations.lua")
Load("GUI/Editor/CanvasHoverOverlay.lua")
local canvas=ns.GUI.Editor.CanvasHoverOverlay
local begin=assert(Find(canvas.UpdateFrame,"BeginDirectMoveDrag"))
local finish=assert(Find(begin,"EndDirectMoveDrag"))
local describe=assert(Find(canvas.UpdateFrame,"ResolveDirectMoveDescriptor"))
local wheel=assert(Find(canvas.UpdateFrame,"ResolveWheelCapability"))
canvas.UpdateFrame=function()end -- UI chrome is outside this native geometry test.
local function Frame(scale,w,h)
    local f={scale=scale*UIParent.scale,width=w or 240,height=h or 60,cx=800/scale,cy=450/scale,scripts={}}
    function f:GetEffectiveScale()return self.scale end
    function f:GetWidth()return self.width end
    function f:GetHeight()return self.height end
    function f:GetLeft()return self.cx-self.width/2 end
    function f:GetRight()return self.cx+self.width/2 end
    function f:GetBottom()return self.cy-self.height/2 end
    function f:GetTop()return self.cy+self.height/2 end
    function f:GetNumPoints()return 1 end
    function f:GetPoint()return table.unpack(self.point) end
    function f:ClearAllPoints()end
    function f:SetScript(key,fn)self.scripts[key]=fn end
    function f:SetPoint(point,parent,relativePoint,x,y)
        self.point={point,parent,relativePoint,x,y}
        local ax,ay=ns.UnitFrameLayout.GetRectAnchor({left=parent:GetLeft(),right=parent:GetRight(),
            top=parent:GetTop(),bottom=parent:GetBottom()},relativePoint)
        local rx,ry=ns.UnitFrameLayout.GetRectAnchor({left=-self.width/2,right=self.width/2,
            bottom=-self.height/2,top=self.height/2},point)
        local ratio=parent:GetEffectiveScale()/self:GetEffectiveScale()
        self.cx,self.cy=ax*ratio+x-rx,ay*ratio+y-ry
    end
    return f
end
ns.UnitFrameFactory={GetAnchorTarget=function(frame,anchor)return anchor=='HealthBar' and frame.HealthBar or frame end}
local refs={{kind="bar",objectKey="PowerBar"},{kind="bar",objectKey="CastBar"},{kind="bar",objectKey="NormalAbsorbBar"},
    {kind="bar",objectKey="HealingAbsorbBar"},{kind="bar",objectKey="ClassPowerBar"},
    {kind="indicator",indicatorKey="Portrait"},{kind="indicator",indicatorKey="CombatIndicator"},
    {kind="decoration",decorationId="test"},{kind="aura",auraKey="Buffs"}}
ns.UnitFrameDecoration={ResolveTarget=function(frame,config)return ns.UnitFrameFactory.GetAnchorTarget(frame,config.anchorTo) end}
local cases=0
for _,scale in ipairs({0.5,0.75,1,1.25,1.5})do
    for _,ref in ipairs(refs)do
        for _,sign in ipairs({-1,1})do
            local owner=Frame(scale);owner._fpUnit="player"
            owner.HealthBar=Frame(scale,120,30);owner.HealthBar:SetPoint('CENTER',owner,'CENTER',13,-7)
            local config={powerBarSizeMode="CUSTOM",powerBarAnchorTo='HealthBar',normalAbsorbBarSizeMode="CUSTOM",healingAbsorbBarSizeMode="CUSTOM",
                normalAbsorbBarAnchorTo='HealthBar',healingAbsorbBarAnchorTo='HealthBar',classPowerBarAnchorTo='HealthBar',
                Portrait={placement="ATTACHED",anchorTo='HealthBar',offsetX=17,offsetY=-23},
                CombatIndicator={placement="ATTACHED",anchorTo='HealthBar',offsetX=17,offsetY=-23},
                Buffs={placement='ATTACHED',point='CENTER',relativePoint='CENTER',offsetX=17,offsetY=-23},
                decorations={{id="test",anchorTo='HealthBar',offsetX=17,offsetY=-23}}}
            units.player=config; owner.config=config
            local descriptor=assert(describe(owner,ref))
            local stored=descriptor.indicatorMeta and config[descriptor.indicatorMeta[descriptor.indicatorKey].optionKey]
                or descriptor.decorationConfig or descriptor.auraConfig or config
            stored[descriptor.offsetXField],stored[descriptor.offsetYField]=17,-23
            local anchorOwner=(ref.objectKey=='CastBar' or ref.kind=='aura') and owner or owner.HealthBar
            local target=Frame(scale,40,20);target:SetPoint("CENTER",anchorOwner,"CENTER",17,-23)
            owner.Elements={PowerBar=target}
            local zone=Frame(scale);zone._focalPointVisualTarget=target;zone._focalPointOwnerFrame=owner;zone._focalPointObjectRef=ref
            local startX,startY=target.cx,target.cy
            assert(begin(zone,{directMove=descriptor}))
            zone.scripts.OnUpdate(zone); Near(target.cx,startX);Near(target.cy,startY)
            cursorX,cursorY=cursorX+sign*100*UIParent.scale,cursorY-sign*100*UIParent.scale
            zone.scripts.OnUpdate(zone)
            Near((target.cx-startX)*scale,sign*100,scale/2+1e-7)
            Near((target.cy-startY)*scale,-sign*100,scale/2+1e-7)
            local previewX,previewY=target.cx,target.cy
            finish(zone,true)
            local point=stored[descriptor.pointField or "point"] or "CENTER"
            local relative=stored[descriptor.relativePointField or "relativePoint"] or "CENTER"
            target:SetPoint(point,anchorOwner,relative,stored[descriptor.offsetXField],stored[descriptor.offsetYField])
            assert(math.abs(target.cx-previewX)<1e-7, "commit X: "..tostring(ref.objectKey or ref.indicatorKey or ref.decorationId).." "..tostring(stored[descriptor.offsetXField]))
            Near(target.cx,previewX);Near(target.cy,previewY)
            local reopened=Frame(scale,40,20)
            reopened:SetPoint(point,anchorOwner,relative,stored[descriptor.offsetXField],stored[descriptor.offsetYField])
            Near(reopened.cx,previewX);Near(reopened.cy,previewY)
            cases=cases+1
        end
    end
end
local powerRef={kind="bar",unit="player",objectKey="PowerBar"}
local function PowerFixture()
    local owner=Frame(1);owner._fpUnit="player"
    local config={width=240,height=60,powerBarPresent=true,showPowerBar=true,powerBarSizeMode="CUSTOM",
        powerBarWidth=40,powerBarHeight=20,powerBarAnchorTo="Frame",powerBarPoint="CENTER",powerBarRelativePoint="CENTER",
        powerBarOffsetX=17,powerBarOffsetY=-23}
    units.player=config;owner.config=config
    local target=Frame(1,40,20);target:SetPoint("CENTER",owner,"CENTER",17,-23)
    owner.Elements={PowerBar=target}
    local zone=Frame(1);zone._focalPointOwnerFrame=owner;zone._focalPointVisualTarget=target;zone._focalPointObjectRef=powerRef
    local root={layoutId="layout:power"}
    ns.ActiveLayoutResolver.GetActiveRuntimeRoot=function()return root end
    return owner,target,config,zone,root
end
do
    local owner,_,config=PowerFixture()
    local capability=assert(wheel(owner,powerRef));assert(capability.min==1 and capability.max==128 and capability.default==8)
    config.powerBarSizeMode="MATCH_TARGET";assert(describe(owner,powerRef)==nil)
    capability=assert(wheel(owner,powerRef));assert(capability.min==4 and capability.max==30 and capability.default==20)
    config.powerBarSizeMode=nil;assert(describe(owner,powerRef)==nil)
end
for _,reason in ipairs({"combat","layout","record","mode","reopen"})do
    local owner,target,config,zone,root=PowerFixture()
    local d=assert(describe(owner,powerRef));assert(begin(zone,{directMove=d}))
    cursorX=cursorX+60*UIParent.scale;zone.scripts.OnUpdate(zone)
    if reason=="combat"then InCombatLockdown=function()return true end
    elseif reason=="layout"then ns.ActiveLayoutResolver.GetActiveRuntimeRoot=function()return {layoutId="layout:other"}end
    elseif reason=="record"then units.player={powerBarSizeMode="CUSTOM",powerBarOffsetX=81,powerBarOffsetY=92}
    elseif reason=="mode"then config.powerBarSizeMode="MATCH_TARGET"
    else ns.framesUnlocked=false end
    finish(zone,true)
    assert(config.powerBarOffsetX==17 and config.powerBarOffsetY==-23 and not zone._focalPointDirectDragState)
    if reason=="record"then assert(units.player.powerBarOffsetX==81 and units.player.powerBarOffsetY==92)end
    InCombatLockdown=function()return false end;ns.framesUnlocked=true
end
-- A deferred editable-copy callback must revalidate immediately before writing.
do
    local owner,target,config,zone=PowerFixture();local pending
    local workflow=ns.LayoutEditWorkflow.RequestEditableLayoutForMutation
    ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(action)pending=action;return false,"confirmation-open"end
    assert(begin(zone,{directMove=assert(describe(owner,powerRef))}))
    cursorX=cursorX+60*UIParent.scale;zone.scripts.OnUpdate(zone);finish(zone,true)
    assert(pending);InCombatLockdown=function()return true end;pending()
    assert(config.powerBarOffsetX==17 and config.powerBarOffsetY==-23)
    InCombatLockdown=function()return false end;ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=workflow
end
-- Selection fallback consumes P14.1's canonical rectangles, including a hidden bar.
Load("Engine/UnitFrame/Shared/UnitFramePreview.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua")
Load("Engine/UnitFrame/Bars/UnitFrameBarLayout.lua")
Load("GUI/Editor/SelectionGeometryResolver.lua")
do
    local owner,target,config=PowerFixture()
    config.powerBarWidth=100;config.powerBarHeight=18;config.powerBarPoint="TOPLEFT"
    config.powerBarRelativePoint="BOTTOMRIGHT";config.powerBarOffsetX=13;config.powerBarOffsetY=-12
    owner.Elements.PowerBar=nil
    local resolve=ns.GUI.Editor.SelectionGeometryResolver.Resolve
    local geometry=assert(resolve(owner,powerRef))
    assert(geometry.source=="power-custom-config" and geometry.width==100 and geometry.height==18)
    Near(geometry.points[1].offsetX,253);Near(geometry.points[1].offsetY,-30)
    owner.Elements.PowerBar=target;target.IsShown=function()return false end
    assert(resolve(owner,powerRef).source=="power-custom-config")
    target.IsShown=function()return true end;assert(resolve(owner,powerRef).target==target)
    -- The real text apply path retains the Power frame as anchor, with unchanged text offsets.
    Load("Engine/Text/Runtime/TextElementApply.lua")
    local text=Frame(1,10,10)
    for _,method in ipairs({"SetWidth","SetTextColor","SetJustifyH","SetShadowOffset","SetShadowColor","Show"})do text[method]=function()end end
    text.SetFont=function()return true end
    ns.TextElementApply.ApplyElementConfig(owner,"PowerText",text,
        {anchorTo="PowerBar",point="CENTER",relativePoint="CENTER",offsetX=7,offsetY=-3},
        {GetAnchorTarget=function(f,key)return f.Elements[key]or f end})
    assert(text.point[2]==target and text.point[4]==7 and text.point[5]==-3)
end
print("PASS Power Direct Move: MATCH_TARGET exclusion, stale/Combat/deferred guards, canonical selection fallback and real text anchor")
print("PASS ComponentDirectMove: "..cases.." scale/sign/component preview-commit-reapply cases (existing integer grid)")
return {ns=ns,Load=Load,Frame=Frame,Find=Find,Near=Near,begin=begin,finish=finish,describe=describe,units=units,
    move=function(x,y)cursorX,cursorY=cursorX+x*UIParent.scale,cursorY+y*UIParent.scale end}
