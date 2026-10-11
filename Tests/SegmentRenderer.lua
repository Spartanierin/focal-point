-- lua54 Tests/SegmentRenderer.lua
-- Existing real Class Power adapter plus isolated holder-only presentation.
-- Native pixel/font/animation parity still requires ingame acceptance.
local function Read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local h=assert(load(Read("Tests/ClassPowerRunes.lua")..[[
return {ns=ns,Defaults=Defaults,Frame=Frame,Eq=Eq,Equal=Equal,Near=Near,Copy=Copy}
]],"@SegmentRenderer/Fixture"))()
local Eq,Equal,Near=h.Eq,h.Equal,h.Near
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Left(bar,holder)
    if bar==holder then return 0 end
    local point,relative,relativePoint,x=bar:GetPoint(1)
    Eq(bar:GetNumPoints(),1)
    local left=Left(relative,holder)+x
    if relativePoint:find("RIGHT",1,true)then left=left+relative:GetWidth()end
    if point:find("RIGHT",1,true)then left=left-bar:GetWidth()end
    return left
end
Test("Class Power adapter preserves fractional fills, geometry and all style channels",function()
    for _,growth in ipairs({"LEFT_TO_RIGHT","RIGHT_TO_LEFT"})do
        for _,current in ipairs({0,2.5,5})do
            for _,alpha in ipairs({0,.65,1})do
                h.Defaults();local frame=h.Frame();local holder=frame.Elements.ClassPowerBar
                h.ns.UnitFrameClassPower.ApplyLayout(frame,{
                    classPowerBarVisible=true,classPowerBarGrowth=growth,
                    classPowerBarWidth=112,classPowerBarHeight=13,classPowerBarSpacing=3,
                    classPowerBarPoint="TOPLEFT",classPowerBarRelativePoint="BOTTOMLEFT",
                    classPowerBarOffsetX=7,classPowerBarOffsetY=-9,
                    liveClassPowerCurrent=current,liveClassPowerMax=5,
                    useBlizzardColorClassPower=false,classPowerTexture="parity-texture",
                    classPowerR=.2,classPowerG=.4,classPowerB=.6,classPowerA=alpha,
                    classPowerBgR=.1,classPowerBgG=.2,classPowerBgB=.3,classPowerBgA=0,
                    classPowerBackgroundShown=false,
                    classPowerBorderR=.7,classPowerBorderG=.8,classPowerBorderB=.9,classPowerBorderA=0,
                })
                local point,parent,relativePoint,x,y=holder:GetPoint(1)
                Eq(parent,frame);Equal({point,relativePoint,x,y},{"TOPLEFT","BOTTOMLEFT",7,-9})
                Eq(holder:GetWidth(),112);Eq(holder:GetHeight(),13)
                local fills=current==0 and {0,0,0,0,0} or current==5 and {1,1,1,1,1} or {1,1,.5,0,0}
                for i,bar in ipairs(holder.Bars)do
                    Eq(bar:IsShown(),i<=5)
                    if i<=5 then
                        Near(Left(bar,holder),(growth=="RIGHT_TO_LEFT" and 5-i or i-1)*23)
                        Eq(bar:GetWidth(),20);Eq(bar:GetHeight(),13);Eq(bar:GetValue(),fills[i])
                        Equal(bar.lastSetStatusBarTexture,{"parity-texture"})
                        Equal(bar.lastSetStatusBarColor,{.2,.4,.6,alpha})
                        Equal(bar.bg.lastSetTexture,{"parity-texture"})
                        Equal(bar.bg.lastSetVertexColor,{.1,.2,.3,0});assert(not bar.bg:IsShown())
                        Equal(bar.border.lastSetBackdropBorderColor,{.7,.8,.9,0});assert(bar.border:IsShown())
                        assert(not bar.lastSetReverseFill and not bar.lastSetOrientation)
                    else assert(not bar.border:IsShown())end
                end
            end
        end
    end
end)

-- A strict namespace/environment makes gameplay, DB, layout, LiveValues and event
-- dependencies fail at their first access, including inside countdown ticks.
local clock=100
local isolated=setmetatable({TextElementUtils=h.ns.TextElementUtils}, {
    __index=function(_,key)
        if key=="MediaRegistry" then return nil end
        error("unexpected renderer namespace access: "..key)
    end,
})
local environment=setmetatable({math=math,string=string,type=type,ipairs=ipairs,pcall=pcall,
    issecretvalue=function()return false end,
    STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF",GetTime=function()return clock end}, {
    __index=function(_,key)error("unexpected renderer global access: "..key)end,
})
assert(load(Read("Engine/UnitFrame/Bars/UnitFrameSegmentRenderer.lua"),"@IsolatedRenderer","t",environment))("FocalPoint",isolated)
local renderer=isolated.UnitFrameSegmentRenderer
Test("holder-only renderer honors supplied slots, timing identity and pure countdown updates",function()
    for _,rtl in ipairs({false,true})do
        h.Defaults();local frame=h.Frame();local holder=frame.Elements.ClassPowerBar
        local bars={table.unpack(holder.Bars)}
        local segments={
            {index=1,ready=true},{index=2,ready=false,startTime=95,duration=10},
            {index=3,ready=false,startTime=98,duration=10},{index=4,ready=false},
            {index=5,ready=true},{index=6,ready=false,startTime=99,duration=8},
        }
        local before=h.Copy(segments);local slots={2,3,5,6,1,4};clock=100
        local options={width=130,height=12,spacing=2,rightToLeft=rtl,
            point="CENTER",anchorParent=frame,relativePoint="CENTER",x=0,y=0,
            current=2,max=6,segments=segments,visualSlots=slots,
            texture="isolated-texture",r=.2,g=.4,b=.6,a=1,
            bgR=0,bgG=0,bgB=0,bgA=.35,borderR=0,borderG=0,borderB=0,borderA=.85,
            timerFontSize=16,timerFontStyle="OUTLINE_MONOCHROME"}
        renderer.Apply(holder,options)
        for i=1,6 do
            Eq(holder.Bars[i],bars[i]);Eq(bars[i].Countdown:GetParent(),bars[i])
            Near(Left(bars[i],holder),(rtl and 6-slots[i] or slots[i]-1)*22)
            local font,size,flags=bars[i].Countdown:GetFont()
            Eq(font,"Fonts\\FRIZQT__.TTF");Eq(size,16);Eq(flags,"OUTLINE,MONOCHROME")
        end
        Eq(bars[2].Countdown:GetText(),"5.0");Eq(bars[3].Countdown:GetText(),"8.0")
        Eq(bars[4]:GetValue(),0);assert(not bars[4].Countdown:IsShown())
        local tick=assert(holder:GetScript("OnUpdate"))
        for i=1,600 do clock=100+i/60;tick(holder)end
        assert(not holder:GetScript("OnUpdate"));Equal(segments,before)
        renderer.PlayHighlight(bars[1]);assert(bars[1].ReadyHighlight.animation.playing)
        renderer.StopHighlight(bars[1]);assert(not bars[1].ReadyHighlight:IsShown())
        renderer.ClearTiming(holder);assert(not holder.segments)
        for i=1,10 do Eq(holder.Bars[i],bars[i]);assert(not bars[i].Countdown:IsShown())end
    end
end)
print("Segment Renderer: "..count.." groups PASS")
