# Architecture Overview

STATUS: CURRENT - current system map for Focal Point 1.2.x.

## Purpose

This document describes the implemented architecture. It replaces the old architecture overviews in `Historical/0.x-Architecture/` as the current orientation point.

## Major areas

### Bootstrap and Core

- `FocalPoint.toc` and `Init.xml` define load order and modules.
- `FocalPoint.lua` sets up the addon, SavedVariables/AceDB, migrations, and global initialization.
- `Engine/Core.lua` connects runtime, editor interaction, frame positioning, unlock, multi-selection, dragging, and central refresh actions.

### GUI and Editor

- `GUI/GUIMainController.lua`, `GUI/GUIController.lua`, and `GUI/AppShell.lua` provide the host, navigation, and window shell.
- `GUI/Editor/*` contains editor-specific runtime: Toolbar, Inspector, frame editing, text overlay, and Media Library.
- `GUI/Pages/*` contains standalone tools: Profiles/Layouts, Text Builder, and Tag Database.

### Services

- `Services/MediaRegistry.lua`: canonical media resolution for status bars, fonts, and decorations.
- `Services/PresetService.lua` and `Services/UserPresetStore.lua`: unified read view for built-in and user presets.
- `Services/ProfileLayoutService.lua`: creates profiles from presets.
- `Services/ProfileAutomation.lua`: handles mappings such as Specialization -> Profile.
- `Services/ProfileTransfer.lua`: profile export/import.
- `Services/ThemeService.lua` and `Services/LegacyThemeAdapter.lua`: still-present 1.x/legacy bridge for preset application, not the long-term product model for Style.

### UnitFrame Runtime

- `Engine/UnitFrame.lua` is the central orchestrator for ApplyConfig, components, and text application.
- `Engine/UnitFrame/Runtime/*` owns build, factory, layout, visibility, refresh, state, and lifecycle diagnostics.
- `Engine/UnitFrame/Bars/*` owns Health, Power, Cast, ClassPower, and AbsorbBars.
- `Engine/UnitFrame/Indicators/*` owns Portrait, Indicators, Decorations, and visual indicator helpers.

### Text Runtime

- `Engine/TextElements.lua` integrates the text runtime into UnitFrames.
- `Engine/Text/Shared/*` contains resolvers, templates, tags, status/color logic, and mutations.
- `Engine/Text/Runtime/*` contains apply/update/state for visible text objects.
- `GUI/Pages/TextBuilder/*` and `GUI/Pages/TagDatabase/*` are tools for template creation and tag reference.

### Auras

- `Engine/Auras/*` contains runtime, layout, managed backend, and legacy/demo rendering.
- On WoW 12.1, the live path uses Blizzard Managed Auras for supported groups. Demo/Unlock use Focal Point data with shared visual semantics.

## Canonical data flows

### Config to runtime

1. AceDB/SavedVariables store profiles and global data.
2. Profile config lives under `db.profile`, especially `Units`, `TextTemplates`, and `General`.
3. UnitFrame build creates frames and components.
4. `ApplyConfig` reads unit configuration and applies layout, style, and components.
5. Refresh paths update LiveValues, auras, text, and visibility.

### Runtime to visuals/text

- Health/Power/Cast/Aura runtime reads WoW or demo data.
- Canonical runtime values live in `frame.LiveValues` and component-specific runtime fields.
- Visuals consume runtime values directly or through their bar/aura helpers.
- Text consumes prepared display values and does not reconstruct truth from rendered bars.

## Canonical sources

- Profile/layout truth: `db.profile.Units`, `db.profile.TextTemplates`, `db.profile.General`.
- User-preset truth: `db.global.UserPresets` through `UserPresetStore`.
- Spec automation truth: `db.global.ProfileAutomation` through `ProfileAutomation`.
- Media truth: `MediaRegistry`.
- Health Family live values: `UnitFrameHealth` writes `frame.LiveValues`; bars and tags consume them.

## Legacy and transition points

- ThemeService/LegacyThemeAdapter remain as a 1.x bridge for preset application.
- Old theme-system documents are historical.
- Direct `tag` strings in TextElements remain as fallback/expert/migration paths; template-first is the preferred product path.
