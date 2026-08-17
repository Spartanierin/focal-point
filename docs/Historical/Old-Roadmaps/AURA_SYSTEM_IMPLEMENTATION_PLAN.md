STATUS: HISTORICAL - completed/old implementation plan; not normative.

# FocalPoint Aura System Implementation Plan

## Purpose

This document translates the aura concept into a concrete implementation plan.
Its job is to answer:

- which modules should exist
- what each module owns
- what should be built first
- where the boundaries are

It is intentionally more technical than `AURA_SYSTEM_CONCEPT.md`.

## V1 Goal

Aura V1 should deliver:

- player buffs
- player debuffs
- target buffs
- target debuffs
- icon rendering
- stack text
- cooldown swipe
- stable event-driven updates
- a small but usable GUI

Buffs and Debuffs are separate runtime blocks.
They should not be treated as one shared aura group with a mode switch.

## Directory Plan

Suggested initial structure:

- `Engine/Auras/Runtime/`
- `Engine/Auras/Layout/`
- `GUI/Layouts/`
- `GUI/Pages/`

## Engine Runtime Modules

### `Engine/Auras/Runtime/AuraRuntime.lua`

**Responsibility**

- public aura runtime facade
- coordinate scan, filter, sort, and render flow
- expose high-level entry points to UnitFrame

**Should own**

- `RefreshAuraGroup(frame, unit, groupKey)`
- `RefreshAuras(frame)`
- `BuildAuraContainers(frame)`
- `RegisterAuraEvents(frame)`

**Should not own**

- low-level widget creation details
- GUI logic

### `Engine/Auras/Runtime/AuraScan.lua`

**Responsibility**

- read raw aura data from the WoW aura API
- normalize raw aura records into FocalPoint aura records

**Should own**

- `CollectUnitAuras(unit, filterMode)`
- `NormalizeAura(rawAura, unit, filterMode)`

**Notes**

- this module should be the only place that directly talks to the raw aura API
- rendering code should never depend on raw aura tuples

### `Engine/Auras/Runtime/AuraFilters.lua`

**Responsibility**

- remove auras that should not be shown

**Should own**

- `ShouldShowAura(aura, config, groupKey, frame)`
- `FilterAuras(auraList, config, groupKey, frame)`

**V1 filters**

- helpful vs harmful
- show only mine
- boss aura option

For V1:

- `mine = player + pet`

### `Engine/Auras/Runtime/AuraSorting.lua`

**Responsibility**

- sort visible auras after filtering

**Should own**

- `SortAuras(auraList, config, groupKey)`

**V1 sorting choices**

- newest first
- oldest first
- shortest remaining first

Timed auras should sort before permanent auras in the default V1 behavior.

### `Engine/Auras/Runtime/AuraEvents.lua`

**Responsibility**

- register aura-related events for the frame
- trigger runtime refreshes

**Should own**

- event registration frame
- routing event updates back into `AuraRuntime`

**Expected V1 events**

- `PLAYER_ENTERING_WORLD`
- `UNIT_AURA`
- `PLAYER_TARGET_CHANGED`
- optional unit-specific events if needed during testing

### `Engine/Auras/Runtime/AuraCache.lua`

**Responsibility**

- store last known visible aura state per frame and group
- avoid unnecessary rebuilds

**Should own**

- cached aura keys per group
- simple diff checks if needed later

**V1 note**

- this may start small
- a minimal cache is enough at first

## Engine Layout Modules

### `Engine/Auras/Layout/AuraContainer.lua`

**Responsibility**

- create one reusable aura widget

**Container parts**

- icon texture
- stack text
- cooldown frame / swipe
- optional border/highlight frame

**Recommended V1 internal anchors**

- stack text: bottom-right

V1 should prioritize fast visual readability:

- duration shown via cooldown swipe
- no timer text in the default V1 aura container

**Should own**

- `CreateAuraContainer(parent)`
- `ApplyAuraContainerLayout(container, config)`
- `ApplyAuraData(container, aura, config)`
- `ClearAuraContainer(container)`

