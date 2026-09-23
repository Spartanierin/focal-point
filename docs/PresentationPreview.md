# Presentation Preview v1 (internal development API)

Owner: `GUI/Helpers/PresentationPreview.lua`. The public value-only API is
`LibStub("AceAddon-3.0"):GetAddon("FocalPoint").PresentationPreview`.
Call functions with a dot, not a colon. No external frame access is needed.

## Contract

- `version = 1`; `GetCapabilities()` and `GetTargets()` return detached metadata.
- `GetBaseline(target)` returns `{ color = { r, g, b }, alpha = a }` from current
  canonical FP contracts. Reads never inspect rendered regions.
- `GetOverrides(target?)` returns detached explicit overrides, or an empty table.
- `Set(target, "color", {r,g,b})` accepts exactly three finite numbers in [0,1].
  This is FP's numeric array color format; alpha is a separate property, so RGBA
  input is rejected rather than silently losing its fourth component.
- `Set(target, "alpha", a)` accepts a finite number in [0,1], including zero.
- `Clear(target, property?)`, `ClearAll()`, `Refresh(target?)` return `true` on success.
- Failed writes return `false, reason`; failed reads return `nil, reason`.
  Reasons: `unknown_target`, `unknown_property`, `invalid_color`, `invalid_alpha`,
  `baseline_unavailable`, `combat`.
- Every public write, including Refresh and Reset, rejects combat without queuing.
- State lives only in RAM. Missing/hidden instances do not discard overrides.
  Close/reopen retains them; reload clears them. No profile/layout data is touched.

## Fixed targets

| ID | Region and canonical source |
| --- | --- |
| `sidebar_shell` | Main toolbar-window fill and AppShell underlay; shared `FormWidgets.GetSidebarShellFill()` canonical resolver |
| `inspector_shell` | Inspector-window main fill; same canonical source, independent override |
| `inspector_section_surface` | InspectorBinding section body fill; Chrome sectionFill |
| `inspector_section_border` | Four shared-renderer section edges; Chrome sectionBorder |
| `inspector_section_accent` | Shared-renderer section accent; Chrome sectionAccent |
| `inspector_slider_thumb` | Inspector FPCompactSlider thumb; Navigator aged brass and CompactSlider thumb alpha |

Shell header fills, shades, borders, local separator lines and collapse-toggle
decorations are excluded. Section texture fallbacks are not preview targets.
Thumb alpha denotes enabled opacity; the existing disabled/normal alpha ratio
continues to apply. No whole-frame alpha, fonts, textures or geometry controls.

Consumers register existing owners internally. API reapply only colors existing
regions; it never rebuilds widgets, changes selection, lays out the Inspector or
uses a timer. Sections rebind on local collapse/expand. Release unregisters pooled
widgets and removes preview appearance before another consumer can acquire them.

## Verification

Automated test: `lua54 Tests/PresentationPreview.lua` (includes existing slider tests).
Uses actual FP renderers and AceGUI pooling with simulated native regions. Checks
cover validation/copies, six targets, current-baseline reset after a skin change,
combat rejection, geometry isolation, 50 section/slider pooling cycles and 25
collapse/expand cycles. Syntax, XML and whitespace checks also passed for Block 1.

In-game color/alpha changes for all six targets, independent control and reset
were reported PASS by the user. These results were obtained on the development
worktree; unrelated visual WIPs are not part of this infrastructure slice.

Full in-game lifecycle coverage is not claimed. Separate acceptance remains for
setting before opening, repeated selection/rebuild, collapse/expand, enabled and
disabled sliders, close/reopen, layout/profile changes, combat and reload. The
production adapter exposes only the API; no diagnostic command is installed.
