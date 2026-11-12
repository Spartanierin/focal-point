# Edit-Mode-Dialog-Pattern

Status: Implementierte lokale Referenz der vom Nutzer nativ abgenommenen
Add-Object-Überarbeitung. Maßgeblich ist der aktuelle Quellcode. Dieses Pattern
ändert weder die Defaults aller Dialoge noch deren fachliche Zuständigkeiten.

## Quellen und Wiederverwendungsgrenzen

| Bestandteil | Verantwortliches Modul / bestehender Einstieg | Allgemein nutzbar oder lokal? |
| --- | --- | --- |
| Dialog und Edit-Mode-Chrome | [FormWidgets.lua](../../GUI/Helpers/FormWidgets.lua): `CreateCompactFormDialog(options)` mit `windowChrome = "editmode"` | Explizite Fabrikoption; andere Dialoge behalten ihre Defaults. |
| Native Shell-Grafik | `FormWidgets.lua`: private `ApplyBlizzardWindowShell()` und `ApplyCompactEditModeChrome()` | Gemeinsame Implementierung, keine öffentlichen Consumer-APIs. `ApplyCustomizeBlizzardShell()` bleibt auf `editor_inspector` beschränkt. |
| Titel und Drag-Fläche | Fabrikoptionen `titleFontSize`, `titleOffsetY`, `headerDrag` | Optional im Edit-Mode-Pfad; keine globale Typografie- oder Hitbox-Änderung. |
| Kontext und Sektionen | `FormWidgets.CreateSectionTitle()`, `FormWidgets.ApplyTextStyle()` und vorhandene AceGUI-Labels/Spacer | Öffentliche Bausteine; Anordnung und Abstände in Add Object sind lokal. |
| Auswahlzeilen | [SelectionRow.lua](../../GUI/Widgets/SelectionRow.lua): `ns.GUI.Widgets.SelectionRow.Create(binding)`, `row:Bind(binding)` | Allgemeines Widget `FocalPointSelectionRow`; Darstellung über optionale `binding.presentation`. |
| Farben | [GUISkin.lua](../../GUI/GUISkin.lua): `ns.GUI.Skins.GetFormPalette()` | Kanonische Palette, insbesondere `CompositionTree` und `Chrome`; keine lokale Ersatzpalette. |
| Icon-Referenz | [CompositionTreeControl.lua](../../GUI/Editor/Composition/CompositionTreeControl.lua): private `ResolveNodeIcon()` und `SetIconColor()` | Referenz für Assets/Farbsemantik, kein öffentlicher Icon-Resolver. Nicht aus anderen Modulen aufrufen oder künstliche Tree-Nodes erzeugen. |
| Add-Object-Aufbau | [CanvasToolbar.lua](../../GUI/Editor/CanvasToolbar.lua): private `OpenAddObjectPicker()`, `AddPickerHeader()`, `AddPickerButton()` | Lokaler Objektkatalog, Präsentation und geschützte Aktivierung; kein universeller Listenbuilder. |
| Moderne Scrollbar | `CanvasToolbar.lua`: private `StyleAddObjectScrollbar(scroll)` | Ausschließlich lokale Grafikangleichung eines vorhandenen AceGUI-ScrollFrames; kein allgemeiner Scrollbar-Service. |

## Fenster, Titel und Header

Der folgende Konfigurationsauszug entspricht Add Object. `title` steht für die
bereits lokalisierte Dialogbeschriftung des Consumers:

```lua
local dialog = FormWidgets.CreateCompactFormDialog({
    title = title,
    width = 420,
    height = math.min(560, UIParent:GetHeight() - 2 * 16),
    bodyLayout = "List",
    addBodySpacer = false,
    contentRoot = true,
    windowChrome = "editmode",
    titleFontSize = 17,
    titleOffsetY = -3,
    headerDrag = { left = 8, right = 36, top = 0, height = 32 },
})
```

Dieser Auszug erzeugt noch keinen Objektkatalog, keine moderne Scrollbar und
keinen fachlichen Close-/Release-Owner. Diese Aufgaben bleiben beim Consumer.

- **Rahmen:** derselbe vorhandene DiamondMetal-Atlas-Satz wie bei Customize,
  über `CanApplyCustomizeEditModeShell()` vorab auf verfügbare, positive
  Atlas-Abmessungen geprüft. Eckstücke liegen ohne zusätzliche Eck-Offsets
  am Fenster; Rahmenebene ist `BORDER`.
