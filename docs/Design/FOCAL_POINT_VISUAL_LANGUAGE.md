# Focal Point Visual Language v1

STATUS: CURRENT / NORMATIVE

## Zweck

Dieses Dokument ist die kanonische Referenz fuer die visuelle Sprache von Focal Point. Es definiert die Bedeutung von Farben, Oberflaechen, Interaktionszustaenden und Control-Rollen fuer neue und schrittweise angepasste Oberflaechen.

Es ist kein Auftrag zu einem Big-Bang-Restyling. Bestehende Oberflaechen duerfen in kleinen, verhaltensbewahrenden Schritten angepasst werden.

## Designziel

> Focal Point feels like a modern World of Warcraft editing tool: dark, warm, precise and native to the game, with a restrained Focal Point orange/gold accent and one consistent visual grammar across all controls.

Focal Point verwendet die visuelle Materialitaet der WoW-Spielwelt, behaelt aber eine eigene Editor-Identitaet:

> Focal Point does not imitate Blizzard UI. It uses World of Warcraft's visual environment as its material foundation while maintaining its own editor identity.

Focal Point soll nicht wie ein klassisches WoW-2008-Optionsfenster, eine Kopie von Blizzard UI, ElvUI oder EllesmereUI oder eine generische Desktop-Anwendung wirken. Gold ist kein Ornament und darf die Oberflaeche nicht dekorativ oder schwer machen.

## Nicht-Ziele

- Keine neue GUI-, Theme- oder Widget-Engine allein fuer visuelle Konsistenz.
- Keine erzwungene Vereinheitlichung spezialisierter Renderer.
- Keine Ersetzung von WoW- oder Gameplay-Farben wie Klassen- und Ressourcenfarben.
- Keine neue Architektur oder Verhaltensaenderung als Nebenwirkung von visuellem Polish.
- Keine grossflaechige Bereinigung historischer Dokumentation.

## Kernprinzip

> Semantics are global. Geometry stays local.

Semantische Rollen wie `Selected`, `Focus`, `Hover`, `Primary` und `Destructive` sind produktweit konsistent. Ihre konkrete Geometrie und Implementierung bleiben beim jeweiligen Control.

- Eine Composition-Tree-Row und eine Layout-Row muessen nicht dasselbe Widget sein.
- Ein Canvas-Selection-Frame und eine ausgewaehlte Tree-Row muessen nicht identisch aussehen.
- `FPCompactSlider` darf ein Spezial-Control bleiben.
- Lokale Renderer duerfen bestehen bleiben.

Lokale Controls sollen dennoch dieselben kanonischen semantischen Rollen konsumieren. Daraus folgt ausdruecklich keine Forderung nach einem neuen generischen GUI-, Theme- oder Widget-Framework.

## Material und Oberflaechen

Focal Point verwendet sehr dunkle, leicht warme Charcoal-Oberflaechen. Wo der Editor die Spielwelt als Arbeitsraum sichtbar halten soll, darf die Flaeche leicht transparent sein.

- `SurfaceBase`: ruhige primaere Arbeits- oder Fensterflaeche.
- `SurfaceInset`: erkennbar tiefere Flaeche fuer Inputs, Listen oder untergeordnete Arbeitsbereiche.
- `SurfaceExplorer`: sehr dunkle Explorer-Flaeche fuer strukturierte Arbeitsraeume wie den Composition Tree.

Inset-Struktur entsteht primaer durch ruhige Surface-Unterschiede und nicht durch viele verschachtelte graue Boxen. Gold darf nicht als permanente grossflaechige Dekoration eingesetzt werden.

## Borders und Window Chrome

Normale Struktur verwendet subtile, warme dunkle Borders. Eine staerkere Bronze- oder Goldnote ist nur fuer Hierarchie, Window Chrome oder einen klaren aktiven Kontext zulaessig.

