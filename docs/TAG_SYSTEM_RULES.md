# Tag System Rules

## Goal

Portrait tags should render stable UI text from prepared display values.
Tags should not be responsible for reconstructing or transforming volatile live unit data at render time.

This matters because modern Retail WoW can expose unit data as secret values. Those values may still work for direct Blizzard UI APIs, but they can break when addons try to:

- compare them
- divide them
- parse them
- use them as table keys
- manipulate them as strings

The tag system should therefore prefer display-ready values over raw unit API calls.

## Core Rules

### 1. Tags Prefer `frame.LiveValues`

A tag should first read from `frame.LiveValues`.

Good:
- `healthCurrentText`
- `healthMaxText`
- `healthPercentText`
- `powerCurrentText`
- `powerMaxText`
- `altPowerCurrentText`
- `altPowerMaxText`

Avoid:
- direct `UnitHealth(...)`
- direct `UnitHealthPercent(...)`
- direct `UnitPower(...)`
- direct `UnitPowerMax(...)`

Exception:
- direct unit API access is acceptable as a final fallback when the result is only passed through for display and not processed further

### 2. Tags Return Display Values, Not Work Values

Tags should usually return:
- a final string
- or a value that is already known to be safe for formatting

Avoid using tag templates as a calculation layer.

Good:
- `[hp:perc]` -> uses `healthPercentText`
- `[power:cur:abbr]` -> uses `powerCurrentAbbr`

Avoid:
- computing a percent inside the token resolver
- recomputing abbreviated values inside the token resolver
- parsing rendered text back into numbers inside normal runtime paths

### 3. Formatting Belongs in Refresh Helpers

Formatting and normalization should happen before tag rendering.

Preferred pattern:
- collect runtime data
- normalize it into `frame.LiveValues`
- render tags from those prepared values

This keeps token resolvers simple and predictable.

### 4. Raw Values Are Allowed Only for Direct Text Output

Raw values are acceptable when the tag only displays them and does not manipulate them.

Examples:
- current HP as a number string
- current Power as a number string

Unsafe follow-up work on raw values:
- arithmetic
- `tonumber(...)` rescue chains
- table indexing
- string token surgery on secret strings

### 5. Layout and Text Rendering Stay Separate

Text updates should not be coupled to layout rebuilds.

Preferred structure:
- refresh runtime values
- update text objects
- keep layout/config application separate

This prevents text bugs from being hidden inside full frame refreshes.

### 6. Test Mode Uses Explicit Dummy Values

Test mode should always use normal Lua values prepared in `frame.TestValues` / `frame.LiveValues`.

Tags in test mode should never depend on live unit API calls.

## Recommended Data Model

For each bar-like domain, maintain three layers:

### Raw

Only when needed for direct UI handoff.

Examples:
- `healthCurrentRaw`
- `healthMaxRaw`
- `powerCurrentRaw`
- `powerMaxRaw`

### Safe Numeric

Only if we have a proven safe conversion path.

Examples:
- `healthCurrentSafe`
- `healthMaxSafe`
- `powerCurrentSafe`
- `powerMaxSafe`

These should be treated as optional, not guaranteed.

### Display

Preferred tag source.

Examples:
- `healthCurrentText`
- `healthMaxText`
- `healthPercentText`
- `healthCurrentAbbr`
- `healthMaxAbbr`
- `powerCurrentText`
- `powerMaxText`
- `powerCurrentAbbr`
- `powerMaxAbbr`

## Abbreviation Style

Portrait currently uses Blizzard number abbreviation output for `:abbr` tags.

### Current Rule

- `:abbr` values are prepared before tag rendering
- Portrait calls Blizzard's `AbbreviateLargeNumbers(...)`
- the returned string is used directly
- Portrait does not normalize casing, spacing, suffixes, or separators afterward
- if Blizzard abbreviation does not return a usable string, Portrait falls back to the prepared display text

### Why

- this is currently the most stable path under Retail secret value behavior
- it avoids further parsing or manipulation of potentially protected values
- it keeps the tag system simple: prepared display values in, rendered text out

### Consequence

- output may differ from earlier Portrait-specific styling
- examples:
  - uppercase `K`
  - spaces before suffixes
  - locale-specific separators
- this is acceptable by design as long as the output is stable and direct from Blizzard

## Color Tags

Portrait supports inline color tags as lightweight formatting prefixes inside templates.

### Current Rule

- color formatting is applied inline through `[color:...]`
- color reset uses `[rc]`
- the returned color escape codes are used directly
- templates may combine multiple color prefixes with normal data tags
- legacy color tags may remain parser-compatible, but the documented syntax is the unified `[color:...]` form

### Supported Forms

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

### Guidance

- use color tags as prefixes around existing data tags
- prefer short, explicit sequences over long nested constructions
- keep color tags declarative; they should resolve to a color code, not perform additional formatting work

Examples:
- `[color:class][name][rc]`
- `[color:blizz_pwr][power:cur][rc]`
- `[color:blizz_yellow][level] [classification][rc]`

## Current Findings In `TextElements.lua`

### Safe / Good Enough

- `hp:cur:abbr`
- `hp:max:abbr`
- `power:cur:abbr`
- `power:max:abbr`
- `altpower:cur:abbr`
- `altpower:max:abbr`
- `perhp`

These already prefer prepared display values.
For `:abbr`, that prepared value is now the direct Blizzard abbreviation string or a plain display-text fallback.

### Needs Cleanup

- `hp:cur`
- `hp:max`
- `power:cur`
- `power:max`
- `curhp`
- `maxhp`
- `curpp`
- `maxpp`

These still keep a narrow fallback path and should eventually move to prepared text variants only.

### Highest Risk

- no longer the primary percent path for `hp:perc` and `power:perc`
- remaining risk is mostly in the broader runtime value preparation, not in the token definitions themselves
- `:abbr` is intentionally delegated to Blizzard formatting instead of Portrait-side math

## Recommended Next Adjustments

### Short Term

- keep `hp:perc` and `perhp` sourced from `healthPercentText`
- add prepared display fields for:
  - `powerPercentText`
  - `altPowerPercentText` if needed later
- reduce the remaining direct unit API fallbacks in token resolvers
- keep abbreviation policy conservative: prefer direct Blizzard output over Portrait-side rewriting

### Medium Term

- split refresh helpers by domain:
  - `RefreshHealthDisplayValues`
  - `RefreshPowerDisplayValues`
  - `RefreshAltPowerDisplayValues`
- let tags consume only those domain display values

### Long Term

- document which tokens are:
  - safe display tokens
  - compatibility/legacy tokens
  - risky raw fallback tokens
- deprecate risky legacy fallbacks gradually once defaults and user templates have migrated

## Practical Rule Of Thumb

If a token needs math, parsing, lookup tricks, or string surgery at render time, it is probably in the wrong layer.

Portrait tags should mostly be:
- read prepared value
- format if trivial
- render
