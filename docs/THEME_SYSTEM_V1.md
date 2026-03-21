# FocalPoint Theme System V1

## Purpose

Themes and Quickmode are meant to turn FocalPoint from a flexible builder into a fast-start product.

The goal for V1 is not to replace the normal configuration UI.
The goal is to provide strong starting points that:

- look intentional immediately
- are usable with minimal setup
- remain fully editable afterwards

Themes are presets.
Quickmode is a guided entry point built on top of those presets.

## Design Principles

### Themes are data, not behavior

Themes must be defined as structured data.

They should not contain:

- runtime logic
- hidden conditional behavior
- UI-only hacks
- feature-specific code paths

All behavior belongs in a dedicated apply layer.

### Theme application is a starting point, not a lock

After applying a theme, all normal GUI options remain editable.

The theme system must not create a parallel configuration universe.

### V1 favors strong defaults over full completeness

Themes should only touch the fields that visibly shape the frame.

V1 should avoid becoming a second full profile system.

## V1 Theme Scope

Themes should primarily define:

- frame proportions and baseline look
- portrait usage
- bar layout
- major text slots
- indicator visibility
- aura baseline layout

Themes should not try to own every advanced option in V1.

## Recommended Theme Set

### Classic

- familiar
- readable
- Blizzard-adjacent
- safe default starting point

### Minimal

- compact
- low visual noise
- reduced information density

### Modern

- stronger visual identity
- more deliberate surfaces and spacing
- better showcase theme

Later themes can include healer and arena-focused variants, but V1 should stay small and strong.

## Theme Data Shape

Theme definitions should live in:

- `Data/Themes.lua`

Suggested shape:

```lua
local _, FocalPoint = ...

FocalPoint.Themes = {
    Classic = {
        id = "classic",
        label = "Classic",
        description = "Familiar, clear, Blizzard-adjacent.",

        global = {
        },

        units = {
            player = {
                frame = {
                    width = 220,
                    height = 44,
                    scale = 1,
                    alpha = 1,
                    backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 0.30 },
                    borderColor = { r = 0, g = 0, b = 0, a = 0 },
                    healthBackgroundColor = { r = 0, g = 0, b = 0, a = 0.65 },
                    powerBackgroundColor = { r = 0.05, g = 0.06, b = 0.06, a = 0.39 },
                    healthBarTexture = "BetterBlizzard",
                    powerBarTexture = "BetterBlizzard",
                },

                portrait = {
                    showPortrait = true,
                    portraitInside = true,
                    portraitInsideSide = "LEFT",
                    portraitSize = 42,
                },

                bars = {
                    showPowerBar = true,
                    showAlternativePowerBar = true,
                    healthBarHeight = 32,
                    powerBarHeight = 10,
                },

                indicators = {
                    showRaidTargetIcon = true,
                    showLeaderIcon = true,
                    showRoleIcon = true,
                    showCombatIndicator = true,
                    showRestingIndicator = true,
                    showReadyCheckIndicator = true,
                },

                texts = {
                    Name = {
                        enabled = true,
                        tag = "[name]",
                        point = "LEFT",
                        anchorTo = "HealthBar",
                        offsetX = 6,
                        offsetY = 0,
                        fontSize = 14,
                    },
                    Health = {
                        enabled = true,
                        tag = "[hp:cur] / [hp:max] | [hp:perc]%",
                    },
                },

                auras = {
                    Buffs = {
                        enabled = true,
                        mode = "ATTACHED",
                        iconSize = 25,
                        iconsPerRow = 4,
                        maxRows = 2,
                        growthX = "RIGHT",
                        growthY = "UP",
                        spacingX = 2,
                        spacingY = 10,
                        showStackText = true,
                        showTimerText = true,
                        showOnlyMine = false,
                        hidePermanentAuras = true,
                        hideLongAuras = true,
                    },
                    Debuffs = {
                    },
                },
            },

            target = {
            },
        },
    },
}
```

## V1 Field Categories

### Frame

Theme-owned V1 fields:

