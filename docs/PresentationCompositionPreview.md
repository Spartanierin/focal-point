# Inspector Section Composition Preview — Block A

Internal experimental runtime, public as `FocalPoint.PresentationCompositionPreview`
on the AceAddon object. Call with a dot. No DevTool UI is included.

## Contract

API version 1; experimental descriptor version 0. Only `inspector_section` is
supported. State is RAM-only and disappears on reload. No product/profile/layout
data or SavedVariables are involved. There is one composition for all Inspector
section surfaces registered through `InspectorBinding.ApplyInspectorSectionStructure`.
External InteractiveLabel toggle headers and unframed groups are not included.

`GetCapabilities()` returns detached type/property lists and numeric limits.
`GetTextureOptions()` returns detached IDs/labels, never editable paths.
`GetComposition(target)` returns a detached descriptor, or nil when inactive;
an unknown target returns `nil, "unknown_target"`.

```lua
{
  version = 0,
  target = "inspector_section",
  layers = {
    { id = "layer_1", type = "surface", color = { 1, 1, 1 }, alpha = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 } },
  },
}
```

Array order is back to front. Session IDs are generated monotonically by FP and
survive reorder; deletion/reset does not recycle IDs. At most 10 layers.
Inputs accept only the listed fields with finite numbers, plain RGB arrays and
plain four-key inset tables. IDs and types cannot be edited. No functions,
metatables, cyclic structures, frame references or arbitrary paths are admitted.

| Call | Result / semantics |
| --- | --- |
| `AddLayer(target, type, initial?)` | `true, layerId`; optional initial properties overlay FP defaults; activates mode |
| `RemoveLayer(target, layerId)` | `true`; removing the last layer keeps mode active |
| `UpdateLayer(target, layerId, property, value)` | `true`; replaces one property, including a complete RGB/insets table |
| `MoveLayer(target, layerId, directionOrIndex)` | `true`; `up` moves toward the front, `down` toward the back, or use a 1-based index; boundary moves are no-ops |
| `ClearComposition(target)` | `true`; activates/retains mode with an empty list and neutralized baseline |
| `ResetComposition(target)` | `true`; removes descriptor, neutralizes own regions, restores current canonical presentation; inactive reset is a no-op |

Rejected writes return `false, reason` before changing the descriptor, IDs or
rendered owners. Reasons: `combat`, `unknown_target`, `unknown_type`,
`invalid_initial`, `invalid_property`, `layer_limit`, `unknown_layer`,
`invalid_position`, `section_color_preview_active`.

## Primitives and bounds

| Type | Properties / defaults |
| --- | --- |
| Surface | RGB white, alpha 1, four zero insets |
| Line | RGB white, alpha 1, edge top, inward offset 0, thickness 1 |
| Texture | textureId parchment, RGB white tint, alpha 1, four zero insets, mode stretch |

RGB/alpha: 0..1. Insets and inward offset: 0..8 UI units. Thickness: 1..4.
Insets are additional to the existing resolver's visible `surfaceInsets`, not
content padding. Lines stay inside the selected edge; negative offsets are invalid.
No free XY, size, frame level, overlay, tiling or blend-mode properties.

The supported native InlineGroup has a minimum auto-layout height of 40
(`LayoutFinished`: content height + 40). Inspector width is currently 315 before
its existing shell/content insets; it is not resized by this runtime. A deliberately
smaller 40 x 40 section is tested with the current 6px horizontal presentation
insets and all four composer insets at 8: 12 x 24 positive inner surface remains.
This is a bounded Inspector pilot, not a guarantee for arbitrary tiny frames or
future unbounded canonical surface insets. Verify the actual smallest sections
in game; changes to these owner contracts require reevaluating the limits.

Regions anchor directly to `section.frame` and follow its bounds without timers,
size callbacks or layout mutations. No new host Frame, clipping or scroll system.
All slots use BACKGROUND and distinct sublevels -8..1; title/content remain in
their existing layers/hierarchy. Native clipping/draw order require client testing.

Texture IDs are `parchment` (existing `Media/Textures/fp_window_background.jpg`,
also used by Manage Layouts) and `blizzard` (`Media/Textures/BetterBlizzard.blp`).
Stretch uses CLAMP wrapping, 0..1 texcoords and both tile flags false. Each reused
slot fully resets texture, tint, alpha, blend, tile flags, coordinates, anchors,
size and draw layer before configuration. No assets were added.

## Presentation and lifecycle ownership

The Inspector dispatcher selects normal presentation or composition. Composer
neutralizes the existing renderer's Fill, Border, Accent, Shades and Divider;
it does not neutralize title, controls, rows or the functional content hierarchy.
Reset uses full surface/border rendering, not structure/padding/text rebuilding.
Canonical values are resolved afresh; no palette is captured as a new baseline.

Each owner has at most 10 reusable texture slots. Unused slots are neutralized
and hidden. Mutation visits registered owners; newly built sections immediately
consume the current composition. The existing Preview BindWidget release callback
also deregisters the composition owner, neutralizes slots and restores canonical
presentation before AceGUI clears callbacks/userdata. There is no second competing
Preview.Bind call. A neutral region cache remains on the pooled frame; no layer
IDs, descriptor or composition callback is stored in that cache. Weak keys are
supplementary; explicit release is mandatory, including in combat.

Composer entry is rejected while any of the three Inspector section color
targets has explicit overrides (including alpha 0 or a baseline-equal value).
Conversely, PresentationPreview.Set on those targets returns
`false, "section_composition_active"` while composer is active. No values are
silently cleared. Preview Clear/ClearAll/Refresh cannot expose the suppressed
baseline while composer is active. Shells, thumb and Sidebar inset stay independent.
Composer Reset does not clear unrelated color overrides.

All public composition writes reject combat; reads remain available. No queue.
Apply happens on mutation, binding/rebuild, reset or existing presentation refresh.
No OnUpdate, polling, timers, functional refresh or AceGUI vendor changes.

There is no slash-command or persistent debug helper in the runtime slice. The external DesignTool, when present, is unchanged and may use the public API. The composition is transient and is cleared by reload; native rendering and clipping still require client-side acceptance.

## Automated coverage

`lua54 Tests/PresentationCompositionPreview.lua` uses real FP modules, real AceGUI
pooling and actual bundled InlineGroup/InteractiveLabel with simulated native WoW
regions. Tests validation/atomic rejection/copies/IDs/limits, all primitive types,
slot material transitions, order/sublevels, multiple and later owners, 60 release/
reacquire cycles with a foreign consumer, 60 real local collapse cycles, bounded
region count, canonical reset including material/shades/divider fallback, both
preview conflicts, combat cleanup and no functional geometry/input mutations.
It does not prove native rendering, texture loading or pixel clipping.

Retain `Tests/PresentationPreview.lua` and the separate DevTool Workbench suite as
regressions. Lua syntax, XML load order and whitespace must also pass.
