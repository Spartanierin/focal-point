-- Real Window/Fill layout and Customize lifecycle; native anchors are the test boundary.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/CustomizeWorkspace.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain,Tree,Node=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain,Tree,Node","@HeaderGeometry/Workspace"))()
local window
local dragDown,dragUp
local function CheckAnchor(region,point,relativeFrame,relativePoint,x,y)
    local matches=0
    for i=1,region:GetNumPoints()do
        local actualPoint,actualFrame,actualRelativePoint,actualX,actualY=region:GetPoint(i)
        if actualPoint==point then
            matches=matches+1
            assert(type(actualPoint)=="string" and actualPoint==point)
            assert(actualFrame==relativeFrame,"anchor relative frame changed")
            assert(type(actualRelativePoint)=="string" and actualRelativePoint==relativePoint)
            assert(type(actualX)=="number" and actualX==x,"anchor X changed")
            assert(type(actualY)=="number" and actualY==y,"anchor Y changed")
        end
    end
    assert(matches==1,"expected exactly one "..point.." anchor")
end
local function Check()
    local targetWidth=window._focalPointCustomizeView=="properties" and 600 or 392
    assert(window.frame:GetWidth()==math.min(targetWidth,UIParent:GetWidth()-32))
    local targetHeight=window._focalPointCustomizeView=="properties" and 520 or 620
    assert(window.frame:GetHeight()==math.min(targetHeight,UIParent:GetHeight()-100))
    -- Reproduce the real owner layout that used to overwrite the Body anchors.
    window:DoLayout();window:DoLayout()
    local inset=window._focalPointInspectorInset
    local owner=window.content
    assert(owner.points.TOPLEFT and owner.points.TOPLEFT.relative==inset,"Window Fill bypasses the title reserve")
    assert(owner.points.BOTTOMRIGHT.relative==inset)
    assert(inset.points.TOPLEFT.relative==window.frame and inset.points.TOPLEFT.y==-64)
    assert(inset.points.BOTTOMRIGHT.relative==window.frame and inset.points.BOTTOMRIGHT.y==16)
    local body=window._focalPointInspectorContent
    assert(body.frame.lastSetAllPoints[1]==owner,"Fill must remain within the canonical content host")
    local _,size=window.titletext:GetFont()
    assert(64 > -window.titletext.points.TOPLEFT.y+size,"title overlaps the reserved content edge")
    CheckAnchor(window.title,"TOPLEFT",window.frame,"TOPLEFT",12,-8)
    CheckAnchor(window.title,"BOTTOMRIGHT",window.frame,"TOPRIGHT",-48,-56)
    assert(window.title:GetNumPoints()==2)
    CheckAnchor(window.titletext,"TOPLEFT",window.frame,"TOPLEFT",36,-18)
    CheckAnchor(window.titletext,"TOPRIGHT",window.frame,"TOPRIGHT",-36,-18)
    -- Right 48px are excluded; the native Close button/its anchors stay untouched.
    assert(window.closebutton.points.TOPRIGHT.x==2 and window.closebutton.points.TOPRIGHT.y==1)
    assert(window.title:GetScript("OnMouseDown")==dragDown and window.title:GetScript("OnMouseUp")==dragUp)
    assert(-window.title.points.BOTTOMRIGHT.y < -inset.points.TOPLEFT.y,"drag overlaps breadcrumb/content")
    local height=window.frame:GetHeight()-64-16
    local header,tree,properties=table.unpack(body.children)
    assert(owner.height==height and owner:GetHeight()==height)
    assert(body.frame:GetHeight()==height)
    assert(tree.frame.points.TOPLEFT.y==-36 and tree.frame:GetHeight()==height-36)
    assert(properties.frame.points.TOPLEFT.y==-36 and properties.frame:GetHeight()==height-36)
    assert(window._focalPointComponentAddButton==nil and #body.children==3)
    assert(36+tree.frame:GetHeight()==height)
    assert(64+36+properties.frame:GetHeight()==window.frame:GetHeight()-16)
    assert(window._focalPointPropertyScroll.frame:GetHeight()==height-36)
    assert(header.frame:IsShown())
    local back=window._focalPointComponentsButton
    assert(back.frame:GetHeight()==30 and header.frame:GetHeight()==30)
    assert(back.frame:IsShown()==(window._focalPointCustomizeView=="properties"))
    if window._focalPointCustomizeView=="properties"then
        local object=window._focalPointObjectBreadcrumb
        assert(object.parent==header and object.frame:GetParent()==header.content)
        local left=object.frame.points.LEFT
        assert(left.relative==header.content and not object.frame.points.RIGHT)
        local widgetRight=left.x+object.frame:GetWidth()
        assert(math.abs(widgetRight-(header.content:GetWidth()-32))<.01)
        -- Measure the FontString's own extent, not just its owner's Table anchors.
        local textLeft=object.label.points.TOPLEFT
        assert(textLeft.relative==object.frame and textLeft.relativePoint=="TOPLEFT")
        local actualTextRight=left.x+textLeft.x+object.label:GetWidth()
        assert(header.content:GetWidth()==window.frame:GetWidth()-32)
        assert(math.abs(16+actualTextRight-(window.frame:GetWidth()-48))<.01,
            "component text must retain the Window's 48px right content inset")
        assert(math.abs(widgetRight-actualTextRight)<.01,"text does not reach its widget's right edge")
        assert(object.label.lastSetJustifyH[1]=="RIGHT")
    end
    -- A centered 30px navigation button fits inside the reserved y=64..94 row;
    -- the unchanged native title drag owner ends at y=56.
    assert(64+(30-back.frame:GetHeight())/2>56)
    assert(64+(30-back.frame:GetHeight())/2+back.frame:GetHeight()<=64+30)
end
local function Pick()
    Tree().control.callbacks.onSelect(Node("unit"));Drain();Check()
    assert(window._focalPointCustomizeView=="properties")
end
local function Back()
    window._focalPointComponentsButton:Fire("OnClick");Drain();Check()
    assert(window._focalPointCustomizeView=="components")
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("actual Window Fill keeps Components and Properties below the same header",function()
    Setup();window=Build()
    dragDown=window.title:GetScript("OnMouseDown");dragUp=window.title:GetScript("OnMouseUp")
    assert(type(dragDown)=="function" and type(dragUp)=="function")
    window.frame:ClearAllPoints();window.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",75,-80)
    Check();Pick();Back()
    assert(window.frame.points.TOPLEFT.x==75 and window.frame.points.TOPLEFT.y==-80)
    local before=h.Copy(ns.db)
    controller.RefreshActiveProperties();Check()
    h.Equal(ns.db,before)
end)
Test("viewport changes and 20 reopen cycles preserve owner anchors and bottom bounds",function()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    for _,viewport in ipairs({{1280,720},{800,420},{520,420},{640,300}})do
        UIParent:SetSize(table.unpack(viewport));controller.UpdateActiveInspectorGeometry()
        Check();Pick();Back()
    end
    UIParent:SetSize(width,height);controller.UpdateActiveInspectorGeometry()
    for _=1,20 do
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain()
        assert(state.IsArrange())
        assert(Build()==window);Check();Pick();Back()
    end
end)
Test("actual release restores Window content anchors and dimensions before reuse",function()
    local ace=h.ui.ace
    ace:Release(window)
    local create,captured=ace.Create
    ace.Create=function(self,kind,...)
        local owner=create(self,kind,...)
        if kind=="Window"then
            captured={points={},width=owner.content:GetWidth(),height=owner.content:GetHeight(),
                dragPoints={},dragWidth=owner.title:GetWidth(),dragHeight=owner.title:GetHeight(),
                dragDown=owner.title:GetScript("OnMouseDown"),dragUp=owner.title:GetScript("OnMouseUp")}
            for i=1,owner.content:GetNumPoints()do captured.points[i]={owner.content:GetPoint(i)}end
            for i=1,owner.title:GetNumPoints()do captured.dragPoints[i]={owner.title:GetPoint(i)}end
        end
        return owner
    end
    window=Build();ace.Create=create;assert(captured)
    dragDown,dragUp=captured.dragDown,captured.dragUp;Check()
    ace:Release(window)
    assert(window.content:GetNumPoints()==#captured.points)
    local points={}
    for i=1,window.content:GetNumPoints()do
        local point={window.content:GetPoint(i)};points[point[1]]=point
    end
    for _,point in ipairs(captured.points)do
        local actual=assert(points[point[1]])
        for j=1,5 do assert(actual[j]==point[j],"Window content anchor leaked past Release")end
    end
    assert(window.content:GetWidth()==captured.width and window.content:GetHeight()==captured.height)
    assert(window.content.width==nil and window.content.height==nil,"AceGUI must clear released layout caches")
    assert(window.title:GetNumPoints()==#captured.dragPoints)
    local restored={}
    for i=1,window.title:GetNumPoints()do local p={window.title:GetPoint(i)};restored[p[1]]=p end
    for _,p in ipairs(captured.dragPoints)do
        local actual=assert(restored[p[1]])
        for j=1,5 do assert(actual[j]==p[j],"native drag anchor leaked past Release")end
    end
    assert(window.title:GetWidth()==captured.dragWidth and window.title:GetHeight()==captured.dragHeight)
    assert(window.title:GetScript("OnMouseDown")==captured.dragDown and window.title:GetScript("OnMouseUp")==captured.dragUp)
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Customize Header Geometry: "..count.." groups PASS")
