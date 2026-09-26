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

The Plaque A runtime asset is release-bound. Its source master and one-shot builder are DEV-only and are archived outside the active release tree. The committed runtime file remains unchanged.

The release contains only the generated Plaque A runtime asset; extraction and build tooling are not part of the runtime tree.

## Offline validation

- `lua54 Tests/NavigatorBrandPlaque.lua` covers the real Header form/table layout,
  renderer and Toolbar, native metric doubles, content/geometry invariance,
  proportional resize, canonical style changes, combat rejection, 25 reopen and
  25 pooled release/reuse cycles. Includes established PresentationPreview tests.
- Regressions: `Tests/NavigatorBrassWindow.lua`, `Tests/TypographyLabels.lua` and
  `Tests/TypographyLabelConsumer.lua`; Lua syntax and `git diff --check`.

The committed Plaque A runtime asset remains the sole productive brand texture.
Native client layering and visual quality remain an ingame acceptance gate.

## Ingame acceptance

Reload and open the Sidebar. Check the complete plaque without checkerboard or
white matte, all four studs and both rivet rows, visible existing inline logo,
title and version, proportional fit, unchanged Header/Options spacing, and
Hide/Reopen. Brass and Label typography must remain unchanged. B1 introduces no
Brand font selection or typography acceptance.
