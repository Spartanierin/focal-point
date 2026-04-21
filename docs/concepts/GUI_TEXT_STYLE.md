# FocalPoint GUI Text Style

## Purpose

This document defines the binding text-color rules for the FocalPoint GUI.

The goal is to create a readable, Warcraft-compatible visual hierarchy without
turning every text element into the same bright color.

The GUI should make these layers obvious at a glance:

1. section headers
2. field labels
3. help text
4. example / accent / selected text
5. disabled text

Page headings remain a separate page-level title treatment and are not part of
the five standard field-text roles below.

This document is the authoritative design rule for future GUI work. New pages
and refactors should follow these roles instead of inventing page-local text
colors.

Exception:

- `GUI/Pages/GeneralPage.lua` is currently exempt from this rule and keeps its
  dedicated presentation style.
- That page should not be auto-converted by shared widget text styling.

## Text Roles

### 1. Section Header

Use for:

- section titles
- group headings for option blocks
- major editable areas like `General`, `Size & Position`, `Colors`, `Behavior`

Intent:

- strong
- warm
- clearly above normal option text

Definition:

- Hex: `#E7C44A`
- RGB: `0.906 / 0.769 / 0.290`
- WoW code: `|cffE7C44A`

### 2. Label Text

Use for:

- field names
- control labels
- normal work-level text beside inputs

Intent:

- highly readable
- calmer than headers
- the main everyday text layer

Definition:

- Hex: `#F2E6C9`
- RGB: `0.949 / 0.902 / 0.788`
- WoW code: `|cffF2E6C9`

### 3. Help Text

Use for:

- descriptions below controls
- explanatory helper text
- supportive context text

Intent:

- clearly secondary
- readable but quieter
- never visually stronger than labels

Definition:

- Hex: `#B7AA8A`
- RGB: `0.718 / 0.667 / 0.541`
- WoW code: `|cffB7AA8A`

### 4. Highlight Text

Use for:

- examples
- tags shown as reference content
- selected or active entries such as the current theme or current profile
- focused or previewed content that should read as an accent layer

Intent:

- cool light-blue accent
- clearly distinct from gold section headers
- used sparingly
- never as the default text color for everything

Definition:

- Hex: `#8FC7FF`
- RGB: `0.561 / 0.780 / 1.000`
- WoW code: `|cff8FC7FF`

### 5. Disabled Text

Use for:

- unavailable controls
- inactive descriptions
- text that should read as intentionally inactive

Intent:

- visibly inactive
- not broken-looking
- not so dark that it becomes hard to read

Definition:

- Hex: `#7E7564`
- RGB: `0.494 / 0.459 / 0.392`
- WoW code: `|cff7E7564`

## Usage Rules

### Hierarchy

- `sectionHeader` is the highest normal option-text layer
- `label` is the standard working layer
- `help` is always subordinate to `label`
- `highlight` is an accent, not a base style
- `disabled` is only for truly inactive content

### Consistency

- text colors must be defined centrally
- do not hardcode role colors repeatedly across page files
- prefer helper/style functions over inline color strings

### Shadows

Where technically possible, GUI text should use a subtle dark shadow:

- offset: `1, -1`
- dark shadow color with moderate alpha

The shadow is for readability only and should not look heavy.

### No Yellow Overuse

Gold/yellow should be reserved for hierarchy and emphasis.

Do not use header gold for:

- every label
- normal descriptions
- default content rows

## Examples

Correct:

- `General` section title -> `sectionHeader`
- `Width` -> `label`
- `Sets the width of the frame.` -> `help`
- `Previewing: Modern` -> `highlight`
- `[hp:cur]` shown as a reference tag -> `highlight`
- selected profile/theme name -> `highlight`
- disabled field label -> `disabled`

Incorrect:

- all labels in gold
- help text brighter than labels
- disabled labels looking identical to active labels

## Application Priority

The style system should be applied in this order:

1. central helper definitions
2. shared widget primitives
3. text-heavy pages
4. remaining special-case pages

This keeps the rollout consistent and avoids ad-hoc color swaps.

## Implementation Rule

The authoritative central definition lives in the GUI text-style helper:

- `GUI/Helpers/TextStyles.lua`

That module should expose named roles like:

- `sectionHeader`
- `label`
- `help`
- `highlight`
- `disabled`

Future GUI pages should adopt these roles instead of inventing page-local text
colors.
