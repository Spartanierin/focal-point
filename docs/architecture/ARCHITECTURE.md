# FocalPoint Architecture Overview

## Purpose

FocalPoint is designed as a modular unit frame addon with a configuration UI that mirrors the real structure of the addon instead of exposing a flat list of unrelated options.

The intended configuration hierarchy is:

**Unit -> Tab -> Object -> Properties**

Example:

- Unit: `player`
- Tab: `bars`
- Object: `HealthBar`
- Property: `height`

This keeps the GUI scalable, learnable, and easy to localize.

## Navigation Model

The navigation follows an object-oriented structure.

### Top level

- General
- Units
- Text Builder
- Tag Database

### Under General

- General settings
- Profiles
- Themes and workflow-related entry points as they are added
- Quick Start / Quickmode as it is introduced

### Under Units

- Player
- Target
- Target of Target
- Pet
- Focus
- Focus Target
- Boss

Each unit follows the same conceptual structure so the UI stays consistent even when units differ in enabled features.

## Standard Unit Tabs

Each unit page is split into the same high-level tab families:

- Frame
- Bars
- Texts
- Elements
- Visibility

These tabs describe the kind of object being edited, not a random collection of options.

## Tab Responsibilities

### Frame

Contains properties that affect the unit frame as a whole.

Examples:

- enabled
- width / height
- scale
- alpha
- anchor points
- offsets
- frame strata
- frame level

### Bars

Contains bar-like objects for a unit.

Current and planned examples:

- Health Bar
- Power Bar
- Alt Power Bar
- Cast Bar

Bars should follow a similar internal structure whenever possible, for example:

- General
- Size and Position
- Style
- Behavior

### Texts

Contains text elements rendered on a unit.

This tab family is now built around a template-driven text system rather than a fixed list of role-specific text labels.

Examples of current text-bearing concepts:

- name
- health
- power
- level / class / race
- status
- cast texts
- additional custom text elements

Texts are independent information objects. They may be visually attached to bars, but they are not conceptually owned by a bar.

### Elements

Contains graphical objects that are neither bars nor text.

Examples:

- portrait
- raid target icon
- leader icon
- role icon
- combat indicator
- resting indicator
- ready check indicator

### Visibility

Contains state- and context-based visibility logic.

Examples:

- show in solo / party / raid
- combat-only conditions
- target-dependent visibility
- alpha / fade rules

Visibility is treated as logic, not as styling.

## Internal Keys vs Localized Labels

Visible labels and technical identifiers are intentionally separated.

### Internal keys

Internal keys are language-neutral and stable.  
They are used in configuration paths, GUI routing, and code references.

Examples:

- `player`
- `target`
- `Texts`
- `Health`
- `Custom1`
- `Portrait`

These keys must not depend on localized UI strings.

### Localization keys

All visible labels go through locale keys.

Examples:

- `NAV_GENERAL`
- `OPTION_ENABLED`
- `INFO_UNIT_TEXT_TEMPLATE_GROUP`

This keeps the data model stable while still allowing the addon UI to be translated cleanly.

## GUI State and Refresh Model

The configuration UI uses a shared widget state model across standard controls such as:

- checkboxes
- dropdowns
- sliders
- color pickers

Each widget may define:

- `disabled`
- `locked`
- `refreshGUI`

`disabled` and `locked` may be static booleans or functions that are evaluated against current state.

### Widget state refresh

Widgets expose a refreshable state model instead of forcing a full page rebuild every time something changes.

This exists because full GUI rebuilds caused major UX problems during development:

- scroll position resetting
- TreeGroup instability
- sliders losing smooth drag behavior
- unnecessary widget recreation

The rule is:

- **state changes** should refresh visible widget state
- **structural changes** may rebuild the page when needed

## Themes and Quickmode

Themes are intended as product-level presets, not as runtime behavior.

Their role is to provide strong, fast starting points for users who should not
have to build an entire layout from scratch.

