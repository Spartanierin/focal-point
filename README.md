# Focal Point

Focal Point is a visual in-game editor for designing custom unit-frame layouts
directly inside World of Warcraft.

**Keep your UI. Design the frames that belong in it.**

Focal Point is built around direct visual editing. Select objects on the Canvas
or Composition Tree, move supported objects directly, and use the Inspector for
precise anchors, offsets, textures, colors, text, and component properties.

Layouts are the central product model. Built-in layouts are read-only starting
points; user layouts are editable, copyable, importable, and exportable.
Specialization automation and the optional Account Default select which layout
becomes active; they do not create a second layout type or mass-mutate
characters.

<a id="release-300"></a>
<a id="release-301"></a>
<a id="release-302"></a>

## Release 3.0.3

Version 3.0.3 improves Add Object and Add Unit with matching Edit Mode windows,
component icons and colors, clearer category headings, modern scrollbar
graphics, and a larger header drag area. Close either picker with X or Escape.
The independently positioned CUSTOM Power Bars and configurable NPC Health
reaction colors introduced in 3.0.2 remain available.
Retail/Midnight has been natively tested. Focal Point 3.0.0 has also been
extensively natively tested on WoW Forever. In 3.0.1, the Components Tree removal
icon improves cross-client presentation and has been natively checked on
Forever and Midnight. These checks do not guarantee every function or client
configuration.

Before updating, close the game and make an external backup of your Focal Point
SavedVariables. A native upgrade test using a real 2.x backup retained existing
layouts and settings in that configuration. This is not a universal migration
guarantee, and a downgrade to 2.x is not guaranteed. Keep the original backup.

- **Canvas/Arrange:** select units and edit directly with move/resize tools.
- **Components:** add and remove components; **Add Unit** restores missing units.
  Unit Root checkboxes control Enabled; optional Unit frames can be removed
  without deleting their saved components. In Customize, Canvas component and
  text clicks select in the Tree; Tree hover highlights the Canvas object, and
  a Tree row click opens Properties.
- **Customize/Properties:** configure the selected object in Appearance,
  Size & Position, and Behavior.
- **Manage Layouts:** manage layouts and open specialization assignments.
- **Options:** global settings and **Manage Text Templates...**.

Known limitations:

- There is no regular global Demo-mode entry point in the new editor.
- Native dropdown widths can vary after Inspector reopen; some localization and
  non-bar property-group differences remain.
- Shadow-color disabled feedback may require an Inspector rebuild. Apart from
  the corrected abbreviated simulated Health tags, Demo/live text-format
  consistency still needs broader native validation.

Please focus feedback on navigation and the editing workflow. Include concrete
steps and the details listed under [Reporting issues](#reporting-issues).

## Quick start

Open Focal Point with `/fp`.

1. Select a unit or object on the Canvas or in the Composition Tree.
2. Drag the frame, or use Shift-drag for supported independently positioned
   child objects.
3. Use the mouse wheel for the selected object's context-sensitive adjustment.
4. Use the Inspector for exact values and component settings.
5. Use the Layout Manager for layouts, import/export, and Account Default.
6. Use the Texts Manager for template entities; use the Text Builder and Tag
   Library for content editing and tag insertion.

Enabled objects show preview and selection outline. Disabled objects can still
show selection outline when the editor exposes them for configuration.

## Features

- Canvas-first editing with Composition Tree selection;
- editable user layouts and read-only built-in layouts;
- specialization assignments and optional Account Default;
- Health, Power, Alternative Power, Class Power, Class Resource Bars, Cast,
  Absorb, Aura, Portrait, Indicator, Decoration, and Text components;
- entity-based text templates, object-local text, Texts Manager, and Tag Library;
- Media Library for fonts and status-bar textures;
- Unlock editing and component previews (see the release notes for Demo access);
- scale-aware movement, resizing, and snap behavior;
- layout import/export with reachable text resources;
- client interface declarations in `FocalPoint.toc` (see the client validation scope above).

## Documentation and contribution

- [Documentation entry point](docs/README.md)
- [Product Model](docs/Product/Product-Model.md)
- [Architecture Overview](docs/Architecture/Architecture-Overview.md)
- [Contributor Guide](CONTRIBUTING.md)

## Installation

1. Download the release package.
2. Extract the `FocalPoint` folder into
   `World of Warcraft\\_retail_\\Interface\\AddOns\\` or the corresponding
   supported client AddOns directory.
3. Enable the addon in the AddOns menu if necessary.
4. Start or reload the game.

Check `FocalPoint.toc` for the exact version and supported interface IDs.

## Slash command

- `/fp` or `/focalpoint` opens the main Focal Point entry point.
- `/fp config` opens the configuration interface.

Support diagnostics and performance commands are gated developer tools, not a
normal product workflow. They are intentionally omitted from the public quick
start.

## Reporting issues

Include the action sequence, expected and actual result, combat state, client
flavor, Lua error text, and whether the issue survives a reload. Do not attach
SavedVariables, ZIPs, profiler dumps, or debug artifacts unless a maintainer
explicitly requests a sanitized excerpt.

## License and credits

This project is released under the terms described in `LICENSE`.

Created by Spartanierin. The toolbar logo uses the *Achtung!Polizeit* typeface
by Chequered Ink Ltd under its permitted non-commercial use terms.
