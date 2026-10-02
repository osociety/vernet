---
name: project-task
description: "Complete Vernet feature work, bug fixes, release tasks, workflow issues, and repo-wide implementation work by using the project’s instructions, memory, and the most relevant specialized skill."
argument-hint: "Describe the task, behavior change, failing test, issue, or CI problem"
---

# Project Task

Use this when a request is broad or cross-cutting and needs the repo’s guidance, memory, and the most relevant specialized skill to complete the work without guessing.

## Procedure

1. Read the repository guidance first: `.github/copilot-instructions.md`, `AGENTS.md`, and `ARCHITECTURE.md` before making a structural or architectural change.
2. Check relevant memory before deciding the approach:
   - read `/memories/` for user or repo constraints, testing patterns, and past fixes
   - use `/memories/session/` for multi-step task tracking
   - preserve prior notes about failing-test workflow and verification standards
3. Identify the task type and choose the closest specialized skill:
   - `graphify` for architecture, file relationships, request routing, or “where is this implemented?” questions
   - `github-issue-implementation` for issue-driven fixes or requested behavior changes
   - `flutter-feature-iteration` for UI, screens, and feature behavior changes
   - `flutter-test-repair` for failing unit, widget, or integration tests
   - `github-actions-repository-workflows` for CI workflow or repo automation failures
   - `android-fastlane-release` for Android release or beta delivery work
   - `firebase-hosting-config` for Firebase or web deployment config problems
   - `close-chat` when asked to close or wrap up a chat, record durable context, or prepare a handoff
4. State one falsifiable cause or expected-behavior hypothesis, then pick the smallest validation that could disprove it. Start from the concrete problem, not a broad refactor.
5. Keep changes narrow and in the correct layer:
   - UI in `lib/pages/` or `lib/widgets/`
   - networking in `lib/services/`
   - data in `lib/models/`
   - utilities in `lib/utils/`
   - feature state in the local or existing project pattern
6. Preserve user work and unrelated dirty files. Never discard or overwrite changes without explicit reason.
7. Validate with the smallest relevant command and rerun after the first meaningful edit:
   - prefer `flutter test path/to/test.dart` for targeted checks
   - run `flutter analyze` after coherent Dart changes
   - for CI or platform work, use the corresponding repository command rather than a broad suite
8. Report the outcome with a short summary of the task, root cause or behavior implemented, files changed, validation commands and results, and any remaining limitations.

## Vernet-specific expectations

- Treat the app as a Flutter network-diagnostics project with a layered architecture; do not mix UI and service logic.
- When a task touches project memory or historical debugging patterns, incorporate the relevant stored guidance as part of the working plan.
- Do not claim a check passed without fresh output.
- If local verification is blocked by environment limits, report the exact blocker and what remains unverified.
