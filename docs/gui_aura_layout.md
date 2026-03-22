# FocalPoint GUI Aura Layout

## Purpose

This document defines the binding layout rules for the Aura page in FocalPoint.

The Aura page already exists and keeps its current conceptual structure:

- `Buffs`
- `Debuffs`

The goal is not to invent a new page, but to keep the existing controls in a
clean, calm, and repeatable layout that can be maintained later without guesswork.

## Base Layout Rule

Each aura section is a full-width block across the available page width.

Inside each section, controls are arranged in a two-column grid.

The section header row may also include a right-aligned section reset button.

The grid should follow deliberate paired rows:

- no random control flow
- no accidental left-right mixing
- no different visual rhythm between `Buffs` and `Debuffs` unless a tab-specific
  option requires it
- `Enabled` checkboxes are a special case: they stay half-width but occupy their
  own row alone

## Section Header Actions

Aura sections may expose a section-level reset action in the header row.

Rule:

- left side: section title
- right side: section reset button

This section-level reset replaces per-control reset buttons for standard aura
controls in the Aura page.

Exception:

- color pickers keep their own dedicated reset buttons on pages that use them

## Binding Section Order

Each aura tab follows this section order:

1. `General`
2. `Style`
3. `Behavior`
4. placement-dependent closing section

The placement-dependent closing section is:

- `Attached`, if `placement = ATTACHED`
- `Inside`, if `placement = INSIDE`

This keeps the page logic aligned with the user journey:

- first define the aura group itself
- then define its visual form
- then define filtering and behavior
- finally define placement-specific details

## Section Layout Rules

### 1. General

Controls:

- `Enabled`
- `Placement`
- `Icon Size`
- `Icons Per Row`
- `Max Rows`

Row layout:

- Row 1: `Enabled` | empty
- Row 2: `Placement` | `Icon Size`
- Row 3: `Icons Per Row` | `Max Rows`

### 2. Style

Controls:

- `Spacing X`
- `Spacing Y`
- `Growth X`
- `Growth Y`
- `Sort Mode`
- `Stack Font Scale`
- `Timer Font Scale`

Row layout:

- Row 1: `Spacing X` | `Spacing Y`
- Row 2: `Growth X` | `Growth Y`
- Row 3: `Sort Mode` | empty
- Row 4: `Stack Font Scale` | `Timer Font Scale`

Rule:

- geometric and directional controls come before text presentation controls

### 3. Behavior

Shared controls:

- `Show Only Mine`
- `Hide Permanent Auras`
- `Hide Long Auras`
- `Long Aura Threshold`
- `Show Boss Auras`
- `Show Stack Text`
- `Show Timer Text`

Tab-specific controls:

- `Buffs`: `Show Stealable Only`
- `Debuffs`: `Show Dispellable Only`

#### Buffs Row Layout

- Row 1: `Show Only Mine` | `Show Boss Auras`
- Row 2: `Hide Permanent Auras` | `Hide Long Auras`
- Row 3: `Long Aura Threshold` | `Show Stealable Only`
- Row 4: `Show Stack Text` | `Show Timer Text`

#### Debuffs Row Layout

- Row 1: `Show Only Mine` | `Show Boss Auras`
- Row 2: `Hide Permanent Auras` | `Hide Long Auras`
- Row 3: `Long Aura Threshold` | `Show Dispellable Only`
- Row 4: `Show Stack Text` | `Show Timer Text`

Rule:

- `Long Aura Threshold` should only be interactive when `Hide Long Auras` is enabled

### 4. Attached

Visible only when:

- `placement = ATTACHED`

Controls:

- `Anchor To`
- `Point`
- `Relative Point`
- `X Offset`
- `Y Offset`

Row layout:

- Row 1: `Anchor To` | `Point`
- Row 2: `Relative Point` | empty
- Row 3: `X Offset` | `Y Offset`

Rule:

- anchor logic comes before offset adjustment

### 5. Inside

Visible only when:

- `placement = INSIDE`

Controls:

- `Inside Anchor To`
- `Inside Side`

Row layout:

- Row 1: `Inside Anchor To` | `Inside Side`

## Parallelism Between Buffs and Debuffs

`Buffs` and `Debuffs` should remain visually parallel wherever possible.

Allowed difference:

- one tab-specific filter row entry

Not allowed:

- different section order
- arbitrary rearrangement of common controls
- different row rhythm for the same shared options

## Activation And Visibility Rules

These runtime GUI rules are part of the layout contract:

- if the unit is disabled, aura options are disabled
- if the aura group is disabled, nested aura options are disabled
- `Attached` controls are shown only for `ATTACHED`
- `Inside` controls are shown only for `INSIDE`
- `Show Dispellable Only` is not shown on `Buffs`
- `Show Stealable Only` is not shown on `Debuffs`
- `Long Aura Threshold` is disabled when `Hide Long Auras` is not enabled

## Implementation Notes

- reuse the existing builder/section architecture
- keep sections as full-width group boxes
- use layout metadata to force consistent left/right row placement
- prefer section-level reset actions over per-control reset buttons
- do not redesign the page into a different concept
