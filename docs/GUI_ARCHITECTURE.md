# GUI Architecture

## Purpose

This document describes how FocalPoint's GUI is currently structured in code and how it appears on screen.

It is intentionally split into:

- current runtime architecture
- visible UI zones
- internal container hierarchy
- editor-specific behavior
- tool-page behavior
- architectural pain points
- target direction for refactoring

The goal is to create a shared understanding before further GUI refactors happen.

Related architecture:

- [TEXT_ARCHITECTURE.md](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/docs/TEXT_ARCHITECTURE.md) describes the text/template model, current legacy slot assumptions, and the migration path to free text elements.

## Product UI Decision

FocalPoint's intended product UI is not a classic windowed dialog.

The intended visible surface is:

- the shell
- the editor presentation
- the tool-page presentation

The visible AceGUI window chrome is not considered part of the product UI.

This means:

- the main host may remain as technical infrastructure
- but the host must not define the visible identity of the addon
- left/right layout zones and in-world editing surfaces are the intended UI
- future refactors should move the code toward a real shell/presentation model, not toward a disguised window model

In practical terms, the project prefers:

- a real shell with visible UI zones
- over a window widget that is repeatedly hidden, bent, or cosmetically disguised

## Terminology

To avoid confusion, these terms should be used consistently.

### Main Window

The top-level visible AceGUI window created with `AceGUI:Create("Frame")`.

Visible characteristics:

- title bar with `Focal Point`
- close button
- outer border / window chrome
- status/footer area, unless hidden by shell mode

This is the outermost visible GUI window of the addon.

### Main Host

The runtime host object that owns the shell root and currently wraps the main window widget.

Current code intent:

- `guiMainHost` is the preferred runtime reference

Today, the main host is still an AceGUI `Frame`, but the code is being refactored so that shell logic depends on a generic host role rather than on an old window-centric widget name.

At runtime, the host chrome is now treated separately from the host itself:

- the host still exists as the root widget
- the visible window chrome is no longer conceptually required for shell rendering
- the shell can use the host in an embedded or windowed presentation mode
- in `editor` mode the host is now visually neutralized and primarily remains technical infrastructure

### Shell

The persistent application structure rendered inside the main window.

The shell currently provides:

- left application sidebar
- right main content area

The shell itself is not the editor. It is the host for different modes.

### Main Content Area

The right-side content host inside the shell.

This area changes depending on the selected navigation path.

Examples:

- editor mode
- profiles page
- text builder page
- tag database page

In `tool` mode, this area should read as a dedicated Focal Point work view rather than as a generic embedded dialog body.

### Editor Mode

A specific mode rendered inside the main content area.

The editor mode consists of:

- visual workspace in the center of the screen
- a separate inspector docked on the right

The editor is not the main window. It is a mode running inside the shell.

### Inspector

A separate editor-specific frame used to edit the currently selected unit.

The inspector exists only in editor mode.

### Tool Pages

Pages such as:

- `Profiles`
- `Text Builder`
- `Tag Database`

These are not editor workspaces. They are classic content pages rendered into the main content area.

Tool pages may be calmer and more guided than the editor, but they should still belong to the same product family.

That means:

- same surface language
- same hierarchy language
- same overall product tone
- same feeling of a deliberate tool rather than a borrowed admin form

Tool pages should also express an internal work flow rather than just a stack of forms.

For reference, the `Profiles` page now follows four explicit tool zones:

1. active state
2. source adoption / management
3. new profile creation
4. maintenance / destructive actions

This zoning is intentional product behavior, not just page decoration.

### Shell Mode

The shell currently has two conceptual modes:

- `editor`
- `tool`

`editor` means:

- editor workspace is active
- inspector may exist
- shell chrome may be minimized or hidden

`tool` means:

- a normal tool page is active in the main content area
- no editor inspector should be present
- the shell remains responsible for the visible UI structure

### Host Chrome Mode

Host chrome mode describes how much of the underlying AceGUI `Frame` should remain visibly present.