- **Fallback:** zuerst der vorhandene native Metallrahmen, andernfalls der
  bestehende flache Rahmen. Auch dabei bleibt im kompakten Edit-Mode-Dialog
  der Hintergrund schwarz-transparent; Rock-Textur und TopTileStreaks werden
  nicht eingeblendet. Verfügbarkeit wird zur Laufzeit geprüft, nicht aus einer
  Clientbezeichnung abgeleitet.
- **Hintergrund:** `SetColorTexture(0, 0, 0, .8)`, sieben UI-Einheiten nach innen
  versetzt. Die kompakte Inhaltsoberfläche einschließlich ihrer Konturen und
  Schattierungen ist transparent. Kein `contentSurface = "parchment"` und
  keine braune Chrome-Füllung für diesen Consumer.
- **Titel:** Rolle `identity`, Weiß, horizontal zentriert innerhalb der
  bestehenden Titelanker. Add Object verwendet Größe 17 und verschiebt die
  ursprünglichen Anker um Y = -3 nach unten. Ohne diese Optionen bleibt im
  kompakten Edit-Mode-Pfad Größe 18 ohne Verschiebung erhalten.
- **Close-X:** vorhandener AceGUI-Window-Close-Button;
  `EnsureStandardWindowCloseButton()` erhält dessen Bedienbarkeit. Kein neues
  Close-Widget, kein dekoratives Ersatz-X.
- **Dragging:** ausschließlich der vorhandene `window.title`-Button mit seinen
  nativen `StartMoving()`-/`StopMovingOrSizing()`-Handlern. Add Object verankert
  ihn links bei 8, oben bei 0 und unten bei -32. Rechts werden mindestens 36
  beziehungsweise `closebutton:GetWidth() + 4` Einheiten ausgespart. Die Fläche
  bleibt oberhalb des Contents; Kontext und Liste sind keine Drag-Flächen.

`dialogPresentation = false` allein aktiviert diese Shell nicht. Das explizite
`windowChrome`-Opt-in wählt den Edit-Mode-Pfad und unterdrückt die sonstige
Materialdarstellung. Andere Dialoge werden dadurch nicht umgestellt.

## Kontext, Sektionen und Zeilen

Alle Maße sind UI-Einheiten, keine garantierten physischen Bildschirm-Pixel.

| Element | Implementierter Add-Object-Vertrag |
| --- | --- |
| Kontext | Vorhandenes, vollbreites Label, z. B. „Choose what to add to Player.“; Textrolle `help`, Größe 13. Der Text folgt dem tatsächlichen Unit-/Objektkontext und bleibt lokalisiert. |
| Kontextabstand | Fester `SimpleGroup`-Spacer mit `SetAutoAdjustHeight(false)`, Höhe 8 vor der ersten Sektion. Keine zusätzliche Header-Leiste. |
| Sektionsüberschrift | Bestehendes `CreateSectionTitle()`, Größe 16; `NORMAL_FONT_COLOR` wie im Tree, andernfalls `TextStyles.Get("strongHeading")`. Nominelle Höhe 22; tatsächliche Labelhöhe kann sich nach Breitenzuweisung ändern. |
| Sektionsabstände | Vor jeder weiteren nichtleeren Kategorie 10, nach jeder Überschrift 5. Keine Trennlinien. Kategorien und Reihenfolge bleiben fachlich vorgegeben. |
| Objektzeile | Höhe 30, Schriftgröße 13, anschließend 4 Einheiten Abstand; linksbündig und einzeilig. Keine neue Row-Implementierung oder zusätzliche Zeilenhöhe für Hinweise. |
| Ruhe/Hover | `CompositionTree.surface` / `rowHover`, Kontur aus `Chrome.sectionBorder` beziehungsweise `CompositionTree.text.selected`; im Ruhezustand `idleAlpha = .65`, Text weiß. |
| Aktivierung | Bestehendes SelectionRow-`OnMouseDown` für die linke Maustaste. `selected = false`, `hideMarker = true`; keine dauerhafte Auswahlmarkierung nach dem Hinzufügen. |

Die allgemein vorhandene `binding.presentation` unterstützt `height`,
`labelSize`, `hideMarker`, `idleAlpha`, `colors`, `iconColor` und `iconStates`.
Add Object setzt diese Parameter lokal. Ohne Opt-in bleiben die bisherigen
SelectionRow-Defaults erhalten, einschließlich weißer Icon-Tönung.

