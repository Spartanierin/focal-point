STATUS: CURRENT / PARTIAL - still-relevant aura principles; not a complete runtime document.

# FocalPoint Aura System Concept

## Purpose

This document defines the conceptual foundation for FocalPoint's future aura system.
It exists to prevent implementation drift and to keep the work aligned with the
same modular direction already used for UnitFrame and Text.

The aura system is intended to become the third major runtime pillar of the addon:

- UnitFrame
- Text
- Auras

## Core Idea

FocalPoint should not treat aura icons as a special one-off feature.
Instead, it should treat them as a generalized container problem:

- a lane or grid places containers
- each container has a known size
- the host area makes room for the container block
- the container itself decides how to render its internal content

This is the same architectural idea already used for inside image elements.

## Shared Container Model

### Overlay containers

Current inside elements are effectively lightweight containers:

- raid target icon
- leader icon
- role icon
- combat indicator
- resting indicator
- ready check indicator

Their content is currently simple:

- one image

### Aura containers

A future aura should use the same outer layout concept, but a richer container:

- icon
- optional stack text
- optional timer text
- optional border / highlight / state mark

This means:

- overlays and auras should share outer block logic
- but they may use different inner rendering logic

## Architectural Goal

FocalPoint should end up with:

1. one shared layout/block engine for visual containers
2. one overlay-container implementation
3. one aura-container implementation

The layout engine should not care whether the container shows:

- only an image
- an image and timer
- an image and stack count
- an image, timer, stack, and border

It should only care about:

- visibility
- size
- order
- spacing
- growth direction
- final block size

## Outer Layout Responsibilities

The outer layout system should be responsible for:

- collecting visible containers
- sorting containers
- grouping them into lanes or grids
- calculating block width and height
- reporting how much room the host must reserve
- placing the containers in final order

The outer layout system should not know:

- how aura timers are formatted
- how stack text is generated
- aura filtering rules
- spell-specific visual logic

## Inner Container Responsibilities

The container renderer should be responsible for:

- creating internal child regions
- assigning textures
- assigning stack text
- assigning timer text
- applying aura border state
- handling its own cooldown/timer visual state

The container renderer should not decide:

- where the block starts
- how much the host frame must shrink
- how neighboring containers are arranged

## Aura Data Model

Each aura should be normalized into a simple runtime object.

Suggested minimum fields:

- `spellId`
- `name`
- `icon`
- `count`
- `duration`
- `expirationTime`
- `sourceUnit`
- `isHelpful`
- `isHarmful`
- `isBossAura`
- `isStealable`
- `dispelName`
- `canApplyAura`
- `isPlayerCast`

Optional derived fields:

- `remaining`
- `priority`
- `sortKey`

The runtime should prefer a normalized, display-oriented aura record rather than
letting rendering code talk directly to the raw aura API.

## Aura Runtime Responsibilities

The runtime layer should:

- listen for aura-related events
- scan and normalize active auras
- cache current aura state per unit
- decide which auras are visible after filters are applied
- pass display-ready aura records to the renderer

The runtime should not:

- build GUI widgets
- decide page layout
- own unit frame geometry directly

### Time classification

Aura timing is documented separately in
[AURA_TIME_CLASSIFICATION.md](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/docs/AURA_TIME_CLASSIFICATION.md).

That document explains:

- which Blizzard fields are evaluated
- how `durationObject` is interpreted
- how FocalPoint distinguishes `TIMED`, `PERMANENT`, `PENDING`, and `UNRESOLVED`

## Initial Supported Units

Phase 1 should intentionally stay small.

Recommended first units:

- player
- target

Optional later expansion:

- focus
- pet
- boss
- targettarget
- focustarget

## Display Groups

Aura display should be split into conceptual groups:

- Buffs
- Debuffs

Each group should be independently configurable per unit.

Buffs and Debuffs are not two views of the same block.
They are two separate aura blocks.

Each block may have its own:

- placement
- anchor target
- anchor points
- offsets
- icon size
- spacing
- fill direction
- row direction
- sorting
- filtering

This allows:

- target debuffs only
- player buffs and debuffs
- buffs above / debuffs below
- independent sizing and spacing

It also allows intentionally mirrored layouts, for example:

- buffs filling left to right
- debuffs filling right to left
- buffs growing downward
- debuffs growing upward

