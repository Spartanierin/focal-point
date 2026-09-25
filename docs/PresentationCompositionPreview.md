# Presentation Composition Preview — Geometry Block A

Internal experimental runtime, public as `FocalPoint.PresentationCompositionPreview`
on the AceAddon object. Call with a dot. No DevTool UI is included.

## Contract

API version 1; experimental descriptor version 0, retained for the additive geometry
extension. State is RAM-only and disappears on reload. No product/profile/layout data
or SavedVariables are involved. Each target has one descriptor shared by its registered
owners. Existing target IDs, bindings and canonical presentation are unchanged:

| Target | Existing owners |
| --- | --- |
| `inspector_section` | Inspector section InlineGroups, excluding external toggle headers |
| `inspector_shell` | Inspector shell |
| `sidebar_shell` | Existing AppShell underlay and toolbar window bindings |
| `sidebar_section` | Workspace, Editing, Options and Secondary section owners |
| `sidebar_unit_navigator_inset` | Sidebar UnitGrid inset |

Structure continues to own bounds, content, lifecycle and semantics. Composition only
creates decorative texture regions on those existing frames. In particular, the two
`sidebar_shell` bindings are not corrected or migrated by this block.

`GetCapabilities()` returns detached type/property lists and numeric limits.
Both it and each `GetTargets()` entry additionally expose:

```lua
canvas = { kind = "structural_owner", bounds = "owner_frame" }
geometryModes = {
  surface = { "inset", "rect" }, texture = { "inset", "rect" }, line = { "edge" },
}
rectAnchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
                "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
```

Surface/Texture property lists add `geometry`; Line's property list is unchanged.
`edge` describes Line's existing placement, not an accepted `geometry` property.
The existing `modes = { "stretch" }` describes texture sampling, not geometry.
Metadata contains no owner/frame references or per-owner descriptor copies.
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
Inputs accept only the listed fields with finite numbers, plain RGB arrays,
plain four-key inset tables and plain geometry tables. IDs and types cannot be edited. No functions,
metatables, cyclic structures, frame references or arbitrary paths are admitted.

| Call | Result / semantics |
| --- | --- |
| `AddLayer(target, type, initial?)` | `true, layerId`; optional initial properties overlay FP defaults; activates mode |
| `RemoveLayer(target, layerId)` | `true`; removing the last layer keeps mode active |
| `UpdateLayer(target, layerId, property, value)` | `true`; atomically replaces one property, including a complete RGB/insets/geometry table |
| `MoveLayer(target, layerId, directionOrIndex)` | `true`; `up` moves toward the front, `down` toward the back, or use a 1-based index; boundary moves are no-ops |
| `ClearComposition(target)` | `true`; activates/retains mode with an empty list and neutralized baseline |
| `ResetComposition(target)` | `true`; removes descriptor, neutralizes own regions, restores current canonical presentation; inactive reset is a no-op |

Rejected writes return `false, reason` before changing the descriptor, IDs or
rendered owners. Reasons: `combat`, `unknown_target`, `unknown_type`,
`invalid_initial`, `invalid_property`, `layer_limit`, `unknown_layer`,
`invalid_position`, target-specific color-preview conflicts,
`geometry_out_of_bounds`, `canvas_bounds_unavailable`.

## Geometry normalization and legacy compatibility

Internally Surface and Texture have exactly one geometry value:

```lua
geometry = { mode = "inset", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
-- OR
geometry = { mode = "rect", anchor = "TOPLEFT", x = 0, y = 0, width = 100, height = 40 }
```

Omitted geometry defaults to INSET. The legacy `insets` input normalizes to INSET;
no parallel inset state is retained. `GetComposition` projects INSET back to the
exact legacy wire shape shown above (`insets`, no `geometry`). This applies even
when INSET was explicitly supplied via `geometry`. RECT returns `geometry`, with
no `insets` field. Line's wire shape is unchanged. All input/output values are detached.

