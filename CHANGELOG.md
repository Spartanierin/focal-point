# Changelog

All notable user-facing changes to Focal Point are documented in this file.

This changelog uses the following categories:

* `Added` for new features
* `Changed` for behavior, UX, or visual updates
* `Fixed` for bug fixes
* `Removed` for removed functionality

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
