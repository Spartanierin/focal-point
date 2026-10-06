# Contributing to Focal Point

Small bug fixes and well-scoped features are welcome. Discuss larger changes
before implementation, especially changes that affect the product model,
SavedVariables, startup, runtime activation, or GUI architecture.

## Product and architecture rules

1. Agree on product behavior before designing architecture.
2. Reuse existing services, mutation layers, UI patterns, and lifecycle paths.
3. Avoid opportunistic refactors in a focused change.
4. Do not introduce a second source of truth.
5. New visual components must cover global integrations, not only the visible
   frame.
6. Do not use timers or retries to hide deterministic lifecycle problems.
7. Add or update automated tests for behavior and failure paths.
8. Describe ingame testing and client flavor in the pull request.
9. Do not include ZIPs, SavedVariables, profiler dumps, or debug artifacts.
10. Keep pull requests focused and explain compatibility boundaries explicitly.

## Where to look

| Task | Start here |
| --- | --- |
| Layout storage and summaries | `Services/LayoutService.lua`, `Services/UserLayoutStore.lua` |
| Active layout and runtime selection | `Services/ActiveLayoutResolver.lua`, `Engine/UnitFrame.lua` |
| Account Default and specialization rules | `Services/LayoutAssignmentService.lua` |
| Layout CRUD and transfer | `Services/LayoutMutations.lua`, `Services/LayoutTransfer.lua`, `Services/LayoutTransferVNext.lua` |
| Inspector properties | `GUI/Editor/Inspector/InspectorController.lua`, `InspectorMutations.lua`, `InspectorRefreshPolicy.lua` |
| Canvas and selection | `GUI/Editor/EditorController.lua`, `EditorState.lua`, `Composition/*`, `CanvasToolbar.lua` |
| Runtime components | `Engine/UnitFrame/*`, `Engine/Auras/*`, `Engine/Text/*` |
| Texts Manager and templates | `GUI/Editor/TextTemplateLibraryWindow.lua`, `Engine/Text/Shared/*` |
| Text Builder and tag insertion | `GUI/Pages/TextBuilder/*`, `GUI/Pages/TagLibrary/*` |
| Locales | `Locales/enUS.lua`, `Locales/deDE.lua` |
| Automated tests | `Tests/*.lua` and `Tests/Fixtures/*` |

The canonical contracts are documented in:

- [Product Model](docs/Product/Product-Model.md)
- [Architecture Overview](docs/Architecture/Architecture-Overview.md)
- [GUI Architecture](docs/Architecture/GUI-Architecture.md)
- [Text Architecture](docs/Architecture/Text-Architecture.md)
- [UnitFrame Runtime Lifecycle](docs/Architecture/UnitFrame-Runtime-Lifecycle.md)
- [Tag System Rules](docs/Rules/Tag-System-Rules.md)
- [Code Organization Rules](docs/Rules/Code-Organization-Rules.md)

## Tests and validation

Use the repository's pinned Lua runtime when available:

```powershell
& 'D:\FocalPoint-Dev\tools\Lua\lua54.exe' 'Tests\YourSuite.lua'
& 'D:\FocalPoint-Dev\tools\Lua\luac54.exe' -p 'Path\To\Changed.lua'
git diff --check
```

Run focused tests first, then the relevant established regression suites. Some
tests are embedded helpers and must not be started as independent top-level
suites; follow the suite's existing runner contract.

## Contributor self-check

### Adding a Cast Bar property

Start with the persisted component defaults and the Cast Bar configuration
consumers. Add the Inspector row and mutation through the existing Inspector
layer, update preview/visual-policy behavior, then update the runtime Cast Bar
apply/refresh path. Preserve Match Frame/Custom Width, anchor and scale
contracts, combat behavior, clear/release behavior, localization, transfer
validation, and focused plus regression tests. Use the new visual component
checklist in the [runtime lifecycle guide](docs/Architecture/UnitFrame-Runtime-Lifecycle.md).

### Changing which layout becomes active at login

Start with `LayoutAssignmentService`, `ActiveLayoutResolver`, and the startup
calls in `FocalPoint.lua`. Preserve specialization precedence, Account Default
fallback, legacy initialization behavior, stale-reference handling, dirty-draft
guards, combat deferral, `activeLayoutId` publication, RuntimeRoot identity,
resync, and rollback. Do not implement a second login switch or mutate every
character. Update the startup/activation tests before making UI changes.
