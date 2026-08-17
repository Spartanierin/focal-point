STATUS: CURRENT / PARTIAL / HIGH VALUE - valid UX principles, not a final 2.0 specification.

# Focal Point Editor UX Principles

## Zones

### Left: Context And Tools

- The left column controls the editor work context.
- It contains navigation, unit selection, editor mode, on-screen editing, presets, and global addon options.
- It provides orientation and tools, but must never overpower the central editing area.

### Center: Editing Space

- The center is the primary workspace.
- It either shows the internal workspace or the actual Focal Point frames on the screen.
- The selected unit is the visual focus.
- Unselected frames remain visible, but only the active unit receives a clear editing marker.

### Right: Inspector

- The right side edits only the current selection.
- It shows properties, not global context.
- The Inspector uses progressive disclosure instead of showing every option at once.

## Left Column Priority

The left column follows this order:

1. Tools
2. Work context
3. Editing
4. Presets
5. Addon

Rules:

- Tools sit at the top, but stay visually restrained.
- Work context and editing are the primary editor blocks.
- Presets are intentionally visible, but act as starting points rather than frame properties.
- Addon options sit lower because they are used less often.

## Inspector Rules

- Only `Frame` and `Health` are open by default.
- Secondary groups start collapsed.
- Groups should read as clear sections, not as repeated generic form blocks.
- Related areas need distinct titles, for example `Cast Bar` and `Cast Bar Position`.
- The Inspector edits only the active unit and should feel calm, focused, and editorial.

## Workspace Focus Rules

- Only the active unit receives a visible yellow edit outline.
- Coordinates are shown only for the active or currently dragged unit.
- Unlock mode exists for direct on-screen editing and must not create a broad global highlight state.
- Demo data is only a data state for the same shell, not a separate mode with a separate UI.
- The workspace should feel like a real editor surface, not a generic preview.

## General Editor Principles

- Do not return to classic page-navigation logic.
- Context belongs on the left, editing in the center, properties on the right.
- Do not make everything maximally visible at the same time.
- Important options come first; specialized options come later.
- Clear hierarchy matters more than decoration.
- Presets are starting states, not a parallel property layer.
- The editor should feel like a tool, not like a traditional addon options dialog.

## Product Decision For The Visible UI

- The addon should not look like a disguised classic window.
- The visible UI should be composed of shell, editor surface, and tool pages, not window chrome.
- If a technical host remains in the background, it must not define the visible product identity.
- Window borders, title bars, and similar visible chrome belong in the UI only when they are intentional, not because the implementation brought them along.
- Architecture work should therefore aim for a real surface structure with clear zones, not endless bending of a window frame.

## Visual Protection Rules

- Architecture changes must not accidentally change the editor's visual character.
- Fonts, sizes, colors, transparency, lines, spacers, and distances are part of the product experience.
- Left sidebar, workspace, and Inspector must keep their visual balance.
- Widths and anchors of the main editor zones are not arbitrary technical values; they are part of the design.
- A refactor is good only when the editor looks the same or intentionally better afterward, not merely cleaner internally.

## Editor Target Model

- The editor is the addon's primary product surface.
- The technical host is only a carrier system and must not define the visible identity of the editor.
- The visible editor structure remains:
  1. left toolbar
  2. free workspace
  3. right Inspector
- If the carrier system changes, the screen impact of these three zones should remain as stable as possible.
- The current implementation already supports this direction: in the editor, the main host is visually mostly neutralized; the editor impression comes from toolbar, workspace, and Inspector rather than from a window frame.

## Editor Migration Rule

- The editor should be rebuilt in phases.
- Responsibilities become clearer first; technical carriers are replaced later.
- Visible editor building blocks should move only after their appearance has been secured as the reference.
- Tool pages may continue to be simplified independently; they are not a reason to pull the editor along too early.
- Early phases should explicitly name the three editor roles first:
  - Toolbar Host
  - Workspace Host
  - Inspector Host
- The next safe layer is a dedicated, invisible editor presentation host behind the same visible editor composition.

## Current Reference Impression

- Left and right sides frame the editor like related tool zones.
- The center stays open and is not a classic form or panel area.
- The dark, translucent side surfaces should not push the game world away; they should frame it.
- Inactive unit frames remain visible parts of the composition and help the whole layout stay readable.
- The active unit stands out more strongly, but the rest of the layout must not visually disappear.
- The visual tension comes from:
  - dark surfaces
  - gold or bright headings
  - red action buttons
  - compact, calm vertical rhythm
- The editor should feel like an embedded in-game tool, not like a standard options window.

## Current Reference Values

