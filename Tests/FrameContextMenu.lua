-- lua54 Tests/FrameContextMenu.lua
-- Native visuals/input delivery remain ingame gates. Model Blizzard's release-before-hide
-- and Pick -> responder -> guarded SendResponse order from both audited Menu.lua versions.
local f=dofile("Tests/FPCompactSlider.lua")
local native=f.native
for _,method in ipairs({"SetFrameStrata","SetClampedToScreen","RegisterEvent","UnregisterEvent"}) do
    native[method]=function(self,...) self["last"..method]={...} end
end
function native:SetHighlightTexture() self.highlight=self:CreateTexture() end
function native:GetHighlightTexture() return self.highlight end
function native:Enable() self.disabled=false end
function native:Disable() self.disabled=true end
function native:HookScript(event,fn)
    local old=self.scripts[event]
    self:SetScript(event,function(self,...) if old then old(self,...) end;fn(self,...) end)
end
function UIParent:GetEffectiveScale() return 1 end
GetCursorPosition=function() return 100,200 end
local alt,shift,combat,blocked=false,false,false,false
IsAltKeyDown=function() return alt end
InCombatLockdown=function() return combat end
local configs={
    player={width=200,height=40,point="TOPLEFT",relativeTo="UIParent",relativePoint="TOPLEFT",x=11,y=-7,
        Texts={health={fontSize=12},other={fontSize=13}}},
    target={width=250,height=50,point="CENTER",x=0,y=0,Texts={health={fontSize=14}}},
}
local events,selected={},nil
local selectedUnits,primary,textUnit,textKey,scope={"player"},"player",nil,nil,nil
local opened,current,attempts={},nil,0
local ns={L={},framesUnlocked=true,GUI={Editor={}},db={char={activeLayoutId="layout:one"}}}
local function Record(event)
    assert(not current,"action ran before native close")
    events[#events+1]=event
end
ns.IsEditorActive=function() return true end
ns.GUI.Editor.InteractionMode={IsCanvasInteractionBlocked=function() return blocked end,IsShiftDown=function() return shift end}
ns.GUI.Editor.State={
    GetPrimaryUnit=function() return primary end,
    GetSelectedUnits=function() return selectedUnits end,
    GetSelectedUnitCount=function() return #selectedUnits end,
    IsUnitSelected=function(unit) for _,key in ipairs(selectedUnits) do if key==unit then return true end end;return false end,
    GetSelectedTextElement=function() return textUnit,textKey end,
    IsTextElementSelected=function(unit,key) return textUnit==unit and textKey==key end,
    GetPropertyScope=function() return scope end,
}
ns.UnitFrameUtils={GetUnitDB=function(unit) return configs[unit] end}
ns.ActiveLayoutResolver={GetEditableActiveUnits=function() return configs end,
    GetStoredActiveLayoutId=function(db) return db.char.activeLayoutId end}
ns.LayoutEditWorkflow={RequestEditableLayoutForMutation=function(action) action();return true end}
ns.SelectEditorUnit=function(_,unit) selected=unit;Record("select") end
ns.RefreshUnitFrame=function() Record("refresh") end
ns.ApplyStoredFramePosition=function() Record("position") end
DEFAULT_CHAT_FRAME={AddMessage=function() Record("message") end}
local resetSize,resetPosition,alignment,textReset
local function Reset(which,units)
    if combat then return {ok=false,reason="combat"} end
    Record(which)
    local snapshot=table.concat(units,",")
    if which=="size" then resetSize=snapshot else resetPosition=snapshot end
    return {ok=true}
end
ns.GUI.Editor.FrameMutations={
    ResetUnitsSize=function(units) return Reset("size",units) end,
    ResetUnitsPosition=function(units) return Reset("reset-position",units) end,
    AlignUnits=function(units,unit,mode)
        if combat then return {ok=false,reason="combat"} end
        Record("align");alignment={table.concat(units,","),unit,mode};return {ok=true}
    end,
}
ns.InspectorMutations={GetTextPositionDefault=function() return {} end,GetTextFontSizeDefault=function() return 12 end}
ns.GUI.Editor.TextEditorOverlay={
    ResetPosition=function(frame,key) Record("text-position");textReset={frame,key,"position"} end,
    ResetSize=function(frame,key) Record("text-size");textReset={frame,key,"size"} end,
}
local player,target=CreateFrame("Frame",nil,UIParent),CreateFrame("Frame",nil,UIParent)
player._fpUnit,target._fpUnit="player","target"
local focus=CreateFrame("Frame",nil,player)
GetMouseFoci=function() return {focus} end
local previous=function(_,button) return button=="MiddleButton" end
focus.HandlesGlobalMouseEvent=previous
local manager={}
function manager:CloseMenus() error("must not close unrelated Blizzard menus") end
function manager:CloseMenu(proxy)
    assert(proxy.live,"released proxy reused")
    events[#events+1]="close"
    for _,fn in ipairs(proxy.root.released) do fn(proxy) end
    proxy.live=false
    for _,description in ipairs(proxy.root.actions) do description.menu=nil end
    if current==proxy then current=nil end
end
Menu={GetManager=function() return manager end}
local api
MenuUtil={CreateContextMenu=function(owner,generator)
    attempts=attempts+1
    assert(not current and not (api and api.menu and api.menu:IsShown()),"two backends")
    local root={children={},actions={},released={}}
    function root:AddMenuReleasedCallback(fn) self.released[#self.released+1]=fn end
    function root:CreateDivider()
        local divider={divider=true}
        self.children[#self.children+1]=divider
        return divider
    end
    function root:CreateButton(text,callback)
        local description={text=text,callback=callback}
        function description:SetEnabled(value) self.enabled=value end
        function description:IsEnabled() return type(self.enabled)=="function" and self.enabled() or self.enabled==true end
        function description:SetTooltip(callback) self.tooltip=callback end
        self.children[#self.children+1]=description
        self.actions[#self.actions+1]=description
        return description
    end
    generator(owner,root)
    local proxy={root=root,owner=owner,live=true}
    for _,description in ipairs(root.children) do description.menu=proxy end
    opened[#opened+1]=proxy;current=proxy
    return proxy
end}
local function Pick(proxy,index)
    local description=proxy.root.actions[index]
    if not description:IsEnabled() then return end
    description.callback()
    -- Blizzard clears description.menu while closing. Pick must not respond again.
    if description.menu then manager:CloseMenu(description.menu) end
end
api=assert(loadfile("GUI/Editor/FrameContextMenu.lua"))("FocalPoint",ns)
local function LegacyCount(count)
    local menu=assert(api.menu)
    assert(menu:IsShown() and not current)
    local shown=0
    for _,button in ipairs(menu.buttons) do if button:IsShown() then shown=shown+1 end end
    assert(shown==count)
    return menu
end
local function MouseDown(button)
    local handled=focus.HandlesGlobalMouseEvent and focus:HandlesGlobalMouseEvent(button,"GLOBAL_MOUSE_DOWN")
    if not handled and current then manager:CloseMenu(current) end
    return handled
end
local function Frame(frame)
    api.ShowForFrame(frame or player)
    assert(current and #current.root.actions==13)
    assert(#current.root.children==15)
    local actions,dividers=0,0
    for index,entry in ipairs(current.root.children) do
        if entry.divider then
            dividers=dividers+1
            assert(index==4 or index==8)
            assert(not entry.callback and entry.enabled==nil and not entry.text)
        else actions=actions+1;assert(entry==current.root.actions[actions]) end
    end
    assert(actions==13 and dividers==2)
    assert(current.root.children[3].text:find("Reset size",1,true))
    assert(current.root.children[5].text=="Copy position")
    assert(current.root.children[7].text:find("Reset position",1,true))
    assert(current.root.children[9].text=="Align selected")
    return current
end
local function Text(key)
    textUnit,textKey="player",key or "health"
    api.ShowForText(player,textKey)
    assert(current and #current.root.actions==2)
    assert(#current.root.children==2)
    for _,entry in ipairs(current.root.children) do assert(not entry.divider) end
    return current
end
local expected={"Copy size","Paste size","Reset size","Copy position","Paste position","Reset position",
    "Align selected","Align left","Align right","Align top","Align bottom","Align horizontal center","Align vertical center"}
local function Tooltip(entry)
    local lines={}
    assert(entry.tooltip)
    entry.tooltip({AddLine=function(_,text) lines[#lines+1]=text end})
    return table.concat(lines,"\n")
end

-- Every native entry, original ordering/disabled state, no legacy renderer or mutation on open.
events={};local first=Frame()
assert(api.menu==nil and first.owner==focus and #events==0 and selected==nil)
for i,text in ipairs(expected) do assert(first.root.actions[i].text==text) end
assert(not first.root.actions[2]:IsEnabled() and not first.root.actions[5]:IsEnabled())
assert(not first.root.actions[7]:IsEnabled() and not first.root.actions[8]:IsEnabled())
Pick(first,7);assert(current==first and #events==0)
assert(Tooltip(first.root.actions[3]):find("size of this unit frame",1,true))
assert(focus:HandlesGlobalMouseEvent("MiddleButton","GLOBAL_MOUSE_DOWN"))
assert(MouseDown("RightButton"));api.ShowForFrame(player)
assert(not current and not first.live and focus.HandlesGlobalMouseEvent==previous)

-- All callbacks share close-before-action and the original clipboard.
events={};first=Frame();local staleCallback=first.root.actions[1].callback
Pick(first,1)
assert(table.concat(events,",")=="close,select,message" and selected=="player")
staleCallback();assert(#events==3)
first=Frame(target);Pick(first,2)
assert(configs.target.width==200 and configs.target.height==40)
first=Frame();Pick(first,4)
first=Frame(target);Pick(first,5)
assert(configs.target.point=="TOPLEFT" and configs.target.x==11 and configs.target.y==-7)

-- Multi-selection labels, tooltips, preservation and every alignment retain canonical inputs.
selectedUnits={"player","target"};primary="player";events={}
first=Frame();assert(first.root.actions[3].text=="Reset sizes (2)")
assert(first.root.actions[6].text=="Reset positions (2)")
assert(Tooltip(first.root.actions[6]):find("all selected unit frames",1,true))
Pick(first,3);assert(resetSize=="player,target" and table.concat(events,",")=="close,size")
events={};first=Frame();Pick(first,6)
assert(resetPosition=="player,target" and table.concat(events,",")=="close,reset-position")
for index,mode in ipairs({"left","right","top","bottom","horizontalCenter","verticalCenter"}) do
    events={};first=Frame();assert(first.root.actions[index+7]:IsEnabled())
    assert(Tooltip(first.root.actions[index+7]):find("primary selection",1,true))
    Pick(first,index+7)
    assert(table.concat(events,",")=="close,align" and alignment[1]=="player,target" and alignment[2]=="player" and alignment[3]==mode)
end
selectedUnits={"player"}

-- Text selection already belongs to the caller. Shift is captured at OPEN, not at click.
shift=false;events={};first=Text()
assert(first.root.actions[1].text=="Reset position" and first.root.actions[2].text=="Reset size")
assert(Tooltip(first.root.actions[1]):find("unit frame",1,true))
shift=true;Pick(first,1);assert(table.concat(events,",")=="close,reset-position")
shift=true;events={};first=Text();shift=false
assert(Tooltip(first.root.actions[1]):find("text element",1,true))
Pick(first,1);assert(textReset[1]==player and textReset[2]=="health" and textReset[3]=="position")
assert(table.concat(events,",")=="close,text-position")
events={};first=Text();Pick(first,2);assert(table.concat(events,",")=="close,text-size")
first=Text();assert(MouseDown("RightButton"));api.ShowForText(player,"health");assert(not current)
first=Text();api.ShowForText(player,"other");assert(not first.live and current);api.Hide()
textUnit,textKey=nil,nil

-- Alt no longer chooses a special menu. Frame/Text switches close only our old proxy.
for _,value in ipairs({false,true}) do alt=value;first=Frame();api.Hide() end
first=Frame();Text();assert(not first.live);api.Hide();textUnit,textKey=nil,nil

-- Missing/unsupported API and declined opens: exactly one fallback, same canonical entries.
local savedUtil,savedMenu,savedFoci=MenuUtil,Menu,GetMouseFoci
for _,missing in ipairs({"util","manager","close","foci","declined"}) do
    MenuUtil,Menu,GetMouseFoci=savedUtil,savedMenu,savedFoci
    local close=manager.CloseMenu
    if missing=="util" then MenuUtil=nil
    elseif missing=="manager" then Menu=nil
    elseif missing=="close" then manager.CloseMenu=nil
    elseif missing=="foci" then GetMouseFoci=nil
    else MenuUtil={CreateContextMenu=function() attempts=attempts+1;return nil end} end
    local before=attempts
    api.ShowForFrame(player);local legacy=LegacyCount(13)
    for i,text in ipairs(expected) do assert(legacy.buttons[i].label:GetText()==text) end
    assert(#legacy.frameItems==13 and #legacy.buttons==13)
    assert(attempts-before==(missing=="declined" and 1 or 0))
    assert(focus.HandlesGlobalMouseEvent==previous)
    legacy.buttons[1]:Run("OnClick");assert(not legacy:IsShown())
    api.ShowForFrame(player);api.ShowForFrame(player);assert(not legacy:IsShown())
    shift=true;textUnit,textKey="player","health";api.ShowForText(player,"health");LegacyCount(2)
    shift=false;legacy.buttons[1]:Run("OnClick");assert(textReset[3]=="position")
    api.Hide();manager.CloseMenu=close;textUnit,textKey=nil,nil
end
MenuUtil,Menu,GetMouseFoci=savedUtil,savedMenu,savedFoci
first=Frame();MenuUtil=nil
api.ShowForText(player,"health");LegacyCount(2)
assert(not first.live and focus.HandlesGlobalMouseEvent==previous)
api.Hide();MenuUtil=savedUtil

-- Guards and orphaned responders after layout/config/unit/selection/text replacement.
for _,change in ipairs({"layout","config","unit","selection","units","scope","text-selection","text"}) do
    local restore
    if change=="text" or change=="text-selection" then first=Text() else first=Frame() end
    local callback=first.root.actions[1].callback
    if change=="layout" then ns.db.char.activeLayoutId="layout:two";restore=function() ns.db.char.activeLayoutId="layout:one" end
    elseif change=="config" then local old=configs.player;configs.player={};restore=function() configs.player=old end
    elseif change=="unit" then player._fpUnit="target";restore=function() player._fpUnit="player" end
    elseif change=="selection" then primary="target";restore=function() primary="player" end
    elseif change=="units" then selectedUnits={"player","target"};restore=function() selectedUnits={"player"} end
    elseif change=="scope" then scope={sectionKey="power"};restore=function() scope=nil end
    elseif change=="text-selection" then textKey="other";restore=function() textKey="health" end
    else local old=configs.player.Texts.health;configs.player.Texts.health={};restore=function() configs.player.Texts.health=old end end
    events={};callback();assert(table.concat(events,",")=="close" and not current)
    restore();callback();assert(#events==1)
    textUnit,textKey=nil,nil
end
local count=#opened
ns.framesUnlocked=false;api.ShowForFrame(player);assert(#opened==count)
ns.framesUnlocked=true;blocked=true;api.ShowForFrame(player);assert(#opened==count)
blocked=false;ns.IsEditorActive=function() return false end;api.ShowForFrame(player);assert(#opened==count)
ns.IsEditorActive=function() return true end
first=Frame();events={};ns.framesUnlocked=false;first.root.actions[1].callback()
assert(table.concat(events,",")=="close");ns.framesUnlocked=true
combat=true;configs.target.width=250;first=Frame(target);Pick(first,2);assert(configs.target.width==250)
shift=true;first=Text();assert(not first.root.actions[1]:IsEnabled() and not first.root.actions[2]:IsEnabled());api.Hide()
combat=false;shift=false;textUnit,textKey=nil,nil

-- Fifty owner switches, native Escape/outside/owner-hide and explicit editor Hide.
for cycle=1,50 do
    focus=CreateFrame("Frame",nil,player);focus.HandlesGlobalMouseEvent=previous
    local proxy=Frame()
    if cycle%4==0 then api.Hide()
    elseif cycle%4==1 then manager:CloseMenu(proxy)
    elseif cycle%4==2 then
        focus=CreateFrame("Frame",nil,UIParent);MouseDown("LeftButton");focus=proxy.owner
    else
        proxy.owner:Hide();if not proxy.owner:IsVisible() then manager:CloseMenu(proxy) end;proxy.owner:Show()
    end
    assert(not proxy.live and current==nil and focus.HandlesGlobalMouseEvent==previous)
    events={};proxy.root.actions[1].callback();assert(#events==0)
end
assert(not (api.menu and api.menu:IsShown()))
assert(#f.errors==0,table.concat(f.errors,"\n"))
print("PASS: native 13/2 Frame/Text menus, ordering/disabled/tooltips, canonical clipboard/reset/alignment, Shift snapshot, close-before-action, stale contexts, fallback isolation and 50 owner/release cycles")

-- Integration boundary: run the actual Core selection/transform and menu hooks.
do
    function native:SetFrameLevel(value) self.testFrameLevel=value end
    function native:GetFrameLevel() return self.testFrameLevel or 100 end
    function native:GetFrameStrata() return "HIGH" end
    function native:SetAllPoints(target) self.testAllPoints=target end
    function native:RegisterForDrag(...) self.testDragButtons={...} end
    ns.GUI.Editor.State.IsArrange=function() return true end
    ns.GUI.Editor.ObjectSelection={GetSelectedObject=function() return {kind="unit",unit=primary} end}
    assert(loadfile("Engine/Core.lua"))("FocalPoint",ns)
    local function Upvalue(fn,wanted)
        for i=1,100 do
            local name,value=debug.getupvalue(fn,i)
            if name==wanted then return value end
            if not name then break end
        end
        error("missing Core test boundary: "..wanted)
    end
    local attach=Upvalue(ns.UpdateFrameDragState,"EnsureEditorContextMenuHooks")
    local transform=Upvalue(ns.UpdateFrameDragState,"UpdateRootTransformOverlay")
    local visual=Upvalue(ns.UpdateFrameDragState,"UpdateSelectionOverlay")
    for _,frame in ipairs({player,target}) do
        frame.MoveOverlay=CreateFrame("Frame",nil,frame);frame.MoveOverlay:SetFrameLevel(140)
        attach(frame)
        transform(frame,frame==player)
        visual(frame)
    end
    local overlay=player.SelectionOverlay
    assert(overlay:IsShown() and overlay.lastEnableMouse[1] and overlay.testAllPoints==player)
    assert(overlay:GetFrameLevel()>player.MoveOverlay:GetFrameLevel())
    assert(not target.SelectionOverlay:IsShown() and not target.SelectionOverlay.lastEnableMouse[1])
    local show,entries=api.ShowForFrame,0
    api.ShowForFrame=function(frame) entries=entries+1;return show(frame) end
    for _,nativeBackend in ipairs({true,false}) do
        MenuUtil=nativeBackend and savedUtil or nil
        for _,multi in ipairs({false,true}) do
            selectedUnits=multi and {"player","target"} or {"player"}
            visual(player);visual(target)
            assert(target.SelectionOverlay:IsShown()==multi and not target.SelectionOverlay.lastEnableMouse[1])
            -- Selected Unit interior goes through SelectionOverlay; other Unit through MoveOverlay.
            for _,hit in ipairs({overlay,target.MoveOverlay}) do
                focus=hit;entries=0;events={}
                hit:Run("OnMouseDown","RightButton");hit:Run("OnMouseUp","RightButton")
                assert(entries==1,"RightButton must reach ShowForFrame exactly once")
                assert(#events==0,"right-click changed selection or invoked an action")
                if nativeBackend then assert(current and #current.root.actions==13)
                else LegacyCount(13) end
                if nativeBackend then assert(MouseDown("RightButton")) end
                entries=0;hit:Run("OnMouseUp","RightButton")
                assert(entries==1 and not current and not (api.menu and api.menu:IsShown()))
            end
        end
    end
    MenuUtil=savedUtil;selectedUnits={"player"};focus=overlay;entries=0;events={}
    local dragStart,dragStop=overlay.scripts.OnDragStart,overlay.scripts.OnDragStop
    overlay:Run("OnMouseDown","LeftButton");overlay:Run("OnMouseUp","LeftButton")
    assert(entries==0 and table.concat(events,",")=="select")
    events={};overlay:Run("OnMouseUp","MiddleButton")
    assert(entries==0 and #events==0)
    assert(overlay.scripts.OnDragStart==dragStart and overlay.scripts.OnDragStop==dragStop)
    assert(#overlay.testDragButtons==1 and overlay.testDragButtons[1]=="LeftButton")
    transform(player,false)
    assert(not overlay.lastEnableMouse[1] and not overlay.scripts.OnMouseUp and not overlay.scripts.OnDragStart)
    api.ShowForFrame=show
    assert(#f.errors==0,table.concat(f.errors,"\n"))
end
print("PASS: real Core Arrange SelectionOverlay/MoveOverlay right-click exactly once, native/fallback, single/multi-selection, toggle, unchanged left-click and drag registration, inactive cleanup")