## Icons und Farbsemantik

`binding.icon` verwendet vorhandene Assets unter
`Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\`:

| Rolle / Einträge | Asset | Farbquelle `CompositionTree.icon` |
| --- | --- | --- |
| Unit Frames im verwandten Add-Unit-Picker | `fp_icon_unit.png` | `unit`, Goldorange |
| Bars einschließlich instanzierter Resource Bars | `fp_icon_bar.png` | `bar`, Blau |
| Portrait | `fp_icon_portrait.png` | `portrait`, Orange |
| Übrige Indicators | `fp_icon_indicator.png` | `indicator`, Rotorange |
| Buffs / Debuffs | `fp_icon_aura.png` | `aura`, Violett |
| Text | `fp_icon_text.png` | `text`, Goldgelb |
| Decorations | `fp_icon_decoration.png` | `decoration`, Blauviolett |

Add Object vergibt die Medienpfade anhand seiner bestehenden Einträge/Kategorien;
`AddPickerButton()` leitet die Farbrolle aus dem vorhandenen Dateinamen ab.
Das ist eine lokale Präsentationskonvention, keine zweite Komponentenregistrierung
und kein allgemeiner Resolver für beliebige Dateinamen.

`presentation.iconColor` referenziert den Rollen-RGB-Wert,
`presentation.iconStates` die bestehende Tree-Icon-Palette. Normalzustand:
Helligkeit 1, Alpha .90; Hover: 1.05 / .94; Auswahl: 1.18 / 1.00.
RGB wird nach Multiplikation bei 1 begrenzt. Disabled verwendet den vorhandenen
`disabled`-RGBA-Wert; Priorität ist Auswahl, Hover, Disabled, Normal wie im Tree.
Add Object selbst erzeugt keine dauerhafte Auswahl. Rebinding ohne Farb-Opt-in
und Release setzen die Vertex-Farbe auf Weiß mit Alpha 1 zurück.

## Moderne Scrollbar ohne neuen Scrollcontroller

`StyleAddObjectScrollbar()` erhält den bestehenden AceGUI-`ScrollFrame`, dessen
Slider und native Thumb-Hitbox. Wiederverwendet werden:

- Track: `minimal-scrollbar-track-top`, `!minimal-scrollbar-track-middle`,
  `minimal-scrollbar-track-bottom`.
- Thumb: `minimal-scrollbar-small-thumb-top`,
  `minimal-scrollbar-small-thumb-middle`, `minimal-scrollbar-small-thumb-bottom`,
  jeweils normal sowie mit `-over` und `-down`.

Alle zwölf Atlanten werden über die vorhandenen Atlas-Info-APIs geschützt
abgefragt. Fehlen Thumb/API/Atlas oder gültige Abmessungen, bleibt die native
Darstellung unverändert. Das ist kein pauschaler Kompatibilitätsnachweis für
jeden Clientstand; native Sicht- und Eingabeprüfungen bleiben erforderlich.

Sechs zusätzliche Grafikregionen zeichnen Track und Thumb mit acht Einheiten
Breite. Der Slider bleibt 16 breit, sein Wertebereich 0–1000; die bestehende
20-Einheiten-Reserve im AceGUI-Content bleibt bestehen. MouseWheel,
`OnValueChanged`, `SetScroll()` und `FixScroll()` werden nicht ersetzt.
Native Pfeilbutton-Eingabezonen bleiben ebenfalls erhalten; ausgeblendet wird
nur deren bisherige Grafik.

Die lokale Anpassung setzt native Grafik-Alpha-Werte vorübergehend auf null und
ergänzt die vorhandenen Enter-/Leave-/MouseDown-/MouseUp-/Hide-Scripts lediglich
um das Zeichnen der Zustände. Originalhandler werden weiter aufgerufen.
Beim Release werden ursprüngliche Alpha-Werte und Script-Referenzen restauriert,
die eigenen Grafikregionen ausgeblendet und alte Paint-Callbacks deaktiviert.
`_fpAddObjectScrollArt` ist ausschließlich ein interner, verborgen weiterverwendeter
Grafikcache, keine öffentliche API oder neue Scroll-Verwaltung.

## Inhaltshöhe, Close und Pooling

Add Object bleibt 420 breit; die maximale Höhe beträgt
`min(560, UIParent:GetHeight() - 32)`. Das lokale feste Höhenbudget enthält die
57 Einheiten des AceGUI-Window-Vertrags, sechs Einheiten Body-Top-Padding,
24 Einheiten Kontextbudget und acht Einheiten Kontextabstand. Größere gemessene
Kontextlabels erhöhen das Budget. Die Liste wird über das echte List-Layout
gemessen und auf den verbleibenden Platz begrenzt; die minimale Listenhöhe ist 62.
Das ist die lokale Picker-Höhenpolitik, kein allgemeiner Fabrik-Automatismus.

- Kein redundanter Cancel-Button, kein leerer Action-Container und kein
  zusätzliches Footer-Padding. X und Escape genügen für diesen sofort
  aktivierenden Picker; Dialoge mit anderen fachlichen Verträgen separat bewerten.
- `dialog:Close()` versteckt das Fenster. In Add Object führt der zentrale,
  gegen Wiederholung geschützte `OnClose`-Callback zu `AceGUI:Release(window)`.
  Die Fabrik gibt Shell und Kinder rekursiv frei; nicht zusätzlich manuell releasen.
- Titel-Font, Farbe, Ausrichtung, Layer und Anker sowie optional veränderte
  Title-Button-Maße/-Anker werden auf den erfassten Ursprungszustand zurückgesetzt.
- SelectionRow entfernt Binding, Callback, Key, Hover, Icon und optionale
  Schriftanpassung. Späte Leave-Ereignisse dürfen keine Markierung wiederbeleben.
- Gepoolte Widgets dürfen ihren nächsten Consumer nicht einfärben oder mit
  Edit-Mode-/Scrollbar-Grafik überlagern. Tests dürfen keine bestimmte
  Pool-Rückgabereihenfolge oder feldgleiche Widget-Identität voraussetzen.

## UX-Regeln und Übertragung auf einen weiteren Dialog

1. Vorhandenen Fensterbesitz, Close/Cancel, Aktivierung und Datenmutationen
   nachvollziehen. Ein Aktionspicker und ein Editor mit ungespeicherten Eingaben
   haben unterschiedliche Abschlussverträge.
2. Bestehende Fabrik mit explizitem `windowChrome`-Opt-in konfigurieren. Titel und
   Drag-Geometrie nur lokal nach dem tatsächlich freien Headerraum einstellen;
   keine Inspector-Rolle vortäuschen und keine globalen Defaults ändern.
3. Vorhandene Textrollen, SectionTitles, Spacer und SelectionRows verwenden.
   Lange DE-/EN-Namen, schmale Inhalte und UI-Skalierung prüfen. Darstellung
   nicht mit Komponenten-IDs, einer zweiten Registrierung oder Auswahlzuständen
   vermischen.
4. Icon-Assets und kanonische Farben wiederverwenden. Den privaten Tree-Resolver
   und die privaten Add-Object-Builder nicht als allgemeine Services behandeln.
   Die lokale Scrollbar-Grafikanpassung wird durch die Fabrik nicht automatisch
   mitaktiviert; Übertragbarkeit und Restore für den jeweiligen Consumer separat
   prüfen, statt nebenbei ein neues Styling-/Listenframework einzuführen.
5. Fachliche Callbacks weiterverwenden. In Add Object bleiben Request-Revalidierung,
   Combat-/Presence-Prüfungen, Editable-Copy, Selection/Refresh sowie Text- und
   Resource-Bar-Sonderwege außerhalb der grafischen Shell verantwortlich.
   Auch die bestehende Close-vor-Aktion-Ausnahme über `closeBefore` bleibt erhalten.
6. Gezielt Reopen, X/Escape, Release und anschließende Nutzung durch einen anderen
   Consumer prüfen. Nativ Header-Drag links/mittig/rechts, Close-X, Content-Klicks,
   Thumb-Drag, MouseWheel, letzte Row und alternative UI-Skalierung abnehmen.

Vorhandene Regressionen stehen insbesondere in `Tests/AddObjectScroll.lua`,
`Tests/AddObjectPresentation.lua`, `Tests/ParchmentWindow.lua`,
`Tests/DialogWindowFamily.lua`, `Tests/ListSelectionRow.lua`,
`Tests/ComponentActions.lua`, `Tests/SegmentedBarAdd.lua`,
`Tests/CustomizeHeaderGeometry.lua` und `Tests/CustomizeWindowShell.lua`.
Sie ersetzen keine native Prüfung von Grafik, Schriftmetriken und Hit-Tests.
