STATUS: CURRENT - canonical code-organization rule.

# CODE ORGANIZATION RULES

## Purpose
Define file-role naming and folder organization rules for GUI work.
This is a release-facing rule set, not a draft guideline.

## Scope
- `GUI/Editor/*`
- `GUI/Pages/*`
- `GUI/Helpers/*`
- `GUI/Widgets/*`
- `GUI/Layouts/*`

## Folder Responsibility Model
- `GUI/Editor/<Feature>/...`: editor-internal feature runtime (for example Toolbar, Inspector).
- `GUI/Pages/<Feature>/...`: standalone tool pages (for example Profiles, TextBuilder, TagDatabase).
- `GUI/Helpers/...`: narrow technical helpers only. No catch-all helper buckets. Domain orchestration must not be hidden here.
- `GUI/Widgets/...`: reusable generic widget primitives.
- `GUI/Layouts/...`: generic/system-wide declarative definitions only. If a definition is feature-owned, it should live with the feature.

## File Role Naming Model
Use explicit role suffixes.

- `*Controller.lua`: feature orchestration, entry, lifecycle, routing, host coordination.
- `*Binding.lua`: runtime wiring, callbacks, widget-state sync, refresh coordination.
- `*Definition.lua`: declarative WHAT (`structure`, `lists`, `properties`, `options`).
- `*Widget.lua`: reusable UI widget/component.
- `*State.lua`: explicit state ownership and state API.

Optional roles:

- `*Style.lua`: use only when styling is the dominant responsibility of the file.
- `*Renderer.lua`: use only when rendering is the dominant responsibility of the file.

## Role Boundaries (What Must Not Be Mixed)
- `Controller` must not become a large style/token file.
- `Definition` must not host callback logic or runtime side effects.
- `Binding` must not own host/window lifecycle.
- `Widget` must not become a feature orchestrator.
- `State` must not hide UI build/orchestration logic.
- `Style` and `Renderer` are optional roles; do not introduce them unless responsibility is clearly dominant.

## Current Baseline (April 2026)
- Pages use `*Controller.lua` + `*Definition.lua` naming.
- Editor features use `*Controller.lua`; Toolbar already has `ToolbarBinding.lua` and `ToolbarDefinition.lua`.
- Widgets use explicit `*Widget.lua` naming.
- States use explicit `*State.lua` naming where ownership is isolated.
- Legacy/transitional names may still exist, but they are not baseline naming.

## Anti-Patterns
- `Draft` in production file names.
- `Builders` as a generic catch-all when the role is controller/router.
- `Page.lua`, `Layouts.lua`, or `Builders.lua` as implied baseline role naming.
- `Shared` as a default naming pattern.
- Historical names that do not describe current responsibility.
- One file mixing controller + binding + style + definition without explicit reason.

## Shared Naming Rule
- `Shared` is an exception, not a default naming pattern.
- `Shared` is only allowed when the consumer group is explicit and stable.
- The `Shared` boundary must be documented in the file header or surrounding docs.

## Refactor Order Rule (Binding)
1. Structure and path clarity first (folder + filename roles).
2. Internal module/identifier naming alignment second.
3. Content-level split/refactor third (behavior-preserving).
4. Behavior or UX changes only by explicit decision.

## Migration Policy
- Prefer small, safe steps with stable runtime behavior.
- Do not introduce broad rewrites during naming/path cleanup.
- Mark unclear cases explicitly as `unclear / needs decision` instead of guessing.

