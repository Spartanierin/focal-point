STATUS: HISTORICAL - old theme implementation plan; Style/Stylist is future direction only.

# Theme Implementation Plan

## Goal

Add a V1 theme and quick-start system that improves first-use UX without introducing a second configuration model.

## Scope

V1 should deliver:

- theme data definitions
- a safe theme apply service
- a simple GUI entry point
- three strong starter themes

## Step 1: Theme Data Source

Add:

- `Data/Themes.lua`

Responsibilities:

- register `FocalPoint.Themes`
- expose metadata and unit preset data
- contain no runtime logic

Done when:

- themes can be resolved by stable `id`
- theme definitions are readable and localized through label keys if needed later

## Step 2: Theme Apply Service

Add:

- `Services/ThemeService.lua`

Responsibilities:

- find theme by `id`
- merge theme fields into active profile
- preserve unrelated profile fields
- trigger a normal refresh path afterwards

Key rules:

- controlled deep merge
- no profile wipe
- no runtime state mutation
- no hidden one-off hacks

Done when:

- `ApplyTheme(themeId)` works against the active profile
- frames visibly update after application

## Step 3: Minimal GUI Entry

Add a simple GUI entry point under General, for example:

- `Themes`
- or `Quick Start`

V1 entry should show:

- theme name
- one-line description
- apply button

Done when:

- a user can apply a theme without touching the raw configuration pages

## Step 4: First Theme Set

Implement:

- `Classic`
- `Minimal`
- `Modern`

Done when:

- each theme looks intentionally different
- each theme is immediately usable in game
- no theme requires further mandatory cleanup before use

## Step 5: Quickmode Layer

Build a small guided layer on top of themes.

V1 choices:

- style
- portrait preference
- aura density

Quickmode should:

- select one base theme
- apply a few explicit follow-up overrides

Done when:

- a new user can get a decent layout in under a minute

## Guardrails

### Do not

- build a second profile system
- hardcode theme behavior into frame runtime
- overload themes with rare specialist options
- mix GUI-specific metadata into runtime preset data

### Do

- keep themes declarative
- keep the apply path centralized
- reuse the normal refresh/runtime pipeline
- document every field class themes are allowed to own

## Documentation Tasks

When implementation starts, update:

- `docs/ARCHITECTURE.md`
- `docs/SYSTEM_MAP.md`
- `docs/THEME_SYSTEM_V1.md`

The theme system should remain visible as a first-class product layer, not an afterthought.

