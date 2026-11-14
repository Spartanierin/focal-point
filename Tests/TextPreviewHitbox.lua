-- Real positioning helper; geometry doubles do not prove native hit testing.
local f=dofile("Tests/ComponentDirectMove.lua")
f.Load("GUI/Editor/TextEditorOverlay.lua")
local api=f.ns.GUI.Editor.TextEditorOverlay
local position=assert(f.Find(api.UpdateFrame,"PositionSafeTextHitbox"))
local owner={}
local config={anchorTo="Frame",point="LEFT",relativePoint="RIGHT",offsetX=17,offsetY=-23,fontSize=12}
local hit={_focalPointTextKey="first"}
function hit:SetSize(w,h)self.width,self.height=w,h end
function hit:SetPoint(p,r,rp,x,y)self.point,self.relative,self.relativePoint,self.x,self.y=p,r,rp,x,y end
local function Check(x,y)
    assert(position(hit,owner,config))
    assert(hit.x==x and hit.y==y)
    assert(hit.relative==owner and hit.point=="LEFT" and hit.relativePoint=="RIGHT")
    assert(hit.width==96 and hit.height==22,"minimum/font hitbox sizing changed")
end
Check(17,-23)
owner._focalPointTextDragPreviewOffsets={first={offsetX=0,offsetY=59},second={offsetX=88,offsetY=99}}
Check(0,59)
hit._focalPointTextKey="second";Check(88,99)
hit._focalPointTextKey="first"
owner._focalPointTextDragPreviewOffsets.first=nil;Check(17,-23)
owner._focalPointTextDragPreviewOffsets=nil;Check(17,-23)
owner._focalPointTextDragPreviewOffsets={first={offsetX=-40,offsetY=0}}
Check(-40,0)
local previousOwner=owner;owner={};Check(17,-23)
assert(previousOwner._focalPointTextDragPreviewOffsets.first.offsetX==-40)
assert(config.offsetX==17 and config.offsetY==-23,"preview mutated stored configuration")
print("PASS: text hitbox config / preview / cleanup, zero offsets, separate text/frame identity and unchanged sizing")
-- Actual Begin/Start/OnUpdate/End + real text Apply + real Inspector mutation.
-- FontString rectangle reads deliberately fail: the commit must not need them.
f.Load("Engine/Text/Runtime/TextElementApply.lua")
local realApply=f.ns.TextElementApply.ApplyElementConfig
local finishText=assert(f.Find(api.StartDrag,"EndTextDrag"))
local shift=true
f.ns.GUI.Editor.InteractionMode={IsShiftDown=function()return shift end}
f.ns.GUI.Editor.CanvasHoverOverlay.RouteSelectedComponentPointer=nil
IsMouseButtonDown=function()return true end
local previousSelect=api.Select
api.Select=function()return true end
local selected,applies=0,0
local liveOwner,liveHit,liveFont,liveConfig
api.UpdateFrame=function(frame)
    for key,cfg in pairs(frame.config.Texts)do
        local target=frame._focalPointTextEditorOverlays[key]
        if target then position(target,frame,cfg) end
    end
end
f.ns.UnitFrame={UpdateTextElements=function()end,ApplyTextElementConfig=function(_,frame,key,obj,cfg)
    applies=applies+1
    return realApply(frame,key,obj,cfg,{GetAnchorTarget=function(owner,anchor)return f.ns.UnitFrameFactory.GetAnchorTarget(owner,anchor)end,
        offsetOverride=frame._focalPointTextDragPreviewOffsets and frame._focalPointTextDragPreviewOffsets[key]})
end}
local function Fixture(scale,point,justify,overflow,preview)
    liveOwner=f.Frame(scale);liveOwner._fpUnit="player"
    liveOwner.HealthBar=f.Frame(scale,180,40);liveOwner.HealthBar:SetPoint("CENTER",liveOwner,"CENTER",0,0)
    liveConfig={anchorTo=point=="CENTER" and "Frame" or "HealthBar",point=point,relativePoint=point,offsetX=-4,offsetY=0,
        justifyH=justify,overflowMode=overflow,fontSize=12}
    liveOwner.config={Texts={Health=liveConfig,Other={anchorTo="Frame",point="CENTER",relativePoint="CENTER",offsetX=44,offsetY=55}}}
    f.units.player=liveOwner.config;f.ns.frames={player=liveOwner}
    liveFont=f.Frame(scale,80,14)
    for _,method in ipairs({"SetWidth","SetTextColor","SetJustifyH","SetShadowOffset","SetShadowColor","Show"})do liveFont[method]=function()end end
    liveFont.SetFont=function()return true end
    for _,method in ipairs({"GetLeft","GetRight","GetTop","GetBottom"})do
        liveFont[method]=function()error("forbidden FontString rectangle read",0)end
    end
    liveOwner.Texts={Health=liveFont}
    liveHit={_focalPointOwnerFrame=liveOwner,_focalPointTextKey="Health",scripts={}}
    liveHit.SetScript=function(self,key,fn)self.scripts[key]=fn end
    liveHit.SetSize=hit.SetSize;liveHit.SetPoint=hit.SetPoint
    liveOwner._focalPointTextEditorOverlays={Health=liveHit}
    if preview then liveOwner._focalPointTextDragPreviewOffsets={Health={offsetX=preview[1],offsetY=preview[2]}} end
    f.ns.UnitFrame:ApplyTextElementConfig(liveOwner,"Health",liveFont,liveConfig)
    api.UpdateFrame(liveOwner)
