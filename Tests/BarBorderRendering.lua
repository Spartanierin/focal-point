-- Local frame/texture doubles prove ownership and geometry, not native pixels.
local ns = {}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
local createdFrames, createdTextures = 0, 0
local methods = {}
local function Region(parent)
    return setmetatable({parent=parent, points={}, width=120, height=20, level=1,
        alpha=1, shown=true, scripts={}}, {__index=methods})
end
function CreateFrame(_, _, parent) createdFrames=createdFrames+1; return Region(parent) end
function methods:CreateTexture() createdTextures=createdTextures+1; return Region(self) end
function methods:SetAllPoints(target) self.allPoints=target or self.parent end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetSize(w,h)
    self.width,self.height=w,h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
end
function methods:SetWidth(w) self:SetSize(w,self.height) end
function methods:SetHeight(h) self:SetSize(self.width,h) end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(n) self.level=n end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:SetFrameStrata(v) self.strata=v end
function methods:EnableMouse(v) self.mouse=v end
function methods:SetTexture(v) self.texture=v end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetStatusBarTexture(v) self.fillTexture=v end
function methods:SetStatusBarColor(...) self.fillColor={...} end
function methods:SetReverseFill(v) self.reverse=v end
function methods:SetMinMaxValues(...) self.range={...} end
function methods:SetValue(v) self.value=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:EffectiveAlpha() return self.alpha*(self.parent and self.parent:EffectiveAlpha() or 1) end
function methods:HookScript(event,fn) assert(not self.scripts[event]); self.scripts[event]=fn end
local function Forbidden() error("unexpected gameplay read") end
UnitHealth,UnitPower,UnitCastingInfo,GetRuneCooldown=Forbidden,Forbidden,Forbidden,Forbidden
Load("Services/LayoutService.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameFactory.lua")
Load("Engine/UnitFrame/Bars/UnitFrameBarLayout.lua")
local F,B=ns.UnitFrameFactory,ns.UnitFrameBarLayout
local count=0
local function Test(name,run) run();count=count+1;print("PASS: "..name) end
local function Equal(a,b)
    if rawequal(a,b) then return end
    if type(a)~="table" or type(b)~="table" then assert(a==b,tostring(a).." ~= "..tostring(b));return end
    for k,v in pairs(a) do Equal(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil) end
