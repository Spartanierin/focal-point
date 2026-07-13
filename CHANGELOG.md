# Changelog

All notable user-facing changes to Focal Point are documented in this file.

This changelog uses the following categories:

* `Added` for new features
* `Changed` for behavior, UX, or visual updates
* `Fixed` for bug fixes
* `Removed` for removed functionality

## [1.0.15]

### Added

* Added profile-aware text template source and copy support in the editor as groundwork for safer cross-profile text template handling.

### Changed

* Improved unlock-mode placeholder handling so non-selected unit frames use a more consistent neutral placeholder presentation.
* Increased unlock placeholder overlay opacity and normalized placeholder alpha so placeholder labels and backgrounds appear more consistent across units with different frame alpha settings.

### Fixed

* Fixed disabled unit frames disappearing from the unlock editor, allowing them to remain visible and reactivatable while frames are unlocked.
* Fixed disabled unit frames remaining visible or reappearing in live mode after target-related events such as `PLAYER_TARGET_CHANGED` or `UNIT_TARGET`.
* Fixed enabled-state changes in the Inspector using only a local refresh instead of synchronizing the unit frame lifecycle.
* Fixed disabled unlocked units being routed through the hard-hide path instead of the editor placeholder path.

## [1.0.14b]

### Fixed

* Fixed additional Midnight secret-value Lua errors in class and classification text/runtime paths.
* Hardened unsafe `UnitClass` and `UnitClassification` checks used by text elements and classification styling.

## [1.0.14a]

### Fixed

* Fixed a Midnight secret-value Lua error in name/status text handling for units such as Target of Target.
* Replaced an unsafe Blizzard `GetUnitName` text status path with a safer fallback.

## [1.0.14]

### Added

* Added bundled text template support for built-in presets, allowing presets to install required text templates safely when applied.
* Added shared unit configuration access helpers as a small step toward more consistent profile and unit configuration reads.
* Added a read-only active profile text template usage scanner to support safer template diagnostics in the editor.

### Changed

* Updated the built-in Classic preset with its latest layout, bar, media, aura, indicator, and text template configuration.
* Improved profile transfer to preserve dynamic profile data that is not represented in the default profile schema.
* Reduced profile export size by storing only compact extra profile data instead of duplicating full profile payloads.
* Excluded transient internal theme snapshot state from profile exports to keep transfer strings compact and focused on user configuration.
* Improved editor unlock placeholder visuals so enabled frames keep their actual bar colors visible.

### Fixed

* Fixed profile export/import losing dynamic settings such as custom health colors, text template references, state templates, and preset-installed text templates.
* Fixed profile imports not immediately refreshing visible unit frames with the imported configuration.
* Fixed profile switching leaving editor and inspector state out of sync with the newly active profile.
* Fixed custom health colors being overridden by fallback/default color paths during later health refreshes.
* Fixed active placeholder health bars using neutral placeholder tint instead of configured health colors.
* Fixed text elements anchored to disabled Power, Alternative Power, or Class Power bars continuing to render after their owning bar was disabled.
* Fixed old text elements remaining visible and overlapping new text layouts after profile or preset changes.
* Fixed missing text template references being hard to identify by showing a read-only warning in the Inspector when a selected text element references templates that are not installed in the active profile.

## [1.0.13]

### Fixed

* Improved text refresh reliability for Target of Target and Focus Target when derived unit names become available shortly after target or focus changes.
* Prevented transient soft-clear recovery paths from directly clearing text objects, keeping text ownership inside the text runtime.
* Fixed composite text templates such as `[power:cur]/[power:max]` briefly rendering separator-only output like `/` during rapid unit changes.
* Fixed stale castbar name and timer texts remaining visible after casts end, fail, interrupt, or when the castbar is disabled.
* Added shared text value safety helpers as groundwork for safer handling of Midnight protected/secret text values.

### Removed

* Nothing.

## [1.0.12]

### Changed

* Missing-unit handling now uses safer soft-clear behavior for protected combat and boss frame states.
* Root visibility and alpha handling is now more consistent across Target, Target of Target, Focus Target, and boss frames.

### Fixed

* Improved target frame stability during rapid target changes and combat transitions.
* Fixed cases where absent Target, Target of Target, and Focus Target frames could briefly reappear due to visibility refreshes.
* Fixed cases where range fade could restore alpha on absent target-like frames.
* Fixed layout refreshes applying normal frame alpha to absent target-like frames.
* Improved boss frame stability during encounter start, phase changes, and encounter end.
* Fixed absent boss frames being shown or receiving visible alpha from refresh, range fade, or layout paths.
* Reduced cases where protected combat missing-unit handling could destructively clear frame visuals.

### Removed

* Nothing.

## [1.0.11]

### Fixed

