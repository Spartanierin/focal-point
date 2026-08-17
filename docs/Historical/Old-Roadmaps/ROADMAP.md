STATUS: HISTORICAL - old roadmap; current 2.0 direction is documented in docs/Roadmap/2.0-Design-Principles.md.

# Focal Point Editor UX Roadmap

Focal Point should continue to grow as a focused visual Unit Frame editor. It should not try to become a full UI replacement in the style of broader UI suites. The editor roadmap should strengthen the core workflow around direct manipulation, mouse-based editing, alignment helpers, and paired frame workflows.

Party and raid frames may come later, but raid-frame design requires healer-aware interaction, visibility, and encounter testing. That work should not be rushed without proper healer feedback.

## 1.0.8 - Frame Context Menu

Purpose:

Add a right-click context menu for unit frames while the editor or unlock mode is active.

Initial MVP actions:

* Edit this frame / select this frame in the inspector.
* Copy size.
* Paste size.
* Copy position.
* Paste position.
* Reset size.
* Reset position.

Notes:

* The context menu should only be active in editor/unlock mode.
* It should not affect combat-safe runtime behavior.
* It should establish a foundation for later mirror-pair and workflow actions.
* Keep the first implementation simple and low risk.

## 1.0.9 - Mouse Resize MVP

Purpose:

Allow users to resize frames directly with the mouse instead of relying only on sliders or numeric controls.

Initial MVP:

* Add a simple resize handle, preferably bottom-right, while frames are unlocked.
* Dragging the handle changes frame width and height.
* Apply live preview while dragging.
* Commit/save values on mouse release.
* Synchronize inspector controls after resizing.
* Respect minimum frame sizes.
* Avoid unsafe protected-frame changes during combat.

Notes:

* Sliders and numeric fields remain important for precision.
* Mouse resize is for fast visual layout work.
* Start with one handle only; do not build a full multi-handle designer yet.

## 1.0.10 - Basic Snap Lines

Purpose:

Help users align frames visually while moving or resizing them.

Initial MVP:

* Snap to screen center, both horizontal and vertical.
* Snap to matching X/Y positions of other visible editor frames.
* Optionally snap to matching frame centers.
* Show simple temporary guide lines while snapping.

Notes:

* Keep the first version simple.
* Avoid a complex design-tool system in the first pass.
* Snap behavior should be easy to disable later if needed.

## 1.0.11 - Mirror Pair MVP

Purpose:

Support symmetrical Player/Target layouts more easily.

Initial MVP:

* Only support Player <-> Target as the first mirror pair.
* Mirror around screen center.
* Add context menu actions:
  * Link Player and Target as Mirror Pair.
  * Unlink Mirror Pair.
  * Copy size to mirror partner.
  * Mirror position to partner.
* When linked, moving one frame updates the mirrored position of the other.
* Resizing one frame can optionally apply the same size to the linked partner.

Notes:

* Do not start with free multi-selection.
* Do not support arbitrary frame pairs in the first implementation.
* Keep it focused on the most common layout use case: symmetrical Player/Target frames.

## 1.0.12 - Polish and Start Workflow

Purpose:

Polish the new editor UX tools and improve first-use clarity.

Possible improvements:

* Better tooltips for context menu, resize, snap, and mirror behavior.
* Small help text or hints in the editor.
* Improved default preset / first-start layout.
* Optional setting to enable or disable snap lines.
* Visual polish for context menu and resize handles using the active skin.
* Better documentation for the editor workflow.

Product direction:

Focal Point should remain a focused Unit Frame editor. It should not try to become a full UI replacement. Future Party/Raid work should be approached deliberately, especially for raid frames where healer-aware design and testing are essential.

