# Product Model

STATUS: CURRENT - canonical product language for Focal Point 1.2.x.

## Core model

Focal Point is a visual unit-frame editor. Users edit profiles that describe visible unit frames. Presets and automation help with starting points, reuse, and switching, but they do not replace the active profile.

## Terms

### Unit Frame

A configured frame for a WoW unit such as Player, Target, Focus, Boss, TargetTarget, or FocusTarget. It consists of visual components such as Health Bar, Power Bar, Absorb Bars, Cast Bar, Text, Auras, Indicators, and Decorations.

### Profile

The active, editable layout. Normal editor changes are written to the current profile. A profile is the canonical working truth for visible frames.

### Preset

A reusable layout template. A preset is not a permanent binding. When a preset is applied or used to create a profile, the result is an editable profile state.

### Built-in Preset

A bundled template. Built-in presets are read-only. They can be previewed, applied, or used as the starting point for a new profile.

### User Preset

A user-saved template, for example through `Profile -> Save as Preset`. User presets are manageable, but they are also not permanent bindings to profiles.

### Preview Preset

A temporary preview state used to inspect a preset before applying it permanently to a profile or creating a profile from it.

### Create Profile

Creates a new profile from a preset. After creation, the new profile is a normal editable profile.

### Automation

Automatically switches profiles, for example Specialization -> Profile. `Unassigned` means: keep the current profile.

### Demo

Demo shows artificial data for design work, independent of whether live units currently exist. Demo does not change the product model of profiles.

### Unlock / Editor

Unlock makes frames visible and movable. Disabled units can become visible in the editor so they can be configured.

### Text Elements and Templates

Text Elements are visible text objects with position, font, color, and other presentation values. Templates describe content, including tags. Product workflows should keep users close to visible text and reusable templates without forcing them to understand technical internals too early.

## Workflow

Canonical workflow:

1. Edit a profile.
2. Use `Save as Preset` when needed.
3. Preview a preset.
4. Create a new profile from a preset or apply a preset.
5. Optionally configure automation that selects profiles.

## Health Family

The Health Family includes:

- Health Bar
- Normal Absorb Bar
- Healing Absorb Bar

Normal Absorb and Healing Absorb belong conceptually to the Health Family, but they are geometrically independent bars. They may look like layers or be positioned separately. No artificial product mode such as `Layer/Separate` is required.

Canonical live values are produced by the health runtime path (`UnitFrameHealth` and `frame.LiveValues`). Visuals and text consume these values. Text does not reconstruct truth from rendered bars.

## Style / Stylist

Style or Stylist is a long-term FUTURE layer for visual transformations. It is not currently part of the implemented Profile/Preset model and must not be documented as existing architecture.

