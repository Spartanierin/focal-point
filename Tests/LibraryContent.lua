-- lua54 Tests/LibraryContent.lua
-- Real Media/Tag controllers, catalog, views and AceGUI layouts. Native text
-- measurements below model wrapping; final font rendering remains ingame QA.
local file=assert(io.open("Tests/ToolWindowFamily.lua")); local source=file:read("*a"); file:close()
local f,mc,tc=assert(load(source.."\nreturn f,mediaContext,tagContext","@Library/ToolFixture"))()
local ns,native,Equal=f.ns,f.native,f.Equal
local media=ns.GUI.Editor.MediaLibrary.Controller
local tags=ns.GUI.Pages.TagLibrary
local mediaView=ns.GUI.Editor.MediaLibrary.MediaLibraryView
local tagView=ns.GUI.Pages.TagLibraryView
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
function native:GetStringHeight()
    local text=(self:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    if text=="" then return 1 end
    if self.lastSetWordWrap and self.lastSetWordWrap[1]==false then return 14 end
    local width=math.max(1,self:GetWidth())
    return 14*math.max(1,math.ceil((utf8.len(text) or #text)*6/width))
end
local function Contains(text,part) assert(text:find(part,1,true),text.." missing "..part) end
local function LabelText(widget) return widget.label:GetText() end
local function CheckMediaLayout()
    local w=mc.widgets
    w.root:DoLayout(); w.metadata:DoLayout()
    Equal({mc.window.frame:GetWidth(),mc.window.frame:GetHeight()},{720,660})
    Equal(w.itemScroll.frame:GetHeight(),226); Equal(w.preview.frame:GetHeight(),112)
    local total=0
    for _,child in ipairs(w.root.children) do total=total+child.frame:GetHeight() end
    assert(total<=mc.window.content:GetHeight(),"Media root budget "..total)
    local metadata=w.selectedLabel.frame:GetHeight()+3+math.max(w.sourceLabel.frame:GetHeight(),w.statusLabel.frame:GetHeight())
    if w.selectionHelp.frame:IsShown() then metadata=metadata+3+w.selectionHelp.frame:GetHeight() end
    assert(metadata<=w.metadata.frame:GetHeight(),"Media metadata budget "..metadata)
    Equal(#w.metadata.children,6)
    Equal(total,603)
    local function CellSpan(widget)
        local left,right
        for i=1,widget.frame:GetNumPoints() do
            local point,_,_,x=widget.frame:GetPoint(i)
            if point=="LEFT" then left=x elseif point=="RIGHT" then right=x end
        end
        return assert(right)-assert(left)
    end
    assert(CellSpan(w.selectedLabel)>CellSpan(w.sourceLabel))
    assert(not w.valueLabel.frame:IsShown() and not w.resolvedAssetLabel.frame:IsShown())
    Equal(w.searchBox.label.font[2],13);Equal(w.sourceDropdown.label.font[2],13)
    Equal(w.searchBox.editbox.font[2],14)
    -- Real AceGUI widget sizes/anchors: Source bottom=40, search row=40,
    -- list section begins at 14+40+12=66; host top remains 15 above it.
    Equal(w.searchBox.frame:GetHeight(),40);Equal(w.sourceDropdown.frame:GetHeight(),40)
    Equal(w.root.children[3].frame:GetHeight(),12)
    Equal(w.selectedLabel:GetUserData("cell").colspan,2)
    Equal(w.selectedLabel.label.lastSetMaxLines,{1})
    Equal(w.listGroup.frame:GetHeight(),272); Equal(w.previewGroup.frame:GetHeight(),192)
    Equal(w.filterRow.frame:GetHeight(),40); Equal(w.actions.frame:GetHeight(),25)
    Equal(#w.actions.children,2)
    Equal(w.actions.children[1],w.applyButton); Equal(w.actions.children[2],w.cancelButton)
    Equal(w.sourceDropdown:GetUserData("table"),nil)
    for _,child in ipairs(w.metadata.children) do
        Equal(child.label.lastSetWordWrap,{false})
        if child==w.selectedLabel then
            Contains(child.frame.__fpInspectorTooltip,LabelText(w.valueLabel))
            Contains(child.frame.__fpInspectorTooltip,LabelText(w.resolvedAssetLabel))
        else assert(child.frame.__fpInspectorTooltip==LabelText(child)) end
    end
    local yellow=NORMAL_FONT_COLOR or ns.GUI.Helpers.TextStyles.Get("sectionHeader")
    Equal(w.listTitle.label.lastSetTextColor,{yellow.r,yellow.g,yellow.b,1})
    Equal(w.listTitle.label.font[2],14); Equal(w.preview.title.font[2],14)
    assert(w.searchBox.frame._fpMediaSearchFill:IsShown())
    assert(not w.previewStatusLabel and not w.fallbackUsedLabel)
    local color=ns.GUI.Helpers.TextStyles.Get("help")
    Equal(w.title.label.lastSetTextColor,{color.r,color.g,color.b,1})
    Equal(w.title.label.font[2],11)
    assert(mc.window:GetUserData("fpDirectEditModeChrome"))
    assert(not mc.window.frame._fpToolChromeActive)
    assert(mc.window.frame._fpModernPortraitBackground:IsShown())
    Equal(mc.window.frame._fpModernPortraitBackground.lastSetColorTexture,{0,0,0,.8})
    Equal({mc.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    NoErrors()
end
local function CheckTagLayout()
    local w=tc.widgets
    -- The accepted ToolWindowFamily reference uses 540 width and FitWindow's
    -- content-derived height; 670 is the requested size, not a fixed text measure.
    Equal(tc.window.frame:GetWidth(),540)
    Equal(w.listScroll.frame:GetHeight(),242)
    Equal(w.browser.frame:GetHeight(),324); Equal(w.detailGroup.frame:GetHeight(),160)
    assert(w.browser.parent==w.detailGroup.parent)
    Equal(w.browser.parent.children[2].frame:GetHeight(),32)
    Equal(w.browser.parent.LayoutFunc,f.ace:GetLayout("List"))
    Equal({tc.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    assert(not tc.window.frame._fpToolChromeActive)
    -- Mirror the existing ToolWindowFamily handling of stretched native anchors.
    tc.dialog.body.content:SetSize(tc.dialog.body.frame:GetWidth(),tc.dialog.body.frame:GetHeight())
    tc.dialog.body:DoLayout()
    local padding=w.root._fpSectionPadding
    w.root.content:SetSize(w.root.frame:GetWidth()-padding.left-padding.right,
        w.root.frame:GetHeight()-padding.top-padding.bottom)
    w.root:DoLayout()
    local stack=w.browser.parent
    stack.content:SetSize(stack.frame:GetWidth(),stack.frame:GetHeight())
    stack:DoLayout()
    w.details:DoLayout()
    Equal(w.details.type,"ScrollFrame")
    Equal(w.details.frame:GetHeight(),112)
    local fields=w.details.children
    if tc.state.selectedEntry then
        Equal(#fields,8)
        local expected={tc.state.selectedEntry.token,tc.state.selectedEntry.category,
            tc.state.selectedEntry.description,tc.state.selectedEntry.example}
        for i,index in ipairs({1,2,5,8}) do
            Equal(fields[index].type,"Label")
            Equal(LabelText(fields[index]),expected[i]~="" and expected[i] or "-")
        end
        Equal(LabelText(fields[4]),ns.L.INFO_TAG_LIBRARY_COL_DESC)
        Equal(LabelText(fields[7]),ns.L.INFO_TAG_LIBRARY_COL_EXAMPLE)
        for _,index in ipairs({3,6}) do
            Equal(fields[index].type,"SimpleGroup"); Equal(fields[index].frame:GetHeight(),8)
        end
    else
        Equal(#fields,1); Equal(LabelText(fields[1]),ns.L.INFO_TAG_LIBRARY_NO_SELECTION)
    end
    local needed=0
    for _,field in ipairs(fields) do needed=needed+field.frame:GetHeight() end
    -- Long descriptions/examples belong to scroll content, not a growing viewport.
    assert(w.details.content:GetHeight()>=needed,"Tag scroll content clips wrapped text")
    local total=w.root._fpSectionPadding.top+w.root._fpSectionPadding.bottom
    for _,child in ipairs(w.root.children) do total=total+child.frame:GetHeight() end
    Equal(total,tc.window.content:GetHeight())
    Equal(tc.window.frame:GetWidth(),540)
    Equal(tc.window.frame:GetHeight(),57+total)
    local color=ns.GUI.Helpers.TextStyles.Get("parchmentSecondary")
    Equal(w.subtitle.label.lastSetTextColor,{color.r,color.g,color.b,1}); Equal(w.subtitle.label.font[2],12)
    NoErrors()
end

local applied,cancelled
local function OpenMedia(kind,current)
    applied=nil; cancelled=0
    assert(media.Open({mediaType=kind or "font",currentValue=current or "fp:font:standard",
        onApply=function(value,item) applied={value=value,item=item} end,
        onCancel=function() cancelled=cancelled+1 end}))
end

-- The longest descriptions are taken from the actual product catalog/locales.
f.Load("Engine/TextElements.lua")
local getDatabase=ns.UnitFrame.GetTagDatabase
for _,locale in ipairs({"enUS","deDE"}) do
    GetLocale=function() return locale end
    f.Load("Locales/enUS.lua"); if locale=="deDE" then f.Load("Locales/deDE.lua") end
    OpenMedia()
    local current=mc.state.currentValue
    assert(mc.state.selectedItem and mc.state.selectedItem.selectable)
    local selected=mc.state.selectedItem
    Equal(mc.widgets.selectionHelp.label:GetText(),ns.L.MEDIA_LIBRARY_SELECTION_VISIBLE)
    assert(not mc.widgets.selectionHelp.frame:IsShown())
    CheckMediaLayout()
    local other
    for _,item in ipairs(mc.state.items) do if item.selectable and item.value~=selected.value then other=item; break end end
    assert(other,"catalog needs multiple selectable fonts")
    mc.callbacks.onSelect(other); selected=other
    Equal(mc.state.currentValue,current); Equal(mc.state.currentItem.value,current)
    Equal(mc.widgets.preview.item,selected)
    Contains(LabelText(mc.widgets.selectedLabel),selected.name)
    mc.widgets.searchBox:Fire("OnTextChanged",selected.name)
    assert(#mc.state.items>0)
    Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_VISIBLE)
    CheckMediaLayout()
    mc.widgets.searchBox:Fire("OnTextChanged","__no_library_result_90231__")
    Equal(#mc.state.items,0); Equal(mc.state.selectedItem,selected)
    Equal(LabelText(mc.widgets.itemScroll.children[1]),ns.L.MEDIA_LIBRARY_NO_MEDIA_FOUND)
    Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_RETAINED)
    assert(mc.widgets.selectionHelp.frame:IsShown())
    assert(not mc.widgets.applyButton.disabled); Equal(mc.widgets.preview.item,selected)
    CheckMediaLayout()
    mc.widgets.applyButton:Fire("OnClick")
    Equal(applied.value,selected.value); Equal(applied.item,selected); Equal(cancelled,0)

    OpenMedia(); selected=mc.state.selectedItem
    mc.widgets.searchBox:Fire("OnTextChanged","__no_library_result_90231__")
    mc.widgets.searchBox:Fire("OnTextChanged","")
    Equal(mc.state.selectedItem.value,selected.value)
    Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_VISIBLE)
    assert(#mc.state.items>0)
    mc.widgets.sourceDropdown:Fire("OnValueChanged","Shared")
    assert(not mc.widgets.applyButton.disabled)
    if not next(mc.state.items) then Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_RETAINED) end
    mc.widgets.sourceDropdown:Fire("OnValueChanged","all")
    mc.widgets.cancelButton:Fire("OnClick"); Equal(cancelled,1)

    -- Missing current reference is a real nonselectable item, not a fabricated selection.
    OpenMedia("font","fp:font:missing-library-test")
    assert(mc.state.selectedItem.missing and mc.state.selectedItem.selectable==false)
    assert(mc.widgets.applyButton.disabled)
    Contains(LabelText(mc.widgets.statusLabel),ns.L.MEDIA_LIBRARY_STATUS_MISSING)
    CheckMediaLayout()
    mc.widgets.searchBox:Fire("OnTextChanged","__no_library_result_90231__")
    Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_RETAINED_UNAVAILABLE)
    assert(mc.widgets.selectionHelp.frame:IsShown())
    mc.widgets.applyButton:Fire("OnClick"); assert(not applied)
    mc.widgets.cancelButton:Fire("OnClick")

    for _,pair in ipairs({{"font","fp:font:standard"},{"statusbar","fp:statusbar:blizzard-default"},{"decoration","fp:decoration:shadow1"}}) do
        OpenMedia(pair[1],pair[2]); assert(mc.widgets.preview.item)
        Equal(mc.widgets.preview.item,mc.state.selectedItem); assert(mc.widgets.preview.asset)
        CheckMediaLayout()
        for _,item in ipairs(mc.state.items) do
            if item.selectable then mc.callbacks.onSelect(item); CheckMediaLayout() end
        end
        media.Close()
    end

    -- A missing registry is the real builder's empty-library path.
    local registry=ns.MediaRegistry; ns.MediaRegistry=nil
    OpenMedia(); Equal(#mc.state.items,0); assert(not mc.state.selectedItem)
    assert(mc.widgets.applyButton.disabled and not mc.widgets.preview.item)
    Equal(LabelText(mc.widgets.selectionHelp),ns.L.MEDIA_LIBRARY_SELECTION_PROMPT)
    CheckMediaLayout(); media.Close(); ns.MediaRegistry=registry

    print("PASS Media "..locale..": 603/603 budget, all three previews, retained/missing/empty selection and callbacks")
end

-- ToolWindowFamily has completed its release assertions for this Tag dialog.
-- Reopen through the real controller with a fresh view, never a released pool owner.
tc.window,tc.dialog,tc.widgets=nil,nil,nil
-- Complete both Media locales before testing the current independent Tag layout.
for _,locale in ipairs({"enUS","deDE"}) do
    GetLocale=function() return locale end
    f.Load("Locales/enUS.lua"); if locale=="deDE" then f.Load("Locales/deDE.lua") end
    local inserted,tagCancels=nil,0
    ns.UnitFrame.GetTagDatabase=getDatabase
    assert(tags.Open({onApply=function(token) inserted=token end,onCancel=function() tagCancels=tagCancels+1 end}))
    assert(#tc.state.items>0); CheckTagLayout()
    local longest=tc.state.items[1]
    for _,entry in ipairs(tc.state.items) do if #entry.description>#longest.description then longest=entry end end
    tc.callbacks.onSelect(longest); CheckTagLayout()
    print("PASS "..locale.." longest tag "..longest.token..", description bytes="..#longest.description..", detail height="..tc.widgets.details.frame:GetHeight())
    tc.widgets.searchBox:Fire("OnTextChanged","__no_tag_result_90231__")
    Equal(#tc.state.visibleEntries,0); assert(not tc.state.selectedEntry and tc.widgets.applyButton.disabled)
    CheckTagLayout(); tc.widgets.applyButton:Fire("OnClick"); assert(not inserted)
    tc.widgets.searchBox:Fire("OnTextChanged","name")
    assert(#tc.state.visibleEntries>0 and tc.state.selectedEntry)
    tc.widgets.searchBox:Fire("OnTextChanged","")
    assert(tc.state.selectedEntry and not tc.widgets.applyButton.disabled); CheckTagLayout()
    local token=tc.state.selectedEntry.token
    tc.widgets.applyButton:Fire("OnClick"); Equal(inserted,token)
    tags.Open({onCancel=function() tagCancels=tagCancels+1 end})
    tc.widgets.cancelButton:Fire("OnClick"); Equal(tagCancels,1)

    -- Additional long-example fixture, still using the real controller and layouts.
    ns.UnitFrame.GetTagDatabase=function() return {{token="[example]",category="Unit",description=longest.description,
        example=string.rep("[color:class][name][rc] ",10)}} end
    tags.Open(); CheckTagLayout(); tags.Close()
    ns.UnitFrame.GetTagDatabase=function() return {} end
    tags.Open(); assert(not tc.state.selectedEntry and tc.widgets.applyButton.disabled)
    CheckTagLayout(); tags.Close()
end
ns.UnitFrame.GetTagDatabase=getDatabase
NoErrors()
print("PASS: Media retained/current/results semantics, unavailable/empty states, 603/603 height budget, all previews; Tag visible selection, vertical compact geometry and scrollable EN/DE details")
