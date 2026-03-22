# FocalPoint GUI Header Layout

## Purpose

This document defines the binding header rule for configuration pages in
FocalPoint.

The goal is a calmer, clearer, less technical page header that supports the
existing navigation instead of repeating it.

## The Problem With The Old Pattern

Some pages previously used combined titles such as:

- `Player - Frame`
- `Player - Bars - Health`
- `Player - Auras - Buffs`

This mixes multiple navigation levels into one technical title line even when
the GUI already communicates those levels through tabs.

Result:

- redundant information
- heavier visual noise
- more technical wording than necessary
- weaker information hierarchy

## Information Architecture

The GUI has two primary context layers:

1. Unit context
   Examples:
   - `Player`
   - `Target`
   - `Pet`
   - `Focus`
   - `Boss`

2. Area context
   Examples:
   - `Frame`
   - `Bars`
   - `Auras`
   - `Texts`
   - `Elements`
   - `Colors`
   - `Visibility`

Important rule:

- these two layers should not be merged into one technical page title when the
  area is already visible through the active tabs

## Binding Rule

### Unit pages

For unit configuration pages, the page header shows primarily the unit context.

Examples:

- `Player`
- `Target`
- `Pet`

The active tabs communicate the area context.

That means the page title must not be composed as:

- `Unit - Area`
- `Unit - Area - Subarea`

### Non-unit pages

For top-level non-unit pages, the page header shows the page title itself.

Examples:

- `Themes`
- `Profiles`
- `Tag Database`

## Preferred Standard Solution

Default behavior:

- unit pages: show only the selected unit in the main header
- non-unit pages: show only the page title in the main header

This is the preferred rule unless a page truly needs extra context.

For unit pages with tabs, the header belongs above the first visible tab row.

That means:

- the selected unit is shown once at the top of the page
- the header appears before the tab strip
- nested tab contents must not repeat the same unit header again

## Optional Secondary Context

If a page needs extra context, it may use a subdued secondary line below the
main heading.

Allowed examples:

- a small context line
- a breadcrumb-like subtitle
- a muted explanatory subtitle

Important:

- this is a secondary pattern, not the default
- the main header stays short and calm

## Visual Rules

1. The header should be short and quiet.
2. Avoid technical combined titles with separators such as `-` or `>`.
3. Do not repeat information that is already visible through tabs.
4. The main header exists for orientation, not for dumping navigation state.
5. The same rule should work across all pages.

## Examples

Correct:

- `Player` with active tab `Frame`
- `Player` with active tab `Bars` and subtab `Cast`
- `Target` with active tab `Auras` and subtab `Debuffs`
- `Themes`

Avoid:

- `Player - Frame`
- `Player - Bars - Cast`
- `Target > Texts > Name`

## Implementation Guidance

- use the shared page-heading helper
- prefer one short primary title
- only add a secondary subtitle when it adds real value
- do not invent page-local title conventions for unit pages
