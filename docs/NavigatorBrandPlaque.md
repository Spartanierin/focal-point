# Navigator Brand B1

The Sidebar Header uses its existing `_fpSectionFill` and
`FormSectionSurfaceRenderer.ApplySectionSurface`. A private descriptor in
`ToolbarController.lua` replaces only this owner's chrome: no border, shades or
accent while enabled. `page_header`, other consumers, Composition, Brass, the
inline logo, title/version typography and DesignTool are unchanged.

The 1024x256 RGBA TGA fits proportionally and centrally into the current Header
frame. At 245x66 the texture rectangle is 245x61.25, with 2.375 units above and
below; its transparent perimeter adds a small safety margin around the bevel.
These are measurements, not a hard-coded group size. Only surface insets change.
An owner-scoped OnSizeChanged hook follows real layout changes without timers,
OnUpdate, padding changes, layout calls or content reflow.

Creation and Toolbar binding refresh/reopen reapply the private presentation.
Internal `ns.GUI.Editor.Toolbar.SetBrandPlaqueEnabled(false)` restores the current
resolved `page_header` surface, border, shades and accent. `true` reapplies the
plaque. The setter rejects combat/invalid input, adds no public Preview API and
is not persisted. Release restores canonical chrome before pooling and clears
the owner binding; the frame size hook is inert when the frame is reused elsewhere.
There is no global skin-change event in GUISkin; existing Toolbar refresh/reopen
and explicit reset resolve current styles. `/reload` starts with the plaque enabled.

## Asset provenance and extraction

Source: `Media/Textures/Window/fp_navigator_brand_Master_1942x809.png`, RGB PNG
without alpha. SHA256:
`861A0302D2AAF467508B6ECF796D2B8FF40B8B931E87E5CEFA635DF34D4035F8`.
The checkerboard is baked into the source. The master is never written.

`Tools/build_navigator_brand.ps1` invokes the narrow, package-free C# builder.
Row and column envelopes of the dark outer outline are intersected to recover
the silhouette. This method is specific to the pinned, orthogonally convex
plaque; it is not global color-key transparency. Every enclosed pixel is retained
regardless of brightness, including bright studs, rivets and bevels. The extracted
bounds are x=23..1915, y=183..658 (inclusive). A 1920x480 canvas at (10,181) keeps
the complete outline plus transparent padding. Exact area integration reduces
both axes by 1.875 in premultiplied alpha; exterior checker RGB does not bleed
into edge pixels. The output is a top-origin, uncompressed 32-bit TGA with
power-of-two dimensions and eight alpha bits.

## Offline validation

- `powershell -File Tools/build_navigator_brand.ps1` builds the runtime file.
- Add `-Check` to compare rebuilt bytes against the existing runtime asset.
- Optional `-PreviewPath <temporary PNG>` renders dark/light background inspection.
- `lua54 Tests/NavigatorBrandPlaque.lua` covers the real Header form/table layout,
  renderer and Toolbar, native metric doubles, content/geometry invariance,
  proportional resize, canonical style changes, combat rejection, 25 reopen and
  25 pooled release/reuse cycles. Includes established PresentationPreview tests.
- Regressions: `Tests/NavigatorBrassWindow.lua`, `Tests/TypographyLabels.lua` and
  `Tests/TypographyLabelConsumer.lua`; Lua syntax and `git diff --check`.

The asset build validates the master hash before/after, silhouette bounds/area,
interior material and all four studs/both rivet rails, bright metal preservation,
transparent perimeter, antialiased alpha and deterministic runtime bytes.
Native client layering and visual quality remain an ingame acceptance gate.

## Ingame acceptance

Reload and open the Sidebar. Check the complete plaque without checkerboard or
white matte, all four studs and both rivet rows, visible existing inline logo,
title and version, proportional fit, unchanged Header/Options spacing, and
Hide/Reopen. Brass and Label typography must remain unchanged. B1 introduces no
Brand font selection or typography acceptance.