Current conceptual modes:

- `shell`
- `window`

`shell` means:

- the host is still the technical root
- title bar, close button, and outer window chrome are hidden
- the visible structure comes from the shell itself

`window` means:

- the underlying AceGUI frame remains visibly window-like

Current runtime direction:

- `editor` currently resolves to host chrome mode `shell`
- `tool` currently resolves to host chrome mode `window`
- in practice, `editor` now keeps the host only as a technical root while the visible editor composition is carried by dedicated toolbar/workspace/inspector runtime layers

Long-term direction:

- visible host chrome should not be required for either editor mode or tool pages
- the shell should be the intended visible structure
- host chrome should only remain if it serves a deliberate product purpose rather than compensating for implementation details

## Current Runtime Structure

## 1. Top-Level Window / Main Host

The top-level window is created in [GUI.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUI.lua).

Current entry point:

- `FocalPoint:CreateGUI()`

Important detail:

- the GUI uses `AceGUI:Create("Frame")` as its top-level container
- this means the addon currently does use a real visible AceGUI window
- this widget is now also treated as the current `Main Host`

Historically, if the user saw a title bar labeled `Focal Point`, that was the real root GUI window, not a nested child panel.
The current refactor direction is to keep that root widget while making its visible chrome optional.
That direction is now materially advanced for the editor: the editor no longer visibly depends on the host window itself.

## 2. Shell Inside the Main Window

The shell is built in [AppShell.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/AppShell.lua).

Current entry point:

- `AppShell.BuildRoot(addon, hostWidget)`

This builds:

- `root`
- `appSidebar`
- `contentHost`

These correspond to:

- the shell root layout
- the left sidebar
- the right main content area

On screen, the shell currently looks like this:

```text
[ Main Window ]
[ Left Sidebar ][ Main Content Area ]
```

## 3. Page Routing

The current page routing lives in [GUI.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUI.lua).

Important functions:

- `ResolveDefaultGUIPath`
- `RenderPage`
- `FocalPoint.GUI:RefreshOptions()`

`RenderPage(container, path)` decides what is rendered into the shell's right-side content host.

Current high-level routes:

- `editor`
- `text_builder`
- `tag_database`
- `profiles`
- unit paths such as `units.player`

From the shell perspective, these routes collapse into two shell modes:

- `editor`
- `tool`

For tool pages, route changes should not feel like leaving the product shell.
They should feel like opening another Focal Point tool inside the same shell, with a clearer workflow and calmer content pacing than the editor.

## Visible UI Zones

## Main Window

Visible on screen:

- title `Focal Point`
- close button
- outer frame
- optional footer/status area depending on shell mode

Ownership:

- AceGUI `Frame`
- created in `FocalPoint:CreateGUI()`

## Left Sidebar

Visible on screen:

- navigation buttons
- work context
- unit selection
- editor-related actions
- presets
- addon options

Ownership:

- shell
- content built primarily by editor/context modules

Current role:

- global navigation
- editor context
- editor tools

This means the left sidebar is currently a mixed-responsibility zone: it is not purely global navigation.

## Main Content Area

Visible on screen:

- whatever page or mode is active

Examples:

- editor workspace
- text builder form
- profiles form
- tag database reference page

Ownership:

- shell

## Right Inspector

Visible on screen only in editor mode.

It contains:

- frame settings
- bar settings
- text settings
- aura settings
- other unit-specific properties

Ownership:

- editor mode
- not shell-global

This is important conceptually:

- the inspector is not a general right sidebar for the entire app
- it is a separate editor-only panel

## Internal Container Hierarchy

The current structure is best understood in two layers: visible UI and AceGUI container hierarchy.

### Visible Hierarchy

```text
Main Window
+- Left Sidebar
`- Main Content Area
   +- Editor Workspace
   +- Tool Page
   `- Other page content
```

In editor mode, this becomes:

```text
Main Window
+- Left Sidebar
+- Main Content Area
|  `- Editor Workspace
`- Inspector
```

### Implementation Hierarchy

