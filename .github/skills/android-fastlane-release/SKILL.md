---
name: android-fastlane-release
description: "Build or troubleshoot Vernet Android release and beta delivery with Fastlane, Play Console supply, signing configuration, Gradle, or release CI."
argument-hint: "Fastlane lane, build error, beta track, or release workflow"
---

# Android Fastlane Release

Use this for Android release builds, Fastlane lanes, Google Play beta/internal tracks, signing failures, and release automation in CI.

## Procedure

1. Determine the requested outcome: diagnose a failed lane, prepare a local build, or publish to a specific track. Do not infer authorization to upload or deploy from a request to investigate or build.
2. Inspect the Android Fastlane `Fastfile`, `Gemfile` and lockfile, Gradle configuration, and the relevant GitHub Actions workflow. Read the exact failing lane output and identify whether the failure is build, signing, authentication, upload, or Play Console state.
3. Verify the installed Fastlane/Ruby/Gradle context and supported lane options before changing dependency versions or command flags. Keep local and CI configuration differences explicit.
4. Preserve the project’s existing signing setup. Use key and service-account paths or secret names only; never read out or expose secret contents. Do not hardcode credentials, package IDs, or production values into committed files for convenience.
5. Make the smallest fix, then validate with a local build or the narrowest non-publishing lane available. If upload is needed, state the target track and obtain explicit user authorization before executing it.
6. Summarize the root cause, files changed, exact validation run, and whether the artifact was built or actually uploaded.

## Safety

- Check for pre-existing edits before touching release files and leave them intact.
- Avoid broad dependency updates when a targeted version or configuration fix is sufficient.
- Never claim a release succeeded based only on a successful build; distinguish build, upload, and rollout states.
