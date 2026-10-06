# Product Model

STATUS: CURRENT - canonical product language for Focal Point 2.2.x.

## Core model

Focal Point is a visual in-game editor for unit-frame layouts. A layout is the
user-facing design object: it contains unit-frame composition, geometry,
components, text bindings, and presentation settings.

The product exposes layouts, not profiles or presets. Older profile/preset
storage and import paths remain as compatibility boundaries, but they are not
current product concepts.

## Layouts

- Built-in layouts are read-only starting points.
- User layouts are editable and can be renamed, copied, deleted, imported, and
  exported.
- A layout contains unit-frame configuration and entity-based text bindings.
- Built-in and user layout IDs are distinct and must never be merged by name or
  content.
- Layout export contains the selected layout and its reachable template
  resources. Local account preferences are not part of the export.

## Active layout and assignment rules

`activeLayoutId` identifies the layout currently applied to the character.
`ActiveLayoutResolver` resolves it into a runtime root; it does not infer an
active layout from a label or a profile name.

Specialization automation and the Account Default are selection rules:

1. a valid specialization mapping wins at login or specialization change;
2. otherwise a valid Account Default may be applied at login;
3. otherwise the existing initialization fallback is retained.

Account Default is an optional global layout reference. It can be set or
cleared, is not a layout type, is not a character mass-mutation operation, and
is not included in layout export. A stale reference is rejected defensively.

The saved character rule remains separate from the active layout. It may be a
legacy existing selection, an Account Default rule, or a Character Override.
The UI does not silently migrate a legacy selection.

## Unit frame

A layout may define frames for units such as Player, Target, Focus, Pet, and
Boss. Components include:

- Health, Power, Alternative Power, Class Power, and Cast Bars;
- Normal Absorb and Healing Absorb Bars;
- text elements and text templates;
- auras, portraits, indicators, and decorations.

The Canvas is the primary editing surface. The Inspector provides precise
component and presentation controls.

## Texts and templates

Text elements own placement and presentation. Templates own content and tags.
The Texts Manager administers built-in and user template entities; the Text
Builder consumer handles create/edit drafts and object or layout usage.

Built-in template entities are read-only. User entities have stable IDs and
remain independent even when names or content are equal. Object-local text is a
valid direct `tag` value without a main template ID.

The runtime resolves entity IDs and direct content through the canonical text
resolver. It consumes prepared `LiveValues`; it does not reconstruct canonical
values from rendered bars.

## Demo and editor modes

Demo supplies explicit preview values for design work. Unlock makes configured
frames visible and movable when live units are absent. Neither mode changes the
layout data model or becomes a second source of truth.

## Health Family

The Health Family is one functional family with independent geometry:

- Health Bar;
- Normal Absorb Bar;
- Healing Absorb Bar.

Health values and absorb values are prepared by the health runtime and exposed
through `UnitFrame.LiveValues`. Text tags consume those prepared values. A
separate incoming-heals component is not currently implemented.

## Cast Bar

The committed Cast Bar supports Match Frame and Custom Width, free positioning
with large offsets, scale-correct editor dragging, texture, color, icon, and
CastName/CastTime text. Editor selection preview and live/detailed preview use
the existing visual-policy path. Interruptibility-related color behavior is
documented only to the extent implemented by the committed configuration and
runtime; external or unmerged changes are not part of this product model.