end
local function Near(a,b)f.Near(a,b,1e-6)end
local function Begin()
    assert(api.BeginDrag(liveHit));assert(api.StartDrag(liveHit))
end
local count=0
for _,scale in ipairs({.75,1,1.5})do
    for _,point in ipairs({"TOPLEFT","CENTER","BOTTOMRIGHT"})do
        for _,justify in ipairs({"LEFT","CENTER","RIGHT"})do
            for _,overflow in ipairs({"NONE","ELLIPSIS"})do
                for _,delta in ipairs({{0,0},{0,2},{0,-5},{5,0},{-2,0},{40,-35}})do
                    UIParent.scale=scale==1.5 and 1 or .65
                    Fixture(scale,point,justify,overflow,{-3,31})
                    local startX,startY=liveFont.cx,liveFont.cy
                    local originalPoint,originalRelative=liveConfig.point,liveConfig.relativePoint
                    Begin();local before=applies
                    liveHit.scripts.OnUpdate(liveHit)
                    assert(applies==before,"zero delta reapplied or reanchored the text")
                    Near(liveFont.cx,startX);Near(liveFont.cy,startY)
                    f.move(delta[1],delta[2]);liveHit.scripts.OnUpdate(liveHit)
                    local factor=UIParent:GetEffectiveScale()/liveOwner:GetEffectiveScale()
                    local x=math.floor(-3+delta[1]*factor+.5)
                    local y=math.floor(31+delta[2]*factor+.5)
                    Near(liveFont.cx-startX,x+3);Near(liveFont.cy-startY,y-31)
                    assert(liveHit.x==x and liveHit.y==y)
                    finishText(liveHit,true)
                    assert(liveConfig.offsetX==x and liveConfig.offsetY==y)
                    assert(liveConfig.point==originalPoint and liveConfig.relativePoint==originalRelative and liveConfig.justifyH==justify)
                    assert(not liveOwner._focalPointTextDragPreviewOffsets and not liveHit._focalPointTextDragState and not liveHit.scripts.OnUpdate)
                    Near(liveFont.cx-startX,x+3);Near(liveFont.cy-startY,y-31)
                    assert(liveOwner.config.Texts.Other.offsetX==44 and liveOwner.config.Texts.Other.offsetY==55)
                    -- Rebind a separately loaded config tuple and apply it again.
                    local loaded={};for k,v in pairs(liveConfig)do loaded[k]=v end
                    liveOwner.config.Texts.Health=loaded
                    f.ns.UnitFrame:ApplyTextElementConfig(liveOwner,"Health",liveFont,loaded)
                    api.UpdateFrame(liveOwner)
                    Near(liveFont.cx-startX,x+3);Near(liveFont.cy-startY,y-31)
                    count=count+1
                end
            end
        end
    end
end
-- Cancel, combat, and config replacement must clear previews without committing.
for _,reason in ipairs({"cancel","combat","replacement"})do
    Fixture(1,"TOPLEFT","LEFT","NONE")
    Begin();f.move(5,-5);liveHit.scripts.OnUpdate(liveHit)
    if reason=="combat" then InCombatLockdown=function()return true end end
    if reason=="replacement" then
        local replacement={};for k,v in pairs(liveConfig)do replacement[k]=v end
        liveOwner.config.Texts.Health=replacement
    end
    finishText(liveHit,reason~="cancel")
    InCombatLockdown=function()return false end
    assert(liveConfig.offsetX==-4 and liveConfig.offsetY==0)
    assert(not liveOwner._focalPointTextDragPreviewOffsets and not liveHit._focalPointTextDragState)
    assert(liveHit.x==-4 and liveHit.y==0)