### Recommended V1 default placement

For both `player` and `target`:

- Buffs should default to the top-left side of the frame
- Debuffs should default to the top-right side of the frame
- both blocks should be mirrored against each other
- both blocks should be attached to the frame by default

## Layout Modes

Overlay indicators and auras should not be treated as the same layout shape.

### Overlay indicators

Inside image elements such as leader, resting, and raid target icons are primarily
lane-based:

- few elements
- one-dimensional order
- simple neighbor placement

### Aura blocks

Auras should use a grid-based block:

- multiple rows
- multiple columns
- row wrapping
- separate horizontal and vertical growth control

Aura V1 should therefore treat Buffs and Debuffs as grid blocks, not as lanes.

## Aura Grid Model

Each aura block should be placed as a 2D grid.

The block is filled in this order:

1. fill one row along `growthX`
2. when the row reaches `iconsPerRow`, start a new row along `growthY`
3. continue until no more visible auras remain or `maxRows` is reached

This means every block has:

- a primary fill direction
- a secondary row direction
- a finite row width

### Required block settings

- `iconSize`
- `spacingX`
- `spacingY`
- `iconsPerRow`
- `maxRows`
- `growthX`
- `growthY`

### Row limit semantics

`maxRows` should support an explicit unlimited mode:

- `maxRows = 0`
  - unlimited rows
- `maxRows > 0`
  - hard row limit

Aura V1 should use unlimited rows as the default behavior.
Filtering and sorting should be the preferred way to reduce clutter, not a low
hard-coded row cap.

Recommended V1 defaults:

- `iconSize = 30`
- `iconsPerRow = 5`

### Block size

Given:

- `visibleCount`
- `iconsPerRow`
- `iconSize`
- `spacingX`
- `spacingY`

The block should calculate:

- `columns = min(visibleCount, iconsPerRow)`
- `rows = ceil(visibleCount / iconsPerRow)`

Then:

- `blockWidth = columns * iconSize + (columns - 1) * spacingX`
- `blockHeight = rows * iconSize + (rows - 1) * spacingY`

This block size is what host-reservation logic must work from.

## Anchor Model

Aura groups should anchor to stable host areas, not to ad hoc offsets.

Suggested initial anchor targets:

- `Frame`
- `HealthBar`
- `PowerBar`

Suggested anchor points:

- `TOP`
- `BOTTOM`
- `LEFT`
- `RIGHT`
- corner variants where useful

The block engine should then calculate:

- starting point
- block growth
- total reserved area

## Placement Modes

Each aura block should support two placement modes:

- `INSIDE`
- `ATTACHED`

### `INSIDE`

The aura block lives inside the chosen host area:

- `Frame`
- `HealthBar`
- `PowerBar`

The host area must make room for the aura block.

Reserve behavior depends on the block side:

- `LEFT` or `RIGHT`
  - reserve block width
- `TOP` or `BOTTOM`
  - reserve block height

### `ATTACHED`

The aura block is anchored outside the host area.

In this mode:

- the host does not reserve internal space
- the block behaves like an attached external object
- geometry stays outside the host's internal layout

This distinction must stay explicit in both code and GUI.

### Inside reserve sizing

For V1:

- `LEFT` or `RIGHT` reserve exactly `blockWidth`
- `TOP` or `BOTTOM` reserve exactly `blockHeight`

Any additional visual spacing should come from config values, not from hidden
automatic padding in reserve math.

## Sorting Model

Sorting must be explicit, even if V1 only exposes a small subset.

Recommended internal support from the start:

- by time remaining
- by applied order
- by player-cast first
- by priority flag

Recommended V1 exposed sorting:

- newest first
- oldest first
- shortest remaining first

## Filtering Model

V1 should stay intentionally small but correct.

Recommended V1 filters:

- helpful vs harmful
- show only mine
- show boss auras

Recommended later filters:

- dispellable only
- stealable only
- whitelist / blacklist
- class- or role-specific rules

## Visual States

Aura containers should support clear internal visual states.

Potential states:

- normal
- expiring soon
- boss aura
- stealable
- dispellable
- player-cast

V1 does not need every state, but the structure should allow them without
rewriting the container model.

## Timer Handling

Auras should prioritize fast visual readability.
Timer handling should therefore default to a swipe-based duration display in V1,
not to text.

Meaning:

