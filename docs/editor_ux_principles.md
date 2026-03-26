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

## Sekundaere Werkzeuge

- `Profiles`, `Text Builder` und `Tag-Datenbank` bleiben eigenstaendige Werkzeuge.
- Sie oeffnen als zentrierte Formularflaeche im Mittelbereich statt als weiterer Inspector.
- Die linke Spalte bleibt als App-Kontext sichtbar.
- Auf Tool-Seiten wird die linke Spalte vereinfacht: Werkzeuge bleiben oben, der volle Unit-Arbeitskontext wird zugunsten eines kompakten Rueckwegs in den Editor reduziert.
- Der Editor fuer Unit-Frames selbst bleibt davon unberuehrt und wird nicht wieder zur klassischen Seitenlogik zurueckgebaut.

### Layout-Regeln fuer Tool-Seiten

- Tool-Seiten nutzen eine bewusste, zentrierte Werkzeugflaeche statt eine fast vollflaechige Form.
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
