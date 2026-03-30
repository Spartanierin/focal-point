# Focal Point Editor UX Principles

## Zonen

### Links: Kontext und Werkzeuge
- Die linke Spalte steuert den Arbeitskontext des Editors.
- Sie enthaelt Navigation, Unit-Auswahl, Editor-Modus, On-Screen-Bearbeitung, Presets und globale Addon-Optionen.
- Sie liefert Orientierung und Werkzeuge, darf aber nie die zentrale Bearbeitung ueberstrahlen.

### Mitte: Bearbeitungsraum
- Die Mitte ist die wichtigste Zone.
- Sie zeigt entweder den internen Arbeitsraum oder die echten FocalPoint-Frames auf dem Bildschirm.
- Die ausgewaehlte Unit ist der visuelle Mittelpunkt.
- Nicht ausgewaehlte Frames bleiben sichtbar, aber nur die aktive Unit bekommt eine klare Bearbeitungsmarkierung.

### Rechts: Inspector
- Der rechte Bereich bearbeitet immer nur das aktuell Ausgewaehlte.
- Er zeigt Eigenschaften, nicht globalen Kontext.
- Der Inspector arbeitet mit progressiver Offenlegung statt mit voller Gleichzeitigkeit.

## Prioritaet der linken Spalte

Die linke Spalte folgt dieser Reihenfolge:

1. Werkzeuge
2. Arbeitskontext
3. Bearbeiten
4. Presets
5. Addon

Regeln:
- Werkzeuge liegen oben, bleiben aber visuell zurueckgenommen.
- Arbeitskontext und Bearbeiten sind die primaeren Editor-Bloecke.
- Presets sind bewusst sichtbar, aber als Startpunkt und nicht als eigentliche Frame-Eigenschaft einsortiert.
- Addon-Optionen liegen unten, weil sie seltener gebraucht werden.

## Inspector-Regeln

- Nur `Rahmen` und `Gesundheit` sind standardmaessig offen.
- Sekundaere Gruppen starten eingeklappt.
- Gruppen sollen als klare Abschnitte lesbar sein, nicht wie gleichlaute Formularbloecke.
- Fachlich aehnliche Bereiche brauchen eindeutige Titel, zum Beispiel `Zauberbalken` und `Zauberbalken-Position`.
- Der Inspector bearbeitet nur die aktive Unit und soll ruhig, fokussiert und editorisch wirken.

## Fokus-Regeln fuer den Bearbeitungsraum

- Nur die aktive Unit bekommt eine sichtbare gelbe Bearbeitungsumrandung.
- Koordinaten werden nur fuer die aktive oder gerade gezogene Unit gezeigt.
- Unlock dient nur der direkten Bearbeitung auf dem Bildschirm und erzeugt keine flaechige globale Markierung.
- Demo-Daten sind nur ein Datenzustand fuer dieselbe Shell, kein eigener Modus mit eigener Oberflaeche.
- Der Bearbeitungsraum soll sich wie eine echte Editor-Flaeche anfuehlen, nicht wie eine allgemeine Vorschau.

## Allgemeine Editor-Prinzipien

- Nicht zur klassischen Seitenlogik zurueckkehren.
- Kontext links, Bearbeitung in der Mitte, Eigenschaften rechts.
- Nicht alles gleichzeitig maximal sichtbar machen.
- Wichtiges zuerst, Spezielles spaeter.
- Klare Hierarchie vor Dekoration.
- Presets sind Startzustaende, keine parallele Eigenschaftenebene.
- Der Editor soll sich wie ein Werkzeug anfuehlen, nicht wie ein Addon-Optionsdialog.

## Visuelle Schutzregeln

- Architektur-Aenderungen duerfen die sichtbare Editor-Anmutung nicht unbeabsichtigt veraendern.
- Schriftarten, Groessen, Farben, Transparenzen, Linien, Spacer und Abstaende gelten als Teil des Produkterlebnisses.
- Linke Leiste, Arbeitsraum und Inspector muessen ihre visuelle Balance behalten.
- Breiten und Anker der editorischen Hauptzonen sind keine beliebigen technischen Werte, sondern Teil des Designs.
- Ein interner Refactor ist nur dann gut, wenn der Editor danach gleich oder bewusster besser aussieht, nicht nur sauberer implementiert ist.

## Editor-Zielmodell

- Der Editor ist die primaere Produktoberflaeche des Addons.
- Der technische Host ist nur Traegersystem und darf nicht die sichtbare Identitaet des Editors bestimmen.
- Die sichtbare Editorstruktur bleibt:
  1. linke Werkzeugleiste
  2. freier Bearbeitungsraum
  3. rechter Inspector
- Wenn das Traegersystem angepasst wird, soll sich die Bildschirmwirkung dieser drei Zonen moeglichst nicht aendern.

## Migrationsregel fuer den Editor

