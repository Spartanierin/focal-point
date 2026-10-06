# Text Architecture

STATUS: CURRENT - canonical text, template, and tag architecture for Focal Point 2.2.x.

## Layers

- A text element owns presentation and placement: enabled state, anchor,
  offsets, font, size, color, style, shadow, and overflow.
- A template entity owns content: a name and expression containing tags or
  inline colors.
- `templateId` and state-template IDs provide stable entity identity.
- `tag` remains a valid object-local direct-content path when no main template
  ID exists.

Built-in template entities are read-only. User entities are independently
identified and managed by the Texts Manager. Equal names or equal content do
not imply identity.

## Modules

- `Engine/TextElements.lua`: integrates text runtime with UnitFrame.
- `Engine/Text/Runtime/TextElementFactory.lua`: creates visible text objects.
- `Engine/Text/Runtime/TextElementApply.lua`: applies presentation and layout.
- `Engine/Text/Runtime/TextElementUpdate.lua`: writes rendered text.
- `Engine/Text/Runtime/TextElementLiveValues.lua`: prepares runtime display
  values.
- `Engine/Text/Shared/TextElementRoles.lua`: role and placement metadata.
- `Engine/Text/Shared/TextTemplateResolver.lua`: canonical content resolution.
- `Engine/Text/Shared/TextTemplateLibrary.lua`: built-in/user entity catalog and
  ID lookup.
- `Engine/Text/Shared/TextTemplateMutations.lua`: entity and binding mutations.
- `Engine/Text/Shared/TextTemplateUsage.lua`: usage scanning.
- `Engine/Text/Shared/TextTemplateValidation.lua`: graph and input validation.
- `GUI/Editor/TextTemplateLibraryWindow.lua`: Texts Manager and picker.
- `GUI/Pages/TextBuilder/*`: draft and entity-builder consumer.
- `GUI/Pages/TagLibrary/*`: tag reference and insertion.

## Runtime flow

1. UnitFrame build creates the text object.
2. Apply paths set presentation and placement from the active layout.
3. Health, Power, Cast, Aura, and other runtime modules prepare `LiveValues`.
4. `TextTemplateResolver` resolves the entity, state template, or object-local
   direct content.
5. Token resolvers consume prepared display values.
6. `TextElementUpdate` writes the final string to the FontString.

Text rendering does not reconstruct canonical values from the visual bars, and
text updates do not require a layout rebuild.

## Draft and context safety

The Text Builder captures a layout/object/entity context and a baseline. Save,
apply, close, and return callbacks validate that context before mutation. A
stale picker or builder cannot redirect a mutation to a newly active layout.
Dirty drafts, combat deferral, and failed mutation results retain the existing
guard behavior.

The Texts Manager administers global template entities without changing object
bindings when it lists, selects, copies, renames, or deletes. Delete validates
current usage before removing a user entity.

## Tags and values

Tags are display resolvers, not a general calculation layer. They should read
prepared display fields such as `healthCurrentText`, `powerPercentText`, or
`castTimeText`. Arithmetic, parsing, table-key use, and string reconstruction of
secret or rendered values do not belong in token resolution.

Inline color tags affect only segments in the content string. The text
element's base color remains presentation state; `[rc]` returns inline color to
that base color.

Test/demo paths use explicit preview values and do not depend on live unit APIs.

## Compatibility boundary

Legacy direct tags, old names, and migration records remain supported where
the current resolver or migration contract requires them. They are not the
preferred product language for new workflows, and no current documentation
should present the old slot-based model as the canonical architecture.
