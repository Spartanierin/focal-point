-- Actual pointer handlers and move/commit code with modeled native mouse events.
-- This does not simulate WoW's native hit testing or modifier event delivery.
local f=dofile('Tests/ComponentDirectMove.lua')
local ns,Near=f.ns,f.Near
local function Noop()end
local function Surface()
    local s={scripts={}}
    for _,name in ipairs({'SetFrameStrata','SetFrameLevel','SetBackdrop','SetBackdropColor','SetBackdropBorderColor',
        'EnableMouse','EnableMouseWheel','RegisterForClicks','RegisterForDrag','SetPoint','SetAllPoints',
        'SetColorTexture','SetHeight','SetWidth','SetSize','ClearAllPoints','RegisterEvent'})do s[name]=Noop end
    function s:SetScript(key,fn)self.scripts[key]=fn end
    function s:GetFrameStrata()return 'FULLSCREEN' end
    function s:GetFrameLevel()return 900 end
    function s:CreateTexture()return Surface()end
    function s:Show()self.shown=true end
    function s:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self)end end
    function s:IsShown()return self.shown~=false end
    return s
end
CreateFrame=Surface
local selected,selectionCalls
ns.GUI.Editor.ObjectSelection={GetSelectedObject=function()return selected end,
    SelectObject=function(ref)selected=ref;selectionCalls=selectionCalls+1;return true end}
f.Load('GUI/Editor/EditorInteractionMode.lua')
local mode=ns.GUI.Editor.InteractionMode
f.Load('GUI/Editor/CanvasHoverOverlay.lua')
local canvas=ns.GUI.Editor.CanvasHoverOverlay
local ensureZone=assert(f.Find(canvas.UpdateFrame,'EnsureHitZone'))
canvas.UpdateFrame=Noop -- geometry/chrome rebuilds are covered by separate suites
f.Load('GUI/Editor/TextEditorOverlay.lua')
local text=ns.GUI.Editor.TextEditorOverlay
local ensureText=assert(f.Find(text.UpdateFrame,'EnsureOverlay'))
text.Select=function(owner,key)
    return ns.GUI.Editor.ObjectSelection.SelectObject({kind='text',unit=owner._fpUnit,textKey=key,objectKey=key})
end
LibStub=function()return {} end
ns.GUI.Editor.Composition={TreeControl={ROW_HEIGHT=20}}
f.Load('GUI/Editor/Composition/CompositionTreeView.lua')
local treeSelect=assert(f.Find(ns.CompositionTreeView.Build,'SelectTreeNode'))
local function Event(hit,event,...)
    assert(hit.scripts[event],'missing handler: '..event)(hit,...)
