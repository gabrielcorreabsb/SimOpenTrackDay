# Plan: UI identity and flow

**Status:** approved as a documentation plan; not implemented. The current baseline is distinct from the proposed redesign.

## Direction

Shape the interface as a track-day operations center / pit wall. Communicate workflow through hierarchy, grouping, and states—not color alone. Preserve the dark theme, red accent, vector logo, and credits. Do not invent metrics or telemetry, or change AI behavior, defaults, profiles, or persistence.

Proposed dashboard: brand, track, session, and actual app status; distinguish enabled from able to run. Show a mode/profile summary or “Custom” only when there is a safe match. Current inference compares only a few fields and must not be described as already reliable. Keep the lane diagram central, with a settings action and short description. Separate Overview from Diagnostics: Overview prioritizes readability; Diagnostics retains the complete technical table and accessible original toggle. This trades simultaneous visibility for lower density.

Proposed settings categories: Driving; Lanes and maneuvers; Experimental (accidents/pathfinding, with warnings); and Advanced and Diagnostics. Use sidebar navigation in wide windows and a compact selector at narrow widths. Keep common controls accessible.

## Existing baseline

The current source includes responsive layout in some sections, en/pt-BR/es localization, and profile inference from existing values. These do not constitute the proposed dashboard or settings categories. CSP runtime and actual appearance remain unvalidated; source does not establish what is installed.

## Proposed phases

1. **[ ] Validate current CSP baseline** — small; depends on installing a test copy and recording evidence. Acceptance: observe window sizes, callbacks, locale, and current state; do not claim prior CSP validation.
2. **[ ] Redesign dashboard** — medium; likely `SimOpenTrackDay.lua`, `UIManager.lua`, `lib/uilib/` modules/widgets, and catalogs. Acceptance: distinguish app states, avoid false profile certainty, keep lanes legible, and provide description/settings access without invented telemetry.
3. **[ ] Visual validation** — small/medium; depends on phase 2 and CSP. Checklist: wide/narrow layouts, overflow, readability, and access to the full table/toggle.
4. **[ ] Categorize settings** — medium; likely `SettingsWindow.lua`, project-owned UI modules, and catalogs. Acceptance: planned groups and experimental warnings, common controls accessible, navigation adapted to width.
5. **[ ] Review locales** — small/medium; depends on final copy. Acceptance: complete en/pt-BR/es catalogs, matching placeholders, stable IDs; run localization and relevant mock checks.

Required order: validate the current UI in CSP first, redesign the dashboard, validate visually, then categorize settings and review locales. Every `[ ]` item is proposed work, not completed work.
