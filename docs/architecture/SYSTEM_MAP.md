# FocalPoint System Map

This document is a small internal map of FocalPoint's main systems.
It is not a full architecture specification. Its job is to make responsibilities,
boundaries, and dependencies visible at a glance.

## Purpose

FocalPoint now has multiple engines and UI subsystems that interact with each other.
This map exists to answer four practical questions:

- What systems exist?
- What is each system responsible for?
- What may it know about?
- What should it avoid knowing about?

The goal is to keep future changes intentional and reduce accidental coupling.

## System Overview

### 1. Layout Engine

**Responsibility**

- Places GUI content inside sections
- Handles two-column structure
- Applies optional layout metadata such as `placement`, `span`, `rowType`, and `subsection`

**May know**

- Generic AceGUI container structure
- Section row and column composition
- Generic layout metadata

**Should not know**

- Unit settings
- text templates
- tags
- profile logic
- page-specific business rules

**Consumed by**

- GUI layout helpers
- GUI page builders

### 2. GUI Layout Helpers

**Responsibility**

- Bridge layout definitions to the layout engine
- Resolve layout text, paths, and lists
- Build shared scrollable content containers
- Validate generic layout definitions

**May know**

- Shared GUI helper rules
- Layout definitions and path replacement
- Localization lookup for layout labels

**Should not know**

- Text workflow rules
- unit frame runtime behavior
- template ownership rules

**Consumed by**

- GUI page modules
- GUI builders/orchestrators

### 3. GUI Pages / GUI Builders

**Responsibility**

- Build concrete configuration pages
- Orchestrate tabs, sections, widgets, and page-local interactions
- Connect page widgets to config state and refresh paths

**May know**

- Which page is being rendered
- Which helper modules and widgets are needed
- How a given feature is configured in the UI

**Should not know**

- low-level frame rendering details
- bar rendering internals
- tag parsing internals beyond what is needed for preview and editing

**Consumed by**

- Main GUI router
- Navigation tree selection

### 4. GUI Widgets

**Responsibility**

- Encapsulate reusable controls such as dropdowns, sliders, checkboxes, and color pickers
- Expose refreshable widget state
- Apply reset behavior and disabled-state logic

**May know**

- How to read and write option paths
- How to refresh their own visible state

**Should not know**

- page structure
- section structure
- template workflow
- unit-specific behavior rules

**Consumed by**

- GUI pages
- layout-based page sections

### 5. Config and Profile System

**Responsibility**

- Store persistent addon state
- Provide profile switching, copying, resetting, and current profile selection
- Hold unit settings, text templates, and general options

**May know**

- SavedVariables layout
- default values
- profile lifecycle

**Should not know**

- GUI layout rules
- how a text is rendered
- how widgets are arranged

**Consumed by**

- GUI
- runtime systems
- text/template systems

### 6. Text System

**Responsibility**

- Manage text elements on units
- Prefer template-driven content through `templateName`
- Fall back to direct raw tag strings when needed
- Keep presentation separate from text content

**May know**

- Text element configuration
- template references
- text placement, font, base color, and effects

**Should not know**

- GUI section layout behavior
- page composition rules
- unrelated frame element configuration

**Consumed by**

- Unit frame runtime
- Text Builder
- Unit text pages

### 7. Tag System

**Responsibility**

- Resolve tags into current unit values
- Provide inline text formatting such as color tags and reset tags
- Keep display-first handling where live API values are sensitive

**May know**

- Supported tag vocabulary
- preview rendering needs
- inline formatting rules
- safe display values

**Should not know**

- global text element layout
- page composition
- frame anchoring logic

**Consumed by**

- Text system

### 8. Runtime Debug Hooks

**Responsibility**

- Provide small operational diagnostics for unstable runtime edge cases
- Help inspect transient frame states without changing the normal feature flow

**Current example**

- `/fp debug target`
- Toggles temporary target visibility diagnostics in chat
- Used to inspect short-lived `target` transitions during events such as `PLAYER_TARGET_CHANGED`

**May know**

- Temporary target visibility state
- Chat debug output helpers
- Event timing relevant to the observed bug

### 9. Theme System

**Responsibility**

- Provide curated visual starting points for the addon
- Define preset data for frame, text, indicator, and aura presentation
- Support a future Quickmode workflow without becoming a second profile system

**May know**

- Theme metadata
- Stable profile field structure
- Which field groups are safe for preset ownership

**Should not know**

- frame runtime internals
- aura cache internals
- text token parsing internals
- GUI layout engine internals

**Consumed by**

- Theme apply service
- General / Quick Start GUI entry points

**Should not know**

- GUI structure
- profile persistence rules
- unrelated runtime behavior outside the debug case

**Consumed by**

- Slash commands
- Target visibility debugging workflow
- Text Builder preview
- Tag Database

### 8. Preview / Builder Support

**Responsibility**

- Provide safe preview output for templates and text editing
- Support builder-side examples without requiring full runtime state

**May know**

- preview fallback values
- text builder state
- selected template content

**Should not know**

- persistent runtime frame ownership
- full unit frame lifecycle

**Consumed by**

- Text Builder
- Unit text pages

### 9. Unit Frame Runtime

**Responsibility**

- Spawn and refresh live unit frames
- Apply bars, texts, portraits, icons, and frame config
- Render resolved text output onto visible frames

**May know**

- active unit configuration
- live frame instances
- rendering order and frame updates

**Should not know**

- editor page layout
- builder-specific workflow state
- tag database presentation

**Consumed by**

- Live gameplay
- Preview/test refresh paths

## Dependency Direction

The intended dependency direction is:

```text
Config / Profiles
    -> Text System
    -> Tag System
    -> Unit Frame Runtime
    -> GUI Widgets

Layout Engine
    -> GUI Layout Helpers
    -> GUI Pages / Builders

Tag System
    -> Text System
    -> Preview / Builder Support

Text System
    -> Unit Frame Runtime

GUI Widgets + Layout Helpers
    -> GUI Pages / Builders
```

In practical terms:

- the GUI may configure systems
- the runtime may consume configured systems
- the layout engine should stay generic
- the text system and tag system should remain conceptually separate

## Boundary Rules

- A template is content, not presentation.
- A text element is presentation, not content.
- Inline color tags belong to text content.
- The base text color belongs to the text element.
- Layout metadata belongs to GUI structure, not to runtime frame logic.
- Preview support may simulate output, but it should not become the runtime source of truth.

## Healthy Next Steps

When adding a new feature, first decide which system owns it.

Good examples:

- New tag: Tag System
- New text-template behavior: Text System
- New page arrangement rule: Layout Engine or GUI Layout Helpers
- New configuration page workflow: GUI Page
- New live frame rendering behavior: Unit Frame Runtime

If a change seems to belong to several places at once, that is usually a sign that a boundary needs to be clarified before implementation.
