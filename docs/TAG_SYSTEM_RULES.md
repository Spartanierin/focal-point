# Portrait Tag System Rules

## Purpose

This document defines the rules for Portrait's tag system and template content layer.

It complements `ARCHITECTURE.md`:

- `ARCHITECTURE.md` explains the larger text system model
- this file explains how tags and inline formatting should behave inside that model

The tag system exists to produce stable rendered text from prepared runtime data.  
It is not intended to be a general calculation layer.

## Architectural Position

Portrait's text architecture is based on a strict separation:

- **template** = content, including tags and inline formatting
- **text element** = presentation, placement, font, base color, and effects
- **tag resolution** = centralized runtime logic
- **rendering** = visible output on the frame

That separation must remain intact.

### Important consequence

Tags belong to the content layer.

That means tags may define:

- which unit data appears
- how segments are formatted inline
- where inline colors begin and end

Tags must not become a replacement for:

- layout configuration
- positioning
- font settings
- default text element color
- visual effects such as shadow

## Why the Rules Are Strict

Modern Retail WoW can expose some unit data as secret values.

Those values may still work when handed directly to Blizzard UI functions, but they become unstable when addons try to:

- compare them
- divide them
- parse them
- use them as table keys
- reshape them as strings

Because of that, Portrait tags should prefer prepared display values over raw unit API values whenever possible.

## Core Rules

### 1. Tags Prefer Prepared Display Values

A tag should first read from prepared values such as `frame.LiveValues`.

Preferred examples:

- `healthCurrentText`
- `healthMaxText`
- `healthPercentText`
- `healthCurrentAbbr`
- `powerCurrentText`
- `powerMaxText`
- `powerPercentText`
- `altPowerCurrentText`
- `altPowerMaxText`

Avoid as a primary tag source:

- direct `UnitHealth(...)`
- direct `UnitHealthPercent(...)`
- direct `UnitPower(...)`
- direct `UnitPowerMax(...)`

### 2. Tags Return Display Values, Not Work Values

Tags should usually return:

- a final string
- or a value already known to be safe for direct formatting

Good:

- `[hp:perc]` -> `healthPercentText`
- `[power:cur:abbr]` -> `powerCurrentAbbr`

Avoid:

- computing percentages inside the token resolver
- rebuilding abbreviations inside the token resolver
- parsing rendered output back into numbers during normal runtime

### 3. Formatting Belongs in Refresh Helpers

Formatting and normalization should happen before tag rendering.

Preferred flow:

1. collect runtime values
2. normalize them into display-ready fields
3. resolve tags from those prepared fields

This keeps token resolvers simple and predictable.

### 4. Raw Values Are Only Acceptable for Direct Pass-Through Output

Raw values are acceptable only when the result is passed straight through for display and not manipulated further.

Acceptable examples:

- showing a current HP number directly
- showing a current power number directly

Unsafe follow-up work on volatile values includes:

- arithmetic
- `tonumber(...)` rescue chains
- table indexing
- string surgery on protected strings

### 5. Layout and Text Resolution Stay Separate

Text updates must not depend on layout rebuilds.

Preferred structure:

- refresh runtime values
- resolve templates and tags
- update text objects
- keep layout/config application separate

This prevents text bugs from hiding inside full frame rebuilds.

### 6. Test Mode Uses Explicit Preview Values

Test mode should use normal Lua preview values prepared in `frame.TestValues` and related preview paths.

Tags in test mode should not depend on live unit APIs.

## Templates and Raw Tag Strings

Portrait supports two content sources for a text element:

1. a linked template via `templateName`
2. a direct raw string via `tag`

### Preferred rule

`templateName` is the primary path.

The direct `tag` string exists as:

- fallback
- migration path
- expert path
- one-off special case

The system should keep moving toward template-first content, not away from it.

## Inline Color Rules

Inline color tags are part of the template content layer.

Examples:

- `[color:class]`
- `[color:blizz_pwr]`
- `[color:reaction]`
- `[color:blizz_yellow]`
- `[color:ffcc00]`
- `[rc]`

### Meaning

- inline color tags affect only segments inside the resolved text string
- they do not redefine the base presentation color of the text element

### Reset rule

