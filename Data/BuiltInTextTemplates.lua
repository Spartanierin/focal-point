local _, FocalPoint = ...

-- Stable, published E2 IDs. Display names never serve as references.
local entries = {
    {templateId = "tpl:b:default-001", record = {name = "Alt Power", content = "[altpower:cur] / [altpower:max]"}},
    {templateId = "tpl:b:default-002", record = {name = "Class Power", content = "[classpower:cur] / [classpower:max]"}},
    {templateId = "tpl:b:default-003", record = {name = "Unit Name Focus", content = "[name] [status] [status:timer]"}},
    {templateId = "tpl:b:default-004", record = {name = "Unit Name Target", content = "[name] [status] [status:timer]"}},
    {templateId = "tpl:b:default-005", record = {name = "Dead/Ghost Timer", content = "[dead] [dead:timer]"}},
    {templateId = "tpl:b:default-006", record = {name = "Cast Name", content = "[cast:name]"}},
    {templateId = "tpl:b:default-007", record = {name = "Power", content = "[power:cur:abbr]/[power:max:abbr]"}},
    {templateId = "tpl:b:default-008", record = {name = "Absorb Value", content = "[absorb:cur:abbr]"}},
    {templateId = "tpl:b:default-009", record = {name = "Healing Absorb Value", content = "[healabsorb:cur:abbr]"}},
    {templateId = "tpl:b:default-010", record = {name = "Unit Name Player", content = "[status] [status:timer] [name]"}},
    {templateId = "tpl:b:default-011", record = {name = "Health", content = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%"}},
    {templateId = "tpl:b:default-012", record = {name = "Player Level and Class", content = "[color:blizz_yellow][level][rc] [color:class][class][rc] [race]"}},
    {templateId = "tpl:b:default-013", record = {name = "Cast Time", content = "[cast:time]"}},
    {templateId = "tpl:b:default-014", record = {name = "Status", content = "[status] [status:timer]"}},
    {templateId = "tpl:b:default-015", record = {name = "Dead Target", content = "[dead]"}},
    {templateId = "tpl:b:default-016", record = {name = "Focus Level and Class", content = "[color:blizz_yellow][level][rc] [color:class][class][rc] [creature]"}},
    {templateId = "tpl:b:default-017", record = {name = "Target Level and Class", content = "[color:blizz_yellow][level][rc] [color:class][class][rc] [creature]"}},
    {templateId = "tpl:b:default-018", record = {name = "Creature", content = "[creature]"}},
    {templateId = "tpl:b:classic-001", record = {name = "Health current", content = "[hp:cur:abbr]"}},
    {templateId = "tpl:b:classic-002", record = {name = "Health w/o perc", content = "[hp:cur:abbr]/[hp:max:abbr]"}},
    {templateId = "tpl:b:classic-003", record = {name = "Power perc", content = "[power:perc]%"}},
    {templateId = "tpl:b:classic-004", record = {name = "Unit Name w/o status", content = "[name]"}},
}
local catalog, reason = FocalPoint.TextTemplateLibrary.CreateBuiltInTemplateCatalog(entries)
assert(catalog, reason and reason.errorCode)
FocalPoint.BuiltInTextTemplates = catalog