end
-- An unexpected mutation failure is rethrown after canonical restore/cleanup.
Fixture(1,"BOTTOMRIGHT","RIGHT","NONE")
Begin();f.move(5,-5);liveHit.scripts.OnUpdate(liveHit)
local mutation=f.ns.InspectorMutations.SetTextPositionOffsets
f.ns.InspectorMutations.SetTextPositionOffsets=function()error("mutation sentinel",0)end
local success,failure=pcall(finishText,liveHit,true)
f.ns.InspectorMutations.SetTextPositionOffsets=mutation
assert(not success and failure=="mutation sentinel")
assert(not liveOwner._focalPointTextDragPreviewOffsets and not liveHit._focalPointTextDragState)
assert(liveConfig.offsetX==-4 and liveConfig.offsetY==0 and liveHit.x==-4 and liveHit.y==0)
-- An already failed old gesture can leave a preview before MouseDown. A
-- zero-motion gesture must preserve and persist that visible position too.
Fixture(1,"TOPLEFT","LEFT","NONE",{-3,31})
assert(api.BeginDrag(liveHit));finishText(liveHit,true)
assert(liveConfig.offsetX==-3 and liveConfig.offsetY==31 and not liveOwner._focalPointTextDragPreviewOffsets)
-- Repeated MouseDown on the same active text aborts the previous gesture.
Fixture(1,"CENTER","CENTER","NONE")
Begin();f.move(5,5);liveHit.scripts.OnUpdate(liveHit)
assert(api.BeginDrag(liveHit))
assert(not liveOwner._focalPointTextDragPreviewOffsets and liveHit.x==-4 and liveHit.y==0)
finishText(liveHit,false)
-- Explicit mutation rejection restores config rather than keeping a preview.
Fixture(1,"TOPLEFT","LEFT","NONE")
Begin();f.move(-5,5);liveHit.scripts.OnUpdate(liveHit)
f.ns.InspectorMutations.SetTextPositionOffsets=function()return {ok=false}end
finishText(liveHit,true)
f.ns.InspectorMutations.SetTextPositionOffsets=mutation
assert(liveConfig.offsetX==-4 and liveHit.x==-4 and not liveOwner._focalPointTextDragPreviewOffsets)
-- Failure after the mutation restores the now-canonical committed position,
-- removes preview even if that Apply fails again, and keeps the original error.
Fixture(1,"CENTER","CENTER","NONE")
Begin();f.move(5,5);liveHit.scripts.OnUpdate(liveHit)
local applyBeforeFailure=f.ns.UnitFrame.ApplyTextElementConfig
f.ns.UnitFrame.ApplyTextElementConfig=function()error("apply sentinel",0)end
success,failure=pcall(finishText,liveHit,true)
f.ns.UnitFrame.ApplyTextElementConfig=applyBeforeFailure
assert(not success and failure=="apply sentinel")
assert(liveConfig.offsetX==1 and liveConfig.offsetY==5)
assert(not liveOwner._focalPointTextDragPreviewOffsets and not liveHit._focalPointTextDragState)
f.ns.UnitFrame:ApplyTextElementConfig(liveOwner,"Health",liveFont,liveConfig)
api.UpdateFrame(liveOwner)
assert(liveHit.x==1 and liveHit.y==5)
-- No Shift continues to delegate to the existing Unit owner drag.
Fixture(1,"CENTER","CENTER","NONE");shift=false
local began,ended=false,false
f.ns.BeginEditorUnitFrameDrag=function(_,frame)assert(frame==liveOwner);began=true;return true end
f.ns.EndEditorUnitFrameDrag=function(_,frame,commit)assert(frame==liveOwner and commit);ended=true end
Begin();finishText(liveHit,true)
assert(began and ended and liveConfig.offsetX==-4 and liveConfig.offsetY==0)
api.Select=previousSelect
print("PASS: "..count.." real Shift-drag/Apply/commit/rebind cases, zero/small/large deltas, stale preview, anchors, justification, overflow config and scales; forbidden FontString reads unused")
print("PASS: cancel/combat/rebind restore, mutation-error cleanup/rethrow, second-text isolation and unchanged Unit-owner drag")
