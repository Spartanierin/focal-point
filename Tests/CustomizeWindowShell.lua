-- Existing Workspace, real shell/composition/Window APIs; native artwork remains an ingame gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/CustomizeWorkspace.lua")
local boundary=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain=assert(load(source:sub(1,boundary)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain","@CustomizeShell/Workspace"))()
local forms,api=ns.GUI.Helpers.FormWidgets,ns.Ace.PresentationCompositionPreview
local native=h.ui.native
local function Find(fn,name,seen)
    seen=seen or {};if seen[fn]then return end;seen[fn]=true
    for i=1,100 do local key,value=debug.getupvalue(fn,i);if not key then break end
        if key==name then return fn,i,value end
        if type(value)=="function"then local f,n,v=Find(value,name,seen);if f then return f,n,v end end
    end
end
local choice,index,initial=Find(controller.UpdateActiveInspectorGeometry,"CUSTOMIZE_SHELL")
assert(choice)
local function Choose(value)debug.setupvalue(choice,index,value);controller.UpdateActiveInspectorGeometry();Drain()end
local nativeAtlas=C_Texture
local missing,invalid,missingMetal
local function AtlasInfo(name)
    if name==missing or (missingMetal and not name:find("DiamondMetal",1,true)) then return nil end
    if name==invalid then return {width=0,height=32}end
    return {width=32,height=32}
end
C_Texture={GetAtlasInfo=AtlasInfo}
local slots={"Left","Center","Right","BottomLeft","BottomCenter","BottomRight","SideLeft","SideRight"}
local function Blizzard(window,shown)
    for _,slot in ipairs(slots)do
        local region=window.frame["_fpModernTitle"..slot]
        assert(region and region:IsShown()==shown,slot)
    end
    for _,key in ipairs({"_fpModernPortraitBackground","_fpModernPortraitTopTileStreaks"})do
        assert(window.frame[key] and window.frame[key]:IsShown()==shown,key)
    end
    assert((window:GetUserData("fpCustomizeBlizzardShell")~=nil)==shown)
end
local function Navigator(window,shown)
    assert(window.frame._fpSidebarPanelFill:IsShown()==shown)
    assert(window.frame._fpNavigatorBrassNineSlice:IsShown()==shown)
end
local editAtlases={Left="UI-Frame-DiamondMetal-CornerTopLeft",Right="UI-Frame-DiamondMetal-CornerTopRight",
    BottomLeft="UI-Frame-DiamondMetal-CornerBottomLeft",BottomRight="UI-Frame-DiamondMetal-CornerBottomRight",
    Center="_UI-Frame-DiamondMetal-EdgeTop",BottomCenter="_UI-Frame-DiamondMetal-EdgeBottom",
    SideLeft="!UI-Frame-DiamondMetal-EdgeLeft",SideRight="!UI-Frame-DiamondMetal-EdgeRight"}
local function EditMode(window)
    Navigator(window,false)
    local frame=window.frame
    for slot,atlas in pairs(editAtlases)do
        local r=assert(frame["_fpModernTitle"..slot]);assert(r:IsShown() and r.atlas==atlas)
        local layer,sub=r:GetDrawLayer();assert(layer=="BORDER" and sub==0)
    end
    for _,corner in ipairs({{"Left","TOPLEFT"},{"Right","TOPRIGHT"},
        {"BottomLeft","BOTTOMLEFT"},{"BottomRight","BOTTOMRIGHT"}})do
        local r=frame["_fpModernTitle"..corner[1]];local p=r.points[corner[2]]
        assert(r:GetNumPoints()==1 and p.relative==frame and p.relativePoint==corner[2] and p.x==0 and p.y==0)
    end
    local bg=frame._fpModernPortraitBackground
    assert(bg:IsShown() and bg:GetTexture()==nil)
    local c=bg.lastSetColorTexture;assert(c[1]==0 and c[2]==0 and c[3]==0 and c[4]==.8)
    local layer,sub=bg:GetDrawLayer();assert(layer=="BACKGROUND" and sub==-5)
    assert(bg.points.TOPLEFT.x==7 and bg.points.TOPLEFT.y==-7)
    assert(bg.points.BOTTOMRIGHT.x==-7 and bg.points.BOTTOMRIGHT.y==7)
    assert(not frame._fpModernPortraitTopTileStreaks or not frame._fpModernPortraitTopTileStreaks:IsShown())
    assert(window:GetUserData("fpCustomizeBlizzardShell"))
end
local function Geometry(window)
    local result={window.frame:GetWidth(),window.frame:GetHeight(),window.frame:GetParent(),
        window.titletext:GetParent(),window.title:GetFrameLevel(),window.closebutton:GetFrameLevel(),
        window.title:GetScript("OnMouseDown"),window.title:GetScript("OnMouseUp"),window.closebutton:GetScript("OnClick")}
    for _,owner in ipairs({window.titletext,window.title,window.closebutton,window._focalPointInspectorContent.frame})do
        for i=1,owner:GetNumPoints()do
            local point,relative,rp,x,y=owner:GetPoint(i)
            result[#result+1]=point;result[#result+1]=relative;result[#result+1]=rp
            result[#result+1]=x or 0;result[#result+1]=y or 0
        end
    end
    return result
end
local function Same(a,b)assert(#a==#b);for i=1,#a do assert(a[i]==b[i],"geometry/script changed at "..i)end end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local window,db
local function MetalGeometry()
    local frame=window.frame
    local function Region(slot)return assert(frame["_fpModernTitle"..slot])end
    local function Point(region,point,relative,rp,x,y)
        local p=assert(region.points[point],point)
        assert(p.relative==relative and p.relativePoint==rp and (p.x or 0)==(x or 0) and (p.y or 0)==(y or 0),point)
    end
    for _,corner in ipairs({{"Left","TOPLEFT",-13,16},{"Right","TOPRIGHT",4,16},
        {"BottomLeft","BOTTOMLEFT",-13,-3},{"BottomRight","BOTTOMRIGHT",4,-3}})do
        local r=Region(corner[1]);assert(r:GetNumPoints()==1)
        Point(r,corner[2],frame,corner[2],corner[3],corner[4])
    end
    for _,edge in ipairs({
        {"Center","TOPLEFT","Left","TOPRIGHT","TOPRIGHT","Right","TOPLEFT",true},
        {"BottomCenter","BOTTOMLEFT","BottomLeft","BOTTOMRIGHT","BOTTOMRIGHT","BottomRight","BOTTOMLEFT",true},
        {"SideLeft","TOPLEFT","Left","BOTTOMLEFT","BOTTOMLEFT","BottomLeft","TOPLEFT",false},
        {"SideRight","TOPRIGHT","Right","BOTTOMRIGHT","BOTTOMRIGHT","BottomRight","TOPRIGHT",false},
    })do
        local r=Region(edge[1]);assert(r:GetNumPoints()==2)
        Point(r,edge[2],Region(edge[3]),edge[4]);Point(r,edge[5],Region(edge[6]),edge[7])
        -- Existing native boundary supplies 20x26 synthetic atlas dimensions, not client metadata.
        assert(edge[8] and r:GetHeight()==26 or not edge[8] and r:GetWidth()==20,"atlas cross dimension")
        assert(r.lastSetHorizTile[1]==edge[8] and r.lastSetVertTile[1]~=edge[8])
    end
    for _,slot in ipairs(slots)do
        local r=Region(slot);assert(r.lastSetDrawLayer[1]=="OVERLAY" and r.lastSetDrawLayer[2]==0)
    end
end
Test("exclusive canonical shells preserve owner, title/drag/close geometry and scripts",function()
    db=Setup();window=Build()
    assert(initial=="editmode","the canonical A/B pilot was not enabled")
    EditMode(window)
    Choose("blizzard")
    Blizzard(window,true);Navigator(window,false)
    Choose("navigator")
    local before=Geometry(window);local data=h.Copy(db)
    Choose("blizzard");Blizzard(window,true);Navigator(window,false);Same(Geometry(window),before)
    assert(window.frame._fpModernPortraitBackground:GetTexture()=="Interface\\FrameGeneral\\UI-Background-Rock")
    assert(window.frame._fpModernPortraitTopTileStreaks.atlas=="_UI-Frame-TopTileStreaks")
    Choose("navigator");Blizzard(window,false);Navigator(window,true);Same(Geometry(window),before);h.Equal(db,data)
end)
Test("Portrait corners and longitudinal edges retain atlas thickness; legacy remains opt-out",function()
    Choose("blizzard");MetalGeometry()
    local fn,upvalue,draw=Find(forms.ApplyCustomizeBlizzardShell,"ApplyModernAtlasRegions")
    assert(fn and upvalue and draw)
    draw(window.frame) -- Actual unchanged legacy selection, including reuse of existing regions.
    assert(window.frame._fpModernTitleLeft.points.TOPLEFT.x==7)
    assert(window.frame._fpModernTitleRight.points.TOPRIGHT.y==-5)
    assert(window.frame._fpModernTitleBottomLeft.points.BOTTOMLEFT.y==5)
    assert(window.frame._fpModernTitleBottomRight.points.BOTTOMRIGHT.x==-3)
    assert(window.frame._fpModernTitleCenter.points.BOTTOMRIGHT)
    assert(window.frame._fpModernTitleBottomCenter.points.TOPRIGHT)
    assert(window.frame._fpModernTitleSideLeft.points.BOTTOMRIGHT)
    assert(window.frame._fpModernTitleSideRight.points.BOTTOMLEFT)
    assert(window.frame._fpModernTitleLeft.lastSetDrawLayer[1]=="ARTWORK")
    assert(not pcall(MetalGeometry),"geometry regression must reject legacy offsets/edge anchors")
    for _,slot in ipairs({"Center","BottomCenter","SideLeft","SideRight"})do
        window.frame["_fpModernTitle"..slot]:SetSize(1,1)
    end
    controller.UpdateActiveInspectorGeometry();MetalGeometry()
end)
Test("all-or-nothing fallback checks atlas API and every required piece before hiding Navigator",function()
    Choose("blizzard")
    for _,name in ipairs({"UI-Frame-PortraitMetal-CornerTopLeft","_UI-Frame-Metal-EdgeBottom","_UI-Frame-TopTileStreaks"})do
        missing=name;controller.UpdateActiveInspectorGeometry();Navigator(window,true);Blizzard(window,false)
    end
    missing=nil;C_Texture=nil;controller.UpdateActiveInspectorGeometry();Navigator(window,true);Blizzard(window,false)
    C_Texture={GetAtlasInfo=AtlasInfo}
    controller.UpdateActiveInspectorGeometry();Blizzard(window,true);Navigator(window,false)
end)
Test("Composition takes exclusive priority and clearing it restores exactly the canonical shell",function()
    for _,mode in ipairs({"navigator","blizzard","editmode"})do
        Choose(mode)
        assert(api.AddLayer("inspector_shell","surface",{color={.2,.3,.4},alpha=.8}))
        Blizzard(window,false);Navigator(window,false)
        local regions=window.frame._fpCompositionRegionsByTarget.inspector_shell
        assert(regions[1]:IsShown())
        controller.UpdateActiveInspectorGeometry();Blizzard(window,false);Navigator(window,false);assert(regions[1]:IsShown())
        assert(api.ClearComposition("inspector_shell"))
        Blizzard(window,false);Navigator(window,false);assert(not regions[1]:IsShown())
        assert(api.ResetComposition("inspector_shell"))
        if mode=="editmode"then EditMode(window)
        else Blizzard(window,mode=="blizzard");Navigator(window,mode=="navigator")end
        assert(not regions[1]:IsShown())
        if mode=="blizzard"then MetalGeometry()end
    end
end)
Test("reapply and geometry/Properties rebuilds do not accumulate regions or change bindings",function()
    Choose("blizzard");local before=Geometry(window);local regionCount=select('#',window.frame:GetRegions())
    local release=window.events.OnRelease;local data=h.Copy(db)
    for _=1,30 do controller.UpdateActiveInspectorGeometry();Blizzard(window,true);Navigator(window,false);MetalGeometry()end
    assert(select('#',window.frame:GetRegions())==regionCount and window.events.OnRelease==release)
    controller.RefreshActiveProperties();Drain();Blizzard(window,true);Navigator(window,false)
    Same(Geometry(window),before);h.Equal(db,data)
end)
Test("Hide/Arrange/Reopen keeps the same host and restores Blizzard without reviving Navigator",function()
    local old=window
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    assert(window==old);Blizzard(window,true);Navigator(window,false)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    assert(window==old);Blizzard(window,true);Navigator(window,false)
end)
local function Zones(top)
    local inset=window._focalPointInspectorInset
    local content=window._focalPointInspectorContent
    local header,tree,properties=table.unpack(content.children)
    local height=window.frame:GetHeight()-top-16-36
    assert(inset.points.TOPLEFT.y==-top and inset.points.BOTTOMRIGHT.y==16)
    -- Flow fits the existing buttons inside the reserved 30px Action zone.
    assert(header.frame.points.TOPLEFT.y==0 and header.frame:GetHeight()>0 and header.frame:GetHeight()<=30)
    assert(tree.frame.points.TOPLEFT.y==-36 and properties.frame.points.TOPLEFT.y==-36)
    assert(tree.frame.points.TOPLEFT.x==0 and properties.frame.points.TOPLEFT.x==0)
    assert(properties.frame:GetWidth()==window.frame:GetWidth()-32)
    assert(tree.frame:GetWidth()==math.min(360,properties.frame:GetWidth()))
    assert(tree.frame:GetHeight()==height and properties.frame:GetHeight()==height)
    assert(window._focalPointPropertyScroll.frame:GetHeight()==height)
    assert(top>=40 and top+30<top+36 and top+36+height==window.frame:GetHeight()-16)
    assert(window.titletext.points.TOPLEFT.y==-18,"Customize title top spacing changed")
    return height
end
Test("Blizzard title-safe Actions and Workspace use one inset; Navigator fallback retains its inset",function()
    Choose("blizzard");assert(Zones(64)==504)
    local before=h.Copy(db)
    missing="_UI-Frame-TopTileStreaks";controller.UpdateActiveInspectorGeometry()
    Navigator(window,true);assert(Zones(64)==504)
    missing=nil;controller.UpdateActiveInspectorGeometry();Blizzard(window,true);assert(Zones(64)==504)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();assert(Zones(64)==504)
    h.Equal(db,before)
end)
Test("small viewport and geometry reapply keep Actions reachable and both scroll regions inside bottom inset",function()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local data=h.Copy(db)
    for _,viewport in ipairs({{1280,720},{800,420},{640,300}})do
        local available=viewport[2]
        UIParent:SetSize(viewport[1],available);controller.UpdateActiveInspectorGeometry()
        assert(window.frame:GetWidth()==math.min(window._focalPointCustomizeView=="properties" and 600 or 392,viewport[1]-32))
        assert(window.frame:GetHeight()==math.min(window._focalPointCustomizeView=="properties" and 520 or 620,available-100))
        local workspace=Zones(64);assert(workspace>0)
        assert(window.frame:GetHeight()<=available)
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();Zones(64)
        assert(not window._focalPointArrangeButton and not window._focalPointCloseButton)
    end
    UIParent:SetSize(width,height);controller.UpdateActiveInspectorGeometry();Zones(64)
    h.Equal(db,data)
end)
Test("A/B reuses existing regions and preserves host/control alpha, geometry and release hook",function()
    Choose("blizzard");local before=Geometry(window);local data=h.Copy(db)
    local regions=select('#',window.frame:GetRegions());local hook=window.events.OnRelease
    local hostAlpha,titleAlpha,closeAlpha=window.frame:GetAlpha(),window.titletext:GetAlpha(),window.closebutton:GetAlpha()
    for _=1,30 do
        Choose("editmode");EditMode(window);Zones(64);Same(Geometry(window),before)
        assert(window.frame:GetAlpha()==hostAlpha and window.titletext:GetAlpha()==titleAlpha and window.closebutton:GetAlpha()==closeAlpha)
        Choose("blizzard");Blizzard(window,true);MetalGeometry();Zones(64);Same(Geometry(window),before)
        assert(window.frame._fpModernPortraitBackground:GetDrawLayer()=="BACKGROUND")
        local _,sub=window.frame._fpModernPortraitBackground:GetDrawLayer();assert(sub==-6)
        assert(window.frame._fpModernPortraitBackground:GetTexture()=="Interface\\FrameGeneral\\UI-Background-Rock")
    end
    assert(select('#',window.frame:GetRegions())==regions and window.events.OnRelease==hook)
    h.Equal(db,data)
end)
Test("every missing Edit-Mode atlas falls back to complete Metal; unavailable Metal falls back to Navigator",function()
    Choose("editmode");EditMode(window)
    for _,atlas in pairs(editAtlases)do
        missing=atlas;controller.UpdateActiveInspectorGeometry();Blizzard(window,true);Navigator(window,false);MetalGeometry()
        missing=nil;controller.UpdateActiveInspectorGeometry();EditMode(window)
    end
    invalid=editAtlases.Center;controller.UpdateActiveInspectorGeometry();Blizzard(window,true);MetalGeometry();invalid=nil
    missingMetal=true;controller.UpdateActiveInspectorGeometry();EditMode(window) -- B does not depend on A's atlases.
    missing=editAtlases.Left;controller.UpdateActiveInspectorGeometry();Blizzard(window,false);Navigator(window,true)
    missingMetal=nil;missing=nil;controller.UpdateActiveInspectorGeometry();EditMode(window)
end)
Test("Edit-Mode reapply and Close/Arrange/Reopen retain the persistent host and clean composition",function()
    Choose("editmode");local before=Geometry(window);local host=window
    controller.RefreshActiveProperties();Drain();EditMode(window)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();assert(window==host);EditMode(window)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();assert(window==host);EditMode(window)
    Same(Geometry(window),before)
end)
Test("explicit Restore and actual Release clear pilot visuals through the existing owner hook",function()
    Choose("editmode");EditMode(window)
    forms.RestoreDefaultWindowChrome(window);Blizzard(window,false)
    controller.UpdateActiveInspectorGeometry();EditMode(window)
    h.ui.ace:Release(window);Blizzard(window,false);Navigator(window,false)
    -- AceGUI does not permit double pooling; the visual cleanup itself is idempotent.
    forms.NeutralizeCustomizeShell(window);forms.NeutralizeCustomizeShell(window)
    Blizzard(window,false);Navigator(window,false)
    local other=h.ui.ace:Create("Window")
    for _,slot in ipairs(slots)do local r=other.frame["_fpModernTitle"..slot];assert(not r or not r:IsShown())end
    assert(not other:GetUserData("fpCustomizeBlizzardShell"));h.ui.ace:Release(other)
end)
debug.setupvalue(choice,index,initial);C_Texture=nativeAtlas
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Customize Window Shell: "..count.." groups PASS")