- `width`
- `height`
- `scale`
- `alpha`
- `backgroundColor`
- `borderColor`
- `healthBackgroundColor`
- `powerBackgroundColor`
- `healthBarTexture`
- `powerBarTexture`

### Portrait

Theme-owned V1 fields:

- `showPortrait`
- `portraitInside`
- `portraitInsideSide`
- `portraitSize`
- `portraitAnchorTo`
- `portraitPoint`
- `portraitOffsetX`
- `portraitOffsetY`

### Bars

Theme-owned V1 fields:

- `showPowerBar`
- `showAlternativePowerBar`
- `healthBarHeight`
- `powerBarHeight`

### Indicators

Theme-owned V1 fields:

- `showRaidTargetIcon`
- `showLeaderIcon`
- `showRoleIcon`
- `showCombatIndicator`
- `showRestingIndicator`
- `showReadyCheckIndicator`

### Texts

Themes should only set the most visible text slots in V1.

Typical slots:

- `Name`
- `Health`
- `Power`
- `Level`
- `CastName`
- `CastTime`

Themes may define:

- enabled
- template/tag
- point / anchor
- offsets
- font size

Themes should not try to own every shadow and font detail in V1.

### Auras

Per `Buffs` and `Debuffs`, themes may define:

- `enabled`
- `mode`
- `iconSize`
- `iconsPerRow`
- `maxRows`
- `growthX`
- `growthY`
- `spacingX`
- `spacingY`
- `showStackText`
- `showTimerText`
- `showOnlyMine`
- `hidePermanentAuras`
- `hideLongAuras`

## Apply Strategy

Theme application should be handled by a dedicated service, for example:

- `Services/ThemeService.lua`

The service should:

1. resolve a theme by `id`
2. validate that the theme exists
3. apply `global`
4. apply `units[unit]`
5. trigger a controlled GUI and frame refresh

### Merge Rules

Themes should use a controlled deep merge.

Rules:

- only fields defined in the theme are overwritten
- unrelated fields in the profile remain untouched
- nested tables are merged recursively
- lists or slot tables are replaced only where explicitly intended

For V1 this means:

- `player.frame.width` in a theme may overwrite only that width
- `player.texts.Name` may overwrite that slot
- untouched text slots remain as they are

### Safety Rules

Theme application must:

- never wipe the entire profile
- never touch runtime/debug state
- never depend on current combat state
- never inject hidden side effects

If a theme omits a field, that field must stay unchanged.

## Refresh Strategy After Apply

After a theme is applied:

1. profile data is updated
2. unit frames receive a normal controlled refresh
3. GUI state is refreshed
4. no ad hoc element-specific hacks should run

Theme application should reuse the normal runtime refresh path.

## Quickmode Relationship

Quickmode should sit above themes, not beside them.

Suggested V1 flow:

1. choose a base style
   - Classic
   - Minimal
   - Modern
2. choose portrait preference
   - inside
   - outside
   - off
3. choose aura density
   - compact
   - visible

Quickmode then applies:

- one theme
- a very small set of follow-up overrides

This keeps Quickmode easy to reason about and avoids a separate preset engine.

## Architecture Boundaries

### Themes may know

- profile field structure
- theme metadata
- unit-level visual presets

### Themes should not know

- runtime queue or commit details
- aura cache internals
- text token internals
- GUI layout internals

### Theme apply service may know

- where theme data lives
- how to merge theme fields into profile data
- how to trigger normal refresh

### Theme apply service should not know

- actual rendering internals of bars, auras, or text

## V1 Non-Goals

The first theme system should not try to solve:

- full profile templating
- import/export of themes
- partial apply modes such as "colors only"
- automatic migration of old theme versions
- highly adaptive or conditional themes

Those can come later if the basic theme system proves useful.

## Recommended Implementation Order

1. `Data/Themes.lua`
2. `Services/ThemeService.lua`
3. GUI entry point for theme selection
4. `Classic`, `Minimal`, `Modern`
5. small Quickmode flow on top

## Summary

For V1, themes should be:

- data-driven
- visually meaningful
- narrowly scoped
- safe to apply
- easy to override afterwards

Quickmode should reuse those themes rather than inventing a second preset model.
