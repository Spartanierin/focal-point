# Portrait – Architekturüberblick

## Ziel

Die GUI von Portrait soll so aufgebaut sein, dass sie logisch, skalierbar und leicht lokalisierbar bleibt.

Die Struktur folgt dabei immer derselben Reihenfolge:

**Unit → Tab → Objekt → Eigenschaften**

Beispiel:

- Unit: `player`
- Tab: `bars`
- Objekt: `health_bar`
- Eigenschaft: `width`

Die GUI soll nicht aus lose verteilten Einzeloptionen bestehen, sondern die technische Struktur des Addons klar widerspiegeln.

---

## Grundprinzip der Navigation

Die Navigation ist objektorientiert aufgebaut.

### Hauptebene

- General
- Units

### Unter „General“

- Profiles
- Themes
- Global Defaults
- Test Mode

### Unter „Units“

- Player
- Target
- Target of Target
- Pet
- Focus
- Focus Target
- Boss

Jede Unit besitzt dieselbe Grundstruktur. Dadurch bleibt die GUI konsistent und erlernbar.

---

## Standardtabs pro Unit

Jede Unit-Seite verwendet dieselben Haupttabs:

- Frame
- Bars
- Texts
- Elements
- Visibility

Diese Tabs beschreiben die Art des bearbeiteten Objekts, nicht einzelne konkrete Optionen.

---

## Inhalt der Tabs

### Frame

Enthält alle Einstellungen, die das gesamte Unit Frame betreffen.

Beispiele:

- Enabled
- Width
- Height
- Scale
- Alpha
- Anchor From / To
- X / Y Offset
- Frame Strata
- Frame Level

### Bars

Enthält alle Bar-Objekte einer Unit.

Maximal vorgesehen:

- Health Bar
- Power Bar
- Alt Power Bar
- Cast Bar

Jede Bar soll möglichst dieselbe innere Struktur besitzen, z. B.:

- General
- Size & Position
- Style
- Behavior

### Texts

Enthält alle Text- bzw. Tag-Objekte einer Unit.

Beispiele:

- Name
- Health Value
- Power Value
- Level
- Status
- Cast Name
- Cast Time
- Custom Texts

Texte sind eigene Informationsobjekte und werden nicht logisch einer Bar untergeordnet, auch wenn sie optisch auf einer Bar liegen können.

### Elements

Enthält alle grafischen Objekte, die weder Bar noch Text sind.

Beispiele:

- Portrait
- Background
- Border
- Highlight
- Raid Target Icon
- Leader Icon
- Role Icon
- Combat Indicator
- Resting Indicator
- Ready Check Indicator
- PvP Indicator

### Visibility

Enthält Sichtbarkeits- und Zustandslogik.

Beispiele:

- Show in Solo / Party / Raid
- In Combat Only
- Out of Combat Only
- Alive Only
- Has Target
- Alpha / Fade Rules

Sichtbarkeit ist eine Logik-Ebene und wird nicht mit Stil-Einstellungen vermischt.

---

## Technische Benennung

Im Projekt werden sichtbare Namen und technische Schlüssel strikt getrennt.

### 1. Internal Keys

Internal Keys sind sprachneutral und stabil.  
Sie werden für Datenmodell, GUI-Struktur und Code-Referenzen verwendet.

Beispiele:

- `player`
- `target`
- `bars`
- `texts`
- `health_bar`
- `name_text`
- `portrait`

Diese Keys dürfen nicht von sichtbaren Texten abhängen.

### 2. Localization Keys

Alle sichtbaren Texte laufen über Locale-Keys.

Beispiele:

- `UNIT_PLAYER`
- `TAB_BARS`
- `BAR_HEALTH`
- `TEXT_NAME`
- `ELEMENT_PORTRAIT`

Die GUI verwendet also niemals sichtbare Rohtexte als technische Identität.

**Richtig:**