### `Engine/Auras/Layout/AuraRenderer.lua`

**Responsibility**

- map prepared aura records onto visible aura containers

**Should own**

- container reuse
- show/hide active containers
- call container update methods

**Should not own**

- aura API reading
- GUI settings

### `Engine/Auras/Layout/AuraBlockLayout.lua`

**Responsibility**

- outer layout of aura containers as a block

**Should own**

- row calculation
- icons-per-row handling
- spacing
- growth direction
- block width and height
- host reserve reporting

**Important**

- this module should follow the same design principles as the inside-lane logic
- but it should implement a grid, not a lane
- Buffs and Debuffs should each use their own block instance

**Grid responsibilities**

- fill containers across one row according to `growthX`
- start new rows according to `growthY`
- respect `iconsPerRow`
- respect `maxRows`
- calculate final block width and height
- report host reservation for `INSIDE`

### `Engine/Auras/Layout/AuraAnchor.lua`

**Responsibility**

- resolve where aura groups attach

**Should own**

- anchor target lookup
- anchor point resolution
- offsets

**V1 targets**

- `Frame`
- `HealthBar`
- `PowerBar`

## UnitFrame Integration

### `Engine/UnitFrame.lua`

UnitFrame should only orchestrate aura integration.

It should eventually:

- create aura runtime/build hooks during frame build
- trigger aura refresh during normal frame refresh
- not own aura scanning logic

Suggested integration points:

- `Build(...)`
- `Refresh(...)`
- `ApplyConfig(...)`

But only as orchestration calls such as:

- `UF:BuildAuraElements(frame)`
- `UF:RefreshAuras(frame)`
- `UF:RegisterAuraEvents(frame)`

## GUI Modules

### `GUI/Layouts/UnitAuraDefinition.lua`

**Responsibility**

- define generic Buff/Debuff option layouts

**V1 controls**

- enabled
- anchor target
- anchor point
- relative point
- offset X
- offset Y
- icon size
- spacing
- icons per row
- max rows
- growth X
- growth Y
- show only mine
- show stack text

### `GUI/Pages/UnitAurasPage.lua`

**Responsibility**

- build the Buffs/Debuffs page for a unit

**Suggested structure**

- Buffs section
- Debuffs section

These sections should stay separate rather than being merged into one shared aura settings block.

### Localization

Expected locale additions:

- aura section names
- sorting labels
- filter labels
- timer/stack options
- anchor/growth labels if new values are introduced

## Data Defaults

### `Data/Defaults.lua`

Recommended V1 default structure per unit:

- `Buffs`
- `Debuffs`

Each with fields such as:

- `enabled`
- `placement`
- `anchorTo`
- `point`
- `relativePoint`
- `offsetX`
- `offsetY`
- `insideAnchorTo`
- `insideSide`
- `iconSize`
- `spacingX`
- `spacingY`
- `iconsPerRow`
- `maxRows`
- `growthX`
- `growthY`
- `showOnlyMine`
- `showTimerText`
- `showStackText`
- `showBossAuras`
- `sortMode`

## Suggested V1 Config Shape

Example:

```lua
Buffs = {
    enabled = true,
    placement = "ATTACHED",
    anchorTo = "Frame",
    point = "TOPLEFT",
    relativePoint = "TOPLEFT",
    offsetX = 0,
    offsetY = 0,
    insideAnchorTo = "Frame",
    insideSide = "RIGHT",
    iconSize = 30,
    spacingX = 3,
    spacingY = 3,
    iconsPerRow = 5,
    maxRows = 0,
    growthX = "RIGHT",
    growthY = "DOWN",
    showOnlyMine = false,
    showTimerText = true,
    showStackText = true,
    showBossAuras = true,
    sortMode = "TIME_REMAINING_ASC",
}
```

## Build Order

Recommended implementation order:

