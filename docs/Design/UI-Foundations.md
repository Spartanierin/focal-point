# UI Foundations

STATUS: CURRENT/PARTIAL - technical inventory and requirements for later UI work.

This document is not a new GUI implementation architecture.

## Current technical state

Focal Point uses AceGUI windows and Focal-Point-specific helpers for chrome, buttons, sections, rows, and form rendering.

Relevant files:

- `GUI/AppShell.lua`
- `GUI/Helpers/FormRenderer.lua`
- `GUI/Helpers/FormWidgets.lua`
- `GUI/Helpers/TextStyles.lua`
- `GUI/Editor/SidebarShared.lua`
- `GUI/Editor/EditorSidebarThemeHelpers.lua`
- `GUI/Editor/Inspector/*`
- `GUI/Editor/Toolbar/*`
- `GUI/Editor/MediaLibrary/*`
- `GUI/Pages/*`

## Stable existing patterns

- Modal/tool windows with `ApplyWindowChrome` and standard close button.
- Role-based button visuals (`primary_action`, `utility`, `danger`).
- Inspector mutations with RefreshPolicy.
- Media Library as a contextual picker.
- TextEditorOverlay for direct visible text editing.
- Toolbar Definition/Binding/Controller split.

## Observed development pain points

These points come from repeated implementation and testing experience. They should inform later UI work, but they are not by themselves hard architectural facts:

- AceGUI width, height, and reflow behavior can be sensitive during compact compositions.
- Small row additions often require manual window-height tuning.
- Narrow button glyphs can need explicit stabilization to remain readable in all states.
- Small visual changes can require disproportionate layout effort.
- Dialog and footer composition tends to repeat across tools.

## Code-backed constraints and existing patterns

These points are visible in the current codebase and should be treated as real constraints or established patterns:

- Some widgets are rebuild-sensitive; controls that only change live geometry should not trigger section rebuilds through RefreshPolicy.
- `FormRenderer.lua` and `FormWidgets.lua` provide existing form, row, control, and visual helper patterns.
- Inspector flows already separate mutation ownership from refresh decisions through `InspectorMutations.lua` and `InspectorRefreshPolicy.lua`.
- Media Library uses an established contextual picker contract with caller-provided context and `onApply`.
- Tool windows and dialogs reuse AppShell/window chrome, footer/action rows, and role-based button visuals.
- TextEditorOverlay is the existing pattern for object-centered visible text editing.

## Useful small foundations

Potential later direction, without a new framework:

- reusable action rows for dialog footers,
- standardized glyph buttons,
- stable section/row patterns for common Inspector compositions,
- declarative height/spacing helpers for recurring tool windows,
- consistent contextual picker contracts following the Media Library pattern.

## Boundaries

- No custom generic GUI framework on speculation.
- No new window/renderer architecture for small UI changes.
- No second configuration or runtime truth.
- UI foundations should stabilize recurring Focal Point patterns, not abstract every AceGUI problem.

## Observation vs. fact

If a problem is known from development experience but not directly provable from code, it must be treated as an observation. Documentation must not turn it into a hard technical fact.
