# Navigator Brass T1 rescue

Implementation is ready for ingame acceptance; no live rendering approval is implied.

## Reproducible assets

Run from the repository root using Windows PowerShell and System.Drawing (no packages):

```powershell
& Tools/build_navigator_brass.ps1
& Tools/build_navigator_brass.ps1 -Check
& Tools/build_navigator_brass.ps1 -Check -PreviewPath "$env:TEMP/navigator-brass-proof.png"
```

`-Check` regenerates in memory and compares the complete TGA bytes without writing
runtime assets. Optional preview output shows two widths, mirrored corners and
partial tiles. The script checks all three source hashes and never writes masters.

Sources in `Media/Textures/Window`:

| Master | Dimensions | Role |
| --- | --- | --- |
| `fp_navigator_corner_Master_1254x1254.png` | 1254 x 1254 | Canonical geometry, brass, patina and bevel |
| `fp_navigator_horz_Master_2172x724.png` | 2172 x 724 | Retained art reference; pixels not needed in final build |
| `fp_navigator_vert_Master_887x1774.png` | 887 x 1774 | Retained art reference; pixels not needed in final build |

The tuning keeps the canonical source map, but crops quiet corner arms at about
source coordinate 920 and assigns the ornamental band 40/128 texels instead of
16/64. Thus more of the runtime corner is artwork, not elongated quiet arms.
The arms straighten toward an independently sized rail profile, with reduced
outer padding. Corner size increases from 32 to 56 UI units; ornament-band depth
increases from about 8 to 17.5 UI units only near the corners. Straight rails end
about 10.5 UI units inside the bounds. Content insets remain unchanged.
16 x 16 area samples per output texel use premultiplied alpha; source alpha below
16 is discarded to remove stray matte. No image generation is involved.

Both edges use the same canonical horizontal corner-arm cross-section, transposed
for the vertical edge. Quiet material variation
comes from up to 150 source pixels along the adjacent corner arm, with periodic
sin-squared blending capped at 18%. The final eight corner texels feather into the
same endpoint profile. Checks compare both tile endpoints and both corner joins
exactly, verify H/V pixel equality after transposition, and require visible widths
within 6-8 UI units at alpha thresholds 16 and 128.
Arbitrary partial tiles retain the same alpha/profile with subtle RGB variation;
the preview and ingame check assess their final corner transition.

Runtime outputs are uncompressed 32-bit BGRA TGA, top-left origin, eight alpha bits,
power-of-two dimensions:

| File | Texels | Presentation |
| --- | --- | --- |
| `fp_navigator_brass_corner.tga` | 128 x 128 | 56 x 56 UI units |
| `fp_navigator_brass_horizontal.tga` | 256 x 128 | 56 UI texture height, mostly transparent; horizontal repeat |
| `fp_navigator_brass_vertical.tga` | 128 x 256 | 56 UI texture width, mostly transparent; vertical repeat |

Both straight rails occupy 15 texels at alpha >= 16 and 14 at alpha >= 128:
approximately 6.6 visible UI units including antialiasing (previously about 4).
The remaining cross-section is transparent padding. No new ornament is added to edges.

## Runtime ownership

`ApplyWindowNineSlice` in FormWidgets is a private helper extracted from the existing
Modern Window path. The helper keeps the existing `NineSlicePanelTemplate` child,
all-points anchoring, disabled mouse input, and owner frame level + 3.
Modern Window continues through `ApplyLayoutByName` with its existing named layouts,
title, portrait, mask, background and close-button treatment.

Navigator passes a private eight-piece layout to `NineSliceUtil.ApplyLayout`.
The existing `setupPieceVisualsFunction` callback supplies file textures, dimensions,
repeat flags and mirrored texture coordinates. There is no atlas registration,
global layout registration, center texture, new engine, descriptor or load-order change.

Bindings are installed only when ToolbarController creates the Sidebar Window and
EditorController creates the Inspector Window. The AppShell sidebar underlay is
not bound. Window/content sizes, insets, hit regions and scrolling are unchanged.
Shell reapply and Inspector geometry refresh reapply the same cached border.

Only the four outer default borders, four inner borders and two edge shades are
hidden while brass is active. Fill/header/accent and composition regions are not
modified by this border path. Mahogany and composition descriptors stay with their
existing owners. A composition reset re-resolves the shell and preserves brass.

For internal acceptance code with an existing owner reference:

```lua
ns.GUI.Helpers.FormWidgets.SetNavigatorBrassEnabled(window, false) -- canonical border
ns.GUI.Helpers.FormWidgets.SetNavigatorBrassEnabled(window, true)  -- brass
```

No UI or saved setting is added. Disabling brass resolves default border colors from
the current skin. Active composition continues to suppress the default border,
including an explicitly empty composition. Reopening preserves this per-owner flag.
Explicit toggles reject combat without scheduling deferred work. The release hook
is chained once, unregisters shell composition, hides brass and clears binding state;
AceGUI reacquisition can bind it afresh. No timers, OnUpdate handlers or retries are added.

## Verification and acceptance

```text
lua54 Tests/NavigatorBrassWindow.lua
lua54 Tests/NavigatorBrassWindow.lua <local Blizzard_SharedXML/NineSlice.lua>
lua54 Tests/PresentationPreview.lua
```

The new test exercises actual FP Sidebar/Inspector builders and composition, with
AceGUI pooling and native Window/ScrollFrame stand-ins. It checks mirrored pieces,
anchors, geometry isolation, canonical/current-skin reset, composition preservation,
combat rejection, 50 reopen cycles, 50 pooling cycles, and the Modern title/portrait
contract. It also passed using unmodified Blizzard `NineSlice.lua` from the live
[wow-ui-source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/NineSlice.lua)
on 2026-09-25. Native drawing and filtering remain untested offline.

`Tests/PresentationPreview.lua` passes. The existing
`Tests/PresentationCompositionPreview.lua:162` fails because it expects
`Interface\\anything.blp` to be rejected while the current MediaRegistry accepts
legacy file references. The identical failure was reproduced with the pre-rescue
FormWidgets file. Neither that existing behavior nor its test is changed here.
The new brass suite separately covers shell composition and reset behavior.

Ingame gate: `/reload`, open Editor; inspect Sidebar and Inspector at their respective
285/315 widths, all four corners, both edge directions, partial-tile seams, alpha and
UI scale. Check mahogany underneath, scroll/click/content, open/close and composition
edits/reset. Check Media Library, Tag Library and Text Builder Modern windows.
Then repeat 20–50 lifecycle cycles if the first visual pass is satisfactory.

No staging, commit, tag, push, deployment or ZIP belongs to this implementation gate.
