# Navigator Brass T1 rescue

Implementation is ready for ingame acceptance; no live rendering approval is implied.

## Runtime assets

The one-shot asset builder and high-resolution source masters are DEV-only and are archived outside the active release tree. The generated runtime files below are the release-bound assets.

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
edits/reset. Check Media Library, Tag Library, Texts Manager, and Text Builder
windows.
Then repeat 20–50 lifecycle cycles if the first visual pass is satisfactory.

No staging, commit, tag, push, deployment or ZIP belongs to this implementation gate.