Current rough implementation flow:

```text
AceGUI Frame
└─ AppShell root
   ├─ appSidebar
   └─ contentHost
      └─ page content selected by RenderPage()
```

In editor mode, there is an additional editor-controlled inspector frame created separately from the normal shell content host.

## Editor Mode Architecture

The editor is a mode, not the whole app window.

The editor page is triggered through:

- `RenderPage(..., editor)`
- `GUIBuilders.BuildEditorPage`
- `EditorPage.Build`

Relevant files:

- [GUI.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUI.lua)
- [GUIBuilders.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/GUIBuilders.lua)
- [Pages/EditorPage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/EditorPage.lua)
- [Editor/EditorController.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Editor/EditorController.lua)

Editor-specific elements:

- left context/sidebar content
- on-screen frame interaction
- selection/highlight logic
- inspector lifecycle

The inspector is created and managed separately from the normal shell content area.

The inspector lifecycle must be tied to shell mode:

- shell mode `editor` -> inspector may exist
- shell mode `tool` -> inspector must be released

That is why editor mode behaves differently from tool pages.

## Tool Page Architecture

Tool pages are currently intended to be normal pages rendered into the shell's main content area.

Relevant files:

- [Pages/ProfilesPage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/ProfilesPage.lua)
- [Pages/TextBuilderPage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TextBuilderPage.lua)
- [Pages/TagDatabasePage.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/GUI/Pages/TagDatabasePage.lua)

Current expectation:

- they should not spawn a second application window
- they should not behave like an inspector
- they should occupy the shell's main content area as classic pages or forms

## AceGUI Notes That Matter

AceGUI widgets usually have both:

- `frame`
- `content`

Important rule:

- children are attached to a container through the container's `content` frame
- layout ownership still belongs to the widget and its `frame`

This matters because GUI bugs can happen if code manually reparents inner `content` frames without respecting the owning AceGUI widget's own layout model.

For the current GUI architecture, the practical takeaway is:

- page content should be built into normal container hierarchies
- window-like geometry should not be simulated by fighting AceGUI's parent/layout expectations

## Current Architectural Pain Points

## 1. Main Window vs App Perception

Users can easily confuse:

- the visible main window
- the shell
- the editor
- the inspector

This happens because the current GUI uses one visible window plus mode-specific overlays and docked frames.

## 2. Left Sidebar Has Mixed Responsibilities

The left sidebar currently acts as both:

- global app navigation
- editor-specific work context

This makes tool pages feel partially like editor pages even when they should behave like simpler forms.

## 3. Editor Architecture Is Stronger Than Tool Architecture

The editor has a clearer mental model:

- visual workspace
- selected unit
- inspector

Tool pages are simpler, but the surrounding shell still feels strongly editor-shaped.

## 4. Terminology Is Not Yet Stable

The code and docs historically use overlapping ideas such as:

- page
- shell
- window
- tool surface
- inspector

This increases confusion during refactors.

## 5. Editor Runtime Depends On Host Compensation

The current editor runtime works, but it does not map naturally to the host model.

Observed patterns:

- the main host is visually stripped down in editor mode
- the host width is collapsed to sidebar width
- the normal shell content area is effectively reduced to a minimal placeholder
- the inspector is detached and anchored directly to `UIParent`
- resize and scroll behavior need follow-up stabilization passes

This means the editor is not merely "using" the host. It is partially compensating for it.

That does not mean the editor is broken. It means the editor architecture is stronger and more screen-native than the current host abstraction.

## Recommended Mental Model Going Forward

The most useful way to understand the GUI is:

```text
App GUI
`- Main Window
   `- Shell
      +- Left Sidebar
      `- Main Content Area
         +- Editor Mode
         |  +- Workspace
         |  `- Inspector
         `- Tool Pages
            +- Profiles
            +- Text Builder
            `- Tag Database
```

This should become the canonical conceptual model.

## Editor Target Architecture

The editor should be treated as the product core of the addon.

The target model is:

