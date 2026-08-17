# Text Architecture

STATUS: CURRENT - current text architecture for Focal Point 1.2.x.

## Purpose

This document describes the current text flow. Old migration notes live in `Historical/0.x-Architecture/TEXT_ARCHITECTURE.md` and are not normative.

## Core terms

### Text Element

An entry in `unitConfig.Texts`. It owns presentation and placement: `enabled`, `templateName` or `tag`, `anchorTo`, `point`, `relativePoint`, offsets, font, font size, style, color, shadow, and overflow.

### Template

A content string from `db.profile.TextTemplates`. Templates may contain tags such as `[hp:cur]`, `[absorb:cur]`, or inline colors. Template content is content, not layout.

### Direct Template / tag

The `tag` field still exists as a fallback, expert, or migration path. The preferred product path is `templateName`.

### State Templates

`stateTemplates` provide alternate templates for states such as dead/ghost. They are part of the current text model and are managed by the template resolver and inspector mutations.

## Main modules

- `Engine/TextElements.lua`: integrates the text system into UnitFrame runtime.
- `Engine/Text/Runtime/TextElementApply.lua`: applies TextElement configuration to FontStrings.
- `Engine/Text/Runtime/TextElementUpdate.lua`: updates visible text content.
- `Engine/Text/Shared/TextElementTemplates.lua`: normalization, template helpers, and preview.
- `Engine/Text/Shared/TextElementRoles.lua`: role and placement metadata for text elements.
- `Engine/Text/Shared/TextTemplateResolver.lua`: canonical template resolution for profile templates, direct content, and state templates.
- `Engine/Text/Shared/TextTemplateValidation.lua`: template validation and safety checks.
- `Engine/Text/Shared/TextElementBasicTags.lua`: basic tags.
- `Engine/Text/Shared/TextElementColors.lua`: inline color tags.
- `Engine/Text/Shared/TextElementStatus.lua`: status and template-state logic.
- `Engine/Text/Shared/TextTemplateMutations.lua`: create/update/rename/delete/assign/usage mutations.
- `Engine/Text/Shared/TextTemplateLibrary.lua`: template entries from profiles, defaults, and presets.
- `Engine/Text/Shared/TextTemplateUsage.lua`: usage and assignment scanning.
- `GUI/Pages/TextBuilder/*`: template draft, save, apply, usage.
- `GUI/Pages/TagDatabase/*`: tag reference.
- `GUI/Editor/TextEditorOverlay.lua`: visible text objects can be selected, moved, resized/reset.

## Render path

1. UnitFrame build creates text objects.
2. ApplyConfig applies presentation and placement.
3. Health/Power/Cast/Aura runtime writes prepared values to `frame.LiveValues`.
4. TextTemplateResolver chooses a template, state template, or direct string.
5. Tag resolvers read prepared display values.
6. TextElementUpdate writes rendered text into the FontString.

## Canonical sources

- Text configuration: `db.profile.Units[unit].Texts`.
- Template content: `db.profile.TextTemplates`.
- Runtime values: `frame.LiveValues`.
- Font media: `MediaRegistry`.

## Tag rules

Tags are display resolvers. They should consume prepared values and should not reconstruct runtime truth. Details live in `Rules/Tag-System-Rules.md`.

## Text Builder

The Text Builder owns a draft state, dirty detection, save flow, and apply flow. Unsaved Apply is guarded by a confirmation dialog. Apply can assign or remove templates for units through `TextTemplateMutations.ApplyTemplateToUnits`.

## Tag Database

The Tag Database is currently a standalone tool with a copy dialog. This is CURRENT, but as a workflow it is less integrated than the Media Library. Improvements belong in future/2.0 documents, not in this current architecture document.

## Legacy / hybrid paths

- `tag` remains as a direct content path.
- Old custom/migration names may still occur in defaults or profiles and are handled by runtime/mutations for compatibility.
- These legacy paths are not the preferred product language for new workflows.

