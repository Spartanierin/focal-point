# GUI Architecture

## Purpose

This document describes the current GUI code structure in the workspace.
It is a runtime/reference document for naming, ownership, and file boundaries.

## Current Naming Baseline

Primary file roles:

- `*Controller.lua`: feature orchestration, entry, lifecycle, routing, host coordination.
- `*Binding.lua`: runtime wiring, callbacks, widget-state sync, refresh coordination.
- `*Definition.lua`: declarative WHAT (`structure`, `lists`, `properties`, `options`).
- `*Widget.lua`: reusable UI widget/component.
- `*State.lua`: explicit state ownership and state API.

Optional roles (only when dominant):

- `*Style.lua`
- `*Renderer.lua`

Legacy/transitional names are not baseline naming and must not be used as default patterns.

## Folder Ownership Model

- `GUI/Editor/<Feature>/...`: editor-specific runtime and feature controllers.
- `GUI/Pages/<Feature>/...`: non-editor feature pages/tools.
- `GUI/Helpers/...`: narrow technical helpers only; no hidden domain orchestration.
- `GUI/Widgets/...`: reusable UI widget components.
- `GUI/Layouts/...`: declarative shared definitions/lists.

Important boundary:

- The editor is intentionally under `GUI/Editor/*`, not under `GUI/Pages/Editor`.

## Current Runtime Entry Points

- Main GUI host orchestration: [GUIMainController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUIMainController.lua)
- Feature/page orchestration helpers: [GUIController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUIController.lua)
- Shell host/runtime: [AppShell.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/AppShell.lua)

Current canonical naming replacements already applied:

- `GUI/GUI.lua` -> `GUI/GUIMainController.lua`
- `GUI/GUIBuilders.lua` -> `GUI/GUIController.lua`

## Active Feature Structure

### Editor

- [EditorController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/EditorController.lua)
- [EditorState.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/EditorState.lua)
- Toolbar:
  - [ToolbarController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/Toolbar/ToolbarController.lua)
  - [ToolbarBinding.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/Toolbar/ToolbarBinding.lua)
  - [ToolbarDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/Toolbar/ToolbarDefinition.lua)
- Inspector:
  - [InspectorController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/Inspector/InspectorController.lua)

### Pages (non-editor)

- Profiles:
  - [ProfilesController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/Profiles/ProfilesController.lua)
  - [ProfilesDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/Profiles/ProfilesDefinition.lua)
- Text Builder:
  - [TextBuilderController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TextBuilder/TextBuilderController.lua)
  - [TextBuilderDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TextBuilder/TextBuilderDefinition.lua)
- Tag Database:
  - [TagDatabaseController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TagDatabase/TagDatabaseController.lua)
  - [TagDatabaseDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TagDatabase/TagDatabaseDefinition.lua)

## Shared Runtime Building Blocks

### Helpers

- [GUIRuntimeHelpers.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/GUIRuntimeHelpers.lua)
- [PageDependencyFactory.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/PageDependencyFactory.lua)
- [GUIState.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/GUIState.lua)
- [OptionPaths.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/OptionPaths.lua)
- [OptionValues.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/OptionValues.lua)
- [OptionRefresh.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/OptionRefresh.lua)
- [LayoutHelpers.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/LayoutHelpers.lua)
- [TextStyles.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/TextStyles.lua)

### Widgets

- [CheckboxWidget.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Widgets/CheckboxWidget.lua)
- [DropdownWidget.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Widgets/DropdownWidget.lua)
- [SliderWidget.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Widgets/SliderWidget.lua)
- [ColorPickerWidget.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Widgets/ColorPickerWidget.lua)

### Layout Definitions

- [FormElementDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/FormElementDefinition.lua)
- [UnitAuraDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitAuraDefinition.lua)
- [UnitBarDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitBarDefinition.lua)
- [UnitFrameDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitFrameDefinition.lua)
- [UnitPortraitDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitPortraitDefinition.lua)
- [UnitTextDefinition.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitTextDefinition.lua)

## Explicit Boundary Cases (Known Exceptions)

These files are intentionally documented as exceptions, not baseline naming examples:

- [SidebarShared.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/SidebarShared.lua): shared editor helper surface for Inspector and Toolbar; `Shared` naming is an exception.
- [FormWidgets.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/FormWidgets.lua): mixed widget/chrome helper responsibilities; not a baseline role suffix.
- [FormRenderer.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Helpers/FormRenderer.lua): runtime layout engine naming outside the core suffix baseline.
- [UnitClassificationIndicatorLayouts.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Layouts/UnitClassificationIndicatorLayouts.lua): legacy/transitional `Layouts` suffix and mixed indicator definition scope.
- [AppShell.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/AppShell.lua): established shell-runtime name outside strict suffix pattern.

## Operational Rules For Future Cleanup

- Do not treat `*Page.lua`, `*Layouts.lua`, or `*Builders.lua` as baseline naming patterns.
- If such names appear, classify them as legacy/transitional until replaced.
- Keep editor runtime ownership in `GUI/Editor/*`.
- Keep non-editor features in `GUI/Pages/*`.
- Treat `Shared` names as exception-only and document their consumer boundary.