1. `AuraScan.lua`
2. `AuraFilters.lua`
3. `AuraSorting.lua`
4. `AuraContainer.lua`
5. `AuraRenderer.lua`
6. `AuraBlockLayout.lua`
7. `AuraRuntime.lua`
8. `AuraEvents.lua`
9. UnitFrame integration
10. GUI layouts and page

## Recommended V1 Defaults

For both `player` and `target`:

- Buffs
  - `placement = ATTACHED`
  - `anchorTo = Frame`
  - `point = TOPLEFT`
  - `relativePoint = TOPLEFT`
  - `growthX = RIGHT`
  - `growthY = DOWN`
- Debuffs
  - `placement = ATTACHED`
  - `anchorTo = Frame`
  - `point = TOPRIGHT`
  - `relativePoint = TOPRIGHT`
  - `growthX = LEFT`
  - `growthY = DOWN`

Shared defaults:

- `iconSize = 30`
- `iconsPerRow = 5`
- `maxRows = 0`
- `spacingX = 3`
- `spacingY = 3`

V1 should target both:

- `player`
- `target`

## Grid Rules

For each block:

1. visible aura containers are filled along `growthX`
2. when `iconsPerRow` is reached, a new row starts
3. the new row is placed according to `growthY`
4. this continues until all visible auras are placed or `maxRows` is reached

This means the renderer should think in:

- `column`
- `row`

not in a single linear lane index.

## Placement Rules

### `INSIDE`

The aura block is part of host geometry.

If the block is anchored to:

- `LEFT` or `RIGHT`
  - host reserve = `blockWidth`
- `TOP` or `BOTTOM`
  - host reserve = `blockHeight`

This reserve should be exact.
Additional spacing should come from config values, not hidden automatic padding.

### `ATTACHED`

The aura block is outside host geometry.

In this mode:

- no host reserve is reported
- the block is positioned via normal anchor points and offsets

## Recommended First Vertical Slice

The smallest meaningful first slice should be:

- player buffs only
- one block
- icon only
- no stack text at first
- swipe-based duration only
- stable refresh via events

Then expand in this order:

1. player debuffs
2. target buffs
3. target debuffs
4. stack text
5. optional timer text
6. sorting options
7. GUI

Important:

- even this first slice should already use the block concept
- it should not be built as a special-case one-row implementation

## Row Limit Rule

`maxRows` should use this semantic:

- `0`
  - unlimited
- `> 0`
  - hard limit

Recommended V1 default:

- `maxRows = 0`

The system should prefer filtering and sorting for visibility control.
Small default row caps should not hide auras unexpectedly.

This keeps risk low and gives visible progress quickly.

## Testing Plan

### Runtime tests

- player gains and loses buffs
- player gains and loses debuffs
- target changes with active buffs/debuffs
- short-duration aura expiration
- stack count updates
- permanent aura ordering after timed auras
- show-only-mine with player and pet sources

### Layout tests

- one icon
- multiple icons in one row
- row wrap
- max row limit
- unlimited rows (`maxRows = 0`)
- growth direction changes
- anchor target changes

### Stability tests

- target switching in combat
- test mode compatibility
- frame refresh interactions
- no lingering aura containers after hidden states
- preview of multi-row timed and stacked aura blocks

## Explicit V1 Boundaries

Do not include in the first implementation pass:

- whitelist UI
- blacklist UI
- class preset rule packs
- priority editor
- boss/focus/pet rollout
- complex dispel/steal priority visuals

## Future Extraction Opportunity

If the aura block engine and inside-lane engine converge enough, a later shared module
could be introduced, for example:

- `Engine/Layout/VisualContainerBlock.lua`

This should only happen after Aura V1 proves the real shared surface area.
It should not be forced too early.

## Working Rule

Before implementation begins for a new aura behavior, the expected result must be
expressed precisely enough to answer:

- what is the host area
- what is the block order
- what is the growth direction
- what reserves space
- what is only visual and what affects geometry

If those points are not clear, implementation should pause and be clarified first.

