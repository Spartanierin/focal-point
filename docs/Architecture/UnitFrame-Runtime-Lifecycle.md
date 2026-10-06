# UnitFrame Runtime Lifecycle

STATUS: CURRENT - canonical build, apply, refresh, visibility, and cleanup lifecycle.

## Main modules

- `Engine/UnitFrame.lua`: activation, resync, component application, and
  runtime-root consumption.
- `Engine/UnitFrame/Runtime/UnitFrameFactory.lua`: frame/component creation.
- `Engine/UnitFrame/Runtime/UnitFrameBuild.lua`: build orchestration.
- `Engine/UnitFrame/Runtime/UnitFrameLayout.lua` and
  `UnitFrameInsideLayout.lua`: geometry and inside-component layout.
- `Engine/UnitFrame/Runtime/UnitFrameRefresh.lua`: refresh dispatch.
- `Engine/UnitFrame/Runtime/UnitFrameVisibility.lua`: visibility and suppression.
- `Engine/UnitFrame/Runtime/UnitFrameState.lua`: runtime state.
- `Engine/UnitFrame/Shared/UnitFramePresence.lua`: live/demo/unlock presence.
- `Engine/UnitFrame/Shared/UnitFrameUnitWatchPolicy.lua`: unit-watch policy.

## Activation boundary

`ActiveLayoutResolver` builds a `RuntimeRoot` from the stored `activeLayoutId`.
`FocalPoint:ActivateLayout` resolves the target root, checks GUI/combat guards,
publishes the character selection and root, runs `ResyncActiveLayout`, and
restores the previous selection/root if publication or resync fails.

The runtime must consume the published root. It must not independently resolve
another layout from labels, profiles, Account Default, or editor state.

## Build and apply

1. Build creates the unit frame and its component owners.
2. The factory creates bars, text, auras, indicators, portraits, and
   decorations according to presence and configuration.
3. Apply reads layout configuration and applies geometry, style, anchors, and
   text bindings.
4. Runtime refresh populates values and visibility without becoming a second
   configuration source.

## Refresh and visibility

Health, Power, Cast, Absorb, Aura, text, range, and visibility refreshes are
separate concerns. A refresh must update the owned runtime object and clear
stale values when its source disappears.

Unit-watch and presence rules cover target, focus, targettarget, boss, pet,
combat, vehicle/override, and demo/unlock cases. Pet Battle suppression and
other hard suppression must remain explicit policy decisions.

## Combat and deferred work

Structural activation and protected-frame operations honor combat lockdown. A
requested layout switch may remain pending and is replayed through the existing
activation path after combat. No timer or retry loop is a substitute for a
deterministic lifecycle contract.

## Demo and editor

Demo uses explicit preview values and artificial presence. Unlock makes frames
available for editing even when live units are absent. Both paths share the
same conceptual geometry and clear/rebuild rules, while neither changes
persisted layout truth.

## Clear and release

Clear paths must remove runtime values, visual artifacts, event bindings, and
owned child state. This is especially important for `LiveValues`, aura groups,
text objects, managed containers, and visibility alpha. Rebuild/release cycles
must not retain stale selection, anchors, or pooled widget state.

## New visual component checklist

Before adding a component, verify all of the following:

1. persisted presence/configuration and default/migration behavior;
2. Inspector section, mutation API, validation, and smallest refresh scope;
3. Canvas selection/preview and `EditorVisualPolicy` behavior;
4. runtime factory ownership and geometry/anchor contract;
5. LiveValues/text dependencies, if any;
6. live, demo, unlock, unit-watch, combat, and post-combat behavior;
7. clear/release/pooling and repeated rebuild behavior;
8. import/export and migration boundaries;
9. focused automated tests plus the established regression suites.

The component is not complete when only its visible frame exists; it must be
integrated across these boundaries.
