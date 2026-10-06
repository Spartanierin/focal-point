# Editor UX Principles

STATUS: DESIGN REFERENCE / PARTIAL - useful UX principles, not a current
product-model or architecture specification.

## Principles

- Keep the Canvas as the primary editing context.
- Make selection, active state, disabled state, and preview state distinct.
- Use the Composition Tree and Inspector as contextual companions.
- Keep layout and text workflows routed through their existing services and
  mutation layers.
- Prefer a small, local change over a new GUI framework or duplicate source of
  truth.
- Preserve close/reopen, pooling, combat, stale-context, and refresh contracts.

The current product model and implemented entry points are documented in
`docs/Product/Product-Model.md` and `docs/Architecture/GUI-Architecture.md`.
