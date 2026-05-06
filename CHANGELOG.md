# Changelog

All notable user-facing changes to Focal Point are documented in this file.

This changelog uses the following categories:

* `Added` for new features
* `Changed` for behavior, UX, or visual updates
* `Fixed` for bug fixes
* `Removed` for removed functionality

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
