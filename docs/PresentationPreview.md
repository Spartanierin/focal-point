# Presentation Preview v1 (internal development API)

Owner: `GUI/Helpers/PresentationPreview.lua`. The public value-only API is
`LibStub("AceAddon-3.0"):GetAddon("FocalPoint").PresentationPreview`.
Call functions with a dot, not a colon. No external frame access is needed.

## Contract

Typography T3 adds `inspector_label` (Area `Inspector`) and `sidebar_label`
(Area `Sidebar`), both displayed as `Label`. They use the existing `font`, `size`,
`flags`, `color`, `alpha`, `shadowEnabled` descriptor and capabilities unchanged.
Inspector owners are the static left-hand PropertyRow labels and static checkbox,
slider and dropdown captions. Sidebar currently binds the active `Expert Mode`
caption. Binding is semantic and slot-specific, never global by TextStyle name.
Headings, values (including On/Off and template names), tree/navigation/buttons,
brand/identity, help/context/warnings, Anchor Points and native ColorPicker captions
are excluded. Reset resolves current product/skin defaults rather than saved region
values; registered state/style refreshes synchronously reapply the presentation.
DesignTool discovery and Workspace Schema 3 are unchanged. Verify with
`lua54 Tests/TypographyLabels.lua` and `lua54 Tests/TypographyLabelConsumer.lua`.

Brand B2 adds `sidebar_brand` (Area `Sidebar`, label `Brand`) with the same six
typography properties. Its only consumer is the Sidebar identity FontString;
the existing separate logo image, version, plaque and section headings are excluded.
`fp:font:achtung-polizei` registers the existing product font in MediaRegistry and
public font discovery. Reset resolves current GUISkin brand colors/title and the
canonical 18-unit hero style, font, flags, alpha and shadow. Explicit RGB removes
inline color markup; without RGB override, canonical two-color branding remains.
FontString alpha is independent of logo alpha. A local, bounded title slot retains
the original canonical row allocation: oversized typography may clip, never grow
the Header or move Options. The legacy inline-logo string is used once solely to
measure that allocation before binding, then replaced with the standalone image.
No frame/font snapshots supply typography defaults. DesignTool and Schema 3 are
unchanged. Tests: `Tests/NavigatorBrandTypography.lua` and
`Tests/TypographyBrandConsumer.lua`; native visual clipping requires ingame acceptance.

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

### Typography discovery

`GetTypographyCapabilities().properties.font.discovery.api` names the public
method `GetTypographyFontOptions`. Call `GetTypographyFontOptions()` on the
same `PresentationPreview` object to receive detached available-font options:

```lua
{
    { id = "fp:font:standard", label = "Focal Point Standard", available = true },
}
```

The adapter owns the `availableOnly` filter and exposes no file paths, frame
references or registry entries. Consumers must use the returned `id` with
`SetTypographyPresentation`; font validation and resolution remain canonical
inside the product MediaRegistry contract.

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

Typography Rescue: the external consumer uses only the public
`GetTypographyFontOptions()` DTOs, reached through the capability discovery method.
The adapter delegates to MediaRegistry and excludes unavailable entries, including
defensively filtering its result. IDs remain directly accepted by typography Set
and resolved internally for built-in and LSM fonts; paths/private entries are not
exposed. Dropdowns and workspace font validation share this public source.

The Sidebar heading binding now applies descriptor RGB after TextStyles' canonical
role styling. Previously font/size/alpha/flags/shadow were applied but RGB was lost.
The Inspector already applies explicit descriptor RGB. Both update bound owners
synchronously without a toolbar/Inspector rebuild; content text is unchanged.

Typography tests use real TextStyles, Sidebar/Inspector bindings and native-region
recording to verify final RGB/alpha/font/size/flags/shadow, multi-owner application,
target isolation, canonical restore, defensive copies, release and combat rejection.
The public font fixture covers built-in, available LSM and unavailable entries.
The external DesignTool additionally tests structural/value sync separation and
continuous callbacks; no live client performance result is claimed for this rescue.

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

## Navigator canonical design promotion

The accepted Navigator materials now resolve from the existing product defaults,
without loading a DesignTool workspace: forged-metal 128 for both shells,
mahagony 128 for sections, and parchment for the Unit Navigator inset. The Sidebar
surface covers its window; the Inspector surface retains its 12-unit bounds.
Content insets, Brass, the cast-iron plaque and B3 brand geometry remain unchanged.
The two 128px material assets and registry IDs are retained unchanged; larger
material variants and source artwork are not part of this promotion.

Target typography defaults provide subdued labels, 14px outlined section
headings and Cinzel Decorative Bold 19 for the brand. Global label/heading roles
are unchanged. Brand text has no inline color markup: its descriptor is the one
color source. Fresh brand layout still measures the original B3 allocation before
applying display typography, so the new font cannot move Options or the version.

The material defaults supersede the earlier color-only baseline descriptions
above. Shell/section/inset color previews recolor their canonical material.
Inspector border preview remains optional (canonical border alpha is zero), and
the accent preview addresses the canonical top line. Clear/reset resolves current
product descriptors, including texture identity, rather than region snapshots.
`ResetComposition` removes an override and restores those defaults; an explicitly
empty composition remains an intentional override, not a product-default reset.

`Tests/NavigatorDesignPromotion.lua` verifies exact accepted values, registry
resolution and asset presence, shell bounds/underlay, absence of legacy chrome,
fresh B3 allocation, typography clear, composition reset, reopen, rebuild and
pooling with native-region doubles. It does not load DesignTool or SavedVariables.
The existing presentation, composition, label, brand, plaque and Brass suites
provide complementary regression coverage. Native font rendering requires the
following user acceptance gate; offline tests do not establish visual equivalence.

Golden visual acceptance:

1. Back up workspace `Test` without overwriting its golden reference.
2. Reset all five composition targets through `ResetComposition`, then clear all
   typography overrides. Do not reapply DesignTool afterwards.
3. `/reload`, then open Navigator fresh. Compare metal shells, Brass, dark wood
   sections, gold lines, parchment inset, headings, labels, plaque, logo, brand
   gold/Cinzel and version placement with the accepted design.
4. Check Options-Y, reopen, Inspector rebuild and reset again.

SavedVariables and the DesignTool repository remain read-only during promotion.
Golden visual PASS is supplied by the user; no automatic workspace deletion,
promotion, commit or release is performed.