* Improved target, targettarget, and focustarget stability by avoiding destructive visual clears while the underlying unit still exists.
* Prevented transient missing-unit recovery from clearing existing target-like frames into partial text-only or bar-only states.
* Prevented existing boss frames from being destructively cleared when boss units are still present.
* Improved boss frame initialization on encounter engage by queuing content refreshes for visibility, bars, texts, and auras.
* Replaced the transient target-missing transition clear with a non-destructive content-value clear to preserve frame skeleton, bars, portrait, and chrome.

### Removed

* Nothing.

## [1.0.10]

### Changed

* Kept the release branch on the proven 1.0.9 runtime baseline while the experimental 1.1.0 runtime refactor remains isolated for further stabilization.

### Fixed

* Fixed `[power:perc]` text rendering for Midnight protected/secret power values so renderable protected values no longer collapse to an incorrect `0%`.
* Fixed protected power percent fallback handling so unresolvable values use a neutral fallback instead of a misleading numeric value.

### Removed

* Nothing.

## [1.0.9]

### Added

* Added profile import/export support on the Profiles tool page.
* Added polished profile transfer dialogs for exporting copyable profile strings and importing them as new profiles.
* Added import profile naming, overwrite confirmation, and visible import status/error handling.

### Changed

* Changed profile exports to use a compact defaults-diff transfer format instead of serialized profile table data.
* Reduced export string length by using schema-indexed values and shortened Focal Point media texture references.
* Refined profile transfer window behavior so the Profiles page is temporarily hidden while export/import dialogs are open.
* Unified profile import/export dialog layouts with the same declarative layout system used by the Profiles and Text Builder pages.

### Fixed

* Fixed profile import creation so imported profiles are reliably materialized in the AceDB profile store.
* Fixed import parsing edge cases caused by WoW edit-box pipe escaping.
* Fixed profile transfer dialogs so repeated export/import openings keep stable layout sizing and avoid AceGUI reparenting errors.

### Removed

* Nothing.

## [1.0.8]

### Added

* Added an editor-only right-click context menu for unlocked unit frames.
* Added quick frame actions for copying/pasting size, copying/pasting position, and resetting size or position.
* Added mouse resize handles for unlocked unit frames.
* Added live frame size preview while dragging resize handles.
* Added basic Snap Lines while moving unlocked unit frames.
* Added snapping to screen center and nearby editable frame positions.
* Added temporary guide lines to help align frames visually.

### Changed

* Localized editor frame context menu labels and status messages.
* Normalized German localization text to proper UTF-8 umlauts instead of ASCII transliterations.
* Resized frame dimensions are committed through the existing editor configuration path.

### Fixed

* Fixed toolbar unit selection so it uses the same editor selection and demo-frame refresh path as clicking a unit frame directly.
* Fixed resize handles so starting a resize on an inactive unit first selects that unit through the central editor selection path.
* Fixed the frame context menu so right-clicking the same frame again closes the menu.
* Fixed unlocked frame coordinate overlays so they show the stored positioning offsets used by the inspector.
* Fixed context menu position paste/reset so the stored position is applied to the visible frame immediately.

### Removed

* Nothing.

## [1.0.7]

### Added

* Added the first internal GUI skin registry for toolbar and inspector styling foundations.

### Changed

* Routed central GUI text colors, form chrome colors, and editor button visuals through the active skin while keeping the default appearance unchanged.
* Updated editor header branding to match the new Focal Point logo colors.
* Updated the default editor skin to better match the new Focal Point logo and brand colors.
* Refined editor button color hierarchy so inactive buttons stay neutral while orange emphasizes interactive and active states.
* Refined the default editor skin so Focal Point orange is used as a focused accent rather than a dominant button fill.
* Updated the default editor button texture to use `shadow1.png`.
* Updated editor button texture coordinates so `shadow1.png` uses the full texture area.
* Calmed editor button backgrounds and texture tinting to improve label contrast without outlines.

### Fixed

* Fixed the editor toolbar brand title so the visible `Focal Point` header renders as white/orange instead of the previous blue text.
* Fixed editor button texture tinting so darker skin fill colors are no longer overwritten by the source texture color.
* Improved editor button texture visibility by rendering the skin texture as a separate overlay above the dark fill.
* Increased editor button texture overlay visibility so `shadow1.png` is easier to perceive.
* Improved editor button text readability by keeping button labels above the texture overlay with a stronger dark shadow.
* Improved editor button label contrast with a near-black text shadow.

### Removed

* Nothing.

## [1.0.6]

### Added

* Added initial boss-frame aura defaults so `Buffs` and `Debuffs` can be configured and rendered on boss units.

### Changed

* Added conservative boss aura defaults with a compact one-row attached layout, keeping `Debuffs` enabled by default and `Buffs` available but disabled by default.
* Clarified demo debug slash commands as intentional runtime-only support diagnostics.
* Restricted the legacy `UnitAura` aura scan fallback to pre-Midnight compatibility only.

