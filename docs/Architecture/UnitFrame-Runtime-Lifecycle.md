# UnitFrame Runtime Lifecycle

STATUS: CURRENT - current build, apply, refresh, and visibility lifecycle.

## Purpose

This document describes how configured unit frames are built, updated, kept visible, and handled in the editor.

## Main modules

- `Engine/Core.lua`: addon orchestration, unlock, dragging, selection, position save/apply.
- `Engine/UnitFrame.lua`: central UnitFrame orchestrator, ApplyConfig, component integration, text application.
- `Engine/UnitFrame/Runtime/UnitFrameFactory.lua`: frame and component creation.
- `Engine/UnitFrame/Runtime/UnitFrameBuild.lua`: build steps.
- `Engine/UnitFrame/Runtime/UnitFrameRefresh.lua`: refresh flows.
- `Engine/UnitFrame/Runtime/UnitFrameVisibility.lua`: visibility and suppression.
- `Engine/UnitFrame/Runtime/UnitFrameState.lua`: runtime state.
- `Engine/UnitFrame/Shared/UnitFramePresence.lua`: existence/preview/demo presence.
- `Engine/UnitFrame/Shared/UnitFrameDemoEnvironment.lua`: demo/unlock data and placeholders.
- `Engine/UnitFrame/Shared/UnitFrameUnitWatchPolicy.lua`: UnitWatch rules.

## Build / Factory / Apply

1. Spawn/build creates the frame for a unit.
2. Factory creates components such as bars, text, auras, indicators, and decorations.
3. `ApplyConfig` reads unit configuration and applies layout, style, components, and text placement.
4. Components remain owned by UnitFrame runtime. UI writes configuration, not runtime objects directly.

## Refresh

Refresh updates runtime data and visible output:

- Health/Power/Cast update LiveValues and bars.
- Auras update managed or demo/legacy renderers.
- Text uses prepared values from LiveValues and template resolvers.
- Range/alpha/visibility are handled separately.

## Visibility and Presence

A configured unit must not disappear when product logic says it should be visible. Critical cases:

- `target` after target changes.
- `focus` and `focustarget`.
- `targettarget`.
- `boss`/`boss1..boss5`.
- Combat transitions.
- Demo/Unlock with disabled or currently non-existing live units.

Pet Battle may remain suppressing. Vehicle/override states must not globally hard-suppress player frames unless there is an explicit product reason.

## Combat and recovery

Combat stability is a core quality. Structural operations must respect combat rules. After combat, resync/refresh paths are required so stale frames, auras, or text do not remain visible.

## Demo and Unlock

- Demo provides artificial data for design work.
- Unlock makes frames visible and movable, even for disabled or currently non-existing units.
- Neither replaces canonical configuration truth.
- Visual rules should use the same conceptual geometry as live, even when data sources differ.

## Clear / cleanup

Clear paths must remove runtime values and visible artifacts consistently. LiveValues for the Health Family, auras, and text display are especially critical because stale values can otherwise remain visible or affect color.

## Health / Power / Cast / Auras

These subsystems have their own module groups or detail documents. For lifecycle purposes, the key points are:

- They are created by UnitFrame build.
- `ApplyConfig` sets layout/style.
- Runtime refresh writes values.
- Text and visuals consume prepared runtime values.

## Canonical rule

Configuration comes from the profile, runtime values come from runtime modules, and visuals consume both. No visible element should create a second truth.
