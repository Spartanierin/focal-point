# GUI Layout Rules

STATUS: DESIGN REFERENCE / PARTIAL - local layout guidance; the canonical
runtime and ownership contracts are in the architecture documents.

## Scope

These rules apply to existing GUI surfaces and small, local changes. They do
not authorize a new window, renderer, layout engine, or generic framework.

## Rules

- Reuse the existing shell, window chrome, section surfaces, list rows, preview
  panels, and footer patterns.
- Keep the Canvas as the primary editing surface and keep Inspector/tool windows
  contextual.
- Use stable local size parameters and explicit anchors. Do not hide lifecycle
  problems behind auto-size, timers, retries, or duplicate refreshes.
- Preserve minimum content bounds, readable labels, selection state, disabled
  state, and footer actions at the supported UI sizes.
- Release pooled children before reacquiring them and make close/reopen behavior
  deterministic.
- Keep configuration, mutation, and runtime layout ownership separate.

## Current entry points

- Layout workflows: `GUI/Editor/LayoutManager/LayoutManagerView.lua` and
  `GUI/Editor/LayoutAssignments/LayoutAssignmentView.lua`.
- Text workflows: `GUI/Editor/TextTemplateLibraryWindow.lua` and
  `GUI/Pages/TextBuilder/*`.
- Contextual media selection: `GUI/Editor/MediaLibrary/*`.

For current GUI ownership and refresh contracts, use
`docs/Architecture/GUI-Architecture.md`.
