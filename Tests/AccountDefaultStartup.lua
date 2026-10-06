-- Actual AceDB/E6A/OnInitialize/OnEnable and assignment event. Native rendering
-- is replaced by a first config read, the same entry used by SpawnUnitFrame.
local file=assert(io.open("Tests/TextTemplateEntityStartup.lua"))
local source=file:read("*a"); file:close()
local boundary=assert(source:find("local result=Start(LegacyDB())",1,true))
local ns,Load,LegacyDB,Start=assert(load(source:sub(1,boundary-1)..
    "\nreturn ns,Load,LegacyDB,Start","@AccountDefault/Startup"))()
local spawn=ns.SpawnUnitFrame
Load("Engine/UnitFrame.lua")
local roots, activations = {}, {}
ns.SpawnUnitFrame=function(...)
    spawn(...)
    local root=assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot())
    roots[#roots+1]=root.layoutId
end
ns.ResyncActiveLayout=function()
    activations[#activations+1]=ns.db.char.activeLayoutId
    assert(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().layoutId==ns.db.char.activeLayoutId)
    return true,"resynced"
end
function GetSpecialization() return 1 end
C_SpecializationInfo={GetSpecializationInfo=function() return 71 end}
local function EventFrame(reset)
    for i=1,20 do
        local name,value=debug.getupvalue(ns.LayoutAssignmentService.InitializeRuntime,i)
        if name=="eventFrame" then
            if reset then debug.setupvalue(ns.LayoutAssignmentService.InitializeRuntime,i,nil) end
            return value
        end
    end
end
local passed=0
for _,case in ipairs({
    {name="legacy", noDefault=true, target="builtin:default"},
    {name="account default", target="builtin:modern"},
    {name="spec priority", spec="builtin:minimal", target="builtin:minimal"},
    {name="spec without default", noDefault=true, spec="builtin:minimal", target="builtin:minimal"},
}) do
    local saved=LegacyDB()
    saved.char={["Test player - Test realm"]={activeLayoutId="builtin:default",LayoutAssignments={
        specialization={[71]=case.spec}}}}
    if not case.noDefault then saved.global.defaultLayoutId="builtin:modern" end
    roots,activations={},{}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot(); EventFrame(true)
    assert(Start(saved).ok)
    assert(#roots==11 and #activations==0,case.name..": early startup changed")
    for _,id in ipairs(roots) do assert(id=="builtin:default",case.name..": early baseline activation") end
    local assignmentsBefore=ns.db.char.LayoutAssignments
    local event=assert(EventFrame())
    event.scripts.OnEvent(event,"PLAYER_ENTERING_WORLD")
    assert(ns.db.char.activeLayoutId==case.target,case.name)
    assert(ns.db.char.LayoutAssignments==assignmentsBefore,case.name..": login adoption/normalization")
    assert(#activations==(case.target=="builtin:default" and 0 or 1),case.name..": extra intermediate activation")
    if #activations==1 then assert(activations[1]==case.target) end
    -- Reload the prepared current database: the same final layout needs no resync.
    local current=ns.db.sv
    roots,activations={},{}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot(); EventFrame(true)
    assert(Start(current).ok)
    event=assert(EventFrame()); event.scripts.OnEvent(event,"PLAYER_ENTERING_WORLD")
    assert(ns.db.char.activeLayoutId==case.target and #activations==0,case.name..": reload changed layout")
    passed=passed+1
end
FocalPointDB=nil
print("PASS AccountDefaultStartup: "..passed.." real startup/reload timelines; early A unchanged, login A-to-B or A-to-C only")
