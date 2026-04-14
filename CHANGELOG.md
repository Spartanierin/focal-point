# Changelog

All notable user-facing changes to this project should be documented in this file.

This changelog follows a simple structure:
- `Added` for new features
- `Changed` for behavior or UX updates
- `Fixed` for bug fixes
- `Removed` for removed functionality

## [Unreleased]

### Added
- Nothing yet.

### Changed
- Nothing yet.

### Fixed
- Nothing yet.

### Removed
- Nothing yet.

## [0.11.0 RC 1]

### Added
- Added a secondary resource bar flow that can display live auxiliary power such as mana for specs that use a different primary resource.
- Added safer runtime handling for secret-value based resource and color updates.

### Changed
- Finalized the default profile layout and promoted the current release candidate defaults from the live `Aradia - Lordaeron` setup.
- Reworked the secondary resource bar so it behaves like a real stacked bar in the frame layout instead of stealing height from the health bar.
- Simplified and clarified several inspector and profile UI labels ahead of release.
- Reduced startup chat noise to the essential load message and kept diagnostics as an explicit support tool.

### Fixed
- Fixed profile switching so only frames from the active profile remain visible.
- Fixed repeated editor refresh corruption caused by fast minimap and toolbar interactions.
- Fixed secondary resource live text updates and hardened them against secret-value pitfalls.
- Fixed target frame recovery during target swaps by adding extra visibility rebind refreshes.
- Fixed elemental shaman secondary resource rendering so mana can be shown live without abusing class power.

### Removed
- Removed the legacy `/fp test` slash command.
- Removed unused embedded libraries and obsolete helper files from the packaged addon.

## [0.11.0 Beta 13]

### Added
- Added a separate class power bar with inspector support and defaults.
- Added higher-quality frame and portrait overlay effects for classification, combat, and resting indicators.
- Added demo aura data in editor preview mode so buff and debuff blocks can be positioned reliably.
- Added project documentation files for release packaging and distribution.

### Changed
- Reworked rare, elite, and rare elite presentation away from plain text toward visual overlays.
- Reworked alternative power handling to use Blizzard alternative power data instead of preview-only heuristics.
- Improved toolbar layout stability when switching between Quick Mode and Expert Mode.
- Improved class power customization with independent inspector color and transparency settings.

### Fixed
- Fixed pet health bar class colors so they inherit the player class correctly.
- Fixed hidden overlay indicators still reserving internal layout space in some frame states.
- Fixed editor toolbar label and spacing instability while toggling editor modes.

### Removed
- Removed several weak texture presets from the bar texture selection.
- Removed obsolete GUI layout modules and legacy preview files that were no longer used.