- Left toolbar width: currently `285`
- Right Inspector width: currently `285`
- Both side zones: dark translucent base surfaces with fine cool-toned borders
- Headings: small to medium, gold/bright, not loud
- Help and description text: compact and restrained
- Standard spacer rhythm: dense but consistent, usually in the `4` to `8` range

## Architecture Direction

- `GUI.lua` is bootstrap and routing, no longer the place for complete shell implementation.
- Shell chrome, tool surface, and app geometry live in `GUI/AppShell.lua`.
- `Profiles`, `Text Builder`, and `Tag Database` render as normal pages into the shell's right main surface.
- The left context bar and the right Inspector live in `GUI/Editor/ContextSidebar.lua` and `GUI/Editor/InspectorSidebar.lua`.
- Inspector lifecycle, rebuild, and scroll restore live in `GUI/Editor/EditorController.lua`.
- Shared sidebar helpers and metadata live in `GUI/Editor/SidebarShared.lua`.
- `GUI/Editor/EditorSidebar.lua` remains only as a legacy bridge for existing call sites.
- Page content remains in page modules.
- In the editor, the left toolbar is now separated from the old shell-sidebar foundation by its own runtime layer.
- The technical main host remains for lifecycle and shared infrastructure, but barely defines the visible editor character anymore.

## Secondary Tools

- `Profiles`, `Text Builder`, and `Tag Database` remain standalone tools.
- They open in the shell's right main surface and not as another Inspector.
- The left column remains visible as app context.
- On tool pages, the left column is simplified: tools stay at the top, while the full unit work context is reduced in favor of a compact way back to the editor.
- The unit-frame editor itself is unaffected by this and must not be rebuilt into classic page logic again.

### Layout Rules For Tool Pages

- Tool pages use the right main surface as a form area instead of creating their own inner window.
- Content follows a clear vertical structure:
  1. introduction
  2. primary action or primary content
  3. management or secondary actions
  4. rare or destructive actions last
- Long action chains should be split into multiple calm rows instead of one wide form row.
- Fixed widths may be used, but must fit the centered tool surface and must not assume the old full-surface dialog.

## Tool Pages As Product Surfaces

- Tool pages should feel like real Focal Point tools, not classic admin or options forms.
- The right tool surface is an intentional workspace inside the same product world as the editor.
- Product coherence comes from the same basic principles:
  - calm dark surfaces
  - gold or bright hierarchy text
  - red action buttons
  - clear vertical rhythm
  - compact but not rushed information density
- Tool pages may be calmer and more guided than the editor, but they must not feel more generic.
- The editor remains the stronger reference for value, tone, and design grammar.

## Tool Pages May Differ From The Editor

- Tool pages do not need a free in-game workspace.
- Tool pages do not need to behave like an Inspector.
- Tool pages may rely more heavily on guided tool flow:
  1. current state
  2. source or context
  3. primary action
  4. less common maintenance or safety actions
- Tool pages should stack less like forms and guide more like calm workflows.

## Tool Zones For Tool Pages

- Tool pages should not consist only of uniform form sections.
- They should be built as recognizable tool zones that make different work phases visible.
- For `Profiles`, the reference pattern is:
  1. active state
  2. adopt or manage source
  3. create new work state
  4. rare or destructive maintenance actions
- These zones should be visible not only in text, but also through surfaces, spacing, weight, and CTA priority.
- Primary actions should appear as deliberate work steps, not just buttons inside a form block.
- Secondary or riskier actions belong visibly lower and should not carry the same everyday importance as normal work actions.

## What Must Stay Consistent For Product Coherence

- Left shell and right tool view must read as parts of one coherent surface.
- The right side must not feel like a foreign sub-application.
- Typography roles must recur:
  - page header
  - section title
  - help text
  - emphasized status value
- Surfaces should feel composed rather than merely technically arranged.
- Every tool page should answer this question positively:
  - Does this feel like a serious Focal Point tool inside the same product family as the editor?

## Text Builder Product Rule

- The Text Builder is not a side tool; it is a core product tool.
- Users work with templates and text elements, not with fixed text slots.
- If Inspector, Builder, and Runtime use different terms, the Text Builder is the reference for the visible product model.
- Hard text-slot terms such as `Name`, `Race`, or `Custom1` must not define the visible product language.
- The underlying architecture should therefore move toward free text elements linked to templates.

## Rollback Rules

- Old editor halfway states such as internal canvas previews should not continue to be maintained in parallel.
- `Unlock` changes interaction only, not the shell layout.
- Demo data changes only the data state, not the surface structure.
- When old GUI ballast is removed, delete dead dependencies and unused render paths before adding new polishing steps.
