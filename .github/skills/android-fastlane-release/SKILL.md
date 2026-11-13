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

## Release Preparation

When preparing a release:
- Bump version in `pubspec.yaml` (format: `major.minor.patch+version_code`)
- Create changelog at `android/fastlane/metadata/android/en-US/changelogs/<version_code>.txt`
- Mirror the same lines into `lib/values/changelog_data.dart`. The in-app What's New dialog reads that Dart list, **not** the fastlane file, so a bump with no matching `ChangelogEntry` ships a dialog that opens empty. `test/values/changelog_data_test.dart` is the guard — it parses `pubspec.yaml` and fails when the running version has no entry, so run it as part of release prep.
- Changelog format: concise, user-friendly lines (one feature/fix per line, no markdown, no version header)
- Localized store copy is not tracked: `android/fastlane/metadata/android/` holds `en-US` only. Translation requests are the `play-store-release-notes` skill's job — it carries the 29 Play locale tags and the bulk-editor output shape. Do not add localized fastlane directories.
- Do not create a root `CHANGELOG.md` file; fastlane structure is the source of truth
- The Google Play build is this repository plus `store_overlay/`. Build it with `dart run scripts/build_store.dart`, not a bare `flutter build appbundle --flavor store`: the bare build succeeds and silently ships an ad-free bundle because `google_mobile_ads`, `in_app_review` and the two `lib/store/` implementations exist only in the overlay. The script splices them in, builds, then restores the tree byte for byte, including `pubspec.lock`, which F-Droid enforces.
- In CI the store bundle is built at the end of `release-android` in `flutter_release.yml` and uploaded as the `store-bundle` artifact; `publish-play-store` then calls `play_store_release.yml`, which only downloads that artifact and runs fastlane. `play_store_release.yml` never builds, so a hand dispatch to the production track publishes the same bytes CI already tested — pass the release run's `run_id` to reuse an older artifact.
- Never commit `google_mobile_ads` or `in_app_review` to `pubspec.yaml`; F-Droid builds the committed file and rejects a non-free dependency. Play-only manifest entries (`AD_ID`, the AdMob `APPLICATION_ID`) belong in `android/app/src/store/AndroidManifest.xml`.
- The `fdroid` flavor also drops the in-app update check via `lib/values/build_flavor.dart`, so that APK makes no GitHub request at startup. Verify a flavor gate from two directions. A flavored **integration** run proves behavior: `flutter test --flavor <name>` does inject `FLUTTER_APP_FLAVOR` — the tool reserves the define against an explicit `--dart-define=`, not against the flag — so it reaches the gated branches, on Android, Linux, macOS and iOS only, which is why `.github/workflows/android-integration-test.yml` matrices the suite over all three flavors. Run them one at a time locally: two flavored `flutter test` runs contend inside one project because the rebuild check keys off `build/test_cache/flavor.txt`. An unflavored `flutter test` still reaches nothing, so tree-shaking is only provable from a built artifact — scan the APK or AAB for `api.github.com` and the AdMob ids rather than trusting the gate.
- iOS and Android read versions from pubspec automatically
- The release workflow builds from the release tag, not from `main`. Land build fixes on `main` before the version-bump commit that creates the tag, or the tag will not contain them.
- Keep the `:app` Gradle build directory at `<repo>/build/app`, assigned in `android/settings.gradle` via `gradle.beforeProject`. Moving it breaks the Flutter CLI's APK lookup, and assigning it later (in `android/build.gradle`) breaks AGP 9's default-ProGuard path resolution.
- `android/settings.gradle` is the only place the AGP and Kotlin plugin versions are pinned, and the release build enforces Flutter's toolchain floors (`DependencyVersionChecker.kt`): as of Flutter 3.47/3.50 that means AGP ≥ 9.1.1 and KGP ≥ 2.4.10 with Gradle 9.3.1, staying on Java 17 — AGP 9.3.x's `lintVitalAnalyzeRelease` needs Java 21. Meet the floors rather than adding `--android-skip-build-dependency-validation`.
- A passing Android **integration** job is not evidence the release build works: `flutter test` runs Gradle with `-PskipDependencyChecks=true`, so only `flutter build apk` validates those versions. Prove any toolchain change with `flutter build apk --split-per-abi --flavor dev`, then confirm the artifact with `apksigner verify --print-certs`.

## Safety

- Check for pre-existing edits before touching release files and leave them intact.
- Avoid broad dependency updates when a targeted version or configuration fix is sufficient.
- Never claim a release succeeded based only on a successful build; distinguish build, upload, and rollout states.