Supplying both `initial.insets` and `initial.geometry` is rejected as `invalid_initial`;
there is no table-iteration-dependent precedence. Updating `insets` explicitly switches
a Surface/Texture to INSET; updating `geometry` replaces the entire geometry. No fields
are merged implicitly. There is no whole-descriptor injection/import API: legacy layer
properties continue to work through AddLayer/UpdateLayer without a schema migration.
Consumers using only legacy INSET see the same descriptors and version as before;
RECT consumers must support the discovered geometry contract. The separate DesignTool
consumes this public geometry contract and owns its own UI/workspace persistence; the
runtime stores no DesignTool state.

## RECT coordinates and bounds

Canvas means the full current `owner.frame` (or raw owner frame) bounds. RECT does
not add the legacy renderer's presentation `surfaceInsets` or functional content
padding. INSET and Line retain those existing target/style offsets exactly.
All nine native anchors use the same point on the rectangle and its own canvas.
There is no `relativePoint`, other target reference or screen coordinate input.

X/Y are logical UI pixels: positive X goes right; positive Y goes down. Native apply
uses `SetPoint(anchor, ownerFrame, anchor, x, -y)` and `SetSize(width, height)`.
For example, TOPRIGHT with `x=-4, y=5` places the rectangle four units inward from
the right and five down. Signed offsets are needed for right/bottom/center anchors;
a TOPLEFT negative X/Y fails bounds checking when an owner exists.

For canvas W/H, rectangle w/h and anchor fractions ax/ay in {0, 0.5, 1} measured from
top-left, the resolved top-left is `((W-w)*ax+x, (H-h)*ay+y)`. The complete rectangle
must fit inside `[0,W] × [0,H]`; exact boundaries and fractional UI pixels are allowed.
Geometry requires a known mode/anchor, all fields, finite X/Y/width/height and strictly
positive width/height. NaN, infinities, unknown fields and metatables are rejected.

On AddLayer and UpdateLayer, the candidate layer is checked before any descriptor,
ID, owner or region mutation. If it is RECT, it must fit **every currently bound owner**.
Any overflow rejects the whole write as `geometry_out_of_bounds`. A bound owner with
missing, non-finite or non-positive dimensions rejects as `canvas_bounds_unavailable`.
Overflow takes precedence if different owners fail for different reasons. An update
to color/alpha on an existing RECT also validates that candidate's geometry.
Other existing layers are not implicitly rewritten or validated as part of that write.

Without bound owners, structural validation suffices. On each later Apply, a RECT
that does not fit that owner's current bounds is neutralized and hidden on that owner
only. Other layers/owners continue rendering; the shared descriptor is unchanged.
Composition remains active and canonical presentation remains neutralized, even if
all its RECT layers are hidden. Clear, Reset, removal and switching to INSET still work.

### Resize behavior

RECT sizes and offsets remain pixel-based. Anchor-relative placement follows the
owner's native anchor; no scaling, percentages, clamp or reflow modifies stored geometry.
At the next existing mutation/binding/rebind/presentation-refresh Apply, bounds are
checked again: shrink beyond validity hides the layer, sufficient growth shows it again.
No resize hook, timer, retry or polling is installed. An isolated native resize without
a subsequent existing Apply is therefore **not** an immediate clipping/containment
guarantee; the owner must reach its normal presentation refresh path. Native draw order
and resize integration require client acceptance. No functional layout mutation occurs.

```lua
local api = FocalPoint.PresentationCompositionPreview
local ok, id = api.AddLayer("inspector_section", "surface", {
  color = { 0.2, 0.3, 0.4 }, alpha = 0.8,
  geometry = { mode = "rect", anchor = "TOPLEFT", x = 8, y = 4, width = 20, height = 12 },
})
-- Check ok/reason: all currently bound section owners must contain this rectangle.
if ok then
  api.UpdateLayer("inspector_section", id, "geometry", {
    mode = "inset", insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
end
```

## Primitives and bounds

| Type | Properties / defaults |
| --- | --- |
| Surface | RGB white, alpha 1, INSET with four zero insets; optional RECT |
| Line | RGB white, alpha 1, edge top, inward offset 0, thickness 1 |
| Texture | textureId parchment, RGB white tint, alpha 1, INSET with four zero insets; optional RECT; mode stretch |