end
Test("missing/zero are allocation-free; 1/5 use four inside edges and independent alpha",function()
    local owner=Region();local frames,textures=createdFrames,createdTextures
    F.ApplyBarBorder(owner);F.ApplyBarBorder(owner,0)
    assert(not owner.BarBorder and frames==createdFrames and textures==createdTextures)
    for _,w in ipairs({1,5}) do
        F.ApplyBarBorder(owner,w,{r=.1,g=.2,b=.3,a=0},true)
        local border=owner.BarBorder;assert(border.parent==owner and border.allPoints==owner)
        assert(#border.edges==4 and border.level>owner.level and border.mouse==false)
        local top,bottom,left,right=table.unpack(border.edges)
        assert(top.height==w and bottom.height==w and left.width==w and right.width==w)
        assert(top.points[1][2]==owner and left.points[1][5]==-w and left.points[2][5]==w)
        for _,edge in ipairs(border.edges) do Equal(edge.color,{.1,.2,.3,0}) end
        assert(owner.width==120 and owner.height==20 and #owner.points==0)
    end
    assert(createdFrames==frames+1 and createdTextures==textures+4)
end)
Test("small/fractional geometry saturates without corner overlap or stored width changes",function()
    local owner=Region();F.ApplyBarBorder(owner,5)
    owner:SetSize(120,4)
    local b=owner.BarBorder;assert(b.requestedWidth==5 and b.edges[1].height==2)
    assert(not b.edges[3].shown and not b.edges[4].shown)
    owner:SetSize(3.5,20);assert(b.edges[1].height==1.75 and b.edges[3].width==1.75)
    assert(b.edges[3].shown and b.edges[3].points[1][5]==-1.75)
    owner:SetSize(120,20);assert(b.edges[1].height==5 and b.edges[3].shown)
    owner:SetSize(0,20);assert(not b.shown)
    owner:SetSize(120,20);assert(b.shown)
    local secret={};issecretvalue=function(v)return rawequal(v,secret)end
    owner.scripts.OnSizeChanged(owner,secret,20);assert(not b.shown)
    issecretvalue=nil;owner:SetSize(120,20);assert(b.shown)
end)
Test("parent visibility/alpha and 50 style/clear/resize/reuse cycles create no new objects",function()
    local root=Region();local owner=Region(root);F.ApplyBarBorder(owner,1)
    local b=owner.BarBorder;local frames,textures=createdFrames,createdTextures
    root:SetAlpha(.5);owner:SetAlpha(.4);assert(b:EffectiveAlpha()==.2)
    root:SetAlpha(0);assert(b:EffectiveAlpha()==0)
    for i=1,50 do
        owner:Hide();assert(not b:IsVisible())
        F.ApplyBarBorder(owner,0);owner:SetSize(100+i,4);owner:Show()
        assert(not b:IsVisible());for _,edge in ipairs(b.edges)do assert(not edge.shown)end
        F.ApplyBarBorder(owner,5,{.2,.3,.4,i%2})
        assert(b:IsVisible() and b.edges[1].height==2)
        Equal(b.edges[1].color,{.2,.3,.4,i%2})
        owner:SetSize(200,20);assert(b.edges[1].height==5)
        assert(owner.BarBorder==b and createdFrames==frames and createdTextures==textures)
        assert(not owner.scripts.OnUpdate and not b.scripts.OnUpdate)
    end
end)
Test("Health and Power adapters preserve anchors/fills and consume their own fields",function()
    local frame=Region();frame.Elements={};frame.config={healthBarBorderWidth=1,powerBarBorderWidth=5,
        healthBarBorderColor={r=1,g=0,b=0,a=0},powerBarBorderColor={0,1,0,.5}}
    F.CreateHealthBar(frame);F.CreatePowerBar(frame)
    local owner={UpdateHealthBarColor=function()end}
    local options={borderInset=1,showPowerBar=true,powerBarHeight=8,alternativePowerBarHeight=0,
        healthTexture="health",powerTexture="power",healthBarReverseFill=true,powerBarReverseFill=false}
    B.ApplyHealthAndPower(owner,frame,options)
    local health,power=frame.Elements.HealthBar,frame.Elements.PowerBar
    assert(health.BarBorder.edges[1].height==1 and power.BarBorder.edges[1].height==4)
    Equal(health.BarBorder.edges[1].color,{1,0,0,0});Equal(power.BarBorder.edges[1].color,{0,1,0,.5})
    local hp,pp=health.points,power.points
    frame.config.healthBarBorderWidth=0;frame.config.powerBarBorderWidth=0
    B.ApplyHealthAndPower(owner,frame,options)
    Equal(health.points,hp);Equal(power.points,pp)
    assert(health.reverse and not power.reverse and health.fillTexture=="health" and power.fillTexture=="power")
    assert(not health.BarBorder.shown and not power.BarBorder.shown)
end)
Test("holder overlay is above child bars and fixed borders without changing their levels",function()
    local owner=Region();owner.level=4;owner.Bars={Region(owner),Region(owner)}
    for i,bar in ipairs(owner.Bars)do bar.level=5+i;bar.border=Region(bar);bar.border.level=7+i end
    F.ApplyBarBorder(owner,1)
    assert(owner.BarBorder.level==10 and owner.level==4)
    assert(owner.Bars[1].level==6 and owner.Bars[2].border.level==9)
    local border=owner.BarBorder
    owner.Bars[1].border.level=12;F.ApplyBarBorder(owner,5)
    assert(owner.BarBorder==border and border.level==13 and owner.Bars[1].level==6)
end)
Test("Alternative Power and both Absorb bars keep their geometry, layers and visibility",function()
    local frame=Region();frame.Elements={};frame.config={alternativePowerBarBorderWidth=5}
    F.CreateAlternativePowerBar(frame)
    B.ApplyAlternativePower(frame,{borderInset=1,alternativePowerBarVisible=true,alternativePowerBarHeight=4})
    local alt=frame.Elements.AlternativePowerBar;assert(alt.BarBorder.edges[1].height==2)
    assert(alt.BarBorder.parent==alt and alt.height==4)
    B.ApplyAlternativePower(frame,{borderInset=1,alternativePowerBarVisible=false,alternativePowerBarHeight=4})
    assert(not alt.BarBorder:IsVisible())
    Load("Engine/UnitFrame/Bars/UnitFrameAbsorbBars.lua")
    local A=ns.UnitFrameAbsorbBars
    for _,name in ipairs({"Normal","Healing"})do
        local prefix=name:lower().."AbsorbBar"
        local bar=A["Create"..name.."AbsorbBar"](frame);local level=bar.level
        local config={[prefix.."SizeMode"]="CUSTOM",[prefix.."Width"]=90,[prefix.."Height"]=4,
            [prefix.."BorderWidth"]=5,[prefix.."BorderColor"]={1,.5,0,0}}
        A["Apply"..name.."AbsorbBarAnchor"](frame,config)
        assert(bar.BarBorder.parent==bar and bar.BarBorder.edges[1].height==2)
        assert(bar.width==90 and bar.height==4 and bar.level==level and not bar:IsVisible())
        Equal(bar.BarBorder.edges[1].color,{1,.5,0,0})
        config[prefix.."SizeMode"]="MATCH_TARGET"
        A["Apply"..name.."AbsorbBarAnchor"](frame,config)
        assert(bar.allPoints==frame and bar.BarBorder.allPoints==bar)
    end
end)
Test("Cast border belongs to the StatusBar, excludes icon and preserves end-flash hold",function()
    ns.UnitFrameUtils={UnpackColor=function(color,fallback)return table.unpack(color or fallback)end}
    Load("Engine/UnitFrame/Bars/UnitFrameCastBar.lua")
    local frame=Region();frame.Elements={};frame.config={castBarBorderWidth=5}
    F.CreateCastBar(frame);local cast=frame.Elements.CastBar;cast.isCasting=true
    local C=ns.UnitFrameCastBar
    local options={showCastBar=true,showCastBarIcon=true,castBarHeight=12,width=200,borderInset=1,
        castBarPoint="TOPLEFT",castBarRelativePoint="BOTTOMLEFT",castBarOffsetX=0,castBarOffsetY=-5}
    C.ApplyLayout(frame,options)
    assert(cast.BarBorder.parent==cast and cast.BarBorder.allPoints==cast and not cast.icon.BarBorder)
    assert(cast.BarBorder.edges[1].height==5 and cast.icon.width==12)
    local width=cast.width;local points=cast.points;local keep=C.KeepEndFlash
    C.KeepEndFlash=function()return true end
    frame.config.castBarBorderWidth=0;options.width=300;C.ApplyLayout(frame,options)
    assert(cast.width==width and cast.points==points and cast.BarBorder.requestedWidth==5)
    C.KeepEndFlash=keep;C.ApplyLayout(frame,options);assert(not cast.BarBorder.shown)
end)

-- Real snapshot/factory/renderer/pool integration, in a separate fixture namespace.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/SegmentedBarRuntime.lua")
local boundary=assert(source:find('Test("two independent',1,true))
local h=assert(load(source:sub(1,boundary-1)..
    "\nreturn {ns=ns,UF=UF,Setup=Setup,Holders=Holders,f=f}","@Border/Runtime"))()
Test("legacy and instance holders get one border; segments, growth and API-read counts stay unchanged",function()
    local frame,legacy=h.Setup();local api=GetRuneCooldown;local reads=0
    GetRuneCooldown=function(...)reads=reads+1;return api(...)end
    frame.config.classPowerBarBorderWidth=5;frame.config.classPowerBarBorderColor={.1,.2,.3,0}
    local records=frame.config.segmentedBars
    records[1].borderWidth=1;records[1].borderColor={1,0,0,.5}
    records[2].borderWidth=5;records[2].borderColor={0,1,0,0}
    h.UF:Refresh(frame);assert(reads==6)
    local a,b=h.Holders(frame)
    for _,holder in ipairs({legacy,a,b})do
        assert(holder.BarBorder and #holder.BarBorder.edges==4 and holder.BarBorder.parent==holder)
        for _,bar in ipairs(holder.Bars)do assert(bar.border and not bar.BarBorder)end
    end
    h.f.Equal(a.BarBorder.edges[1].lastSetVertexColor,{1,0,0,.5})
    h.f.Equal(b.BarBorder.edges[1].lastSetVertexColor,{0,1,0,0})
    local borders={legacy.BarBorder,a.BarBorder,b.BarBorder}
    -- Keep API function identity: it is part of the canonical snapshot context.
    for i=1,50 do
        h.ns.UnitFrameSegmentedBars.Clear(frame)
        assert(not a.BarBorder:IsVisible() and not b.BarBorder:IsVisible())
        records[1].growth=i%2==0 and "LEFT_TO_RIGHT" or "RIGHT_TO_LEFT"
        records[1].height=i%2==0 and 4 or 14
        records[1].borderWidth=i%2==0 and 5 or 0
        h.UF:ApplyConfig(frame)
        assert(reads==6, "extra gameplay read in layout")
        assert(legacy.BarBorder==borders[1] and a.BarBorder==borders[2] and b.BarBorder==borders[3])
        assert(a.BarBorder:IsShown()==(i%2==0), "cycle="..i.." shown="..tostring(a.BarBorder:IsShown()).." requested="..tostring(a.BarBorder.requestedWidth).." record="..tostring(frame.config.segmentedBars[1].borderWidth))
        if i%2==0 then assert(a.BarBorder.edges[1]:GetHeight()==2)end
        h.ns.UnitFrameSegmentRenderer.ClearTiming(a)
        assert(not a:GetScript("OnUpdate"))
    end
    -- Actual holder pool reuse, with the next record's border disabled.
    frame.config.segmentedBars={};h.ns.UnitFrameSegmentedBars.Apply(frame)
    assert(not a.BarBorder:IsVisible() and not b.BarBorder:IsVisible())
    local record=h.f.Copy(records[1]);record.id="segmented-bar-reused";record.borderWidth=0
    frame.config.segmentedBars={record};h.ns.UnitFrameSegmentedBars.Apply(frame)
    local reused=frame._segmentedBars.byId[record.id]
    assert((reused==a or reused==b) and not reused.BarBorder:IsShown())
    GetRuneCooldown=api
end)
print("Bar Border Rendering: "..count.." groups PASS")