- Der Editor wird nur phasenweise umgebaut.
- Zuerst werden Verantwortlichkeiten klarer, erst spaeter technische Traeger ersetzt.
- Sichtbare Editor-Bausteine werden erst dann umgehaengt, wenn ihr Erscheinungsbild als Referenz gesichert ist.
- Tool-Seiten duerfen unabhhaengig davon weiter vereinfacht werden; sie sind kein Grund, den Editor frueh mitzuziehen.
- Fruehe Phasen benennen zuerst die drei Editor-Rollen explizit:
  - Toolbar-Host
  - Workspace-Host
  - Inspector-Host
- Die naechste sichere Ebene ist ein eigener, unsichtbarer Editor-Presentation-Host hinter derselben sichtbaren Editor-Komposition.

## Aktuelle Referenzwirkung

- Links und rechts rahmen den Editor wie zwei verwandte Werkzeugzonen.
- Die Mitte bleibt offen und ist kein klassischer Formular- oder Panelbereich.
- Die dunklen, halbtransparenten Seitenflaechen sollen die Spielwelt nicht verdraengen, sondern einrahmen.
- Auch inaktive Unit Frames bleiben sichtbar Teil der Komposition und tragen zur Lesbarkeit des Gesamtlayouts bei.
- Die aktive Unit hebt sich staerker ab, aber der Rest des Layouts darf nicht optisch verschwinden.
- Die visuelle Spannung entsteht aus:
  - dunkler Flaeche
  - goldenen/hellen Ueberschriften
  - roten Aktionsbuttons
  - kompaktem, ruhigem Vertikalrhythmus
- Der Editor soll wie ein eingebettetes Ingame-Werkzeug wirken, nicht wie ein Standard-Optionsfenster.

## Aktuelle Referenzwerte

- Linke Werkzeugleiste: Breite aktuell `285`
- Rechter Inspector: Breite aktuell `285`
- Beide Seitenzonen: dunkle halbtransparente Grundflaechen mit feinen kuehlen Rahmen
- Ueberschriften: klein bis mittelgross, gold/hell, nicht plakativ
- Hilfs- und Beschreibungstexte: kompakt und zurueckgenommen
- Standard-Spacer-Rhythmus: dicht, aber konsistent, meist im Bereich `4` bis `8`

## Architektur-Richtung

- `GUI.lua` ist Bootstrap und Routing, nicht mehr der Ort fuer komplette Shell-Implementierung.
- Shell-Chrome, Tool-Flaeche und App-Geometrie leben in `GUI/AppShell.lua`.
- `Profiles`, `Text Builder` und `Tag-Datenbank` rendern als normale Seiten in die rechte Hauptflaeche der Shell.
- Die linke Kontextleiste und der rechte Inspector leben in `GUI/Editor/ContextSidebar.lua` und `GUI/Editor/InspectorSidebar.lua`.
- Inspector-Lifecycle, Rebuild und Scroll-Restore leben in `GUI/Editor/EditorController.lua`.
- Gemeinsame Sidebar-Helfer und Metadaten leben in `GUI/Editor/SidebarShared.lua`.
- `GUI/Editor/EditorSidebar.lua` bleibt nur als Legacy-Bruecke fuer bestehende Aufrufe erhalten.
- Seiteninhalte bleiben in ihren Page-Modulen.

## Sekundaere Werkzeuge

- `Profiles`, `Text Builder` und `Tag-Datenbank` bleiben eigenstaendige Werkzeuge.
- Sie oeffnen in der rechten Hauptflaeche der Shell und nicht als weiterer Inspector.
- Die linke Spalte bleibt als App-Kontext sichtbar.
- Auf Tool-Seiten wird die linke Spalte vereinfacht: Werkzeuge bleiben oben, der volle Unit-Arbeitskontext wird zugunsten eines kompakten Rueckwegs in den Editor reduziert.
- Der Editor fuer Unit-Frames selbst bleibt davon unberuehrt und wird nicht wieder zur klassischen Seitenlogik zurueckgebaut.

### Layout-Regeln fuer Tool-Seiten

- Tool-Seiten nutzen die rechte Hauptflaeche als Formularbereich statt eines eigenen Innenfensters.
- Inhalte folgen einer klaren Vertikalstruktur:
  1. Einfuehrung
  2. Hauptaktion oder Hauptinhalt
  3. Verwaltung oder Nebenaktionen
  4. seltenere oder destruktivere Aktionen zuletzt
- Lange Aktionsketten sollen in mehrere ruhige Zeilen aufgeteilt werden statt in eine einzige breite Formularreihe.
- Feste Breiten duerfen genutzt werden, muessen aber an die zentrierte Tool-Flaeche angepasst sein und nicht mehr vom alten Vollflaechen-Dialog ausgehen.

## Rueckbau-Regeln

- Alte Editor-Zwischenwelten wie interne Canvas-Vorschauen sollen nicht weiter parallel gepflegt werden.
- `Unlock` veraendert nur Interaktion, nicht das Shell-Layout.
- Demo-Daten veraendern nur den Datenzustand, nicht die Oberflaechenstruktur.
- Wenn alter GUI-Ballast entfernt wird, zuerst tote Abhaengigkeiten und ungenutzte Renderpfade streichen, bevor neue Polishing-Schritte dazukommen.
