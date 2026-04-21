# Text Architecture

## Purpose

This document describes:

- the current text architecture in Focal Point
- why the current model conflicts with the intended product concept
- the target model for free text elements
- the migration path from legacy text slots to template-driven text elements

The Text Builder is a core product feature.
Its runtime and editor model must therefore match the visible product concept:

- users create templates
- templates are assigned to units
- units own free text elements
- the user never works with hardcoded text slots

## Product Model

The intended product model is:

- a unit owns text elements
- each text element has a technical id
- each text element links to a template or direct tag content
- the visible UI shows the template name or a user-facing label
- technical ids are implementation detail only

Example:

```lua
Texts = {
    ["1"] = {
        templateName = "Unit Player Name",
        enabled = true,
        point = "TOPLEFT",
        relativeTo = "HealthBar",
        relativePoint = "TOPLEFT",
        x = 10,
        y = -6,
    },
    ["2"] = {
        templateName = "Player Level and Class",
        enabled = true,
        point = "BOTTOMLEFT",
        relativeTo = "PowerBar",
        relativePoint = "BOTTOMLEFT",
        x = 8,
        y = 2,
    },
}
```

This is the intended model.

It is not the same as the legacy slot model:

```lua
Texts = {
    Name = { templateName = "Unit Player Name" },
    Race = { templateName = "Player Level and Class" },
    Custom1 = { ... },
}
```

## Current Legacy State

The codebase still contains a real slot-based text model.

### Legacy Indicators In Code

- [Defaults.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Data/Defaults.lua)
  - units still define `Texts.Name`, `Texts.Health`, `Texts.Race`, `Texts.Custom1`, `Texts.Custom2`, `Texts.Custom3`
- [Themes.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Data/Themes.lua)
  - theme text blocks still refer to `Custom1..3`
- [ThemeService.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Services/ThemeService.lua)
  - theme merge still applies text configs by key into `unitConfig.Texts[key]`
- [SidebarShared.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/SidebarShared.lua)
  - still contains `TEXT_ORDER`
- [EditorState.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/EditorState.lua)
  - still tracks `selectedTextKey`
- [TextBuilderPage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TextBuilderPage.lua)
  - previously chose `Custom1`, `Custom2`, `Custom3` when applying a template to a unit
  - is now being moved toward free text-element ids such as `text_1`
- [GUI.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUIMainController.lua)
  - still resolves text configs through `GetTextConfig(unit, textKey)`
- [TextElementUpdate.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Text/Runtime/TextElementUpdate.lua)
  - still contains semantic runtime branching by key such as `Name` and `AltPower`

### Important Conclusion

The previous template work modernized template resolution, but did not fully migrate:

- storage
- editor selection
- builder assignment
- runtime semantic text roles

This means the current system is hybrid:

- template-driven at the content level
- slot-driven at the storage and runtime role level

## Why This Conflicts With The Product

The current hybrid model causes product confusion:

1. The user creates templates, but the editor still thinks in keys like `Name` and `Custom1`.
2. The Text Builder presents unit-template assignment as a template workflow, but internally still lands on hardcoded fallback slots.
3. The Inspector can easily leak technical slot concepts even though the product concept has no such concept.
4. Runtime semantics are attached to storage keys instead of to explicit text-element roles.

This is not only a UI naming issue.
It is a model mismatch.

## Target Model

## 1. Free Text Elements

Each unit owns a collection of free text elements.

Each element has:

- `id`
- `enabled`
- `templateName`
- optional `tag`
- optional `stateTemplates`
- layout data
- style data
- optional semantic `role`

Suggested shape:

```lua
Texts = {
    ["text_1"] = {
        id = "text_1",
        enabled = true,
        templateName = "Unit Target Name",
        role = "name",
        point = "TOPLEFT",
        relativeTo = "HealthBar",
        relativePoint = "TOPLEFT",
        x = 8,
        y = -6,
        font = "Friz Quadrata TT",
        size = 16,
        justifyH = "LEFT",
        overflowMode = "NONE",
    },
}
```

## 2. Separate Identity And Role

The technical id and the semantic role must not be the same thing.

- `id` answers: which element is this?
- `role` answers: does this element have special runtime meaning?

This is critical because current runtime behavior still treats some texts specially.

Examples of semantic roles:

- `name`
- `altpower`
- `cast_name`
- `cast_time`
- `status`

Not every text element needs a role.
Most elements should remain generic.

## 3. Templates Stay The User-Facing Truth

In the visible product:

- dropdowns
- summaries
- inspector labels
- tool pages

must speak in:

- template names
- element labels
- workflow language

and never in:

- `Name`
- `Race`
- `Custom1`
- `Custom2`

unless a technical migration/debug mode explicitly exists.

## 4. Role-Based Runtime Instead Of Key-Based Runtime

