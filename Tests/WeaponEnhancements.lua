-- lua54 Tests/WeaponEnhancements.lua
-- Public native-container doubles test our bindings/budget, not WoW's secure UI.
local ns = {L={}}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
local function Copy(t) if type(t)~="table" then return t end local r={} for k,v in pairs(t) do r[k]=Copy(v) end return r end
local passed=0
local function Test(name, fn) fn(); passed=passed+1; print("PASS: "..name) end
local now, combat, reads, nativeAllocations = 100, false, 0, 0
local equipment = {}
GetTime=function() return now end
InCombatLockdown=function() return combat end
issecretvalue=function() return false end
INVSLOT_MAINHAND, INVSLOT_OFFHAND = 16,17
GetInventoryItemTexture=function(unit,slot) assert(unit=="player"); return 1000+slot end
C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot) reads=reads+1; return equipment[slot] end}
STANDARD_TEXT_FONT="font"
AuraContainerItemEnchantmentSlot={MainHand=0,OffHand=1}
AuraContainerItemEnchantmentSortMethod={Slot=0}
AuraContainerSortDirection={Normal=0,Reverse=1}
AuraContainerSortMethod={AuraInstanceIDOnly=8,ExpirationOnly=5}
CustomAuraContainerItemEnchantmentPlacement={BeforeAuraGroups=0}
AnchorUtil={FlowDirection={Left=0,Right=1,Up=2,Down=3},FlowLayoutAxis={Horizontal=0}}
local function Noop() end
local function Surface()
    local s={scripts={},events={},shown=false}
    for _,key in ipairs({"ClearAllPoints","SetAllPoints","SetJustifyH","SetTextColor","SetShadowColor","SetShadowOffset",
        "SetFont","SetMaxLines","SetTexCoord","SetColorTexture","SetBackdrop","SetBackdropColor","SetBackdropBorderColor",
        "SetDrawEdge","SetDrawSwipe","SetReverse","SetHideCountdownNumbers"}) do s[key]=Noop end
    function s:SetSize(w,h) self.width=w;self.height=h end
    function s:SetPoint(...) self.point={...} end
    function s:SetFrameStrata(v) self.strata=v end
    function s:GetFrameStrata() return self.strata or "MEDIUM" end
    function s:SetFrameLevel(v) self.level=v end
    function s:GetFrameLevel() return self.level or 1 end
    function s:EnableMouse(v) self.mouse=v end
    function s:Show() self.shown=true end
    function s:Hide() self.shown=false end
    function s:IsShown() return self.shown end
    function s:SetText(v) self.text=v end
    function s:SetTexture(v) self.texture=v end
    function s:SetScript(k,v) self.scripts[k]=v end
    function s:RegisterEvent(k) self.events[k]=true end
    function s:CreateTexture() return Surface() end
    function s:CreateFontString() return Surface() end
    function s:SetIcon(v) self.icon=v end
    function s:SetApplicationCount(v) self.countText=v end
    function s:SetDurationText(v) self.durationText=v end
    function s:GetParent() return self.parent end
    function s:SetCooldown(start,duration) self.cooldown={start,duration} end
    return s
end
CreateFrame=function(kind,_,parent)
    local s=Surface();s.parent=parent
    if kind~="AuraContainer" then return s end
    nativeAllocations=nativeAllocations+1;s.slots={}
    function s:AddAuraGroup(key,filter,options)
        assert(type(filter)=="string" and type(options)=="table")
        assert(not self.group); self.group=key;self.filter=filter;self.cap=options.maxFrameCount
        self.filters=options.candidateFilters;options.initializeFrame(Surface())
    end
    function s:SetUnit(unit) self.unit=unit end
    function s:SetEnabled(enabled) self.enabled=enabled end
    function s:AddItemEnchantment(slot,options)
        assert(self.slots[slot]==nil);assert(options.candidateFilters==nil and options.hidePermanent==false)
        self.slots[slot]=options;options.initializeFrame(Surface())
    end
    function s:SetItemEnchantmentLayout(options) self.enchantLayout=options end
    function s:SetItemEnchantmentSortMethod(method,direction) self.enchantSort={method,direction} end
    function s:SetAuraGroupMaxFrameCount(key,count) assert(key==self.group);self.cap=count end
    function s:SetAuraGroupFilterString(key,filter) assert(key==self.group);self.filter=filter end
    function s:SetAuraGroupCandidateFilters(key,filters) assert(key==self.group);self.filters=filters end
    function s:SetAuraGroupSortMethod(key,method,direction) assert(key==self.group);self.sort={method,direction} end
    function s:SetAuraGroupLayout(key,options) assert(key==self.group);self.auraLayout=options end
    function s:SetFlowLayoutAxis(v) self.axis=v end
    function s:SetFlowLayoutAnchorPoint(v) self.anchor=v end
    function s:SetFlowLayoutGrowthDirection(x,y) self.growth={x,y} end
    function s:SetFlowLayoutMaximumLineSize(v) self.lineSize=v end
    function s:UpdateAllAuras() self.updates=(self.updates or 0)+1 end
    if arg and arg[1]=="forever" then
        -- Same product path on Forever: do not depend on this extra capability.
        function s:SetItemEnchantmentEnabled() error("unexpected client-specific path") end
    end
    -- Deliberately no private removal API.
    return s
