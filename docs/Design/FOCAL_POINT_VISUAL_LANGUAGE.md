# Focal Point Visual Language

STATUS: CURRENT / NORMATIVE - visual roles and integration rules for the existing GUI.

## Purpose

This document defines the visual language used by the committed Focal Point
GUI. It is a presentation contract, not a new theme engine or widget
framework.

## Core principle

Visual consistency comes from shared semantic roles and existing local helpers:
window chrome, section surfaces, labels, selection rows, buttons, sliders,
dropdowns, checkboxes, previews, and status text must communicate the same
state everywhere. Reuse the existing implementation patterns before adding a
new helper.

## Semantic states

Controls may be in these distinct states:

- normal;
- hover;
- pressed;
- selected;
- focused;
- active/current;
- disabled;
- danger/destructive;
- close/cancel utility.

Selected is not the same as active, and disabled is not the same as hidden.
Rows and controls must preserve these distinctions in text, border, fill,
alpha, and interaction behavior.

## Surface hierarchy

- Window chrome frames the workflow.
- Section surfaces group related controls.
- Primary content receives the strongest contrast and space.
- Secondary/help text remains readable without competing with content.
- Previews show the result of the current selection or draft and must not become
  an independent data source.

The Canvas remains the primary editing surface. The Inspector and tool windows
support precise work without replacing Canvas context.

## Control roles

- Buttons use existing action-role styling for primary, secondary, danger, and
  utility actions.
- Selection rows show name, source/type, selection, and active state without
  redundant metadata lines.
- Sliders and dropdowns preserve their existing interaction geometry and value
  feedback.
- Checkboxes distinguish checked, unchecked, disabled, and unavailable.
- Labels use the established typography roles; wording should be concise and
  localized through `Locales/enUS.lua` and `Locales/deDE.lua`.

## Picker and manager rule

Contextual pickers follow the Media Library pattern where practical: explicit
selection rows, a bounded preview/detail area, and a clear footer action. The
picker owns temporary selection only; the caller owns mutation and refresh.

The Layout Manager and Texts Manager may have feature-specific details, but
they must preserve the same selection, source, active, disabled, release, and
reopen semantics.

## Integration and ownership

New visual components must preserve persisted configuration, Inspector binding,
Canvas/demo preview, runtime ownership, geometry/anchor behavior, refresh,
visibility, combat, text dependencies, clear, and release. See the global
checklist in `docs/Architecture/UnitFrame-Runtime-Lifecycle.md`.

Do not add a global visual framework solely to unify local controls. Do not add
timers, retries, or duplicate window infrastructure to compensate for a
deterministic lifecycle issue.

## Relationship to other documents

- `docs/Architecture/GUI-Architecture.md` defines ownership and data flow.
- `docs/Rules/GUI-Visual-Role-Rules.md` defines role-level GUI constraints.
- `docs/Rules/GUI-Layout-Rules.md` remains a partial layout reference.
- `docs/Design/GUI-Text-Style.md` remains a partial typography reference.