```text
Main Host
`- Editor Presentation
   +- Left Toolbar
   +- Workspace Layer
   `- Inspector Layer
```

Meaning:

- the main host is only the technical root
- the editor presentation owns the visible editor composition
- the left toolbar remains the contextual control surface
- the workspace remains the primary visual editing area
- the inspector remains a dedicated editor-only property surface

The important architectural goal is not to redesign the editor. It is to let the runtime model match what the editor already is on screen.

## Visual Invariance Rule

Editor refactors must preserve the visible editor unless a change is explicitly requested.

The following should be treated as protected visual contracts:

- sidebar width
- inspector width
- visual anchoring on screen
- typography, including font choices and font sizes
- colors, opacity, borders, and accents
- spacer rhythm and section spacing
- section hierarchy and reading order
- perceived balance between left toolbar, workspace, and inspector

In practical terms:

- architecture may change under the surface
- the on-screen editor should remain visually familiar
- "cleaner internals" is not a reason to casually alter design

This rule has priority over architectural neatness.

## Refactor Direction

Before further refactors, the target direction should be:

## 1. Keep Shell and Mode Separate

The shell should remain only:

- left sidebar
- main content host

The shell should not itself behave like the editor.

The code should prefer an explicit shell mode such as:

- `editor`
- `tool`

over inferring UI behavior ad hoc from individual navigation paths in many places.

## 2. Treat Editor as a Distinct Mode

Editor mode should own:

- workspace behavior
- on-screen interaction
- inspector

Editor mode should also be evaluated separately from tool pages when host decisions are made.

If the host works well enough for tool pages but creates compensation logic for the editor, the editor should still be allowed to evolve toward a better fitting runtime model.

The inspector should be documented and treated as editor-only UI.

## 3. Treat Tool Pages as Simple Content Pages

Tool pages should:

- render directly into the main content area
- not create extra internal windows
- not mimic editor-specific chrome

The right-side main content area should therefore be prepared explicitly per shell mode:

- `editor` -> editor workspace host
- `tool` -> tool-page host

Even if both currently use the same physical content area, the shell should treat them as distinct runtime roles.

If visual framing is desired, it should be ordinary page layout, not nested window simulation.

## 4. Clarify Sidebar Responsibilities

Long-term, the left sidebar should distinguish between:

- global navigation
- editor-only controls

That does not necessarily require separate sidebars, but it does require clearer responsibility boundaries.

## Recommended Refactor Phases

### Phase 1: Documentation and Naming

- document current shell, editor, inspector, and tool-page roles
- align code comments and docs with those terms

### Phase 2: Shell Stabilization

- simplify shell layout responsibilities
- ensure the main content area behaves consistently across editor and tool pages

### Phase 3: Editor Isolation

- make editor-specific UI and lifecycle more explicit
- keep inspector clearly editor-owned
- document and preserve visual invariants before structural work
- separate "editor host compensation" from true editor requirements

### Phase 4: Tool Page Simplification

- standardize tool pages as classic content pages
- remove assumptions that tool pages need editor-like structure

### Phase 5: Optional Main Window Simplification

After the internal architecture is clearer, decide whether the visible AceGUI main window should remain:

- as a classic framed application window
- or be replaced/minimized with lighter shell chrome

That decision should come after shell/mode separation is stable.

For the editor specifically, a host change should only happen if it reduces compensation logic without violating the visual invariance rule.

## Editor Migration Outline

This outline is intentionally editor-only.

Tool pages do not need to be migrated together with the editor.

### Goal

Reduce host compensation in editor mode while preserving the current visual editor experience.

### Phase E1: Freeze Visible Contracts

Before editor-host work begins, treat the following as reference contracts:

- left toolbar width
- inspector width
- editor screen anchors
- section spacing and rhythm
- typography and color usage
- inspector grouping and collapse behavior

Recommended practice:

- compare every editor-host change against current screenshots
- treat visible regressions as architectural failures, not cosmetic follow-ups

### Phase E1 Reference Baseline

The current editor baseline should be derived from both:

