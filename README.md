# Focal Point

Focal Point is a dedicated visual in-game editor for designing deeply customized unit frames directly inside World of Warcraft.

Keep your UI. Design the frames that belong in it.

Focal Point is built for players who want to keep their existing action bars, nameplates, WeakAuras, raid tools, and other addons while replacing or redesigning only the unit frames that should feel more personal. Instead of configuring everything through detached menus, you work visually in the game world: select frames, move them, resize them, align them, edit text directly on the frame, and browse fonts and textures with live previews.

## Features

* Visual unit frame editing with direct frame selection, movement, resizing, and layout control
* Multi-selection for moving and aligning several frames together
* Snap Lines for aligning frames to screen center and nearby editable frames
* Visual Text Editing with direct text selection, dragging, anchor picking, mouse wheel font sizing, and reset actions
* Visual Text Builder with reusable text displays and state templates
* Media Library for browsing, searching, filtering, and previewing fonts and statusbar textures
* LibSharedMedia and SharedMedia support for fonts and statusbar textures from other installed addons
* Quick Mode and Expert Mode for different levels of configuration depth
* Demo and preview states for checking different units, values, indicators, cast bars, auras, and text states
* Presets, profiles, and profile import/export
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

## Getting Started

1. Enter the game and open Focal Point with `/fp`.
2. Unlock frames or open the editor workspace.
3. Select a unit from the sidebar or directly by clicking its visible frame.
4. Move, resize, align, and customize the selected frame.
5. Switch to Text Mode when you want to select, move, anchor, or resize text directly on the frame.
6. Use Demo Mode and previews to check different states before returning to live play.
7. Keep the finished layout in your active profile, or use profiles and import/export to share or back it up.

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