```lua
key = "health_bar"
name = L["BAR_HEALTH"]





## GUI State and Refresh Model

The configuration UI uses a shared widget state model across all standard controls (checkboxes, dropdowns, sliders, color pickers).

Each widget may define:
- `disabled`
- `locked`
- `refreshGUI`

The `disabled` and `locked` values may be static booleans or functions that are evaluated dynamically against the current configuration state.

### Widget state refresh

Widgets expose a `RefreshState()` function and register themselves with the GUI refresh system.  
This allows the UI to update the interactive state of visible controls without rebuilding the entire page.

This was introduced because full GUI rebuilds caused multiple UX and interaction problems:
- scroll position jumping back to the top
- TreeGroup state instability
- sliders losing proper drag behavior
- unnecessary widget recreation for simple state changes

The rule is:

- **State changes** should refresh visible widget states
- **Structural changes** may rebuild the page if necessary

A full page rebuild is therefore a fallback, not the primary refresh mechanism.

## Refresh Separation

The refresh system is intentionally split into separate layers:

- `OptionRefresh.GUI()`  
  Refreshes visible widget states in the configuration UI

- `OptionRefresh.Live()`  
  Refreshes live unit frames and preview/test environments

- `OptionRefresh.All()`  
  Combines both when needed

This separation exists because GUI refreshes and live frame refreshes have different requirements.

### Why this separation exists

Using a single “refresh everything” path caused several problems during development:
- GUI controls were rebuilt during slider interaction
- scroll position was lost
- TreeGroup state was reset unexpectedly
- widget interaction became unstable

As a result, GUI refreshes are treated as a separate concern from frame rendering.

## Portrait as the First Image Element

The portrait system is the first complete image-based element implemented end-to-end.

It includes:
- defaults in the unit configuration
- a dedicated GUI section
- hierarchical option dependency handling
- live application inside `UnitFrame.lua`
- portrait-specific event-based texture refresh

This element serves as the blueprint for future image-based elements such as:
- raid target marker
- resting symbol
- combat indicator
- other icon or texture based overlays

## Image Element Placement Model

Image-based elements follow a placement model with two distinct modes:

- `INSIDE`
- `ATTACHED`

These are not cosmetic variants. They represent different layout behaviors.

### INSIDE

An image element placed `INSIDE` reserves space inside the unit frame.

For portraits this means:
- the portrait remains square
- the frame reserves horizontal space for it
- health and power bars do **not** anchor directly to the portrait
- bars only shift their own offsets to leave room

This rule is important because anchoring bars directly to the portrait caused circular dependency issues in WoW’s layout system.

### ATTACHED

An image element placed `ATTACHED` does not affect the internal frame layout.

Instead, it is anchored freely to a chosen target such as:
- `Frame`
- `HealthBar`
- `PowerBar`

This allows image-based elements to behave like external anchors without forcing health/power layout changes.

## Portrait Element Model

The portrait configuration uses a dedicated image-element style data model.

Example fields:

- `enabled`
- `placement`
- `mode`
- `size`
- `scale`
- `padding`
- `insideSide`
- `anchorTo`
- `point`
- `relativePoint`
- `offsetX`
- `offsetY`

### Size and scale instead of width and height

Portraits intentionally use `size` and `scale` instead of separate width and height values.

This avoids distortion and keeps portraits square by design.

The general rule for image-based elements is:
- bars may stretch
- images should usually keep aspect ratio unless explicitly designed otherwise

## Portrait Rendering Strategy

The current portrait implementation supports a stable 2D rendering path first.

The 2D portrait is updated through portrait-related events, including world entry and portrait/model update events.  
This was necessary because setting the portrait texture during initial frame construction was sometimes too early, which caused the portrait area to exist without the image being visible until a later manual refresh.

The portrait update path was therefore made event-driven instead of relying only on frame construction timing.

### Current status of 3D mode

The portrait model already contains a `mode` field (`2D` / `3D`) as part of the architecture.

At the current stage:
- `2D` is the stable implementation
- `3D` is part of the intended model, but should be treated as an extension point until a dedicated model-based implementation is added

## Dependency Handling in the GUI

The GUI uses hierarchical dependency logic for options.

Example:
- unit disabled → all portrait options disabled
- portrait disabled → all portrait sub-options disabled
- portrait placement = `INSIDE` → inside-only options enabled
- portrait placement = `ATTACHED` → anchor/offset options enabled

This dependency model is implemented through widget state functions rather than page-local ad hoc conditions.

The goal is to keep option dependencies declarative and reusable.

## Navigation and UI State Persistence

The configuration UI maintains state for:
- expanded TreeGroup nodes
- selected navigation path
- visible widget states

This was added to avoid repeated UI friction during iterative configuration work.

Examples:
- the `Units` node should remain expanded by default
- option toggles should not force the user back to the top of long option lists
- visible controls should update state without disrupting the current work context

## Architectural Direction for Future Image Elements

Portrait is the first implementation of a broader design direction.

Future image-based elements should reuse the same conceptual model where appropriate:
- shared placement logic (`INSIDE` vs `ATTACHED`)
- square-safe sizing (`size` + `scale`)
- anchor-based external attachment
- state-driven GUI visibility and enable/disable logic

The goal is to avoid one-off implementations for each indicator or symbol and instead grow a reusable image-element architecture.