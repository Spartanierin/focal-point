-- Re-express only bindings in the frozen pre-E6 vocabulary so the original
-- presentation fingerprints keep protecting every non-binding field.
local bindings = dofile("Tests/Fixtures/LegacyTextBindings.lua")
return function(ns, layout, preset)
    local copy = ns.LayoutService.Clone(layout)
    local function merge(a,b)
        for k,v in pairs(b or {}) do
            if type(v)=="table" then a[k]=a[k] or {};merge(a[k],v) else a[k]=v end
        end
    end
    copy.TextTemplates=ns.LayoutService.Clone(bindings.defaultTemplates)
    if preset=="classic" then merge(copy.TextTemplates,bindings.classicTemplates) end
    for unit,config in pairs(copy.Units) do
        for key,text in pairs(config.Texts) do
            local old=ns.LayoutService.Clone((bindings.defaults[unit] or {})[key] or {})
            if preset=="classic" then merge(old,(bindings.classic[unit] or {})[key]) end
            local function check(id,name)
                if type(name)=="string" and name~="" then
                    local entity=assert(ns.TextTemplateLibrary.ResolveTemplateEntity(id,{}),key)
                    assert(entity.name==name,key.." binding changed")
                else assert(id==nil,key.." invented binding") end
            end
            check(text.templateId,old.templateName)
            for state,id in pairs(text.stateTemplateIds or {}) do check(id,type(old.stateTemplates)=="table" and old.stateTemplates[state]) end
            for state,name in pairs(type(old.stateTemplates)=="table" and old.stateTemplates or {}) do
                check(text.stateTemplateIds and text.stateTemplateIds[state],name)
            end
            text.templateId=nil;text.stateTemplateIds=nil
            text.templateName=old.templateName;text.stateTemplates=old.stateTemplates
        end
    end
    return copy
end
