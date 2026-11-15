# WoW Modern UI Design Guide

Status — Gestalterische Grundlage für eigenständige Focal-Point-Funktionsfenster.
Die technischen Angaben beschreiben den Stand nach dem UI-Abschluss auf Basis
von `ef83876e441a3a4cd62d34a68302ce515ab41b61`.
Native Grafikabnahmen bleiben Bestandteil jedes einzelnen Umstellungsblocks.

## Zwei Designwelten

| Designwelt | Einsatz und Aufgabe |
| --- | --- |
| Edit Mode Look | Canvas / Customize, Add Object, Add Unit sowie Manage Layouts, Specialization Assignments, Options und New Layout. Gemeinsame Fensteroptik bei jeweils eigener Informationsarchitektur. |
| WoW Modern Look | Media Libraries und Tag Library verwenden weiterhin ihre bestehende Modern-/Materialdarstellung. Weitere Funktionsfenster werden je aktivem Consumer gesondert bewertet. |

Die Zuordnung ist eine Produktentscheidung. Der technische Umstellungsstand wird
je Consumer geprüft. Die vorhandene
[Edit-Mode-Referenz](EditMode-Dialog-Pattern.md) bleibt die Grundlage für dessen
eigene Chrome-, Typografie- und Interaktionsverträge.

## Gestaltungsprinzipien

- Visuelle Gewichtung folgt der Nutzeraufgabe. Titel und primärer Zustand geben
  Orientierung, sekundäre Erklärungen treten durch vorhandene Textrollen zurück.
- Zusammengehörige Informationen werden räumlich gruppiert. Ein Panel erhält
  eine fachliche Aufgabe und eine inhaltsgerechte Größe. Einfache Sections können
  durch Überschrift und Abstand gegliedert werden.
- Metallrahmen und Titelleiste bilden die äußere Shell. Kontext, Status und ein
  oberer Hintergrundübergang werden mit der tatsächlichen Content-Geometrie
  abgestimmt. Navigation und globale Aktionen erhalten einen fachlich passenden Ort.
- Übergeordnete und lokale Navigation werden unterscheidbar dargestellt.
  Die Auswahl eines Eintrags und seine fachliche Aktivierung sind eigene Aktionen.
  Für Layouts gilt insbesondere die bestehende Trennung von Row-Auswahl und
  Aktivierung über die Canvas Toolbar.
- Status steht möglichst beim zugehörigen Inhalt. Lokale Aktionen stehen am
  betreffenden Objekt. Übergreifende Aktionen können Header oder Footer nutzen.
  Ob ein Footer benötigt wird, ergibt sich aus dem Abschluss- und Aktionsvertrag.
- Gleichartige Objekte verwenden konsistente Zustände für Hover, Auswahl und
  Disabled. Listen eignen sich für vergleichbare Einträge, Karten für wiederholte
  Informationspakete und Panels für zusammengehörige Aufgaben.

## Blizzard-Referenzen und Informationsarchitektur

Die folgende Einordnung ist eine projektinterne Analyse der im Auftrag
beschriebenen sichtbaren Blizzard-Oberflächen. Die exakte Grafik und das
Interaktionsverhalten der Referenzen sind beim jeweiligen nativen Vergleich zu
prüfen. Offiziell dokumentierte Blizzard-UX-Regeln werden daraus nicht abgeleitet.

| Referenz | Beobachtetes Organisationsprinzip | Übertragbare Entwurfsfrage |
| --- | --- | --- |
| Guild & Communities | Mehrere fachlich getrennte Inhaltsbereiche, eingefasste Panels, Header-Navigation, kontextbezogene Aktionen und eine Footer-Aktion. | Welche Bereiche benötigen eine eigene Abgrenzung, lokale Navigation oder einen gemeinsamen Abschluss? |
| Housing Dashboard | Zustandsorientierter Einstieg, dominante Kennzahl, kontextabhängige Fortschrittsnavigation und gleichartige Belohnungskarten. Ein Aktionsfooter ist für dieses Modell optional. | Welcher Zustand muss zuerst verständlich sein, und welche wiederholten Informationen lassen sich als Karten vergleichen? |
| Adventure Guide / Traveler's Log | Die beschriebenen Referenzansichten zeigen Kontext und Fortschritt, Kategorie- und Inhaltsnavigation, unabhängige Scrollbereiche und wiederkehrende Eintragskarten. | Welche Navigationsebene steuert welchen Inhalt, und welche Bereiche müssen unabhängig scrollen? |

Adventure Guide und Traveler's Log werden bei einer konkreten Übertragung als
eigene Referenzansichten identifiziert. Die gemeinsame Nennung legt keine
identische technische Implementierung fest.