### Fixed

* Fixed an unlock-editor-close cleanup gap where demo remnants could remain visible after closing the editor while frames were still unlocked.
* Removed normal-release aura cooldown debug `OnUpdate` overhead; aura cooldown debug counters now attach only while demo debug diagnostics are active.
* Fixed a raid-combat target visibility issue where the protected target frame could remain hidden after short target-loss transitions during an encounter.
* Fixed stale literal text separators remaining visible on unit frames after the live unit temporarily disappeared.
* Improved combat target-swap recovery by resynchronizing target bars, texts, auras, and castbar state with a forced aura full scan.
* Reduced combat target-swap refresh overhead by making live refreshes respect dirty scopes and avoiding layout/config work for targeted combat resyncs.

### Removed

* Nothing.

## [1.0.5]

### Added

* Added the `Shadow1` bar texture to the media selection lists so it can be chosen in the inspector.

### Changed

* Reworked inspector section expand/collapse handling to rebuild only the affected section instead of rebuilding the full inspector.
* Extended the local inspector rebuild path to cover section-local selection and structure updates where possible, while keeping `Unit` and `Quick/Expert` mode changes on full rebuilds.
* Improved inspector scroll retention logic so visible section anchors are preserved more reliably during the remaining full rebuild paths.
* Updated the default player `LeaderIcon` placement to the new attached top-right layout.

### Fixed

* Fixed large inspector scroll jumps when opening or closing grouped sections such as text elements, indicators, and aura settings.
* Fixed inspector refresh behavior so section-local changes like text element, indicator, and aura-block selection can update without forcing the full inspector back to the top.
* Fixed an editor startup state mismatch where saved `Expert Mode` could be enabled after reload while the inspector still opened in `Quick Mode` until toggled manually.

### Removed

* Nothing.

## [1.0.4]

### Added

* Added a centralized `UnitFrameDemoEnvironment` runtime path to control demo/test/unlock frame behavior from one place.
* Added `/fpdebugdemo` diagnostics commands for runtime demo inspection (`on`, `off`, `status`, `once`, `reset`).
* Added runtime demo component isolation toggles for castbar, auras, aura timers, text updates, range fade, bar smoothing, and single-unit demo filtering.
* Added demo runtime counters and reporting fields for castbar ticks/value updates, aura timer activity, bar smoothing ticks, and range-fade ticks.
* Added explicit loading/registration of the new demo environment module in runtime initialization.
* Added custom preset foundation in the existing editor preset workflow:
  * Save current layout as a custom preset.
  * Preview selected presets before committing.
  * Apply previewed preset changes.
  * Cancel preview and restore the pre-preview state.
  * Delete saved custom presets.
* Added a small save dialog (AceGUI window + edit box) to enter a custom preset name when saving.
* Added automatic duplicate-name handling for custom presets by appending a numeric suffix (for example `Name (2)`).
* Added custom preset metadata markers (`source`/`type`) and dedicated custom preset IDs for clean separation from built-in themes.

### Changed

* Migrated demo/preview mode decisions in unit-frame runtime modules to the centralized demo environment API.
* Updated class power and presence demo handling to use the demo environment instead of scattered direct preview/test checks.
* Migrated preview value and preview aura sources from `UnitFramePreview` into the centralized demo environment while keeping compatibility wrappers.
* Updated demo visibility handling so missing units are no longer force-hidden while demo visibility is intentionally active.
* Updated GUI test-mode exit handling to use centralized demo-exit cleanup instead of distributed one-off cleanup paths.
* Reduced demo debug overhead in normal operation by gating hot-path debug counters behind explicit debug enablement.
* Reduced runtime guard warning spam so guard warnings are emitted only while relevant debug modes are active.
* Reworked preset flow in the toolbar to use a safe preview session:
  * Selecting a preset now previews it.
  * `Apply` now commits the active preview.
  * `Cancel` now restores the exact state from before preview started.
* Moved custom preset storage to `profile.CustomPresets` for cleaner structure and lower risk to general profile settings.
* Updated preset copy/labels in the editor (EN/DE) for consistent `Save`, `Preview`, `Apply`, `Cancel`, and `Delete` wording.

### Fixed

* Fixed choppy demo castbar playback by running preview cast progress on a dedicated frame-based `OnUpdate` time path.
* Fixed demo castbar timing drift/restart jitter by using explicit preview start/duration tracking during preview updates.
* Fixed diagnostic usability by ensuring demo debug output is reachable through addon slash commands without requiring direct global namespace access.
* Fixed unlock-to-lock cleanup gaps where demo remnants (notably aura and absorb preview leftovers) could remain visible after leaving unlock mode.
* Fixed a preset-label localization gap (`EDITOR_PRESET_START`) so the preset dropdown label is consistently localized.

### Removed

