---
name: flutter-feature-iteration
description: "Implement or refine Vernet Flutter features and UI, including form controls, network-tool screens, responsive layouts, and focused regression coverage."
argument-hint: "Feature request, screen/widget, or visual behavior to refine"
---

# Flutter Feature Iteration

Use this for adding or iteratively refining a Vernet screen, control, or user-visible workflow.

## Procedure

1. Start from the named screen, behavior, or nearby test. State the expected behavior in observable terms and inspect the smallest owning UI/controller/service path before editing.
2. Follow Vernet's existing boundaries: UI in pages/widgets, network operations in services, structured results in models, and feature state local to the feature. Read `ARCHITECTURE.md` before structural changes.
3. Preserve established visual conventions. Make controls work with keyboard, focus, validation, loading, empty, and error states where applicable. Keep actions near the input they operate on when that matches the requested workflow; account for mobile and desktop constraints.
4. For image or web presentation work, preserve source aspect ratios unless intentional cropping is requested. Check the target section against the current live or reference behavior when supplied; do not overwrite existing assets or copy unrelated design wholesale.
5. Make the smallest adjacent change and add/update a focused widget or integration test for the visible behavior. Avoid unrelated redesigns and do not put network calls directly in widgets.
6. Run the narrowest relevant test, then analyze affected Dart code. If an app is attached, hot reload or hot restart and verify the changed interaction on the target screen/device.
7. Summarize the user-visible change and the exact test/device/viewport used. Call out any requested visual state that could not be verified.