Die belegte technische Communities-Referenz stammt aus Gethe-Commit
`297d7aaaa736f346b3e036f38ee088eaf7f8c07f`. `CommunitiesFrame` erbt
`ButtonFrameTemplateMinimizable`. Dessen Template-Kette kombiniert äußeren Rock,
TopTileStreaks und einen Inhalts-Inset mit Marble. Diese gemeinsame Shell und die
Communities-spezifischen Listenflächen besitzen getrennte Zuständigkeiten.
[CommunitiesFrame.xml](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_Communities/CommunitiesFrame.xml#L304),
[SharedUIPanelTemplates.xml](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml#L660-L708)

## Vorhandene technische Bausteine

| Baustein | Bestehender Einstieg und tatsächliche Grenze |
| --- | --- |
| Compact-Dialog | `FormWidgets.CreateCompactFormDialog(options)` unterstützt die expliziten Opt-ins `windowChrome = "editmode"` und `windowChrome = "modern"`. `portrait = false` wählt im Modern-Pfad den portraitlosen Rahmen. Ohne Opt-in bleiben die bestehenden Dialog-Defaults erhalten. Der Consumer behält Fensterbesitz, Inhalt und fachliche Aktionen. |
| Modern-Chrome direkt | `FormWidgets.ApplyModernWindowChrome(window, options)` verwendet mit `nineSlice = true` die vorhandenen Blizzard-NineSlice-Layouts. `portrait` wählt den Rahmen. `focalPointTool = true` aktiviert die bisherige Focal-Point-Materialdarstellung. |
| Hintergrund und oberer Übergang | Im Modern-Pfad reicht die Fabrik `background = "blizzard"` und `topTileStreaks = true` weiter. Rock wird über den bestehenden Hintergrundpfad erzeugt. Streaks sind ein explizites Opt-in im portraitlosen NineSlice-Pfad und werden erst nach erfolgreicher Atlas-Abfrage angezeigt. Der Edit-Mode-Pfad verwendet stattdessen den dunklen, transparenten Hintergrund ohne Rock oder Streaks. |
| Restore, Close und Fokus | `RestoreDefaultWindowChrome()`, `EnsureStandardWindowCloseButton()`, `CenterWindow()` und `FocusWindow()` sind vorhandene Funktionen. Die Compact-Fabrik besitzt Shell-Release und Escape-Anbindung. `dialog:Close()` versteckt das Fenster, tatsächliches Release wird vom bestehenden Consumer-Vertrag bestimmt. |
| Text und Sections | `ApplyTextStyle(target, role, size, alpha)`, `CreateBodyText()` und `CreateSectionTitle()` verwenden vorhandene Textrollen. Die konkrete Typografie und Abstände werden am jeweiligen Content geprüft. |
| Flächen | `ApplySurfacePresentation(widget, key, options)` gestaltet bestehende Frames unter anderem über `fill`, `border` und `material`. Diese Präsentation legt weder Navigation noch Panel-Größe fest. |
| Palette | `ns.GUI.Skins.GetFormPalette()` stellt unter anderem `Chrome`, `CompositionTree` und `ListSelectionRow` bereit. Lokale Consumer verwenden die bestehenden Rollen und Zustandsfarben. |
| Auswahlzeilen | `ns.GUI.Widgets.SelectionRow.Create(binding)` und `row:Bind(binding)` verwenden `FocalPointSelectionRow`. Das Binding enthält etwa `key`, `label`, `icon`, `selected`, `disabled` und `onSelect`. Optionale `presentation`-Werte steuern die vorhandene Darstellung. Aktivierung erfolgt mit linker Maustaste auf MouseDown. |
| Container und Scrollen | Bestehende AceGUI-Container und `ScrollFrame` bilden vorhandene Inhalts- und Scrollbereiche. Ein zusätzlicher Scrollbereich wird nur bei einer eigenständigen fachlichen Aufgabe eingeplant. |

Technische Quellen sind
[FormWidgets.lua](../../GUI/Helpers/FormWidgets.lua),
[GUISkin.lua](../../GUI/GUISkin.lua) und
[SelectionRow.lua](../../GUI/Widgets/SelectionRow.lua).

## Lokale Lösungen und Wiederverwendungsgrenzen

- Manage Layouts setzt ausdrücklich `windowChrome = "editmode"`, Titelgröße 16,
  `titleOffsetY = -7` (nominal Y=-15) und die lokale 32er-`headerDrag`-Option.
  Die noch vorhandenen Modern-Parameter `portrait`, `background` und
  `topTileStreaks` aktivieren in diesem Pfad weder Rock noch Streaks.
  Ein lokales `InsetFrameTemplate` umfasst den vorhandenen ScrollFrame und den
  Zähler. Seine `Bg`-Region ist verborgen; die zusätzlich eingeführte lokale
  Marble-Content-Texture wurde entfernt. Das Inset ist nicht interaktiv und wird
  beim Release des Bodys verborgen. Ein allgemeiner Content-Inset-Parameter
  existiert hierfür derzeit nicht.
  [LayoutManagerView.lua](../../GUI/Editor/LayoutManager/LayoutManagerView.lua)
- `StyleAddObjectScrollbar()` übernimmt Minimal-Scrollbar-Atlanten auf dem
  vorhandenen AceGUI-Slider, einschließlich lokalem Fallback und Restore.
  Die Funktion ist privat und auf Add Object begrenzt. Das Modern-Chrome-Opt-in
  bringt diese Scrollbar-Gestaltung nicht automatisch mit.
  [CanvasToolbar.lua](../../GUI/Editor/CanvasToolbar.lua)
- Der Composition Tree besitzt eigene Rows, Icon-Zuordnung und Scrollbar-Grafik.
  Seine Gestaltung liefert Referenzwerte. Selection- und Tree-Controller bleiben
  fachlich gebunden. [CompositionTreeControl.lua](../../GUI/Editor/Composition/CompositionTreeControl.lua)
- Media Library und Tag Library verwenden weiterhin direkte Windows mit
  `ApplyModernWindowChrome()` und `focalPointTool = true`.
  [MediaLibraryView.lua](../../GUI/Editor/MediaLibrary/MediaLibraryView.lua),
  [TagLibraryView.lua](../../GUI/Pages/TagLibrary/TagLibraryView.lua)
- Options → Manage Text Templates öffnet über `GUIController.OpenTextBuilderWindow()`
  und das in `TextBuilderEntity.lua` überschriebene `TextBuilder.OpenWindow` den Texts Manager.
  Dieser und die aktiven New-Template-/Edit-Text-Dialoge verwenden Compact-Dialoge
  ohne Edit-Mode-/Modern-Opt-in. Die direkte Modern-Großfensterimplementierung in
  `TextBuilderController.lua` ist nicht der normale Options-Einstieg. Diese Fenster
  sind nicht Bestandteil der abgeschlossenen Vier-Fenster-Umstellung.
  [TextBuilderEntity.lua](../../GUI/Pages/TextBuilder/TextBuilderEntity.lua),
  [TextTemplateLibraryWindow.lua](../../GUI/Editor/TextTemplateLibraryWindow.lua)
- `titleFontSize`, `titleOffsetY` und `headerDrag` sind derzeit Optionen des
  kompakten Edit-Mode-Pfads. Ihre Übertragbarkeit auf Modern-Fenster erfordert eine
  eigene Prüfung des bestehenden Titel- und Drag-Vertrags.

## Entwurf und Umsetzung eines einzelnen Fensters

1. Nutzeraufgabe, Einstieg und Rückweg bestimmen. Auswahl, Aktivierung,
   Datenänderung und Abschluss anhand der vorhandenen Callbacks auseinanderhalten.
2. Informationen und Aktionen fachlich gruppieren. Bestehende Layouts bleiben das
   anwenderseitige Produktmodell, interne Speicherstrukturen bleiben intern.
3. Primäre Information und Zustände bestimmen, einschließlich Read-only,
   Disabled, leerem Inhalt und Fehlerrückmeldung.
4. Passende Blizzard-Patterns für diese Aufgabe auswählen. Panel-Anzahl,
   Navigation, Scrollbereiche und Footer aus dem Inhalt ableiten.
5. Den Entwurf vorhandenen Factories, Textrollen, Rows, Flächen und Services
   zuordnen. Lokale Implementierungen vor einer Übertragung auf Grenzen prüfen.
6. Einen kleinen Implementierungsblock mit explizitem Consumer-Opt-in festlegen.
   Darstellungsänderung und fachliche Mutation behalten ihre bestehenden Besitzer.
7. Funktionale Regressionen und native Sichtprüfung durchführen. Lange DE-/EN-Texte,
   UI-Skalierung, Scrollen, Titel/Close/Drag, X/Escape, Reopen, Release und Pool-Reuse
   prüfen. Client-Fallbacks auf Midnight und Forever nach Verfügbarkeit abnehmen.
8. Den nativ bestätigten Zustand mit API, lokalen Sonderlösungen und Grenzen
   dokumentieren, bevor das Pattern auf einen weiteren Consumer übertragen wird.

## Qualitäts- und Entscheidungspunkte

Vorhandene Editor-Patterns und kanonische Farbrollen haben Vorrang. X/Escape
genügen für sofort aktivierende Picker, sofern der fachliche Vertrag dies erlaubt.
Cancel bleibt bei Entwürfen mit verwerfbaren Eingaben eine eigene Entscheidung.
Darstellung konsumiert bestehende IDs und Kataloge. Weitere Komponentenregister,
Listenframeworks oder Fensterframeworks benötigen keine Einführung für diesen
gestalterischen Ablauf.

Native Sichtprüfungen entscheiden über Kontrast, Schriftmetriken und Hitboxes.
Die aktuelle Manage-Layouts-Komposition mit Edit-Mode-Chrome, dunklem transparentem
Hintergrund und lokalem Listen-Inset wurde vom Entwickler nativ visuell und
funktional abgenommen. Rock und TopTileStreaks sind in diesem Consumer nicht aktiv.
Eine zusätzliche lokale Marble-Content-Fläche gehört nicht zum aktuellen Stand.

Für weitere Fenster bleiben Panel-Zuschnitt, Informationsgewichtung und lokale
Aktionen je Nutzeraufgabe zu entscheiden. Ein allgemein verfügbarer
Marble-Inset-Builder oder Modern-Scrollbar-Style ist durch diesen Guide nicht
eingeführt.
