# GUI Architecture

STATUS: CURRENT - current GUI/editor architecture for Focal Point 1.2.x.

## Purpose

This document describes the implemented GUI structure. It is not a proposal for a new UI framework and does not invent abstractions that are not present in the code.

## Role model

- `*Controller.lua`: window/feature orchestration, lifecycle, routing.
- `*Binding.lua`: callback wiring, widget-state sync, refresh coordination.
- `*Definition.lua`: declarative structure and layout description.
- `*State.lua`: explicit state API.
- `*Widget.lua`: reusable widget components.

This role model is used most clearly in Toolbar, Pages, and parts of the Inspector. Some historical helper files remain as intentional exceptions.

## Main modules

### GUI Host

- `GUI/GUIMainController.lua`: main entry for the addon GUI.
- `GUI/GUIController.lua`: opens tool pages such as Text Builder and Tag Database.
- `GUI/AppShell.lua`: editor/tool shell, chrome, docking, and host geometry.

### Editor

- `GUI/Editor/EditorController.lua`: editor surface and inspector host.
- `GUI/Editor/EditorState.lua`: canonical selection for unit, multi-selection, text element, indicator, aura, and preset. Preset selection is also held here; the current field name `selectedThemeId` is legacy naming and does not mean that Theme is still the visible product model. The current product model is Profile/Preset.
- `GUI/Editor/EditorInteractionMode.lua`: frame/text mode.
- `GUI/Editor/FrameContextMenu.lua`: context menu for visible frames and text.
- `GUI/Editor/TextEditorOverlay.lua`: object-centered text editing on visible frames.

### Toolbar

- `ToolbarController.lua`: window/lifecycle.
- `ToolbarDefinition.lua`: declarative sidebar/tool structure.
- `ToolbarBinding.lua`: widget state, presets, unit selection, demo/unlock, and global options.

### Inspector

- `InspectorController.lua`: builds sections for unit, bars, absorbs, text, indicators, decorations, and auras.
- `InspectorContext.lua`: creates the current editing context from EditorState and profile data.
- `InspectorMutations.lua`: writes configuration changes through a central mutation layer.
- `InspectorRefreshPolicy.lua`: chooses between `live`, `section`, `sidebar`, `unitEnabled`, and `none`.
- Selection helpers (`InspectorTextSelection`, `InspectorIndicatorSelection`, `InspectorAuraSelection`) keep element selection stable.

The Inspector is a precision tool. Direct editing exists for frames and text; other components are currently edited mainly through the Inspector.

### Media Library

- `MediaLibraryController.lua`: opens a contextual picker with `mediaType`, current value, default/fallback, and `onApply`.
- `MediaLibraryItems.lua`: builds available items from MediaRegistry and providers.
- `MediaLibraryView.lua` and preview modules: list, preview, metadata, Apply/Cancel.

This is a strong pattern: the picker knows the caller context and writes the selected value back directly, without internal copy/paste.

### Tool Pages

- `ProfilesController.lua`: profiles, import/export, Save as Preset, automation.
- `LayoutsPresetsController.lua`: preset list, preview, apply, create profile, rename/delete for user presets.
- `TextBuilderController.lua`: template draft, dirty state, save, apply, usage assignments.
- `TagDatabaseController.lua`: tag reference and copy dialog. CURRENT, but currently more isolated as a workflow than the Media Library.

## Data and control flow

1. EditorState determines current unit/selection.
2. InspectorContext reads profile and unit context.
3. Controllers build widgets from definitions and helpers.
4. User action calls a mutation or service.
5. RefreshPolicy or a page controller updates runtime/UI.
6. UnitFrame/runtime applies the changed configuration.

## Stable patterns

- Context -> Mutation -> RefreshPolicy instead of direct UI writes.
- Media Library as a contextual picker.
- TextEditorOverlay for visible text objects.
- EditorState as central selection truth.
- PresetUI + services for profile/preset workflows.

## Known transition points

- `FormWidgets.lua`, `FormRenderer.lua`, and SidebarShared are established helpers, but not a complete new GUI architecture.
- Tag Database is currently more of a standalone tool than a contextual insert picker.
- Some 1.x layouts are intentionally pragmatic and not automatically a 2.0 norm.

