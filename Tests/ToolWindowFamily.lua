-- lua54 Tests/ToolWindowFamily.lua
-- Reuse native WoW doubles and real AceGUI widgets, without modifying U1 tests.
local file=assert(io.open("Tests/DialogWindowFamily.lua")); local source=file:read("*a"); file:close()
local stop=assert(source:find("-- Direct utility chrome",1,true))
local f,Find=assert(load(source:sub(1,stop-1).."\nforms.CreateCompactFormDialog=create; return f,Find","@Tool/NativeFixture"))()
local ns,ace,native,Equal,Load,Upvalue=f.ns,f.ace,f.native,f.Equal,f.Load,f.Upvalue
local forms=f.widgets
function native:SetStatusBarColor(...) self.lastSetStatusBarColor={...} end
function native:SetStatusBarTexture(...) self.lastSetStatusBarTexture={...} end
local tool={nineSlice=true,portrait=true,focalPointTool=true}
local legacy={nineSlice=true,portrait=true,portraitTexture="portrait.png"}
local material=ns.GUI.Skins.GetFormPalette().CompactDialogContent.parchment
local texture=ns.MediaRegistry.ResolveReference(material.textureId,"texture").resolvedAsset
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
local function Check(window,w,h)
    local frame=window.frame; local border=assert(frame._fpModernNineSlice)
    assert(frame._fpToolChromeActive and border:IsShown())
    Equal({frame:GetWidth(),frame:GetHeight()},{w,h})
    Equal(border.TopLeftCorner.nativeWidth,28); Equal(border.TopEdge.nativeHeight,28)
    Equal(border.TopRightCorner.lastSetTexCoord,{1,0,0,1})
    Equal(border.lastSetAllPoints,{frame})
    assert(not window._fpNavigatorBrassTarget and not frame._fpCompactFormShell)
    for _,key in ipairs({"_fpToolBody","_fpToolTitlebar"}) do
        local region=assert(frame[key]); assert(region:IsShown())
        Equal(region:GetTexture(),texture)
        Equal(region.lastSetVertexColor,key=="_fpToolBody" and material.tint or material.headerTint)
        Equal(region.lastSetHorizTile,{false}); Equal(region.lastSetVertTile,{false})
        Equal(region.lastSetTexCoord,{0,1,0,1})
    end
    Equal(frame._fpToolTitlebar:GetHeight(),24)
    local color=ns.GUI.Helpers.TextStyles.Get("sectionHeader")
    Equal(window.titletext.lastSetTextColor,{color.r,color.g,color.b,1})
    for _,key in ipairs({"_fpModernPortraitContainer","_fpModernPortraitBackground","_fpModernPortraitTopTileStreaks",
        "_fpModernTitleLeft","_fpModernTitleCenter","_fpModernTitleRight"}) do
        assert(not frame[key] or not frame[key]:IsShown(),key)
    end
    for _,region in ipairs({frame:GetRegions()}) do
        if region:GetTexture()==251963 or region:GetTexture()==251966 or region:GetTexture()==137056 then
            assert(not region:IsShown(),"native texture leaked")
        end
    end
    assert(not border.Center or not border.Center:IsShown())
    Equal(window.closebutton:GetFrameLevel(),frame:GetFrameLevel()+5)
    Equal(window.title:GetFrameLevel(),frame:GetFrameLevel()+4)
    assert(not window.sizer_se:IsShown() and not window.sizer_s:IsShown() and not window.sizer_e:IsShown())
end

-- Compare the same actual Window before/after presentation, including scripts.
local window=ace:Create("Window"); window:EnableResize(false)
local nativeStates={}
for _,region in ipairs({window.frame:GetRegions()}) do
    nativeStates[region]={region:IsShown(),region:GetAlpha(),region:GetTexture()}
end
local neutral=f.Geometry(window)
forms.ApplyModernWindowChrome(window,legacy)
local baseline=f.Geometry(window); local font={window.titletext:GetFont()}
local shadowOffset,shadowColor=window.titletext.lastSetShadowOffset,window.titletext.lastSetShadowColor
local close,drag,dragEnd=window.closebutton:GetScript("OnClick"),window.title:GetScript("OnMouseDown"),window.title:GetScript("OnMouseUp")
forms.ApplyModernWindowChrome(window,tool)
Equal(f.Geometry(window),baseline); Equal({window.titletext:GetFont()},font)
Equal(window.titletext.lastSetShadowOffset,shadowOffset); Equal(window.titletext.lastSetShadowColor,shadowColor)
Equal(window.closebutton:GetScript("OnClick"),close); Equal(window.title:GetScript("OnMouseDown"),drag)
Equal(window.title:GetScript("OnMouseUp"),dragEnd)
local count=f.Count(); local release=window.events.OnRelease
for i=1,50 do
    local sizes={{720,660},{760,560},{1040,700}}; local size=sizes[(i-1)%3+1]
    window:SetWidth(size[1]); window:SetHeight(size[2])
    forms.ApplyModernWindowChrome(window,tool); Check(window,size[1],size[2])
    Equal(window.content:GetWidth(),size[1]-34); Equal(window.content:GetHeight(),size[2]-57)
    Equal(window.events.OnRelease,release)
    forms.RestoreDefaultWindowChrome(window)
    assert(not window.frame._fpToolBody:IsShown() and not window.frame._fpToolTitlebar:IsShown())
    assert(not window.frame._fpModernNineSlice:IsShown())
    for region,state in pairs(nativeStates) do Equal({region:IsShown(),region:GetAlpha(),region:GetTexture()},state) end