- `BorderSoft`: normale, zurueckhaltende Struktur.
- `BorderStrong`: begruendete staerkere Trennung oder Chrome-Hierarchie.
- Keine permanent leuchtenden Goldrahmen.
- Keine zusaetzliche Ornamentik, nur um etwas "mehr WoW" wirken zu lassen.

> WoW liefert Materialitaet. Focal Point liefert Praezision.

Ein Focal-Point-Fenster ist dunkel, leicht warm und gegebenenfalls leicht transparent. Es hat eine feine Kontur und eine zurueckhaltende Bronze- oder Goldnote, kopiert aber kein Blizzard-Dialogfenster. Das Close-Control gehoert sichtbar zur selben Control-Familie wie andere Actions.

## Farbsemantik

Die Focal-Point-Orange-/Gold-Familie ist die kanonische Brand- und Interaktionsfamilie.

Gold/Orange steht fuer:

- Brand-Akzent
- `Selection`
- `Focus`
- `Active`
- `Primary Action`

Rot steht ausschliesslich fuer:

- `Destructive` Actions
- Errors oder invaliden Zustand

Rot ist nie normaler Focus, normaler Pressed-State oder allgemeine Hervorhebungsfarbe. Slate/Blue darf als neutrales Material oder fachliche Ingame-Farbe bestehen, besitzt aber keine konkurrierende globale UI-Semantik fuer `Active` oder `Selected`. Klassen-, Power- und andere Gameplay-Farben bleiben Inhaltsfarben und werden nicht durch Editor-Chrome ersetzt.

Kanonische semantische Kandidaten sind `BrandGold`, `DestructiveRed`, `TextPrimary`, `TextSecondary`, `TextDisabled`, `SurfaceBase`, `SurfaceInset`, `SurfaceExplorer`, `BorderSoft` und `BorderStrong`.

## Interaktionszustaende

### Normal

Ruhig und dunkel. Normal ist die Grundlage, nicht eine abgeschwaechte Primary-Darstellung.

### Hover

Leicht heller und/oder waermer. Hover zeigt Interaktivitaet, ohne `Selected` zu imitieren.

### Pressed

Etwas tiefer, dunkler oder kontrastreicher. Rot ist kein allgemeiner Pressed-State.

### Selected

Verwendet Gold/Orange als strukturellen Akzent, nicht automatisch als grossflaechige Goldfuellung.

### Focus

Eine feine warme Gold-/Orange-Kante oder gleichwertige lokale Darstellung. Focus und Selection sind verschieden, nutzen aber dieselbe Markenfamilie.

### Active

Verwendet dieselbe Gold-Familie. Wenn Active fachlich von Selected abweicht, erfolgt die Unterscheidung durch Form oder Statusdarstellung, nicht durch eine zweite konkurrierende Akzentfarbe.

### Disabled

Entsaettigt, kontrastarm und eindeutig nicht interaktiv, ohne unlesbar zu werden.

## Selection und Arbeitskontext

> Gold/Orange bedeutet: Das ist der aktuelle Arbeitskontext.

Die Darstellung darf je Oberflaeche variieren.

- Composition Tree: dunkle Row bleibt Grundlage; eine subtile warme Aufhellung, Gold-/Orange-Kante, Border oder vergleichbarer struktureller Akzent und hoeherer Textkontrast markieren die Auswahl. Eine vollflaechige beige oder goldene Selection ist nicht der Standard.
- Unit Navigator: Active und Selected verwenden dieselbe Gold-/Orange-Familie; eine konkurrierende Blue-/Slate-Active-Semantik ist nicht zulaessig.
- Layout Manager: Selected verwendet dieselbe Selection-Sprache. Das aktive Layout darf zusaetzlich ein Statuslabel, Icon oder Marker tragen, aber nicht eine zweite Akzentfarbe.
- Canvas: Das bestehende fachliche Selection-Modell bleibt unveraendert; sein Selection Frame gehoert zur Gold-/Orange-Familie. Tree, Canvas und Inspector sollen als ein Arbeitskontext lesbar sein.

