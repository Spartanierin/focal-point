# Focal Point Documentation

STATUS: CURRENT - documentation entry point for the current repository state.

This documentation intentionally separates three layers:

- CURRENT: documents what the current code actually implements.
- HISTORICAL: old architecture notes, migration plans, theme-system drafts, and completed roadmaps. These files are preserved, but they are not normative.
- FUTURE / DESIGN DIRECTION: discussed product and UX direction for later 2.0 work. These documents do not describe implemented architecture.

## Canonical current documents

- `Architecture/Architecture-Overview.md`: system map, major modules, and data flows.
- `Architecture/GUI-Architecture.md`: current GUI, editor, tool, and inspector structure.
- `Architecture/Text-Architecture.md`: current text, template, and tag flow.
- `Architecture/UnitFrame-Runtime-Lifecycle.md`: build/apply/refresh/visibility lifecycle for unit frames.
- `Product/Product-Model.md`: product language for profiles, presets, demo, unlock, text, and the Health Family.

## Current rules and concepts

- `Rules/Code-Organization-Rules.md`
- `Rules/GUI-Visual-Role-Rules.md`
- `Rules/Tag-System-Rules.md`
- `Rules/Aura-Time-Classification.md`
- `Architecture/Aura-System-Concept.md` is CURRENT/PARTIAL: it still documents important aura principles, but it does not replace current runtime documentation.
- `Design/Editor-UX-Principles.md` is CURRENT/PARTIAL: valuable UX principles, not a complete 2.0 specification.

## 1.x-specific or partial design references

- `Rules/GUI-Layout-Rules.md` is CURRENT/PARTIAL: relevant for existing 1.x surfaces, but not a rigid 2.0 norm.
- `Design/GUI-Aura-Layout.md`, `Design/GUI-Header-Layout.md`, and `Design/GUI-Text-Style.md` are partial 1.x design references.
- `Design/UI-Foundations.md` documents current UI foundations and requirements before larger 2.0 UI work.

## Future / 2.0 Design Direction

- `Roadmap/2.0-Design-Principles.md` is FUTURE / DESIGN DIRECTION. It describes direction and principles, not implemented architecture and not a final roadmap.

## Historical documents

Historical documents live under `Historical/` and are preserved for traceability:

- `Historical/0.x-Architecture/`: old architecture overviews and migration descriptions.
- `Historical/Theme-System/`: earlier theme-system notes and implementation plans.
- `Historical/Old-Roadmaps/`: old roadmaps and completed implementation plans.
- `Historical/Skin-Backups/`: old skin/backup files.

Historical documents must not be used as current technical truth unless a current document explicitly points to a still-valid detail.