end
Equal(f.Count(),count)
window:SetWidth(neutral[1]); window:SetHeight(neutral[2]); Equal(f.Geometry(window),neutral)
forms.ApplyModernWindowChrome(window,tool); ace:Release(window)
local poolCount; local releases=0
for i=1,30 do
    local acquired=ace:Create("Window"); Equal(acquired,window); acquired:EnableResize(false)
    acquired:SetCallback("OnRelease",function() releases=releases+1 end)
    forms.ApplyModernWindowChrome(acquired,legacy)
    forms.ApplyModernWindowChrome(acquired,tool); Check(acquired,700,500)
    forms.ApplyWindowChrome(acquired,{focalPointDialog=true})
    assert(not acquired.frame._fpToolBody:IsShown()); assert(not acquired.frame._fpModernNineSlice:IsShown())
    forms.ApplyModernWindowChrome(acquired,tool); assert(not acquired.frame._fpParchmentNineSlice:IsShown())
    ace:Release(acquired)
    Equal(releases,i)
    assert(not acquired.frame._fpModernNineSlice:IsShown())
    if i==1 then poolCount=f.Count() else Equal(f.Count(),poolCount) end
end
NoErrors()

-- Actual tools: only media/catalog and persistence are fixture data.
local applyModern=forms.ApplyModernWindowChrome; local consumerCount=0
forms.ApplyModernWindowChrome=function(owner,options)
    assert(options.focalPointTool and options.nineSlice and options.portrait)
    local old={}; for k,v in pairs(options) do old[k]=v end; old.focalPointTool=nil
    applyModern(owner,old)
    local geometry=f.Geometry(owner); local titleFont={owner.titletext:GetFont()}
    applyModern(owner,options)
    Equal(f.Geometry(owner),geometry); Equal({owner.titletext:GetFont()},titleFont)
    consumerCount=consumerCount+1
end
for _,path in ipairs({"GUI/Editor/MediaLibrary/MediaLibraryItems.lua","GUI/Editor/MediaLibrary/MediaLibraryPreviewWidget.lua",
    "GUI/Editor/MediaLibrary/MediaLibraryPreview.lua","GUI/Editor/MediaLibrary/MediaLibraryView.lua",
    "GUI/Editor/MediaLibrary/MediaLibraryController.lua"}) do Load(path) end
local applied,cancelled=nil,0
local media=ns.GUI.Editor.MediaLibrary.Controller
local function OpenMedia()
    assert(media.Open({mediaType="font",onApply=function(value) applied=value end,onCancel=function() cancelled=cancelled+1 end}))