## Typografie

Focal Point verwendet eine kleine, klare Hierarchie.

- Window Title: hoechste Textebene, warmes Gold oder Creme.
- Section Title: warm, aber zurueckhaltender als ein Window Title.
- Primary Text: helles, leicht warmes Weiss.
- Secondary Text: gedaempftes Grau oder Beige.
- Hint und Disabled: deutlich reduzierter Kontrast.

Gold ist nicht automatisch die Farbe jeder Ueberschrift oder jedes wichtigen Textes. Typografie darf nicht mit Selection und Primary Actions konkurrieren.

## Section Header

Section Header strukturieren, sie dekorieren nicht.

- Warmer heller Gold-/Creme-Titel.
- Feine horizontale Struktur oder Linie.
- Normalerweise keine eigene Box.
- Konsistente Abstaende.
- Eine Section beantwortet eine klare Nutzerfrage statt nur technische Komponenten zu gruppieren.

Vermeiden: `Panel -> Box -> Box -> Control -> Box`.

## Control-Rollen

### Buttons

Es gibt genau drei semantische Action-Rollen:

- `Primary`: zentrale positive Aktion im lokalen Kontext, zum Beispiel `Add Object`. Der staerkste zulaessige FP-Akzent, jedoch kein unnoetig leuchtender Vollflaechenbutton.
- `Utility`: normale sekundaere Aktion, zum Beispiel `Manage Layouts`, `Rename`, `Duplicate` oder `Close`. Ruhige dunkle Oberflaeche; Hover zeigt Interaktivitaet.
- `Destructive`: `Delete`, `Remove` und vergleichbare destruktive Aktionen. Rot ist eine Warnsemantik; der Normalzustand darf zurueckhaltend sein und Hover darf die destructive Bedeutung verdeutlichen.

Ein Glyph- oder Icon-Button ist keine vierte Rolle. Er ist lediglich eine kompakte Darstellung von `Primary`, `Utility` oder `Destructive`.

### Dropdown

Dropdowns verwenden eine dunkle Inset-Surface, subtile warme Border und einen zur Control-Familie gehoerenden Pfeil. Hover wird leicht waermer, Focus verwendet eine feine Goldkante und Disabled ist kontrastarm. Toolbar-Selector und Inspector-Dropdown duerfen geometrisch verschieden sein, gehoeren aber derselben Familie an.

### Checkbox

Checkboxen sind die Standarddarstellung fuer binaere Zustaende. Derselbe boolesche Property-Typ wird nicht beliebig zwischen Checkbox, Toggle Switch und gedruecktem Button gemischt.

Checked verwendet einen zurueckhaltenden Gold-/Creme-Akzent. Hover ist warm und Disabled klar gedimmt.

### Slider

`FPCompactSlider` darf technisch ein Spezial-Control bleiben. Sein Track ist ruhig und dunkel, der Handle gut erkennbar. Focus oder aktive Interaktion duerfen Gold verwenden. Ein Slider wird nicht dauerhaft vollstaendig orange oder gold gefaerbt.

Gold zeigt Interaktion, nicht Dekoration.

### EditBox und Input

Inputs verwenden eine dunkle Inset-Surface und subtile Border. Hover ist nur minimal heller oder waermer, Focus nutzt eine Goldkante. Rot ist Invalid/Error vorbehalten; normale Eingabe verwendet kein Rot.

### Tree- und List-Row

Composition Tree und Layout Manager duerfen eigene Renderer und Geometrie behalten. Gemeinsame Semantik:

- Normal: ruhige dunkle Row.
- Hover: subtile warme Surface-Reaktion.
- Selected: Gold-/Orange-Strukturakzent plus hoeherer Textkontrast; keine vollflaechige Goldflaeche als Standard.
- Disabled: deutlich gedimmt.

Ziel ist gleiche Bedeutung, nicht identische Implementierung.

## Technische Ownership und Integration