- the live on-screen presentation
- the currently implemented geometry and styling values

#### Screen-Level Contracts

From the current editor presentation, the following are treated as visual contracts:

- the editor is composed as a three-zone presentation:
  - left toolbar
  - free in-world workspace
  - right inspector
- the center is not a boxed page panel; it remains an open scene-backed workspace
- the left toolbar and right inspector act as visual siblings that frame the workspace
- both side zones use a dark, semi-transparent, tool-like surface language
- the workspace remains visually dominant even while the side zones stay permanently visible
- the editor must continue to feel like an in-world editing tool, not a conventional options dialog
- inactive unit frames remain visibly integrated into the workspace composition
- the active unit receives the dominant edit highlight, but inactive units are not reduced to visually irrelevant placeholders
- active versus inactive state is communicated through visual weighting, not by removing the surrounding layout context

#### Current Geometry Contracts

Current code-backed geometry values:

- editor left toolbar width: `285`
- editor inspector width: `285`
- main host width: `1220`
- editor host anchor: `TOPLEFT` to `UIParent`
- inspector anchor: `TOPRIGHT` to `UIParent`
- inspector inset: `16` left/right, `10` top/bottom

These values may eventually change internally, but any migration must preserve the same perceived spatial composition unless an intentional redesign is approved.

#### Surface and Color Contracts

Current code-backed surface styling:

- left toolbar background: `0.05, 0.06, 0.08, 0.84`
- left toolbar border: `0.16, 0.19, 0.24, 0.9`
- inspector background: `0.05, 0.06, 0.08, 0.76`
- inspector border: `0.16, 0.19, 0.24, 0.9`
- inspector accent: `0.78, 0.65, 0.24, 0.50`

Shared section styling from sidebar helpers:

- prominent section title color: `0.94, 0.85, 0.46, 1`
- default section title color: `0.79, 0.83, 0.88, 1`
- muted section title color: `0.63, 0.67, 0.72, 1`
- prominent section backdrop: `0.10, 0.11, 0.14, 0.52`
- default section backdrop: `0.09, 0.10, 0.12, 0.38`
- muted section backdrop: `0.08, 0.09, 0.11, 0.26`
- prominent accent strip: `0.83, 0.70, 0.30, 0.55`

These are not merely implementation details. They define the editor's current material language.

#### Typography Contracts

Current code-backed typography:

- brand title in left toolbar: `STANDARD_TEXT_FONT`, size `16`
- version line in left toolbar: size `12`
- section title sizes:
  - prominent: `13`
  - default: `12`
  - muted: `11`
- inspector summary size: `11`
- inspector hint size: `10`
- sidebar supporting text commonly uses size `11`

The current editor hierarchy relies on compact typography with contrast coming more from color, grouping, and spacing than from large type jumps.

#### Rhythm Contracts

Current spacing rhythm:

- base spacer helper default: `8`
- local section gaps frequently use `4`, `6`, or `8`
- buttons in sidebars commonly use heights `22`, `24`, or `26`
- active sidebar items use height `26`

This creates a dense but readable tool aesthetic and should be preserved as a rhythm, not copied mechanically without understanding.

### Phase E2: Separate Editor Runtime Roles

Define editor runtime roles explicitly in code:

- editor toolbar host
- editor workspace host
- editor inspector host

Current runtime naming direction:

- `guiEditorToolbarHost`
- `guiEditorWorkspaceHost`
- `guiEditorInspectorHost`

At this phase, behavior should remain the same.

The purpose is only to stop treating the editor as:

- "the shell with hidden host chrome"
- "a tool page with special cases"

### Phase E3: Isolate Host Compensation

Move current host-compensation logic behind clearly named editor-only functions.

Examples of compensation that should become explicit:

- host chrome suppression in editor mode
- host docking to the top-left of `UIParent`
- shell width collapse to sidebar width
- content host minimization
- inspector re-anchoring to `UIParent`
- resize/timer-based geometry stabilization

This phase does not remove the compensation yet.

