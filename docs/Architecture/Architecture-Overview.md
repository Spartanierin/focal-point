# Architecture Overview

STATUS: CURRENT - canonical system map for Focal Point 2.2.x.

## Product boundary

Focal Point exposes editable and read-only layouts. The runtime applies one
resolved layout to unit frames. Profiles, presets, and legacy theme names may
remain in storage or migration code, but they are compatibility inputs rather
than a second current product model.

## Bootstrap and load order

- `FocalPoint.toc` declares the supported Retail and Forever interface IDs and
  loads `Libraries/Init.xml` and `Init.xml`.
- `FocalPoint.lua` owns addon initialization, AceDB/SavedVariables setup,
  startup diagnostics, and lifecycle entry points.
- `Init.xml` loads layout services before runtime and GUI consumers, then loads
  text, aura, unit-frame, and editor modules in dependency order.

## Layout data flow

1. AceDB provides the persisted store and current character context.
2. `UserLayoutStore` owns user-layout records.
3. `LayoutService` projects built-in and user sources into layout envelopes or
   lightweight summaries.
4. `ActiveLayoutResolver` resolves `activeLayoutId` and builds the
   materialized `RuntimeRoot`.
5. `FocalPoint:ActivateLayout` publishes the root and runs the normal resync
   path atomically with rollback on failure.
6. Unit-frame build, layout, visibility, and refresh consume that root.

`activeLayoutId` is the persisted selection of the applied layout. `RuntimeRoot`
is the materialized runtime truth. `ActiveRuntimeRootReads` and resolver read
APIs are read-only; they do not activate layouts or mutate character intent.

## Assignment flow

`LayoutAssignmentService` owns selection rules:

- specialization assignments are character-scoped and may win at login or
  specialization change;
- Account Default is an optional global layout reference;
- if no valid specialization assignment exists, login may use Account Default;
- otherwise the existing active-layout initialization fallback remains in use.

Assignment evaluation delegates activation to the normal `ActivateLayout` path.
It respects stale references, combat deferral, dirty Text Builder drafts, and
existing activation guards. It does not mass-mutate characters.

## Layout mutations and transfer

- `LayoutMutations` owns create, rename, copy, delete, and related layout
  changes.
- `LayoutTransfer` is the public transfer boundary.
- `LayoutTransferVNext` carries the current entity-aware layout document and
  reachable template resources.
- `LayoutTransferCodec` bounds and serializes transfer envelopes.
- legacy transfer conversion is explicit and fail-closed; it never guesses a
  layout from names or reconstructs missing resources.

Account Default and other local account preferences are deliberately outside
the exported layout payload.

## Runtime areas

- `Engine/UnitFrame.lua` coordinates activation, resync, component application,
  and runtime-root consumption.
- `Engine/UnitFrame/Runtime/*` owns build, factory, layout, refresh, state,
  visibility, and lifecycle diagnostics.
- `Engine/UnitFrame/Bars/*` owns Health, Power, Absorb, Class Power, and Cast
  Bar behavior.
- `Engine/TextElements.lua` and `Engine/Text/*` own text application,
  prepared values, template resolution, and entity mutations.
- `Engine/Auras/*` owns aura scanning, filtering, sorting, layout, and the
  Managed Aura backend.

## GUI areas

- `GUI/Editor/*` contains Canvas editing, Composition Tree, Toolbar, Inspector,
  Layout Manager, assignment UI, media pickers, and text library windows.
- `GUI/Pages/TextBuilder/*` contains the draft/consumer workflow.
- `GUI/Pages/TagLibrary/*` contains the tag reference workflow.
- `GUI/Editor/TextTemplateLibraryWindow.lua` is the Texts Manager and template
  picker entry point.

The GUI writes through mutation/services and requests the existing refresh
paths. It does not create a parallel runtime root, resolver, or persistence
model.

## Canonical invariants

- configuration comes from the selected layout;
- `activeLayoutId` identifies the applied layout;
- `RuntimeRoot` is the materialized runtime truth;
- Account Default is a selection rule, not a layout kind;
- Current RuntimeRoot reads remain read-only;
- runtime values are prepared before text/tag rendering;
- failed activation, transfer, and migration paths fail closed without partial
  publication.