Diese Spezifikation legt Designregeln fest, nicht den vollstaendigen aktuellen Implementierungsstand. Folgende vorhandene Schichten sind wahrscheinliche technische Owner:

- `GUISkin.visual` und `GUISkin.textColors`: semantische Farben und Tokens.
- `FormElementDefinition.ComponentStyles`: semantische Component- und Action-Rollen.
- `FormWidgets`: gemeinsame Verbraucher fuer Dialog-Chrome, Actions, Dropdowns, EditBoxes und Checkboxes.
- `TextStyles`: Textrollen.
- `FormSectionSurfaceRenderer`: Surface-, Border- und Section-Regeln.

Spezialisierte lokale Renderer bleiben erlaubt, insbesondere Composition Tree, Canvas, Layout Rows, `FPCompactSlider` und andere geometrisch oder interaktiv spezialisierte Controls. Sie sollen semantische Tokens konsumieren, ohne auf ein gemeinsames Renderer-Framework umgestellt werden zu muessen.

## Migration und aktuelle Abweichungen

Die Visual Language v1 ist verbindliche Zielsemantik fuer neue und schrittweise angepasste Oberflaechen. Sie behauptet nicht, dass jeder bestehende Consumer bereits konform ist.

Bekannte Migrationsthemen:

- Slate/Blue wird aktuell teilweise fuer Hover, Pressed oder Active verwendet.
- Der Unit Navigator verwendet bereits eine waermere Gold-/Orange-Active-Semantik.
- Tree Rows besitzen lokale Farben und einen spezialisierten Renderer.
- `FieldStyles.accented` verwendet derzeit roten Focus-/Pressed-Kontrast; das ist gegen die hier definierte Rot-Semantik zu migrieren, nicht als neue Regel zu lesen.
- Layout Rows verwenden einen lokalen gepoolten Renderer.

Breite Section- oder `SimpleGroup`-Politur bleibt bis zum Abschluss der bekannten Inspector-1px-/Pooling-Diagnose zurueckgestellt.

## Guardrails fuer zukuenftige UI-Arbeit

- Vor einem neuen lokalen Style pruefen, ob bereits eine semantische Rolle existiert.
- Keine zweite Farbsemantik fuer denselben Zustand schaffen.
- Keine neue Widget- oder Theme-Engine allein zur visuellen Vereinheitlichung bauen.
- Spezialrenderer duerfen lokal bleiben.
- Semantische Tokens zentral konsumieren statt lokale Farbwerte zu duplizieren.
- Visueller Polish darf Layout-, Sizing-, Pooling- oder Lifecycle-Verhalten nicht unnoetig veraendern.
- Bei kleinen Anpassungen vorhandene Rows, Container und Patterns bevorzugen.
- Wenn ein kleiner visueller Polish neue Renderer-, Window- oder Layout-Infrastruktur benoetigt: stoppen und neu bewerten.
- Neue UI muss sowohl zur Focal-Point-Identitaet als auch zur WoW-Spielwelt passen.
- Gold zeigt Bedeutung, nicht Dekoration.

## Verhaeltnis zu bestehenden Dokumenten

`Rules/GUI-Visual-Role-Rules.md` bleibt die allgemeine Regel fuer rollenbasierte visuelle Hierarchie. Dieses Dokument praezisiert die verbindliche Farb- und Zustandssemantik fuer Focal Point.

`Design/Editor-UX-Principles.md` und `Design/UI-Foundations.md` bleiben CURRENT/PARTIAL und beschreiben UX-Richtung beziehungsweise technische Grundlagen. Sie werden hier nicht als vollstaendige Style-Spezifikationen ersetzt.

`Design/GUI-Text-Style.md` ist eine 1.x-Teilreferenz. Sein historischer blauer `highlight`-Text darf als Inhalts- oder Referenzakzent bestehen, begruendet aber keine konkurrierende globale UI-Semantik fuer Selection, Focus oder Active.
