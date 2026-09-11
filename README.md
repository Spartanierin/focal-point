# Focal Point

Focal Point is a dedicated visual in-game editor for building and designing custom unit frames directly inside World of Warcraft.

**Keep your UI. Design the frames that belong in it.**

Focal Point is for players who like the rest of their interface and only want to replace or redesign their unit frames. Keep your action bars, nameplates, WeakAuras, raid tools, bags, and other addons, then build unit frames that fit naturally into that setup.

Focal Point 2.0 is built around direct visual editing, not detached option pages. Select objects on the Canvas or in the Composition Tree, move them directly on the frame, add the components you need, and use the Inspector when you want precise control over anchors, offsets, textures, colors, and other details.

Layouts are the central design model. Built-in Layouts are read-only starting points; your edits live in an editable Layout.

Canvas first. Inspector second. **Stop configuring. Start designing.**

## Quick Start - How to edit in Focal Point 2.0

Open Focal Point with `/fp`, then design directly on the Canvas. The Inspector is there for precise details, not as the primary way to position or size your frame.

### 1. Select what you want to edit

* Click a visible object directly on a unit frame.
* Or select it in the Composition Tree.
* The selected object is highlighted on the Canvas.

### 2. Move it

* Drag to move the owning unit frame.
* Shift + Drag moves supported child elements relative to that frame.

### 3. Resize or adjust it

Use the Mouse Wheel on a selected object for its most relevant adjustment:

* Text: font size
* Supported bars: thickness
* Aura groups: icons per row
* Portraits and supported icons: scale
* Decorations: proportional size

### 4. Fine-tune in the Inspector

Use the Inspector for exact anchors, offsets, textures, colors, visibility, and component-specific settings. It stays synchronized with direct Canvas editing.

### 5. Add what you need

Use the Composition Tree and Add Object workflow to add components such as a portrait or text. New text can reuse existing templates and starts from the current visual context.

| Action | Result |
| --- | --- |
| Click | Select an object |
| Drag | Move the owning unit frame |
| Shift + Drag | Move a supported child element |
| Mouse Wheel | Adjust the selected object's size or density |
| Composition Tree | Navigate, select, expand, and toggle components |
| Inspector | Fine-tune exact properties |

After moving a supported child element, Focal Point may choose a more appropriate anchor for its new visual position. This is intentional: anchors keep the layout stable without requiring routine manual adjustment.

### Layouts

A Layout is the design you are editing. Built-in Layouts are read-only starting points; editing one creates or uses your own editable Layout. Automation can switch Layouts by specialization.

## Features

* Canvas-first visual editing with direct object selection, movement, resizing, and layout control
* Composition Tree for navigating, selecting, expanding, toggling, and scrolling to each unit frame component
* Add or remove supported components directly from the editor, including text and portraits
* Normal Drag for frame movement and Shift + Drag for supported independently positioned child elements
* Context-sensitive Mouse Wheel editing for text size, supported bar thickness, aura density, portrait and indicator scale, and decoration size
* Visual Text Editing with direct selection, dragging, anchor picking, reset actions, reusable text displays, and state templates
* Normal Absorb and Healing Absorb Bars as independently configurable health components
* Layout-first workflow with built-in starting points, editable User Layouts, and specialization automation
* Multi-selection and Snap Lines for moving and aligning several frames together
* Measured and optimized editor and runtime performance to reduce unnecessary updates, rebuilding, polling, and allocation churn during visual editing
* Media Library for browsing, searching, filtering, and previewing fonts and statusbar textures
* LibSharedMedia and SharedMedia support for fonts and statusbar textures from other installed addons
* Quick Mode and Expert Mode for different levels of configuration depth
* Demo and preview states for checking different units, values, indicators, cast bars, auras, and text states
* Minimap button
* Slash commands for quick access
* Diagnostic tools for troubleshooting and testing

## Supported Game Version

* World of Warcraft Retail

Please refer to the `.toc` file for the exact interface version included in this release.

## Installation

1. Download the latest release package.

2. Extract the folder `FocalPoint` into your WoW AddOns directory:

   `World of Warcraft\_retail_\Interface\AddOns\`

3. Make sure the final path looks like this:

   `World of Warcraft\_retail_\Interface\AddOns\FocalPoint\`

4. Start or restart the game.

5. Enable the addon in the AddOns menu if necessary.

## Slash Commands

* `/fp` - open the main command entry
* `/fp config` - open the configuration interface
* `/fp diag` - print diagnostic information

Some legacy aliases may still be available for compatibility.

## Reporting Issues

If you encounter a bug, please include as much detail as possible:

* what you did
* what you expected
* what happened instead
* whether it happened in combat
* whether it happened on a fresh profile
* any Lua error message
* output from `/fp diag` if relevant

## Feedback

Feedback, bug reports, and improvement suggestions are welcome.

Detailed reproduction steps are especially helpful when reporting issues.

## License

This project is released under the terms described in the `LICENSE` file.

## Credits

Created by Spartanierin.

### Typography

The Focal Point toolbar logo uses the *Achtung!Polizeit* typeface by Chequered Ink Ltd.

Included with permission for non-commercial use only.

https://www.chequered.ink/