- the outer block reserves space for the full container
- swipe state updates inside the container
- the block size does not reflow on every timer tick

This is important for stable, non-jittering aura rows.

### Recommended V1 timer/count placement

For V1, the aura container should follow a Blizzard-adjacent visual pattern:

- stack count in the bottom-right corner
- duration shown via cooldown swipe

Timer text should not be part of the default V1 container.
It may become an optional later feature, but not part of the initial visual model.

## Stack Handling

Stack counts should behave like timer text:

- rendered inside the container
- no outer layout change on each count update

The container should own:

- font size
- anchor within the icon
- visibility threshold, if any

## Timed vs Permanent Auras

Timed and permanent auras should sort predictably.

Recommended V1 behavior:

- timed auras first
- permanent auras after timed auras

This should remain configurable later, but V1 should use this order by default.

## Ownership Rule For `showOnlyMine`

`showOnlyMine` should not mean strictly "cast by the player character only".

Recommended V1 interpretation:

- player-cast auras count as mine
- pet-cast auras count as mine

Potential later extensions may include vehicle handling if needed, but V1 should
standardize on:

- `mine = player + pet`

## Boss Aura Rule

`showBossAuras` should work as an additional include rule.

Meaning:

- boss auras may be forced visible even if other normal visibility filters would
  otherwise hide them
- this rule should not redefine the normal helpful/harmful group separation

## Shared Future With Inside Elements

The long-term goal is not to delete the current inside image-element logic,
but to align it with the same model:

- overlay container = image-only container
- aura container = image + text container

## Test Mode Requirement

Aura development should include explicit preview/test-mode support from the start.

The preview path should be able to simulate:

- multiple buffs
- multiple debuffs
- timed and permanent auras
- stack counts
- mixed block sizes across several rows

This is required to make layout debugging practical before full live testing.

This allows a shared block engine while preserving separate feature modules.

## Proposed Module Structure

Suggested future files:

- `Engine/Auras/Runtime/AuraRuntime.lua`
- `Engine/Auras/Runtime/AuraFilters.lua`
- `Engine/Auras/Runtime/AuraSorting.lua`
- `Engine/Auras/Runtime/AuraEvents.lua`
- `Engine/Auras/Layout/AuraBlockLayout.lua`
- `Engine/Auras/Layout/AuraContainer.lua`
- `Engine/Auras/Layout/AuraRenderer.lua`

Potential shared layout extraction later:

- `Engine/Layout/VisualContainerBlock.lua`

That extraction should happen only if it truly simplifies both systems.
It does not need to be done before Aura V1.

## GUI Concept

Each unit should get an Aura page or tab group.

Suggested first structure:

- Buffs
- Debuffs

Each group should expose only core V1 controls:

- enabled
- anchor target
- anchor point
- offset X / Y
- icon size
- spacing
- icons per row
- max rows
- growth direction
- show only mine
- show timer text
- show stack text

Later additions:

- boss only
- stealable / dispellable filters
- sorting
- whitelist / blacklist
- priority rules

## V1 Scope

Aura V1 is done when:

- player buffs work
- player debuffs work
- target buffs work
- target debuffs work
- icon rows are stable
- stack text works
- timer text works
- target changes update correctly
- no visible layout jitter occurs

## Explicit Non-Goals For V1

Do not include these in the first implementation block:

- whitelist / blacklist editor
- advanced priority system
- per-class preset aura rules
- multi-unit rollout beyond player and target
- highly custom border-rule engines

## Implementation Phases

### Phase 1: Data pipeline

- normalize aura records
- build event-driven refresh
- cache visible aura state per unit

### Phase 2: Aura container

- create reusable aura widget
- icon + stack + timer
- stable internal anchors

### Phase 3: Block layout

- row layout for containers
- reserve calculation
- anchor integration with unit frame

### Phase 4: GUI

- add Buffs / Debuffs config for player and target

### Phase 5: Polish

- visual tuning
- edge cases
- combat and target-change testing

## Design Rule For Future Work

If a planned aura feature is not precise enough, implementation should pause
until the desired behavior is specified clearly.

Especially for:

- sorting priority
- growth direction
- host-area reservation
- timer visibility rules
- stack visibility rules
- anchor semantics

This rule exists to avoid repeating the ambiguity problems that appeared during
the inside-lane work.

