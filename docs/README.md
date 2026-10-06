# Focal Point Documentation

STATUS: CURRENT - documentation entry point for the committed repository state.

Current documentation is written in English and is the source of truth for
implemented behavior. Historical and future/design documents are explicitly
labelled and are not normative for current code.

## Canonical current documents

- [Product Model](Product/Product-Model.md): layouts, assignment rules, text
  entities, and current component vocabulary.
- [Architecture Overview](Architecture/Architecture-Overview.md): services,
  data flow, runtime root, transfer, and lifecycle boundaries.
- [GUI Architecture](Architecture/GUI-Architecture.md): editor, Inspector,
  Layout Manager, Texts Manager, and UI ownership patterns.
- [Text Architecture](Architecture/Text-Architecture.md): templates, entities,
  tags, draft safety, and runtime rendering.
- [UnitFrame Runtime Lifecycle](Architecture/UnitFrame-Runtime-Lifecycle.md):
  build, activation, refresh, visibility, combat, and visual integration.
- [Tag System Rules](Rules/Tag-System-Rules.md): prepared values and tag
  boundaries.
- [Code Organization Rules](Rules/Code-Organization-Rules.md): file roles and
  safe change boundaries.
- [Contributor Guide](../CONTRIBUTING.md): workflow, code locations, tests, and
  pull-request expectations.

## Current partial references

The following documents describe valid local design or visual contracts but do
not replace the architecture documents above:

- `Architecture/Aura-System-Concept.md`
- `Design/Editor-UX-Principles.md`
- `Design/FOCAL_POINT_VISUAL_LANGUAGE.md`
- `Design/GUI-Aura-Layout.md`
- `Design/GUI-Header-Layout.md`
- `Design/GUI-Text-Style.md`
- `Design/UI-Foundations.md`
- `PresentationPreview.md`
- `PresentationCompositionPreview.md`
- `NavigatorBrandPlaque.md`
- `NavigatorBrassWindow.md`

When a partial design note conflicts with committed code or the canonical
architecture docs, the code and canonical docs win.

## Historical and future material

- `Historical/` contains old architecture notes, migration plans, theme-system
  drafts, completed roadmaps, and preserved assets. It is not current truth.
- `Roadmap/` contains future/design direction, not an implemented contract.

Historical documents may mention old profiles, presets, themes, text slots, or
selection models for traceability. Current documents may mention those terms
only when describing a compatibility boundary.
