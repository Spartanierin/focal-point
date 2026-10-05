-- Actual Canvas/Inspector bindings and CastBar runtime; native coordinates are modeled.
local function Read(path)
    local file=assert(io.open(path));local source=file:read('*a');file:close();return source
end
local runtime, MakeFrame, Options = assert(load(Read('Tests/CastBarSelectionPreview.lua') ..
    '\nreturn ns.UnitFrameCastBar, MakeFrame, Options', '@Tests/CastBarSelectionPreview.lua'))()
local f=dofile('Tests/ComponentDirectMove.lua')
local ns,Near=f.ns,f.Near
ns.UnitFrameCastBar=runtime
f.Load('Engine/Text/Shared/TextElementRoles.lua')
f.Load('Engine/Text/Runtime/TextElementApply.lua')
local textBudget=assert(f.Find(ns.TextElementApply.ApplyElementConfig,'ResolveOverflowWidth'))
local ref={kind='bar',objectKey='CastBar',unit='player'}
ns.GUI.Editor.ObjectSelection={GetSelectedObject=function()return ref end}
LibStub=function()return {} end
f.Load('GUI/Editor/Inspector/InspectorController.lua')
local inspector=ns.GUI.Editor.Inspector
local register=assert(f.Find(inspector.Build,'RegisterActiveCanvasDirectMoveOffsetControls'))
local suppressed=assert(f.Find(inspector.Build,'IsActiveCanvasDirectMoveOffsetControlSuppressed'))
local source=Read('GUI/Editor/Inspector/InspectorController.lua')
local first=assert(source:find('    local function BuildCastPositionSectionContent(',1,true))
local last=assert(source:find('\n    if isExpert then',first,true))
local function Build(config)
    local controls={}
    local context={ns=ns,unitConfig=config,state={selectedUnit='player'},isExpert=true,L={},barAnchorList={},
        AddDropdown=function()end,RegisterActiveCanvasDirectMoveOffsetControls=register,
        IsActiveCanvasDirectMoveOffsetControlSuppressed=suppressed,
        SetUnitField=function(key,value)
            local result=ns.InspectorMutations.SetUnitField({unitConfig=config},key,value)
            assert(result.ok and result.changed,'Inspector callback did not mutate its config')
        end,
        AddSlider=function(_,_,min,max,step,value,callback)
            local control={min=min,max=max,step=step,value=value,callback=callback}
            function control:SetSliderValues(a,b,s)self.min,self.max,self.step=a,b,s end
            function control:SetValue(v)
                assert(suppressed(self),'Canvas sync must retain suppression')
                -- Model finite native slider bounds, not native cursor or rendering.
                self.value=math.max(self.min,math.min(self.max,v))
            end
            controls[#controls+1]=control;return control
        end}
    local build=assert(load(source:sub(first,last-1)..'\nreturn BuildCastPositionSectionContent',
        '@Inspector.CastPosition','t',setmetatable(context,{__index=_G})))()
    build({});assert(#controls==2,'Cast position controls missing')
    return controls
end
local cases=0
local anchors={'LEFT','CENTER','RIGHT','TOP','BOTTOM'}
for _,scale in ipairs({0.5,0.75,1,1.25,1.5})do
    for index,point in ipairs(anchors)do
        for _,sign in ipairs({-1,1})do
            local config={scale=scale,width=240,castBarWidthMode='CUSTOM',castBarWidth=600,
                showCastBar=true,showCastBarIcon=true,castBarHeight=20,
                castBarPoint=point,castBarRelativePoint=anchors[index%#anchors+1],
                castBarOffsetX=sign*9000,castBarOffsetY=-sign*8000}
            f.units.player=config
            local owner=f.Frame(scale);owner.config=config;owner._fpUnit='player'
            function owner:GetFrameStrata()return 'MEDIUM' end
            function owner:GetFrameLevel()return 10 end
            owner.Texts={};ns.frames={player=owner}
            local target=f.Frame(scale,600,20)
            local cast=MakeFrame(config).Elements.CastBar
            for key,value in pairs(cast)do
                if key~='SetPoint' and key~='ClearAllPoints' then target[key]=value end
            end
            owner.Elements={CastBar=target}
            local function Apply()
                local options=Options(config)
                for _,key in ipairs({'castBarPoint','castBarRelativePoint','castBarOffsetX','castBarOffsetY'})do
                    options[key]=config[key]
                end
                runtime.ApplyLayout(owner,options)
            end
            local controls=Build(config)
            Near(controls[1].value,config.castBarOffsetX);Near(controls[2].value,config.castBarOffsetY)
            assert(controls[1].max>=9000 and controls[2].max>=8000,'Existing offsets were excluded')
            controls[1].callback(sign*8500);controls[2].callback(-sign*7500)
            Near(config.castBarOffsetX,sign*8500);Near(config.castBarOffsetY,-sign*7500)
            Apply()
            local zone=f.Frame(scale);zone._focalPointVisualTarget=target;zone._focalPointOwnerFrame=owner;zone._focalPointObjectRef=ref
            local descriptor=assert(f.describe(owner,ref))
            local startX,startY=target.cx,target.cy
            assert(f.begin(zone,{directMove=descriptor}));zone.scripts.OnUpdate(zone)
            Near(target.cx,startX);Near(target.cy,startY) -- no pull back to 500
            f.move(sign*1200,-sign*1200);zone.scripts.OnUpdate(zone)
            Near((target.cx-startX)*scale,sign*1200);Near((target.cy-startY)*scale,-sign*1200)
            local previewX,previewY=target.cx,target.cy
            f.finish(zone,true)
            assert(math.abs(config.castBarOffsetX)>9000 and math.abs(config.castBarOffsetY)>8000)
            assert(inspector.SetActiveCanvasDirectMoveOffsetValues('player',ref,config.castBarOffsetX,config.castBarOffsetY))
            Near(controls[1].value,config.castBarOffsetX);Near(controls[2].value,config.castBarOffsetY)
            assert(not suppressed(controls[1]) and not suppressed(controls[2]))
            Apply();Near(target.cx,previewX);Near(target.cy,previewY)
            Near(target.width,600);Near(target.icon.width,20)
            Near(textBudget('CastName',{anchorTo='CastBar'},target),544)
            Near(textBudget('CastTime',{anchorTo='CastBar'},target),48)
            -- Reopen and runtime reapply; native /reload remains an ingame smoke.
            Build(config);Apply();Near(target.cx,previewX);Near(target.cy,previewY)
            local _,maxX,_,maxY=ns.GUI.Editor.AnchorGeometry.ResolveCastBarOffsetRange(owner,
                {width=240,castBarWidthMode='CUSTOM',castBarWidth=600,castBarHeight=20})
            assert(maxX>=1920/scale+240+600 and maxY>=1080/scale+60+20)
            local _,fallbackX=ns.GUI.Editor.AnchorGeometry.ResolveCastBarOffsetRange(nil,
                {scale=scale,width=240,castBarWidthMode='CUSTOM',castBarWidth=600,castBarHeight=20})
            Near(fallbackX,maxX)
            cases=cases+1
        end
    end
end
-- Existing non-CastBar contract remains bounded after the shared scale conversion.
ref={kind='bar',objectKey='ClassPowerBar',unit='player'}
local owner=f.Frame(1.5);owner._fpUnit='player';owner.config={};f.units.player=owner.config
local target=f.Frame(1.5);target:SetPoint('CENTER',owner,'CENTER',0,0)
local zone=f.Frame(1.5);zone._focalPointVisualTarget=target;zone._focalPointOwnerFrame=owner;zone._focalPointObjectRef=ref
local descriptor=assert(f.describe(owner,ref))
assert(f.begin(zone,{directMove=descriptor}));f.move(3000,-3000);zone.scripts.OnUpdate(zone)
Near(target.cx-owner.cx,500);Near(target.cy-owner.cy,-500);f.finish(zone,false)
print('PASS CastBarFreePosition: '..cases..' scale/anchor/sign Inspector-Canvas-runtime cases, dynamic ranges, other component limit')
