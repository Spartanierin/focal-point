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
    local width=math.max(1,self:GetWidth())
    return 14*math.max(1,math.ceil((utf8.len(text) or #text)*6/width))
end
local function Contains(text,part) assert(text:find(part,1,true),text.." missing "..part) end
local function LabelText(widget) return widget.label:GetText() end
local function CheckMediaLayout()
    local w=mc.widgets
    w.root:DoLayout(); w.metadata:DoLayout()
    Equal({mc.window.frame:GetWidth(),mc.window.frame:GetHeight()},{720,660})
    Equal(w.itemScroll.frame:GetHeight(),270); Equal(w.preview.frame:GetHeight(),112)
    local total=0
    for _,child in ipairs(w.root.children) do total=total+child.frame:GetHeight()+3 end
    assert(total<=mc.window.content:GetHeight(),"Media root budget "..total)
    local metadata=0
    for _,child in ipairs(w.metadata.children) do metadata=metadata+child.frame:GetHeight() end
    assert(metadata<=w.metadata.frame:GetHeight(),"Media metadata budget "..metadata)
    Equal(#w.metadata.children,6)
    assert(not w.previewStatusLabel and not w.fallbackUsedLabel)
    local color=ns.GUI.Helpers.TextStyles.Get("help")
    Equal(w.title.label.lastSetTextColor,{color.r,color.g,color.b,1})
    Equal(w.title.label.font[2],11)
    assert(mc.window.frame._fpToolChromeActive)
    NoErrors()
end
local function CheckTagLayout()
    local w=tc.widgets
    w.root:DoLayout(); w.details:DoLayout()
    Equal({tc.window.frame:GetWidth(),tc.window.frame:GetHeight()},{760,560})
    Equal({w.listScroll.frame:GetWidth(),w.listScroll.frame:GetHeight()},{304,322})
    local fields=w.details.children[3]
    Equal(fields.frame:GetWidth(),352)
    assert(not w.details.noAutoHeight)
    if tc.state.selectedEntry then
        Equal(#fields.children,4)
        local expected={tc.state.selectedEntry.token,tc.state.selectedEntry.category,tc.state.selectedEntry.description,tc.state.selectedEntry.example}
        local needed=0
        for i,field in ipairs(fields.children) do
            local label,value=field.children[1],field.children[2]
            Equal(LabelText(value),expected[i]~="" and expected[i] or "-")
            assert(value.frame:GetWidth()>=352,"detail value width regressed")
            assert(field.frame:GetHeight()>=label.frame:GetHeight()+value.frame:GetHeight(),"field clips wrapped text")
            needed=needed+field.frame:GetHeight()+(i>1 and 8 or 0)
        end
        assert(fields.frame:GetHeight()>=needed,"fields overlap")
        assert(w.details.frame:GetHeight()>=fields.frame:GetHeight(),"detail surface clips")
    else
        Equal(#fields.children,1); Equal(LabelText(fields.children[1]),ns.L.INFO_TAG_LIBRARY_NO_SELECTION)
    end
    local total=0
    for _,child in ipairs(w.root.children) do total=total+child.frame:GetHeight()+3 end
    assert(total<=tc.window.content:GetHeight(),"Tag root budget "..total)
    local color=ns.GUI.Helpers.TextStyles.Get("help")
    Equal(w.subtitle.label.lastSetTextColor,{color.r,color.g,color.b,1}); Equal(w.subtitle.label.font[2],11)
    assert(tc.window.frame._fpToolChromeActive)
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
print("PASS: Media retained/current/results semantics, unavailable/empty states, 600/603 height budget, all previews; Tag visible selection and content-sized EN/DE details; U2 bounds/chrome unchanged")