end
local function Ref(key)return {kind='bar',unit='player',objectKey=key}end
local function Fixture(scale,key)
    local owner=f.Frame(scale);owner._fpUnit='player';owner.MoveOverlay=Surface()
    owner.config={castBarOffsetX=17,castBarOffsetY=-23,classPowerBarOffsetX=17,classPowerBarOffsetY=-23}
    f.units.player=owner.config;ns.frames={player=owner}
    local target=f.Frame(scale,40,20);target:SetPoint('CENTER',owner,'CENTER',17,-23)
    local zone=ensureZone(owner,'selected')
    zone._focalPointObjectRef=Ref(key);zone._focalPointOwnerFrame=owner
    zone._focalPointVisualTarget=target;zone._focalPointMovesUnit=true
    local other=ensureZone(owner,'other');other._focalPointOwnerFrame=owner
    other._focalPointObjectRef=Ref('HealthBar');other._focalPointMovesUnit=true
    other._focalPointVisualTarget=f.Frame(scale)
    local texts={}
    for _,name in ipairs({'CastName','CastTime'})do
        local hit=ensureText(owner,name);hit._focalPointOwnerFrame=owner;hit._focalPointTextKey=name
        texts[#texts+1]=hit
    end
    selected=zone._focalPointObjectRef;selectionCalls=0
    mode.SetShiftDown(true)
    return owner,target,zone,other,texts
end
local cases=0
for _,scale in ipairs({0.5,0.75,1,1.25,1.5})do
    for _,key in ipairs({'CastBar','ClassPowerBar'})do
        for hitIndex=1,4 do
            local owner,target,zone,other,texts=Fixture(scale,key)
            local hit=hitIndex==4 and zone or hitIndex==3 and other or texts[hitIndex]
            -- A short SHIFT click must not select its hit target, even if SHIFT
            -- is released before the matching MouseUp/OnClick.
            Event(hit,'OnMouseDown','LeftButton');mode.SetShiftDown(false)
            Event(hit,'OnMouseUp','LeftButton')
            if hitIndex<=2 then Event(hit,'OnClick','LeftButton')end
            assert(selected==zone._focalPointObjectRef and selectionCalls==0)
            -- Next normal click regains the original selection behavior.
            Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnMouseUp','LeftButton')
            if hitIndex<=2 then Event(hit,'OnClick','LeftButton')end
            assert(selectionCalls==1 and (hitIndex==4 or selected~=zone._focalPointObjectRef))
            selected=zone._focalPointObjectRef;selectionCalls=0;mode.SetShiftDown(true)
            local x,y=target.cx,target.cy
            Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnDragStart')
            assert(hit._focalPointDirectDragState.target==target,'drag followed hit instead of selection')
            f.move(100,-100);Event(hit,'OnUpdate')
            Near((target.cx-x)*scale,100,scale/2+1e-7);Near((target.cy-y)*scale,-100,scale/2+1e-7)
            local px,py=target.cx,target.cy
            Event(hit,'OnDragStop');Event(hit,'OnMouseUp','LeftButton')
            if hitIndex<=2 then Event(hit,'OnClick','LeftButton')end
            assert(selected==zone._focalPointObjectRef and selectionCalls==0)
            assert(not hit._focalPointGesture and not hit._focalPointDirectDragState)
            local prefix=key=='CastBar' and 'castBar' or 'classPowerBar'
            local cfg=owner.config
            target:SetPoint(cfg[prefix..'Point'] or 'CENTER',owner,cfg[prefix..'RelativePoint'] or 'CENTER',
                cfg[prefix..'OffsetX'],cfg[prefix..'OffsetY'])
            Near(target.cx,px);Near(target.cy,py)
            cases=cases+1
        end
    end
end
-- Explicit Tree selection remains permitted with SHIFT held; a stale drag must
-- neither commit nor restore its old selection afterward.
local owner,target,zone,other,texts=Fixture(1.5,'CastBar')
local hit=texts[1];local x,y=target.cx,target.cy
Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnDragStart');f.move(90,90);Event(hit,'OnUpdate')
assert(treeSelect({type='textElement',unit='player',inspectorTarget={kind='text',sectionKey='texts',textKey='CastTime'}},{},{}))
Event(hit,'OnUpdate');Event(hit,'OnMouseUp','LeftButton');Event(hit,'OnClick','LeftButton')
assert(selected.textKey=='CastTime' and selectionCalls==1)
Near(target.cx,x);Near(target.cy,y);Near(owner.config.castBarOffsetX,17)
-- Cancellation/hidden overlay resets the active gesture and restores preview.
selected=zone._focalPointObjectRef;selectionCalls=0
Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnDragStart');f.move(90,90);Event(hit,'OnUpdate')
text.CancelActiveDrag();assert(not hit._focalPointGesture and not hit._focalPointDirectDragState)
Near(target.cx,x);Near(target.cy,y)
mode.ResetToFrameMode();Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnMouseUp','LeftButton');Event(hit,'OnClick','LeftButton')
assert(selected.kind=='text' and selectionCalls==1,'cancel left selection locked')
selected=zone._focalPointObjectRef;mode.SetShiftDown(true)
Event(hit,'OnMouseDown','LeftButton');Event(hit,'OnDragStart');f.move(90,90);Event(hit,'OnUpdate');Event(hit,'OnHide')
assert(not hit._focalPointGesture and not hit._focalPointDirectDragState)
Near(target.cx,x);Near(target.cy,y)
print('PASS ComponentMoveSelection: '..cases..' pointer/scale/component cases; click, release, drag ownership, commit, Tree and cancellation')
