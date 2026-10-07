-- M1.2: pure canonical geometry and parity with the applied layout pipeline.
-- Optional extraction audit: lua Tests/UnitFrameGeometry.lua --compare-head
-- reads the pre-extraction modules from HEAD without checking out files.
local function Equal(a, b, context)
    context = context or "value"
    assert(type(a) == type(b), context .. ": type mismatch")
    if type(a) ~= "table" then
        assert(a == b, context .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return
    end
    for k, v in pairs(a) do Equal(v, b[k], context .. "." .. tostring(k)) end
    for k in pairs(b) do assert(a[k] ~= nil, context .. ": unexpected " .. tostring(k)) end
end
local function Copy(t)
    if type(t) ~= "table" then return t end
    local r = {}; for k, v in pairs(t) do r[k] = Copy(v) end; return r
end
local function Noop() end
local function Rect(l, r, b, t) return {left=l, right=r, bottom=b, top=t} end
local function Load(ns, path, baseline)
    if baseline then
        local pipe = assert(io.popen('git show HEAD:' .. path, "r"))
        local source = pipe:read("*a"); assert(pipe:close())
        assert(load(source, "@HEAD:" .. path))("FocalPoint", ns)
    else
        assert(loadfile(path))("FocalPoint", ns)
    end
end

-- Only the application tests use frame doubles. The canonical API below runs
-- with live APIs and frame construction forbidden.
local function Frame(name, parent)
    local f = {name=name, parent=parent, points={}, shown=false, width=0, height=0, scale=1}
    function f:ClearAllPoints() self.points={} end
    function f:SetPoint(point, target, relativePoint, x, y)
        self.points[point]={target=target.name, relativePoint=relativePoint, x=x, y=y}
    end
    function f:SetSize(w,h) self.width=w; self.height=h end
    function f:SetHeight(h) self.height=h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetScale(s) self.scale=s end
    function f:GetEffectiveScale() return self.scale end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:SetShown(s) self.shown=s end
    function f:IsShown() return self.shown end
    function f:IsProtected() return false end
    function f:Rect()
        local p=self.points
        if self.name=="HealthBar" then
            return Rect(p.TOPLEFT.x, self.parent.width+p.TOPRIGHT.x,
                p.BOTTOMLEFT.y, self.parent.height+p.TOPLEFT.y)
        elseif self.name=="PowerBar" then
            return Rect(p.BOTTOMLEFT.x, self.parent.width+p.BOTTOMRIGHT.x,
                p.BOTTOMLEFT.y, p.BOTTOMLEFT.y+self.height)
        end
        return Rect(0,self.width,0,self.height)
    end
    function f:GetCenter()
        local r=self:Rect(); return (r.left+r.right)/2,(r.bottom+r.top)/2
    end
    for _, method in ipairs({"SetAlpha","SetFrameLevel","SetFrameStrata","EnableMouse",
        "SetMouseClickEnabled","SetClampedToScreen","SetBackdropColor","SetBackdropBorderColor",
        "SetStatusBarTexture","SetStatusBarColor","SetReverseFill","SetAllPoints","SetTexture",
        "SetMinMaxValues","SetValue"}) do f[method]=Noop end
    return f
end
UIParent=Frame("UIParent")
InCombatLockdown=function() return false end
UnitExists=function() return true end

local function Namespace(baseline)
    local ns={
        UnitFrameUtils={UnpackColor=function(c,d) return table.unpack(c or d) end},
        UnitFrameAssets={GetStatusBarTexture=function() return "fixture" end},
        UnitFramePresence={IsPreviewModeEnabled=function() return true end},
        UnitFrameClassPower={ApplyLayout=Noop},
        UnitFrameClassificationIndicator={ApplyLayout=Noop},
    }
    for _, path in ipairs({
        "Engine/UnitFrame/Shared/UnitFrameColors.lua",
        "Engine/UnitFrame/Shared/UnitFramePreview.lua",
        "Engine/UnitFrame/Runtime/UnitFrameLayout.lua",
        "Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua",
        "Engine/UnitFrame/Bars/UnitFrameBarLayout.lua",
        "Engine/UnitFrame/Indicators/UnitFramePortrait.lua",
        "Engine/UnitFrame/Indicators/UnitFrameIndicators.lua",
    }) do Load(ns,path,baseline) end
    -- Explicit visibility input for the applied path, independently supplied
    -- from canonical configuration. No live decision is changed in production.
    ns.UnitFramePreview.GetSecondaryPowerValues=function()
        if ns.altVisible then return 0,0,100,0 end
    end
    Load(ns,"Engine/UnitFrame.lua",baseline)
    return ns
end
local ns=Namespace()
local Bar,Inside,Layout=ns.UnitFrameBarLayout,ns.UnitFrameInsideLayout,ns.UnitFrameLayout
Load(ns,"GUI/Editor/EditorAnchorGeometry.lua")
assert(ns.GUI.Editor.AnchorGeometry.GetRectAnchor==Layout.GetRectAnchor)

local base={width=220,height=40,powerBarPresent=true,showPowerBar=true,powerBarHeight=8}
local function Canonical(config,unit)
    local saved=Copy(config)
    local names={"CreateFrame","UnitExists","UnitPower","GetRaidTargetIndex","UnitGroupRolesAssigned","UnitAffectingCombat"}
    local previous={}
    for _, name in ipairs(names) do
        previous[name]=_G[name]; _G[name]=function() error("Live API accessed: "..name) end
    end
    local ok,result=pcall(Bar.ComputeCanonicalRects,config,unit or "target")
    for _, name in ipairs(names) do _G[name]=previous[name] end
    assert(ok,result); Equal(config,saved,"immutable config")
    return result
end
local g=Canonical(base)
Equal(g.Frame,Rect(0,220,0,40)); Equal(g.HealthBar,Rect(1,219,9,39))
Equal(g.PowerBar,Rect(1,219,1,9)); assert(g.powerBarEnabled)
local disabled=Copy(base); disabled.showPowerBar=false
disabled.Buffs={anchorTo="PowerBar",insideAnchorTo="HealthBar",enabled=true}
disabled.Debuffs={anchorTo="HealthBar",enabled=false}
g=Canonical(disabled)
assert(not g.powerBarEnabled); Equal(g.PowerBar,Rect(1,219,1,9))
Equal(g.HealthBar,Rect(1,219,1,39))
local absent=Copy(base); absent.powerBarPresent=false
Equal(Canonical(absent).HealthBar,Rect(1,219,1,39))
Equal(Canonical({}).PowerBar,Rect(1,219,1,9))

local points={LEFT={10,50},RIGHT={50,50},TOP={30,80},BOTTOM={30,20},CENTER={30,50},
    TOPLEFT={10,80},TOPRIGHT={50,80},BOTTOMLEFT={10,20},BOTTOMRIGHT={50,20}}
for point, expected in pairs(points) do Equal({Layout.GetRectAnchor(Rect(10,50,20,80),point)},expected,point) end
local alternative=Copy(base)
alternative.alternativePowerBarPresent=true; alternative.showAlternativePowerBar=true
alternative.alternativePowerBarHeight=5
g=Canonical(alternative,"player")
Equal(g.Frame,Rect(0,220,0,45)); Equal(g.HealthBar,Rect(1,219,14,44)); Equal(g.PowerBar,Rect(1,219,6,14))
Equal({Layout.GetRectAnchor(g.Frame,"CENTER")},{110,22.5})
Equal({Layout.GetRectAnchor(g.Frame,"TOP")},{110,45})
Equal({Layout.GetRectAnchor(g.Frame,"BOTTOM")},{110,0})
for _,unit in ipairs({"target","focus","party1","boss1","pet"}) do
    Equal(Canonical(alternative,unit).Frame,Rect(0,220,0,40),unit.." no fallback")
end
local latentAlt=Copy(alternative); latentAlt.showPowerBar=false
Equal(Canonical(latentAlt,"player").HealthBar,Rect(1,219,6,44))
Equal(Canonical(latentAlt,"player").PowerBar,Rect(1,219,6,14))
for _,field in ipairs({"alternativePowerBarPresent","showAlternativePowerBar"}) do
    local off=Copy(alternative); off[field]=false
    Equal(Canonical(off,"player").Frame,Rect(0,220,0,40))
end

local function Indicator(size,scale,padding,area,side)
    return {present=true,enabled=true,placement="INSIDE",size=size,scale=scale,padding=padding,
        insideAnchorTo=area,insideSide=side}
end
local lanes=Copy(base)
lanes.Portrait=Indicator(10,1.25,0.5,"Frame","LEFT") -- 13
lanes.RaidTargetIcon=Indicator(10,1.5,99,"HealthBar","RIGHT") -- 15; first padding excluded
lanes.LeaderIcon=Indicator(4,2,0.5,"HealthBar","RIGHT") -- +3.5+8 = 26.5
lanes.RoleIcon=Indicator(6,0.5,-4,"HealthBar","LEFT") -- 3; first padding excluded
lanes.CombatIndicator=Indicator(100,1,2,"Frame","RIGHT")
lanes.CombatIndicator.effect="FRAME_OVERLAY" -- no lane reserve
lanes.RestingIndicator=Indicator(4.5,1.5,2,"PowerBar","LEFT") -- 6.75
lanes.ReadyCheckIndicator=Indicator(3.5,1,2,"Frame","RIGHT")
g=Canonical(lanes)
Equal({g.options.frameLeftReserve,g.options.frameRightReserve,g.options.healthLeftReserve,
    g.options.healthRightReserve,g.options.powerLeftReserve,g.options.powerRightReserve},{13,3.5,3,26.5,6.75,0})
Equal(g.HealthBar,Rect(17,189,9,39)); Equal(g.PowerBar,Rect(20.75,215.5,1,9))
local inputs=Inside.ResolveGeometryInputs(lanes)
local block=Inside.ComputeLaneBlock({inputs.entries[1],inputs.entries[2]})
Equal(block.width,26.5); Equal(block.items[2].spacingBefore,3.5); Equal(block.items[2].edgeOffset,18.5)
local hidden=Copy(lanes)
hidden.Portrait.enabled=false; hidden.RaidTargetIcon.present=false; hidden.LeaderIcon.enabled=false
Equal(Canonical(hidden).options.healthRightReserve,0)
Equal(Canonical(hidden).options.frameLeftReserve,0)
local symmetric=Copy(base)
symmetric.LeaderIcon=Indicator(12,1,2,"HealthBar","LEFT")
symmetric.RoleIcon=Indicator(12,1,2,"HealthBar","RIGHT")
Equal(Canonical(symmetric).HealthBar,Rect(13,207,9,39))
Equal({Layout.GetRectAnchor(Canonical(symmetric).HealthBar,"CENTER")},{110,24})
local fractional=Copy(base); fractional.width=220.5; fractional.height=40.25; fractional.powerBarHeight=8.75
Equal(Canonical(fractional).HealthBar,Rect(1,219.5,9.75,39.25))
Equal(Canonical(fractional).PowerBar,Rect(1,219.5,1,9.75))
local defaults=Copy(base); defaults.Portrait={present=true}; defaults.RaidTargetIcon={present=true,placement="INSIDE"}
Equal(Canonical(defaults).options.frameLeftReserve,44)
Equal(Canonical(defaults).options.frameRightReserve,18)

local forty=Copy(base); forty.RaidTargetIcon=Indicator(40,1,2,"HealthBar","RIGHT")
g=Canonical(forty)
Equal(g.options.healthRightReserve,40)
local hx,hy=Layout.GetRectAnchor(g.HealthBar,"RIGHT")
local fx,fy=Layout.GetRectAnchor(g.Frame,"RIGHT")
Equal({hx,hy},{179,24}); Equal({fx,fy},{220,20}); Equal({hx-fx,hy-fy},{-41,4})
Equal({7+hx-fx,-3+hy-fy},{-34,1}); Equal({hx+7,hy-3},{186,21})
Equal({fx-34,fy+1},{186,21}) -- geometry only, no Aura migration

local keys={"Portrait","RaidTargetIcon","LeaderIcon","RoleIcon","CombatIndicator","RestingIndicator","ReadyCheckIndicator"}
local function Applied(runtime,config,unit,altVisible,hiddenKeys)
    runtime.altVisible=altVisible
    local saved=Copy(config)
    local frame=Frame("Frame"); frame.config=config; frame._fpUnit=unit; frame.Elements={}
    for _,key in ipairs({"HealthBar","PowerBar","AlternativePowerBar",table.unpack(keys)}) do
        frame.Elements[key]=Frame(key,frame)
    end
    local owner={UpdateHealthBarColor=Noop,ApplyRangeFade=Noop,UpdatePortraitTexture=Noop}
    function owner:GetAnchorTarget(f,key) return f.Elements[key] or f end
    for _,key in ipairs(keys) do
        owner["Update"..key]=function(_,f) f.Elements[key]:SetShown(not (hiddenKeys and hiddenKeys[key])) end
    end
    runtime.UnitFrame.ApplyConfig(owner,frame)
    Equal(config,saved,"applied immutable config")
    local snapshot={Frame={width=frame.width,height=frame.height,points=Copy(frame.points),shown=frame.shown}}
    for key,element in pairs(frame.Elements) do
        snapshot[key]={width=element.width,height=element.height,points=Copy(element.points),shown=element.shown,scale=element.scale}
    end
    return frame,snapshot
end
local fixtures={base,disabled,absent,alternative,latentAlt,lanes,hidden,symmetric,fractional,defaults,forty}
local previous=arg and arg[1]=="--compare-head" and Namespace(true) or nil
local count=0
for index,config in ipairs(fixtures) do
    for _,unit in ipairs({"player","target"}) do
        for _,point in ipairs({"CENTER","TOP","BOTTOM"}) do
            local c=Copy(config); c.point=point; c.scale=1.25
            local pure=Canonical(c,unit)
            local frame,snapshot=Applied(ns,c,unit,pure.options.alternativePowerBarVisible)
            Equal(frame:Rect(),pure.Frame,"applied frame "..index)
            Equal(frame.Elements.HealthBar:Rect(),pure.HealthBar,"applied health "..index)
            if pure.powerBarEnabled then
                Equal(frame.Elements.PowerBar:Rect(),pure.PowerBar,"applied power "..index)
            else
                assert(not frame.Elements.PowerBar:IsShown()); Equal(frame.Elements.PowerBar.points,{})
            end
            local extension=pure.Frame.top-c.height
            local expectedY=point=="BOTTOM" and -extension/1.25 or point=="CENTER" and -extension/2/1.25 or 0
            Equal(frame.points[point].y,expectedY,"root extension compensation")
            if previous then
                local _,before=Applied(previous,c,unit,pure.options.alternativePowerBarVisible)
                Equal(snapshot,before,"HEAD parity "..index.." "..unit.." "..point)
            end
            count=count+1
        end
    end
end
-- Live visibility remains a separate input: no configured placeholder reserve
-- may leak into live bars when its actual holder is hidden.
local live,snapshot=Applied(ns,forty,"target",false,{RaidTargetIcon=true})
Equal(live.Elements.HealthBar:Rect(),Rect(1,219,9,39))
if previous then
    local _,before=Applied(previous,forty,"target",false,{RaidTargetIcon=true})
    Equal(snapshot,before,"hidden live indicator parity")
end
-- The canonical fallback also remains the one consumed by the real preview
-- predicate. Other units must not gain a simulated secondary power bar.
ns.UnitFrameUtils.GetUnitDB=function() return alternative end
ns.EditorVisualPolicy={Resolve=function() return "editor-simulated" end}
assert(ns.UnitFramePreview.ShouldForceSecondaryPowerPreview("player"))
assert(not ns.UnitFramePreview.ShouldForceSecondaryPowerPreview("target"))
ns.EditorVisualPolicy.Resolve=function() return "hidden" end
assert(not ns.UnitFramePreview.ShouldForceSecondaryPowerPreview("player"))
ns.UnitFrameUtils.GetUnitDB=nil

-- Existing Aura target selection and offsets survive the extraction, including
-- hidden PowerBar targets. This deliberately does NOT transform stored data.
Load(ns,"Engine/Auras/Layout/AuraAnchor.lua")
Load(ns,"Engine/Auras/Layout/AuraBlockLayout.lua")
for _,config in ipairs({base,disabled}) do
    local owner=Applied(ns,config,"target",false)
    for _,target in ipairs({"Frame","HealthBar","PowerBar"}) do
        for _,placement in ipairs({"ATTACHED","INSIDE"}) do
            local aura={enabled=true,placement=placement,point="TOPLEFT",relativePoint="RIGHT",
                anchorTo=placement=="ATTACHED" and target or "Frame",
                insideAnchorTo=placement=="INSIDE" and target or "Frame",offsetX=7,offsetY=-3}
            local saved=Copy(aura)
            local blockFrame=Frame("Buffs",owner)
            local resolved,x,y=ns.AuraBlockLayout.ApplyAnchor(blockFrame,owner,aura,"Buffs")
            assert(resolved==(owner.Elements[target] or owner))
            Equal({x,y},{7,-3}); Equal(aura,saved)
            Equal(blockFrame.points.TOPLEFT,{target=target,relativePoint="RIGHT",x=7,y=-3})
        end
    end
end
print("PASS UnitFrameGeometry: pure rects, nine anchors, latent/alternative power, lanes, immutable config; "..
    count.." applied fixtures; preview and Aura anchor regressions"..(previous and "; HEAD before/after parity" or ""))
