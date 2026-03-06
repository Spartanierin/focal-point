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