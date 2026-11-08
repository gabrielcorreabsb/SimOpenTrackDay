# Plan: project organization

## Goal

Reduce unnecessary context and make intent easier to recover through concise documentation. This does not promise session recovery after rename or automate OpenCode configuration.

## Status and phases

- [x] Create a concise auto-loaded entry point, topic index, and OpenCode workflow; the localization reference also exists.
- [x] Keep technical references at their existing paths; this phase did not reorganize source or configuration files.
- [ ] Consider moving or splitting references only when there is a concrete need; update and verify every affected link.
- [ ] Diagnose potential `.gitignore` cleanup only; do not perform cleanup in this plan phase.
- [ ] Consider skills, commands, or local configuration only if needed and after exact-file approval. Do not invent agents/plugins or change models/permissions.

## Acceptance

- Short task-based index and identifiable source of truth by topic.
- Valid internal links; automatic rules distinguished from human guides and plans.
- No runtime, dependency, or global/local configuration changes without specific authorization.

## Suggested next step

Before implementing the UI redesign, validate the current UI in CSP and record observations; see the [identity plan](UI_IDENTITY.md).
