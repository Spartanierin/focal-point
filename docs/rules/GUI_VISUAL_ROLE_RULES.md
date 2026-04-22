# GUI VISUAL ROLE RULES

## Purpose

Define the visual role system for sidebar, toolbar, forms, and editor-facing GUI surfaces.
This is a release-facing rule set, not a moodboard.

## Scope

* `GUI/Editor/*`
* `GUI/Pages/*`
* `GUI/Helpers/*`
* `GUI/Layouts/*`
* `GUI/Widgets/*`

## Core Principle

Visual styling must communicate role, not decoration.

A control or surface must look different only when its role is different.
Visual variance must be justified by function.

## Visual Hierarchy Order

1. Layout and grouping
2. Surface hierarchy
3. Action hierarchy
4. Typography
5. Accent detail

Color must not be used as the first tool for separation when spacing, grouping, or hierarchy already solves it.

## Surface Rules

### Base Surfaces

* Primary GUI surfaces should live in a tight dark-neutral family.
* Surface tint differences must stay subtle.
* Section panels must feel like parts of one system, not separate themed cards.

### Section Panels

* Section panels may use slight tint variation for grouping.
* Tint variation must remain narrow in hue and restrained in intensity.
* Panel accents must support separation, not become visual headlines.

### Special Surfaces

* Only truly special surfaces may visually step out of the neutral family.
* Special treatment must be rare and role-driven.

## Button Role Rules

### Primary

Use primary styling only for the most important action in a local context.

Primary is allowed for:

* the main confirm/apply action of a block
* the main mode-entry action of a screen
* one dominant action in a tightly grouped area

Primary must not be used for multiple sibling actions in the same group unless explicitly justified.

### Secondary

Secondary is the default button role.

Use secondary for:

* navigation between tools
* switching views or units
* utility actions
* non-destructive actions
* actions that are important but not dominant

If there is no clear reason for primary, use secondary.

### Danger

Danger is reserved for destructive, risky, or clearly irreversible actions.

Danger must not be used for:

* close
* navigation
* tool switching
* neutral reset/navigation utility
* standard editing actions

Danger should be rare.

### Disabled / Passive

Disabled or passive states must reduce emphasis clearly without harming readability.

Do not fake secondary by only slightly changing a strong primary look.
The role difference must be visibly real.

## Toolbar / Sidebar Rules

* Sidebar and toolbar must read as one coherent tool system.
* They must not rely on many competing highlight colors.
* Only a very small number of actions should visually dominate at the same time.
* Section panels should be calmer than the actions they contain.
* Utility actions should never compete with core actions.

## Typography Rules

* Typography should support hierarchy, not replace it.
* Section titles may carry mild emphasis.
* Body/help text must stay quieter than titles and actions.
* Typography should not be used to compensate for unclear color roles.

## Accent Rules

* Gold/yellow accents are for headings, selected highlights, or restrained editor accents.
* Accent use must be sparse and repeatable.
* Accent color must not become a second primary action language.

## Consistency Rules

* The same semantic role must map to the same visual role across the GUI.
* A style decision that is correct in one area should not invert meaning elsewhere.
* Runtime styling and build-time styling must converge to the same visual intent.

## Anti-Patterns

* multiple primary sibling buttons in one group
* danger styling for non-danger actions
* heavily tinted section panels competing with button emphasis
* using color variation as decoration
* nearly identical visual output for different semantic roles
* one-off visual exceptions without a documented role reason

## Decision Rule

When unsure:

* reduce variance
* prefer neutral surfaces
* prefer secondary over primary
* prefer primary over danger
* prefer one dominant action over several loud actions
* prefer consistency over local cleverness

## Migration Policy

* Prefer small, visible, behavior-preserving steps
* First fix central style layers, then local exceptions
* Do not mix structural refactors with visual-role cleanup
* Re-evaluate with screenshots after each small step
