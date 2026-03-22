# FocalPoint GUI Layout Rules

## Purpose

This document defines the binding layout rules for the FocalPoint GUI.

It is the shared layout baseline for unit configuration pages and should be used
as the default reference before page-specific layout documents such as the Aura
page rules.

Scope:

- these layout rules apply to the navigation area `Units`
- they are not automatically binding for non-unit pages such as `General`,
  `Themes`, `Profiles`, `Text Builder`, or `Tag Database`
- non-unit pages may selectively reuse these rules where it improves clarity

The goal is not visual novelty. The goal is a calm, readable, Warcraft-friendly
editing surface with predictable structure.

## Core Principle

FocalPoint GUI layout follows this principle:

- full-width, calm sections
- real rows instead of free-flow placement
- clear hierarchy
- logically grouped controls
- important decisions first
- context-dependent details last

## Binding Rules

### 1. Every main section is full width

- every main section spans the full available page width
- there are no side-by-side main sections

### 2. Every main section is a group box

- main sections are displayed as real group boxes
- old line-style headings are not used for primary option sections

### 3. Inside a section, use a two-column grid

- controls inside a section are arranged in a two-column grid
- the grid exists to create order, not free-flow packing

### 4. Controls are placed in real rows

- left and right controls belong to the same row
- different control heights must not destroy the shared row rhythm
- rows are intentional, not accidental

### 5. Controls are grouped logically

- controls that answer the same user question belong together
- grouping follows user logic, not implementation coincidence

Examples:

- basic state and top-level toggles belong together
- visual shape belongs together
- behavior and filtering belong together
- placement-specific settings belong together

### 6. Grouping follows a fixed user-oriented order

The default order is:

1. basic decision
2. visual form
3. behavior
4. positional or context-dependent details

This order should be preferred unless a page has a strong reason to differ.

### 7. `Enabled` always belongs to `General`

- an `enabled` control is always part of the `General` section
- it is not treated as an arbitrary field that can be placed elsewhere

### 8. `Enabled` stands alone in its own row

- `enabled` remains half-width
- it occupies its own row alone
- this applies to unit-level and unit-element-level `enabled` controls

### 9. Section headers may carry actions

- left side: section title
- right side: optional section action such as `Reset`

Header actions must remain small, clear, and secondary to the section title.

### 10. Sections keep a visible spacer between each other

- between two main sections there should be roughly one text line of vertical
  breathing room
- sections should not visually collapse into each other
- the spacer is part of the unit-page layout rhythm, not an optional page-local
  tweak

This spacing should be solved centrally through the shared section layout.

### 11. Prefer section reset over per-control reset

- where practical, reset should happen at section level
- this reduces repetitive UI noise and improves scanability

Exception:

- color pickers may keep dedicated reset buttons

### 12. Context-dependent sections come last

Sections like `Attached` or `Inside` should appear after general, style, and
behavior sections.

They are detail sections and should not appear before the user has established
the broader configuration context.

### 13. Parallel pages should stay structurally parallel

Pages or tabs with the same purpose should keep the same structural rhythm.

Examples:

- `Buffs` and `Debuffs`
- similar unit-element pages

Allowed differences:

- only where the content itself truly differs

### 14. Dependent controls remain context-aware

Layout must respect runtime GUI state and dependencies.

Examples:

- disabled units disable nested controls
- hidden or inactive placement modes disable or hide their dependent controls
- threshold controls stay disabled until the parent feature is enabled

These rules are part of the layout contract, not optional polish.

### 15. Text hierarchy is central, not page-local

Text hierarchy is defined centrally through the GUI text-style roles:

- section header
- label
- help
- highlight
- disabled

See:

- `docs/gui_text_style.md`

Exception:

- `GUI/Pages/GeneralPage.lua` is currently intentionally excluded from the
  shared text-style rules

### 16. Layout rules should be solved centrally

- prefer shared layout helpers and section metadata
- avoid inventing one-off page behavior when a rule is meant to be general
- page-specific exceptions should be deliberate and documented

## Recommended Section Pattern

When designing or refactoring a unit settings page, prefer this pattern:

1. `General`
2. visual/styling section
3. behavior/filtering section
4. placement/detail section

Not every page must have every section, but the order should stay consistent
with the page's real purpose.

## Relationship To Page-Specific Documents

This document defines the global baseline.

Page-specific documents may refine these rules for a concrete page, but should
not contradict them without a deliberate, documented exception.

Example:

- `docs/gui_aura_layout.md`
- `docs/gui_header_layout.md`

## Implementation Guidance

- reuse the existing builder and section architecture
- drive row behavior through layout metadata when possible
- prefer documented conventions over ad-hoc page composition
- optimize for calm structure, not maximum density