RGB/alpha: 0..1. Insets and inward offset: 0..8 UI units. Thickness: 1..4.
Insets are additional to the existing resolver's visible `surfaceInsets`, not
content padding. Lines stay inside the selected edge; negative offsets are invalid.
Line has no free XY/size or `geometry` input. No frame-level, overlay, tiling or
blend-mode properties are introduced for any primitive.

The supported native InlineGroup has a minimum auto-layout height of 40
(`LayoutFinished`: content height + 40). Inspector width is currently 315 before
its existing shell/content insets; it is not resized by this runtime. A deliberately
smaller 40 x 40 section is tested with the current 6px horizontal presentation
insets and all four composer insets at 8: 12 x 24 positive inner surface remains.
This legacy INSET check does not guarantee positive areas for arbitrary tiny frames
or future unbounded canonical surface insets. RECT's current-owner bounds validation
is separate; legacy INSET behavior is deliberately unchanged.

Regions anchor directly to their existing owner frame and follow its bounds without timers,
size callbacks or layout mutations. No new host Frame, clipping or scroll system.
All slots use BACKGROUND and distinct sublevels -8..1; title/content remain in
their existing layers/hierarchy. Native clipping/draw order require client testing.

Texture IDs include the compatibility IDs `parchment` (existing `Media/Textures/fp_window_background.jpg`,
also used by Manage Layouts) and `blizzard` (`Media/Textures/BetterBlizzard.blp`), plus canonical IDs discovered from the GUI texture manifest.
Stretch uses CLAMP wrapping, 0..1 texcoords and both tile flags false. Each reused
slot fully resets texture, tint, alpha, blend, tile flags, coordinates, anchors,
size and draw layer before configuration. The registry is the single source of texture paths; no DesignTool-specific asset list is maintained.

## GUI texture media

`GetTextureOptions()` is backed by the FocalPoint `MediaRegistry` `texture` type.
The Composer has no local GUI-texture table and does not discover files itself.
The generated `Media/Textures/GUI/GUITextureManifest.lua` registers supported
`.png`, `.tga` and `.blp` files through the same registry resolver as other media.

Compatibility IDs `parchment` and `blizzard` remain valid input and option IDs. They normalize to
the registered canonical references `fp:texture:parchment` and
`fp:texture:blizzard`; discovered folder assets use
`fp:texture:<normalized-full-filename-stem>` and retain resolution suffixes.
The registry stores the internal asset path; the public option DTO exposes only
an ID and label. To add a GUI texture, place it in `Media/Textures/GUI` and run
`python Tools/generate_gui_texture_manifest.py` before reloading the addon.
## Presentation and lifecycle ownership

The existing target dispatchers select normal presentation or composition. Composer
neutralizes the target's existing canonical regions (section Fill, Border, Accent,
Shades and Divider, or the existing shell/inset regions);
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

Composer entry is rejected while any color-preview target in that composition
target's conflict set has explicit overrides (including alpha 0 or a baseline-equal
value). Conversely, PresentationPreview.Set rejects conflicting active compositions.
The existing target-specific error strings and conflict sets are unchanged. No values
are silently cleared. Preview Clear/ClearAll/Refresh cannot expose the suppressed
baseline while composer is active. Different composition targets retain independent
descriptors; Composer Reset does not clear unrelated color overrides.

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
The geometry extension retains all these checks and adds exact legacy wire-shape
comparison, explicit INSET normalization, RECT validation and atomic rejection
(including no region writes), nine anchors/Y conversion, Surface/Texture RECT,
alpha zero, geometry/material transitions on the same pooled slot, bounded region
count on reorder, differing/late owner bounds, shrink/hide/grow at Apply, unavailable
bounds, release/reacquire, all five targets and nested defensive metadata/geometry copies.
It does not prove native rendering, texture loading or pixel clipping.

Retain `Tests/PresentationPreview.lua` and the separate DevTool Workbench suite as
regressions. Lua syntax, XML load order and whitespace must also pass.