* Nothing.

## [1.0.3]

### Added

* Added a minimum absorb visibility marker on health bars so very small absorb values remain visible even when the overlay segment is sub-pixel thin.

### Changed

* Removed temporary absorb debug slash output from the normal command surface after absorb validation.

### Fixed

* Fixed absorb overlay visibility edge cases where valid but very small absorb values could appear visually missing.

### Removed

* Nothing.

## [1.0.2]

### Added

* Added first-step absorb runtime support on unit health bars:
  * A dedicated absorb overlay layer is now created on health bars.
  * Total absorbs are captured into live values during health refresh.
  * Absorb update events are wired so overlay updates react to absorb changes.
* Added demo-preview absorb values so absorb overlays are visible and testable in demo/test mode.

### Changed

* Updated target swap runtime handling in combat to avoid destructive visual clearing on target frames during swap transitions.

### Fixed

* Fixed cases where target frames could disappear or stay visually empty during raid/combat target swaps.

### Removed

* Nothing.

## [1.0.1]

### Added

* Added a release checklist document for safer repeatable release workflow.

### Changed

* Updated default unit-frame textures:
  * Health bars use Blizzard Raid Bar Fill defaults across all core units.
  * Resource bar defaults (power/alternative power/class power where applicable) use Healbot texture.
* Enabled the `Health` text template by default for `targettarget` and `focustarget`.

### Fixed

* Fixed special-mode frame suppression so unit frames are reliably hidden while Pet Battle, Vehicle UI, or Override Action Bar modes are active.
* Fixed refresh/event handling during vehicle and override transitions so suppression also triggers correctly when entering those modes after login/reload.

### Removed

* Nothing.

## [1.0.0]

### Added

* Added support for a secondary resource bar that can display live auxiliary resources such as mana for specs that use a different primary resource.
* Added a separate class power bar with inspector support and default styling.
* Added demo aura data for editor preview mode so buff and debuff blocks can be positioned more reliably.
* Added built-in presets for faster setup and iteration.
* Added project documentation for release packaging and user onboarding.

### Changed

* Finalized the default profile layout for the first public release.
* Reworked the secondary resource bar into a proper stacked layout element instead of sharing space with the health bar.
* Improved the editor workflow and interface consistency across toolbar, inspector, and tool pages.
* Improved the presentation of rare, elite, and rare elite units with visual overlays instead of plain text.
* Improved alternative power handling to use Blizzard alternative power data more reliably.
* Reduced startup chat output to the essential load message.

### Fixed

* Fixed profile switching so only frames from the active profile remain visible.
* Fixed repeated editor refresh corruption caused by fast toolbar and minimap interactions.
* Fixed secondary resource text updates and improved runtime stability for protected WoW values.
* Fixed target frame recovery during target swaps.
* Fixed elemental shaman secondary resource rendering so mana can be displayed correctly.
* Fixed pet health bar class colors so they inherit the player class correctly.
* Fixed hidden overlay indicators still reserving layout space in some frame states.
* Fixed several editor layout and spacing inconsistencies while switching modes.

### Removed

* Removed the legacy `/fp test` slash command.
* Removed unused embedded libraries and obsolete helper files from the release package.

## [0.11.0 RC 1]

### Added

* Added a secondary resource bar flow for live auxiliary power such as mana.
* Added safer runtime handling for protected resource and color updates.

### Changed

* Finalized the release candidate default profile layout.
* Reworked the secondary resource bar into a real stacked bar layout.
* Simplified several inspector and profile UI labels ahead of release.
* Reduced startup chat noise and kept diagnostics as an explicit support tool.

### Fixed

* Fixed profile switching visibility issues.
* Fixed repeated editor refresh corruption from fast UI interactions.
* Fixed live updates for the secondary resource text.
* Fixed target frame recovery during target swaps.
* Fixed elemental shaman secondary resource rendering.

### Removed

* Removed the legacy `/fp test` slash command.
* Removed unused libraries and obsolete helper files.

## [0.11.0 Beta 13]

### Added

* Added a separate class power bar with inspector support and defaults.
* Added higher-quality frame and portrait overlay effects for classification, combat, and resting indicators.
* Added demo aura data in editor preview mode.
* Added project documentation files for release packaging and distribution.

### Changed

* Reworked rare, elite, and rare elite presentation toward visual overlays.
* Reworked alternative power handling to use Blizzard alternative power data.
* Improved toolbar stability when switching between Quick Mode and Expert Mode.
* Improved class power customization with independent inspector color and transparency settings.

### Fixed

* Fixed pet health bar class colors.
* Fixed hidden overlay indicators still reserving layout space in some frame states.
* Fixed editor toolbar label and spacing instability while toggling modes.

### Removed

* Removed several weak texture presets from the bar texture selection.
* Removed obsolete GUI layout modules and legacy preview files.