Quickmode is intended to sit above themes as a guided entry flow:

- choose a base style
- apply a small number of practical overrides
- keep the resulting profile fully editable

This keeps the addon flexible without forcing every user into an expert-first workflow.

## Section Layout Metadata

FocalPoint's two-column GUI layout now supports small optional metadata on section items.

These fields are interpreted by the shared section layout engine and are fully backward-compatible.
If a layout item does not provide them, the engine keeps the previous alternating left/right behavior.

### Supported fields

- `placement`
  - Optional
  - Supported values:
    - `"left"`
    - `"right"`
    - `"full"`
  - `"full"` forces a full-width row
  - Any other value, or no value, falls back to automatic alternating placement

- `span`
  - Optional
  - Supported values:
    - `1`
    - `2`
  - `2` makes the item render as a full-width row inside the section

- `rowType`
  - Optional
  - Currently supported values:
    - `"default"`
    - `"inline"`
    - `"actions"`
    - `"preview"`
    - `"toolbar"`
  - `actions`, `preview`, and `toolbar` currently default to full-width rows
  - `default` and `inline` keep normal section flow unless `placement` or `span` says otherwise

- `subsection`
  - Optional
  - String label for a lightweight subsection header inside the current section
  - When the subsection value changes, the engine inserts a full-width heading row before the next item

### Usage example

```lua
{ widget = "dropdown", path = ..., placement = "left", rowType = "inline" }
{ widget = "slider", path = ..., placement = "right", rowType = "inline" }
{ widget = "checkbox", path = ..., placement = "full", rowType = "toolbar" }
{ widget = "colorpicker", path = ..., span = 2, rowType = "preview", subsection = "SECTION_COLOR" }
```

### Design intent

This metadata exists to improve local layout structure without introducing page-specific hacks.

It allows a page definition to express:

- forced left/right placement
- full-width rows
- semantic row roles such as toolbars, previews, and action rows
- lightweight subsection grouping semantics without page-specific hacks

The engine remains generic and reusable across pages.

## Refresh Separation

Refresh behavior is intentionally split into separate layers:

- `OptionRefresh.GUI()`  
  Refreshes visible configuration controls

- `OptionRefresh.Live()`  
  Refreshes live unit frames and preview/test state

- `OptionRefresh.All()`  
  Combines both when necessary

This separation prevents GUI interaction problems while still allowing live frame updates.

## Text System

The text system is one of FocalPoint's core architectural features and must be treated as an existing system, not as an experimental side feature.

### Core model

- A unit can have multiple **text elements**
- Each text element is its own text carrier on the unit
- A text element stores presentation data such as:
  - enabled state
  - position
  - anchor target
  - font
  - base color
  - effects such as shadow

The actual text content comes primarily from a **template**.

### Template model

A template is a stored text string that may contain:

- content tags
- inline formatting tags
- inline color tags

Examples:

- `[name]`
- `[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%`
- `[color:blizz_yellow][level][rc] [color:class][class][rc] [race]`

Templates live in `profile.TextTemplates`.

### Template references

A text element uses `templateName` to reference a stored template.

If no template is linked, the text element may fall back to a direct raw tag string in `tag`.

That means:

- `templateName` is the preferred content source
- `tag` is fallback or an expert/special-case path

### Runtime resolution

At runtime the text system resolves:

1. the linked template if `templateName` exists
2. otherwise the direct `tag` string

That resolved string is then evaluated against live unit data and rendered into the frame.

This keeps the separation clear:

- **template** = content
- **text element** = presentation
- **tag resolution** = runtime logic
- **rendering** = visible output

### Color model

The text system distinguishes between global text presentation and inline content formatting.

#### Global text color

The `color` field on a text element is part of the element's presentation.

It defines the base text color for that whole text object.

#### Inline color tags

Inline color tags are part of the content string, for example:

- `[color:class]`
- `[color:blizz_pwr]`
- `[color:reaction]`
- `[color:ffcc00]`
- `[rc]`

