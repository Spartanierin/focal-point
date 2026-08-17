STATUS: CURRENT - canonical aura time-classification rule.

# FocalPoint Aura Time Classification

## Purpose

This document explains how FocalPoint classifies buffs and debuffs into timed
and not-timed states, which Blizzard data is used for that decision, and which
fallback states still exist in the runtime.

The goal is to preserve the reasoning behind the current implementation so we do
not have to rediscover it later.

## Core Rule

FocalPoint does **not** treat `durationObject present` as equivalent to
`timed aura`.

Instead, the runtime distinguishes between:

- `TIMED`
- `PERMANENT`
- `PENDING`
- `UNRESOLVED`

These states are produced in
[AuraScan.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Auras/Runtime/AuraScan.lua)
by `ResolveTimeModel(...)`.

## Blizzard Data Sources

The runtime currently evaluates time information from these Blizzard-facing
sources:

1. Raw aura fields from `AuraData`
- `duration`
- `expirationTime`

2. Aura identity and lookup
- `auraInstanceId`
- `C_UnitAuras.GetAuraDataByAuraInstanceID(...)`

3. Blizzard duration object
- `C_UnitAuras.GetAuraDuration(unit, auraInstanceId)`

The returned `durationObject` is the most important non-raw source. It is read
through `ReadDurationObjectFields(...)` in
[AuraScan.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Auras/Runtime/AuraScan.lua).

## What Blizzard Actually Gives Us

### Timed auras

Timed auras can be identified when at least one of these paths is usable:

- raw `duration > 0` and raw `expirationTime > 0`
- `durationObject:GetRemainingDuration()` returns a positive value
- `durationObject:GetDuration()` or `GetTotalDuration()` returns a positive value
- `durationObject:GetStartTime()` plus duration can be resolved into an
  expiration time

If one of those paths succeeds, FocalPoint classifies the aura as:

- `durationState = TIMED`
- `timerState = READY`

### Explicitly not timed / permanent auras

Permanent auras can be identified in two explicit ways:

1. Raw permanent signal
- raw `duration = 0`
- raw `expirationTime = 0`

2. Explicit zero-timer object
- `durationObject` exists
- the object exposes a real duration signal
- but all readable timer values resolve to zero

The second case matters because Blizzard may return a `LuaDurationObject` even
when the aura is not actually timed.

This is how mount buffs are currently identified correctly:

- raw duration = `0`
- raw expirationTime = `0`
- duration object methods resolve to zero

If that happens, FocalPoint classifies the aura as:

- `durationState = PERMANENT`
- `timerState = HIDDEN`
- `durationSource = object-zero`

## Why `durationObject` Alone Is Not Enough

Blizzard may return a `durationObject` for both:

- real timed auras
- auras that are effectively not timed

Because of that, FocalPoint does **not** use this rule:

- `durationObject exists -> timed`

That rule was explicitly rejected because it causes permanent auras such as
mount buffs to look like unresolved timed auras.

The correct rule is:

- `durationObject with readable positive timer values -> timed`
- `durationObject with explicit zero timer values -> permanent`
- `durationObject present but still unreadable -> not yet decided`

## Remaining Non-final States

Not every aura can be classified immediately.

### `PENDING`

Used for event-driven auras where:

- the aura came from the `EVENT` path
- `durationObject` exists
- but the timer values are not readable yet

This protects fresh proc auras from being misclassified too early.

`PENDING` means:

- likely a timed candidate
- but Blizzard has not yielded a reliable readable timer yet

### `UNRESOLVED`

Used when the runtime has:

- no readable raw time
- no readable duration object
- no explicit permanent signal

This is the true unresolved fallback.

## Current Classification Table

### `TIMED`

Conditions:

- readable positive raw timer
- or readable positive `durationObject`

Result:

- `durationState = TIMED`
- `timerState = READY`

### `PERMANENT`

Conditions:

- raw `0/0`
- or explicit zero-timer `durationObject`
- or some non-event unreadable object fallbacks

Result:

- `durationState = PERMANENT`
- `timerState = HIDDEN`

### `PENDING`

Conditions:

- `EVENT` aura
- `durationObject` exists
- object still unreadable

Result:

- `durationState = PENDING`
- `timerState = UNAVAILABLE`

### `UNRESOLVED`

Conditions:

- no usable time basis at all

Result:

- `durationState = UNRESOLVED`
- `timerState = UNAVAILABLE`

## Buffs and Debuffs

The same time-classification logic is used for:

- buffs
- debuffs

There is no separate resolver for debuffs. Both groups pass through the same
`ResolveTimeModel(...)` function.

That means:

- mount buffs
- player buffs
- target debuffs
- proc debuffs

all use the same timing model.

## Important Implementation Notes

### Secret values

Some Blizzard values may be secret/tainted and cannot be safely compared or
logged directly.

Because of that, the runtime uses guarded comparisons such as:

- `ComparePositive(...)`
- `CompareNonPositive(...)`
- `ToSafeNumber(...)`

Direct arithmetic or direct string logging on unknown Blizzard values is not
considered safe.

### Reconcile behavior

Event auras in non-final timing states are revisited by the aura cache
reconcile path in
[AuraCache.lua](/d:/World%20of%20Warcraft/_retail_/Interface/AddOns/FocalPoint/Engine/Auras/Runtime/AuraCache.lua).

The reconcile logic currently treats these as needing another pass:

- `UNKNOWN` legacy state
- `PENDING`
- `UNRESOLVED`

This keeps the runtime compatible while the newer state model settles in.

## What We Learned from Mount Buffs

The most important practical lesson from the mount investigation was:

- Blizzard may provide a `LuaDurationObject`
- but that does **not** guarantee a timed aura

For mount buffs, the decisive signal was:

- raw `duration = 0`
- raw `expirationTime = 0`
- readable duration object values resolving to zero

That is why FocalPoint now explicitly treats this as `PERMANENT` rather than
falling back to a vague unresolved state.

## Practical Summary

When reading the code later, remember this:

- `TIMED` means a positive timer was really observed
- `PERMANENT` means Blizzard explicitly gave us a zero/non-timed signal
- `PENDING` means an event aura may still become timed
- `UNRESOLVED` means we genuinely do not know yet

The system should prefer:

- explicit `TIMED`
- explicit `PERMANENT`

and keep the other two states as controlled transition/fallback states, not as
the normal steady-state outcome.

