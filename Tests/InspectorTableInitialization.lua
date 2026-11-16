-- lua54 Tests/InspectorTableInitialization.lua
-- Real Inspector/AceGUI; reject invalid transient tables even when Lua tolerates 0/0.
local function Read(path)
    local file=assert(io.open(path));local source=file:read("*a");file:close();return source
end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain","@InspectorTable/Workspace"))()
local ace=h.ui.ace
local originalTable=ace:GetLayout("Table")
local originalAddChild=ace.WidgetContainerBase.AddChild
local calls,synchronous,addDepth=0,0,0
local invalid
ace:RegisterLayout("Table",function(content,children)
    calls=calls+1
    if addDepth>0 then synchronous=synchronous+1 end
    local definition=content.obj:GetUserData("table")
    if type(definition)~="table" or type(definition.columns)~="table" or #definition.columns<1 then
        invalid="Table executed without columns: "..tostring(content.obj.type)..", children="..#children
        error(invalid)
    end
    return originalTable(content,children)
end)
ace.WidgetContainerBase.AddChild=function(self,...)
    addDepth=addDepth+1
    local result=originalAddChild(self,...)
    addDepth=addDepth-1
    return result
end
local function Check(window)
    assert(not invalid,invalid)
    assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
    local found=0
    local function Visit(widget)
        if widget:GetUserData("focalPointSectionRole")=="content" then
            local navigation=window._focalPointPropertyNavigation.children[1]
            if navigation and navigation:GetUserData("table") then
                local columns=navigation:GetUserData("table").columns
                assert(#columns==3 and #navigation.children==3)
                assert(navigation.parent==window._focalPointPropertyNavigation and navigation.frame:GetHeight()==40)
                for index,key in ipairs({"appearance","geometry","behavior"}) do
                    assert(navigation.children[index]:GetUserData("normalAbsorbPropertyTab")==key)
                    assert(columns[index].weight>0)
                end
                found=found+1
            end
        end
        for _,child in ipairs(widget.children or {}) do Visit(child) end
    end
    Visit(window._focalPointPropertyScroll)
    assert(found==1,"missing or duplicate property navigation")
end
Setup()
local window=Build();Check(window)
for _,object in ipairs({{kind="unit",unit="player"},{kind="bar",unit="player",objectKey="HealthBar"}}) do
    assert(selection.SelectObject(object));Drain();Check(window)
    for _=1,3 do
        assert(controller.RefreshActiveProperties());Drain();Check(window)
        window._focalPointPropertyScroll:DoLayout();Check(window)
    end
end
controller.ReleaseInspector()
window=Build();Check(window)
assert(calls>0 and synchronous>0,"test missed synchronous AddChild layout")
ace:RegisterLayout("Table",originalTable)
ace.WidgetContainerBase.AddChild=originalAddChild
print("PASS: every Table invocation has columns; synchronous AddChild, Unit Root/Health, rebuild and release/reopen; "..calls.." layouts")
