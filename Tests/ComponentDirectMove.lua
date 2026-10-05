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
local refs={{kind="bar",objectKey="CastBar"},{kind="bar",objectKey="NormalAbsorbBar"},
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
            local config={normalAbsorbBarSizeMode="CUSTOM",healingAbsorbBarSizeMode="CUSTOM",
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
print("PASS ComponentDirectMove: "..cases.." scale/sign/component preview-commit-reapply cases (existing integer grid)")
return {ns=ns,Load=Load,Frame=Frame,Find=Find,Near=Near,begin=begin,finish=finish,describe=describe,units=units,
    move=function(x,y)cursorX,cursorY=cursorX+x*UIParent.scale,cursorY+y*UIParent.scale end}