`[rc]` resets inline color formatting back to the text element's configured base color.

This is a key architectural rule:

- global text color remains part of the text element's presentation
- inline colors remain part of the content string
- reset tags return from content-level formatting to element-level default color

The two layers must not be merged conceptually.

## Supported Color Syntax

The documented color syntax is the unified `[color:...]` format plus `[rc]`.

Supported forms include:

- `[color:class]`
- `[color:blizz_pwr]`
- `[color:reaction]`
- `[color:blizz_yellow]`
- `[color:blizz_red]`
- `[color:blizz_green]`
- `[color:blizz_highlight]`
- `[color:ffcc00]`
- `[color:#ffcc00]`
- `[color:aarrggbb]`
- `[rc]`

Legacy color tags may remain parser-compatible for migration purposes, but they are not the preferred documented syntax.

## Abbreviation Policy

Portrait currently uses Blizzard abbreviation output for `:abbr` tags.

### Current rule

- abbreviation values are prepared before tag rendering
- Portrait calls Blizzard's `AbbreviateLargeNumbers(...)`
- the returned string is used directly
- Portrait does not rewrite casing, spacing, suffixes, or separators afterward
- if Blizzard does not return a usable string, Portrait falls back to prepared display text

### Why

This is currently the most stable approach under Retail secret-value behavior.

It avoids:

- addon-side number reconstruction
- risky post-processing
- reformatting of possibly protected values

### Consequence

Output may differ from Portrait's earlier custom styling.

Examples:

- uppercase `K`
- spaces before suffixes
- locale-specific separators

That is acceptable as long as the output is stable and directly sourced from Blizzard formatting.

## Recommended Runtime Data Layers

For each bar-like domain, Portrait should maintain three conceptual layers.

### Raw

Only when needed for direct UI handoff.

Examples:

- `healthCurrentRaw`
- `healthMaxRaw`
- `powerCurrentRaw`
- `powerMaxRaw`

### Safe Numeric

Only if a proven safe conversion path exists.

Examples:

- `healthCurrentSafe`
- `healthMaxSafe`
- `powerCurrentSafe`
- `powerMaxSafe`

These are optional, not guaranteed.

### Display

This is the preferred tag source.

Examples:

- `healthCurrentText`
- `healthMaxText`
- `healthPercentText`
- `healthCurrentAbbr`
- `healthMaxAbbr`
- `powerCurrentText`
- `powerMaxText`
- `powerPercentText`
- `powerCurrentAbbr`
- `powerMaxAbbr`
- `altPowerCurrentText`
- `altPowerMaxText`

## Current Practical Assessment

### Stable / Good Enough

These already fit the intended direction reasonably well:

- `hp:cur:abbr`
- `hp:max:abbr`
- `power:cur:abbr`
- `power:max:abbr`
- `altpower:cur:abbr`
- `altpower:max:abbr`
- `hp:perc`
- `power:perc`
- `perhp`

These prefer prepared display values.

### Still Worth Cleaning Up Later

These still retain narrower fallback behavior and should gradually move toward display-first-only resolution:

- `hp:cur`
- `hp:max`
- `power:cur`
- `power:max`
- `curhp`
- `maxhp`
- `curpp`
- `maxpp`

### Current Risk Profile

The highest remaining risk is no longer the token definitions themselves.

The bigger risk sits in runtime value preparation whenever volatile unit data still has to be normalized.

## Recommended Direction

### Short term

- keep percent tags sourced from prepared text values
- continue using prepared abbreviation values
- reduce direct live-unit fallbacks where possible

### Medium term

Split display preparation by domain:

- `RefreshHealthDisplayValues`
- `RefreshPowerDisplayValues`
- `RefreshAltPowerDisplayValues`

Then let tags consume only those prepared domain values.

### Long term

Classify tokens explicitly as:

- safe display tokens
- compatibility tokens
- risky legacy fallback tokens

Then deprecate risky fallback behavior gradually once templates and defaults are fully migrated.

## Rule of Thumb

If a token requires math, parsing, lookup tricks, or string surgery at render time, it is probably operating in the wrong layer.

Portrait tags should mostly do this:

1. read prepared value
2. format only if trivial
3. render