These tags affect only segments inside the resolved text string.

#### Reset behavior

Reset tags end inline color control and restore the text element's configured base color.

This is an important rule:

- inline color logic must not replace the text element's global presentation color
- the global presentation color must remain the default state that inline formatting returns to

### Builder and unit-page relationship

The Text Builder is not a second text system.  
It is the authoring and distribution tool for the same template-based text architecture.

Its responsibilities are:

- build and preview templates
- save templates
- show where templates are already used
- apply templates to units

The unit text pages are the presentation editors for individual text elements.

Their responsibilities are:

- choose which template a text element uses
- place the text element
- style the text element
- optionally edit the raw fallback string in Expert Mode

### Current UI direction

The long-term direction is:

- content comes from templates
- units expose text elements instead of hard-coded "health text", "power text", and similar mental models

The current implementation already moves toward this by:

- linking text elements to templates
- showing template-aware tab labels
- hiding empty text elements
- keeping raw tag editing as an expert path instead of the primary workflow

## Portrait as the First Image Element Blueprint

Portrait is the first complete image-based element implemented end-to-end.

It includes:

- defaults in the unit configuration
- dedicated GUI sections
- dependency-aware option handling
- live application in `UnitFrame.lua`
- event-driven refresh logic

This serves as the blueprint for future image-style elements.

## Image Element Placement Model

Image-based elements follow a shared placement model with two modes:

- `INSIDE`
- `ATTACHED`

### INSIDE

An `INSIDE` element reserves space inside the frame.

For portraits this means:

- the portrait remains square
- the frame reserves space visually
- bars shift to make room
- bars do not anchor directly to the portrait

This avoids circular layout dependencies.

### ATTACHED

An `ATTACHED` element does not alter internal layout.  
It anchors freely to a selected target such as:

- `Frame`
- `HealthBar`
- `PowerBar`

## Portrait Element Model

Portrait uses an image-element style data model with fields such as:

- `enabled`
- `placement`
- `mode`
- `size`
- `scale`
- `padding`
- `insideSide`
- `anchorTo`
- `point`
- `relativePoint`
- `offsetX`
- `offsetY`

### Size and scale instead of width and height

Portrait intentionally uses `size` and `scale` instead of separate width and height values.

That keeps the portrait square by design and avoids distortion.

General rule:

- bars may stretch
- image elements should preserve aspect ratio unless intentionally designed otherwise

## Portrait Rendering Strategy

The stable implementation path prioritizes 2D rendering first.

Portrait updates are event-driven rather than relying only on initial frame construction timing.  
This exists because portrait textures could otherwise fail to appear until a later manual refresh.

### 3D mode status

The data model already supports `2D` and `3D`.

At the current stage:

- `2D` is the stable mode
- `3D` is an extension point and should be treated as such until a full model-based path is finished

## Dependency Handling in the GUI

The GUI uses hierarchical dependency logic for option state.

Examples:

- unit disabled -> child options disabled
- portrait disabled -> portrait sub-options disabled
- placement = `INSIDE` -> inside-only options enabled
- placement = `ATTACHED` -> anchor options enabled

The goal is to keep dependency behavior declarative instead of spreading ad hoc conditions across page code.

## Navigation and UI State Persistence

The configuration UI preserves:

- expanded TreeGroup nodes
- selected navigation path
- visible widget state
- scroll position where possible

This is important because FocalPoint is a workflow-heavy UI, and rebuilding too aggressively creates unnecessary friction.

## Practical Stability Exception

There is at least one intentional implementation exception in the GUI:

- the **Units > Frame > Behavior** checkboxes are rendered directly with raw AceGUI `CheckBox` widgets

This exists because earlier wrapper-based implementations caused those controls to disappear in-game even though surrounding content rendered correctly.

So for that block the current rule is:

- prefer direct rendering
- do not abstract it again without re-testing in-game

This is a deliberate stability choice, not unfinished cleanup.