The runtime must stop assuming that storage keys define meaning.

Today this still happens in places like:

- [TextElementUpdate.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Text/Runtime/TextElementUpdate.lua)

Target direction:

- generic text rendering uses template/tag resolution
- special runtime behavior is triggered by explicit metadata such as `role`
- not by hardcoded storage keys

## Migration Strategy

The migration should be done in controlled phases.

## T1. Freeze The Product Contract

Before code migration, the contract is:

- users assign templates to units
- inspector should show template-facing terminology
- text element ids are internal only
- hard text slots are legacy only

This phase is documentation and language alignment.

## T2. Introduce Text Element Ids

Add a new id-based shape for text collections.

Requirements:

- each text element gets a stable id
- ids may be strings
- ids do not encode semantic meaning
- old slot entries can be migrated into ids

Example migration map:

- `Name` -> `text_name_legacy`
- `Custom1` -> `text_custom_1_legacy`

This is transitional only.

## T3. Add Explicit Text Roles

Where the runtime still needs semantic meaning, add `role`.

Examples:

- legacy `Name` becomes `role = "name"`
- legacy `AltPower` becomes `role = "altpower"`

This is the key step that lets us remove runtime dependence on storage keys.

## T4. Move Inspector State To Element Ids

Replace:

- `selectedTextKey`

with:

- `selectedTextId`

Inspector list generation must iterate text elements and build user-facing labels from:

1. template name
2. explicit element label
3. generic fallback such as `Unlinked Template`

not from storage keys.

Status:

- started
- the editor layer should now move toward `selectedTextId` terminology even before the underlying storage migration is complete

## T5. Move Text Builder Off Custom Slots

Replace `GetNextTextElementSlot()` and all `Custom1..3` assumptions.

Applying a template to a unit should:

- create a new text element id when needed
- or update an existing linked element when explicitly chosen
- never require a fixed custom slot budget

This is a major product fix because the Text Builder should not artificially stop at three custom text slots.

Status:

- started
- builder assignment should now create free text-element ids instead of writing into `Custom1..3`

## T6. Make Theme Application Id-Based

Theme application currently merges text config by key.

Theme support must be updated so that:

- themes can either define text element presets declaratively
- or text theme fragments can be applied by role / label / template criteria

This will need a compatibility layer because theme data is currently slot-shaped.

## T7. Runtime Switch From Key To Role

In text update/runtime code:

- stop branching on `key == "Name"` etc.
- branch on explicit role where needed
- otherwise treat text elements as generic template renderers

This is the main runtime simplification.

Status:

- started
- runtime special cases for `name`, `cast_name`, `cast_time`, `altpower`, `class`, and `level` should now prefer `textConfig.role` with legacy key fallback

## T8. Data Migration And Backward Compatibility

On load:

- detect old slot-based `Texts`
- convert them into id-based elements
- preserve visual placement and behavior
- preserve template links
- preserve any special semantic role

Backward compatibility should be one-way:

- old saved data is upgraded
- new runtime should no longer depend on slot naming

## Suggested File Impact

The following files are central to this migration:

### Data / Migration

- [Defaults.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Data/Defaults.lua)
- [Themes.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Data/Themes.lua)
- a future migration helper file is recommended

### GUI / Inspector / Builder

- [EditorState.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/EditorState.lua)
- [SidebarShared.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/SidebarShared.lua)
- [InspectorSidebar.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/InspectorSidebar.lua)
- [TextBuilderPage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TextBuilderPage.lua)
- [GUI.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUIMainController.lua)

### Runtime

- [TextElementTemplates.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Text/Shared/TextElementTemplates.lua)
- [TextElementUpdate.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Text/Runtime/TextElementUpdate.lua)
- any text creation/orchestration files that build `frame.Texts`

### Theme And Services

- [ThemeService.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Services/ThemeService.lua)

## Migration Risks

The highest risks are:

1. Runtime semantics for `Name` and `AltPower`
2. SavedVariables migration
3. Theme compatibility
4. Inspector selection state
5. Builder assignment and unlinking rules

The lowest-risk parts are:

1. UI language cleanup
2. Inspector label cleanup
3. replacing hardcoded list labels
4. introducing ids alongside old keys in a compatibility phase

## Practical Recommendation

Do not try to remove all slot assumptions in one step.

Recommended order:

1. document the target model
2. introduce ids and roles
3. migrate inspector state
4. migrate builder assignment
5. migrate runtime semantics
6. migrate themes
7. remove legacy slot assumptions

## Decision

Focal Point should treat hard text slots as a legacy implementation detail.

The intended architecture is:

- free text elements
- template-driven unit assignment
- optional explicit semantic roles
- no user-facing slot vocabulary

This is especially important because the Text Builder is a primary product feature and must not be constrained by early-version slot assumptions.