end
Load("Engine/Auras/Runtime/WeaponEnhancements.lua")
Load("Engine/Auras/Layout/AuraBlockLayout.lua")
Load("Engine/Auras/Runtime/AuraFilters.lua")
Load("Engine/Auras/Runtime/AuraSorting.lua")
Load("Engine/Auras/Managed/ManagedAuraBackend.lua")
local W,M=ns.WeaponEnhancements,ns.ManagedAuraBackend
local config={present=true,enabled=true,iconsPerRow=4,maxRows=1,iconSize=25,spacingX=3,spacingY=3,
    showTimerText=true,showStackText=true,hideLongAuras=false,sortMode="NEWEST_FIRST"}
local owner=Surface();owner._fpUnit="player";owner.config={Buffs=config}
local function Refresh() assert(M.EnsureGroup(owner,"Buffs",config));return owner.ManagedAuraBackend.PlayerBuffs end
local function ChangeEquipment(main,off)
    equipment={[16]=main,[17]=off};W.Invalidate(owner)
end
local function Enchant(id,ms,charges) return {enchantID=id,remainingTimeMs=ms,chargesRemaining=charges or 0,hasExpirationTime=true} end
local state
Test("old layouts stay off; native variants allocated once with public APIs",function()
    ChangeEquipment(Enchant(42,60000)); state=Refresh()
    assert(reads==0 and state.container==state.baseContainer and state.container.cap==4)
    assert(nativeAllocations==4 and not state.weaponVariantsUnavailable)
    assert(state.container.filter=="HELPFUL" and state.container.sort[1]==8 and state.container.sort[2]==1)
    local a={};assert(W.Prepend(owner,"Buffs",config,a)==a)
end)
Test("Main/Offhand identity, milliseconds, charges, no invented aura/spell IDs",function()
    config.showWeaponEnhancements=true
    ChangeEquipment(Enchant(42,60500,2),Enchant(42,30500,3));state=Refresh()
    assert(state.container==state.weaponVariants[3] and state.container.cap==2)
    local e=W.GetEntries(owner,"Buffs",config)
    assert(#e==2 and e[1].inventorySlot==16 and e[2].inventorySlot==17)
    assert(e[1].enchantID==e[2].enchantID and e[1].expirationTime==160.5 and e[2].count==3)
    assert(e[1].icon==1016 and not e[1].spellId and not e[1].auraInstanceID and not e[1].auraInstanceId)
    assert(state.container.slots[0] and state.container.slots[1] and state.container.enchantSort[1]==0)
end)
Test("event snapshots cache reads; apply/renew/remove/expire/weapon swap",function()
    local before=reads; for i=1,20 do Refresh() end;assert(reads==before)
    for _,case in ipairs({{Enchant(9,90000),false,1},{false,Enchant(7,30000),2},{false,false,0},
        {Enchant(8,0),false,0},{Enchant(11,120000),Enchant(12,30000),3}}) do
        ChangeEquipment(case[1] or nil,case[2] or nil);state=Refresh()
        assert(state.container==state.weaponVariants[case[3]])
    end
    assert(W.GetEntries(owner,"Buffs",config)[1].expirationTime==220)
    assert(nativeAllocations==4)
end)
Test("tiny budgets, Mainhand priority, Offhand alone, cap and unchanged aura order",function()
    config.iconsPerRow=1;ChangeEquipment(Enchant(1,1000),Enchant(1,2000));state=Refresh()
    assert(state.container==state.weaponVariants[1] and state.container.cap==0)
    ChangeEquipment(nil,Enchant(2,5000));state=Refresh()
    assert(state.container==state.weaponVariants[2] and state.container.cap==0)
    for limit=2,8 do
        config.iconsPerRow=limit;ChangeEquipment(Enchant(1,1000),Enchant(1,2000));state=Refresh()
        assert(state.container.cap+2==limit)
        local a={{name="first"},{name="second"}};local result=W.Prepend(owner,"Buffs",config,a)
        assert(#result<=limit and result[1].inventorySlot==16 and result[2].inventorySlot==17)
        if limit>=4 then assert(result[3]==a[1] and result[4]==a[2]) end
        assert(state.container.enchantLayout.forceNewLine~=true and state.container.auraLayout.forceNewLine~=true)
        assert((state.container.auraLayout.groupSpacing or 0)==0, "double spacing can add an extra row")
    end
    config.maxRows=0;state=Refresh();assert(state.container.cap==38)
    config.iconsPerRow=4;config.maxRows=1
end)
Test("Aura-only metadata/duration filters never filter weapon records",function()
    for _,field in ipairs({"showOnlyMine","showBossAuras","showStealableOnly","showDispellableOnly","hideLongAuras","hidePermanentAuras"}) do
        config[field]=true
    end
    config.longAuraThreshold=1;state=Refresh()
    local visible=ns.AuraFilters.FilterAuras({{isHelpful=true,durationState="TIMED",duration=300}},config,"Buffs",owner)
    local result=W.Prepend(owner,"Buffs",config,visible)
    assert(#visible==0 and #result==2 and state.container.cap==2)
    assert(state.container.slots[0].candidateFilters==nil and state.container.filters.maxDuration==1)
    config.showWeaponEnhancements=false;state=Refresh();assert(state.container==state.baseContainer)
    config.showWeaponEnhancements=true;state=Refresh();assert(state.container==state.weaponVariants[3])
end)
Test("Player only, including saved option on non-player and Debuffs",function()
    local before=reads
    for _,unit in ipairs({"target","focus","boss1","boss","pet","targettarget","focustarget"}) do
        local f={_fpUnit=unit};assert(#W.GetEntries(f,"Buffs",config)==0)
        local a={};assert(W.Prepend(f,"Buffs",config,a)==a)
    end
    assert(#W.GetEntries(owner,"Debuffs",config)==0 and reads==before)
end)
Test("Clear/reuse and layout/spec config replacement retain bounded containers",function()
    M.ClearGroup(owner,"Buffs");for _,v in pairs(state.weaponVariants) do assert(not v.shown and v.enabled==false) end
    config=Copy(config);owner.config.Buffs=config;config.showWeaponEnhancements=false;state=Refresh()
    assert(state.container==state.baseContainer)
    config=Copy(config);owner.config.Buffs=config;config.showWeaponEnhancements=true;state=Refresh()
    for i=1,20 do config.showWeaponEnhancements=not config.showWeaponEnhancements;Refresh() end
    assert(nativeAllocations==4)
end)
Test("Combat updates equipment within applied config; settings defer until resync",function()
    config.showWeaponEnhancements=true;config.iconsPerRow=4;state=Refresh();combat=true
    config.showWeaponEnhancements=false;config.iconsPerRow=1
    ChangeEquipment(nil,Enchant(4,30000));state=Refresh()
    assert(state.container==state.weaponVariants[2] and state.container.cap==3 and state.weaponConfigPending)
    combat=false;state=Refresh();assert(state.container==state.baseContainer and state.container.cap==1)
    assert(not state.weaponConfigPending)
    assert(nativeAllocations==4)
end)
Test("existing aura event lifecycle routes weapons without cache clear or polling",function()
    local queued=0
    ns.UnitFrameState={QueueRefresh=function(frame,channel) assert(frame==owner and channel=="auras");queued=queued+1 end}
    ns.AuraCache={ClearAll=Noop}
    Load("Engine/Auras/Runtime/AuraEvents.lua")
    ns.AuraEvents.Register(owner,Noop);local event=owner.AuraEventFrame
    assert(event.events.WEAPON_ENCHANT_CHANGED and event.events.WEAPON_SLOT_CHANGED and not event.events.PLAYER_EQUIPMENT_CHANGED)
    local before=queued;event.scripts.OnEvent(event,"WEAPON_ENCHANT_CHANGED");assert(queued==before)
    config.showWeaponEnhancements=true;event.scripts.OnEvent(event,"WEAPON_SLOT_CHANGED");assert(queued==before+1)
    assert(owner._weaponEnhancements==nil and event.scripts.OnUpdate==nil)
    event.scripts.OnEvent(event,"PLAYER_ENTERING_WORLD");assert(queued==before+3)
    Refresh();combat=true;config.showWeaponEnhancements=false;Refresh()
    assert(state.weaponConfigPending)
    -- The applied source remains live until the deferred disable is committed.
    event.scripts.OnEvent(event,"WEAPON_ENCHANT_CHANGED");assert(queued==before+4)
    combat=false;event.scripts.OnEvent(event,"PLAYER_REGEN_ENABLED");assert(queued==before+5)
    Refresh();event.scripts.OnEvent(event,"PLAYER_REGEN_ENABLED");assert(queued==before+5)
    config.showWeaponEnhancements=true
    local target={_fpUnit="target",config={Buffs=config}}
    ns.UnitFrameState.QueueRefresh=Noop;ns.AuraEvents.Register(target,Noop)
    assert(not target.AuraEventFrame.events.WEAPON_ENCHANT_CHANGED)
end)
Test("actual Runtime fallback/preview bypass aura filters without contaminating AuraCache",function()
    local cache={};local rendered;local fixtures
    ns.AuraCache={GetGroup=function() return cache end,ClearAll=Noop,ClearGroup=Noop}
    ns.AuraScan={CollectUnitAuras=function() return true,{{isHelpful=true,isMine=true,isStealable=true,durationState="TIMED",duration=0.5,icon=5}} end}
    ns.AuraRenderer={RenderGroup=function(_,_,entries) rendered=entries end,ClearGroup=Noop}
    ns.AuraBackendResolver={RefreshManagedGroup=function() return false end,ClearManagedGroup=function(f,k) M.ClearGroup(f,k) end}
    ns.UnitFrameDemoEnvironment={GetAuras=function() return fixtures end}
    Load("Engine/Auras/Runtime/AuraRuntime.lua")
    config.iconsPerRow=4;ChangeEquipment(Enchant(1,30000),Enchant(2,50000))
    ns.AuraRuntime.RefreshAuraGroup(owner,"player","Buffs")
    assert(#rendered==3 and rendered[1].kind=="weaponEnhancement")
    assert(#cache.sortedAuras==1 and not cache.sortedAuras[1].kind and #cache.allAuras==1)
    ns.guiTestModeEnabled=true;fixtures={{isHelpful=true,isMine=true,isStealable=true,icon=4,durationState="TIMED",duration=0.5}}
    local before=reads;ns.AuraRuntime.RefreshAuraGroup(owner,"player","Buffs")
    assert(rendered[1].preview and rendered[1].tooltipKind==nil and reads==before)
    fixtures={};ns.AuraRuntime.RefreshAuraGroup(owner,"player","Buffs");assert(#rendered==0)
    ns.guiTestModeEnabled=false;ns.AuraRuntime.Reset(owner);assert(owner._weaponEnhancements==nil)
end)
Test("existing icon renderer: inventory tooltip, synthetic isolation, pool clear",function()
    Load("Engine/Auras/Layout/AuraContainer.lua")
    GameTooltip={SetOwner=function(self,o) self.owner=o end,IsOwned=function(self,o) return self.owner==o end,
        SetInventoryItem=function(self,u,s) assert(u=="player");self.slot=s end,Show=Noop,
        Hide=function(self) self.owner=nil end}
    local icon=ns.AuraContainer.Create(Surface());local entry=W.GetEntries(owner,"Buffs",config)[1]
    ns.AuraContainer.ApplyData(icon,entry,config);icon.scripts.OnEnter(icon)
    assert(icon.mouse and GameTooltip.slot==16 and icon.Cooldown.cooldown[2]==30)
    ns.AuraContainer.Clear(icon);assert(not icon.mouse and icon.AuraData==nil and not GameTooltip.owner)
    ns.AuraContainer.ApplyData(icon,W.GetEntries(owner,"Buffs",config,true)[1],config)
    icon.scripts.OnEnter(icon);assert(not GameTooltip.owner and not icon.mouse)
end)
Test("minimal Inspector checkbox uses existing mutation path and Player-only disabled state",function()
    local file=assert(io.open("GUI/Editor/Inspector/InspectorController.lua"));local source=file:read("*a");file:close()
    local a=assert(source:find('        if selectedAuraKey == "Buffs" then\n            local addWeaponOption',1,true))
    local b=assert(source:find('        local auraIconsPerRowControl',a,true))
    local block=source:sub(a,b-1)
    for _,unit in ipairs({"player","target","focus","boss","pet"}) do
        for _,scoped in ipairs({false,true}) do
            local row,mutations;mutations=0
            local function Add(_,label,value,callback,disabled,key) row={label=label,callback=callback,disabled=disabled,key=key} end
            local env={selectedAuraKey="Buffs",selectedUnit=unit,isScopedObject=scoped,auraConfig=config,L={},
                AddPropertyCheckBoxRow=Add,AddCheckBox=Add,SetAuraField=function(k,f,v)
                    assert(k=="Buffs" and f=="showWeaponEnhancements" and v==true);mutations=mutations+1 end}
            assert(load(block,"@WeaponCheckbox","t",env))()
            assert(row.key=="aura_weapon_enhancements" and row.disabled==(unit~="player"))
            row.callback(true);assert(mutations==(unit=="player" and 1 or 0))
        end
    end
end)
print("WeaponEnhancements: "..passed.." groups passed; native-client smoke still required")

return {ns=ns, owner=owner, config=config, Refresh=Refresh, ChangeEquipment=ChangeEquipment, Enchant=Enchant}