It only makes clear which logic is:

- true editor behavior
- temporary host adaptation

Current compensation naming direction:

- `ApplyEditorHostChromeCompensation`
- `ApplyEditorShellLayoutCompensation`
- `ApplyEditorHostDockingCompensation`
- `ApplyVisualChromeSuppression`
- `ExpandHostContentToFullscreen`

Tool-mode counterparts should stay separately named where relevant so editor-only compensation does not remain hidden inside generic shell code.

### Phase E4: Introduce an Editor Screen Host

Create a dedicated editor presentation root that conceptually owns:

- left toolbar
- workspace layer
- inspector layer

Important:

- this can still coexist with the current main host
- the goal is to give the editor a screen-native structure
- the tool-page host should remain unchanged during this phase

Current runtime naming direction:

- `guiEditorPresentationHost`
- `guiEditorToolbarHost`
- `guiEditorWorkspaceHost`
- `guiEditorInspectorHost`

This is the first phase where the editor starts to have a runtime model that matches its on-screen identity.

### Phase E5: Reattach Existing Visual Components

Once the editor screen host exists, reattach existing visual editor parts to it without redesigning them:

- keep `ContextSidebar` styling and section rhythm
- keep `InspectorSidebar` styling and hierarchy
- keep current widths and screen positions
- keep workspace behavior visually unchanged

Current safe first step:

- parent and anchor the inspector against the editor presentation host instead of anchoring it directly to `UIParent`
- introduce an explicit workspace layer beneath the same presentation host without changing the visible workspace composition
- introduce a dedicated inspector layer beneath the same presentation host so workspace and inspector become sibling runtime layers
- explicitly tag the left editor sidebar as the editor toolbar runtime surface, even while it still lives in the shell

Success condition:

- same editor look
- simpler ownership model

### Phase E6: Remove Redundant Compensation

Only after the editor presentation host is stable should redundant compensation be removed.

Candidates:

- main-host width collapse for editor mode
- editor-only host chrome suppression that no longer matters
- content-host placeholder shrinking
- repeated geometry correction timers that become unnecessary

This phase should be incremental.

If a compensation layer is still stabilizing visual behavior, it should stay until its replacement is proven safe.

Current first reduction direction:

- stop collapsing the invisible editor main host to sidebar width if the visible editor composition remains unchanged

Current status:

- collapsing the editor main host to sidebar width has been removed
- forcing the host content to fullscreen has been removed
- broad host-child suppression has been reduced to explicit chrome children
- extra backdrop nulling has been removed
- the remaining editor-specific host suppression is primarily the host `regions`, because those still render the visible AceGUI window frame behind the editor

This means the editor now treats the main host as:

- technical root for routing, lifecycle, and shared shell ownership
- visually neutralized infrastructure in editor mode
- not the visible source of editor identity
- stop minimizing the shell content host to a one-pixel placeholder if editor presentation layers already own the visible workspace
- stop forcing move/resize suppression on the invisible editor host when mouse suppression already prevents direct interaction
- stop forcing full-screen height onto the shell content host in editor mode when presentation layers already own the visible editor area

### Phase E7: Reevaluate the Main Host

Only after the editor runs naturally on its own presentation host should the project decide:

- keep the current AceGUI main host
- or replace the main host with a lighter WoW `Frame`

At the current stage, replacing the host is no longer urgent for editor visuals.
The more important open question is whether the remaining host `regions` can ever be classified more precisely than a broad region hide, or whether that broad hide is the pragmatic final state for the AceGUI host.

At that point, the host decision becomes much safer because the editor will no longer depend on host tricks for its identity.

## Editor Migration Decision Gates

The editor should only move from one migration phase to the next when all of the following remain true:

- no visible regression in toolbar, workspace, or inspector composition
- no regression in editor interaction flow
- no new overlap, drift, or anchor instability after resize or UI scale changes
- no loss of inspector scroll stability
- no loss of section hierarchy or readability

If these gates are not met, the migration should pause and preserve the current presentation.