end
OpenMedia(); NoErrors()
local mediaContext=Upvalue(media.Open,"context")
Check(mediaContext.window,720,660)
assert(mediaContext.widgets.preview and mediaContext.widgets.itemScroll)
assert(#mediaContext.state.items>0)
mediaContext.widgets.searchBox:Fire("OnTextChanged","unlikely-missing-font"); NoErrors()
Equal(mediaContext.state.searchText,"unlikely-missing-font")
mediaContext.widgets.searchBox:Fire("OnTextChanged","")
mediaContext.widgets.sourceDropdown:Fire("OnValueChanged","all"); NoErrors()
local row=assert(mediaContext.widgets.itemRows[1]); row.widget:Fire("OnClick")
mediaContext.widgets.applyButton:Fire("OnClick"); NoErrors(); assert(applied)
OpenMedia(); mediaContext.widgets.cancelButton:Fire("OnClick"); Equal(cancelled,1)

ns.UnitFrame=ns.UnitFrame or {}
function ns.UnitFrame:GetTagDatabase() return {{token="[name]",category="Unit",description="Unit name",example="Player"},
    {token="[hp:cur]",category="Health",description="Current health",example="100"}} end
Load("GUI/Pages/TagLibrary/TagLibraryView.lua"); Load("GUI/Pages/TagLibrary/TagLibraryController.lua")
local tags=ns.GUI.Pages.TagLibrary; local tagApplied
local function OpenTags() assert(tags.Open({owner="fixture",onApply=function(token) tagApplied=token end})) end
OpenTags(); NoErrors()
local tagContext=Upvalue(tags.Open,"context"); Check(tagContext.window,760,560)
tagContext.widgets.searchBox:Fire("OnTextChanged","name"); NoErrors()
Equal(#tagContext.state.visibleEntries,1); Equal(tagContext.state.selectedEntry.token,"[name]")
assert(#tagContext.widgets.details.children>0 and tagContext.widgets.listScroll)
tagContext.widgets.applyButton:Fire("OnClick"); Equal(tagApplied,"[name]")
OpenTags(); tagContext.widgets.cancelButton:Fire("OnClick")
NoErrors()

Load("Data/Constants.lua"); ns.KeyMap=ns.KeyMap or {}
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua"); Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Pages/TextBuilder/TextBuilderDefinition.lua")
local templates={Sample="[name]"}; local mutationCalls={}
ns.db.GetCurrentProfile=function() return "Test" end
ns.UnitFrameUtils={GetTextTemplatesDB=function() return templates end}
local builderPayload={TextTemplates=templates,Units={}}
ns.ActiveLayoutResolver={
    GetStoredActiveLayoutId=function() return ns.db.char.activeLayoutId end,
    GetActiveLayout=function() return {name="Tool fixture",readOnly=false,payload=builderPayload} end,
    EnsureEditableForMutation=function() return builderPayload,ns.db.char.activeLayoutId end,
}
ns.TextTemplateMutations={
    CreateTemplate=function(_,name,text) templates[name]=text; mutationCalls.create=name; return {ok=true} end,
    UpdateTemplate=function(_,name,text) templates[name]=text; mutationCalls.update=name; return {ok=true} end,
    ApplyTemplateToUnits=function(_,opts) mutationCalls.apply=opts; return {ok=true,appliedUnits=opts.unitsToAdd} end,
}
Load("GUI/Pages/TextBuilder/TextBuilderController.lua")
local builder=ns.GUI.Pages.TextBuilder
builder.OpenWindow(); NoErrors()
Equal(consumerCount,3); forms.ApplyModernWindowChrome=applyModern
local builderContext=Upvalue(builder.OpenWindow,"windowContext")
Check(builderContext.window,1040,700)
local key=table.concat({"profile","Test","Test","","Sample"},"\031")
builderContext.templateSelect:Fire("OnValueChanged",key); NoErrors()
Equal(builderContext.state.selectedTemplate,"Sample"); Equal(builderContext.templateEdit:GetText(),"[name]")
builderContext.templateEdit:SetText("[hp:cur]"); builderContext.templateEdit:Fire("OnTextChanged","[hp:cur]")
assert(builder.HasUnsavedChanges())
builderContext.saveButton:Fire("OnClick"); NoErrors()
Equal(mutationCalls.update,"Sample"); Equal(templates.Sample,"[hp:cur]"); assert(not builder.HasUnsavedChanges())
builderContext.usageCheckboxes.player:Fire("OnValueChanged",true)
builderContext.applyTemplateButton:Fire("OnClick"); NoErrors()
Equal(mutationCalls.apply.templateText,"[hp:cur]"); Equal(mutationCalls.apply.unitsToAdd,{"player"})
builderContext.templateEdit:SetText("[name] dirty"); builderContext.templateEdit:Fire("OnTextChanged","[name] dirty")
assert(builder.HasUnsavedChanges())
builder.HideWindow(); NoErrors(); assert(builderContext.window.frame:IsShown())
local function Closure(fn,name,seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local children={}
    for i=1,100 do local key,value=debug.getupvalue(fn,i); if not key then break end
        if key==name then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local value=Closure(child,name,seen); if value then return value end end
end
local closeContext=assert(Closure(builder.HideWindow,"unsavedCloseDialogContext"))
assert(closeContext.window.frame._fpParchmentNineSlice:IsShown())
assert(not closeContext.window.frame._fpToolChromeActive)
closeContext.cancelButton:Fire("OnClick"); assert(builderContext.window.frame:IsShown())
builder.HideWindow(); closeContext.discardCloseButton:Fire("OnClick"); assert(not builderContext.window.frame:IsShown())
-- Discard now clears the draft rather than only hiding the tool.
assert(not builder.HasUnsavedChanges())
Equal(builderContext.templateEdit:GetText(),"")
assert(builderContext.state.editingLayoutId==nil and builderContext.state.draftBaseline==nil)
NoErrors()

local warmCount
local callbacks={mediaContext.window.events.OnRelease,tagContext.window.events.OnRelease,builderContext.window.events.OnRelease}
for cycle=1,30 do
    OpenMedia(); Check(mediaContext.window,720,660)
    mediaContext.window.frame:Run("OnKeyDown","ESCAPE"); assert(not mediaContext.window.frame:IsShown())
    OpenTags(); Check(tagContext.window,760,560)
    tagContext.window.closebutton:Run("OnClick"); assert(not tagContext.window.frame:IsShown())
    builder.OpenWindow(); Check(builderContext.window,1040,700)
    builderContext.window.closebutton:Run("OnClick"); assert(not builderContext.window.frame:IsShown())
    Equal({mediaContext.window.events.OnRelease,tagContext.window.events.OnRelease,builderContext.window.events.OnRelease},callbacks)
    if cycle==1 then warmCount=f.Count() else Equal(f.Count(),warmCount) end
end
NoErrors()
print("PASS: FP Tool structure/material/neutralization, 50 reset/size/reapply cycles, 30 pooling/tool-reopen cycles; real Media/Tag search/selection/preview/actions and TextBuilder template/edit/save/apply/dirty-close with U1 utility")
