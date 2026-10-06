# GUI Architecture

STATUS: CURRENT - canonical GUI and editor architecture for Focal Point 2.2.x.

## Ownership model

- `*Controller.lua` owns feature orchestration and lifecycle.
- `*Binding.lua` owns callback wiring, widget state, and refresh coordination.
- `*Definition.lua` describes declarative structure and options.
- `*State.lua` owns explicit state APIs.
- `*Widget.lua` owns reusable widget behavior.

These roles are conventions for new work. Existing local exceptions remain
valid when changing them would be a refactor without product value.

## GUI host and editor

- `GUI/GUIMainController.lua` opens the main host.
- `GUI/GUIController.lua` routes the editor and tools.
- `GUI/AppShell.lua` owns shell chrome and host geometry.
- `GUI/Editor/EditorController.lua` owns the editor surface and Inspector host.
- `GUI/Editor/EditorState.lua` owns current unit and object selection.
- `GUI/Editor/Composition/*` owns tree ownership, presence, and selection rows.
- `GUI/Editor/CanvasToolbar.lua` routes layout, unit, demo, and editor actions.

Canvas selection is the primary editing context. The Composition Tree provides
the structured alternative. The Inspector is a precision surface, not a second
data source.

## Layout Manager and assignments

`GUI/Editor/LayoutManager/LayoutManagerView.lua` reuses the existing manager
window and list patterns for layout summaries, selection, rename/copy/delete,
import/export, and Account Default actions.

`GUI/Editor/LayoutAssignments/LayoutAssignmentView.lua` presents
specialization-to-layout rules. Both surfaces call `LayoutMutations` or
`LayoutAssignmentService`; they do not directly alter runtime frames.

The manager displays resolved layout names from summaries and handles stale
references defensively. Account Default can be set or cleared without changing
the current character layout. “Use” actions delegate to the existing
activation/assignment path and preserve combat, dirty-draft, and stale guards.

## Inspector

- `InspectorController.lua` builds current sections, rows, and controls.
- `InspectorContext.lua` captures the selected layout/unit/object context.
- `InspectorMutations.lua` writes component and text changes.
- `InspectorRefreshPolicy.lua` chooses the smallest valid refresh scope.
- selection helpers preserve text, indicator, and aura selection across rebuilds.

New Inspector properties belong in the existing section/control patterns and
must go through the mutation layer. Small properties do not justify a new
window, renderer, or layout system.

## Text tools

- `TextTemplateLibraryWindow.lua` is the Texts Manager and template picker.
- `GUI/Pages/TextBuilder/*` owns draft creation/editing and entity-builder
  return contexts.
- `GUI/Pages/TagLibrary/*` owns tag discovery and insertion.
- `GUI/Editor/MediaLibrary/*` is the reusable contextual picker pattern for
  media selection.

Text drafts preserve baseline/context and reject stale returns. Manager and
Builder operations call `TextTemplateMutations` and refresh through the
existing GUI path.

## Stable UI patterns

- context -> mutation/service -> existing refresh path;
- summaries for list display, payloads only at an explicit edit boundary;
- selection rows with deterministic release/reacquire behavior;
- Media Library patterns for contextual pickers;
- no timer/retry workaround for lifecycle or layout problems;
- no second source of truth in a window or widget.

## Visual/runtime integration

When adding a visual component, preserve the component configuration schema,
Inspector binding, preview/demo policy, runtime factory, layout/anchor path,
refresh/visibility path, combat behavior, text/LiveValues dependencies, and
clear/release lifecycle. The complete checklist is in
`docs/Architecture/UnitFrame-Runtime-Lifecycle.md`.
