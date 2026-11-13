/// Which product flavor is being compiled.
///
/// The Flutter tool injects `FLUTTER_APP_FLAVOR` for every `--flavor` build, so
/// these are compile-time constants and the code behind a disabled one is
/// tree-shaken out of the binary rather than merely skipped at runtime.
///
/// Builds that pass no flavor — snap, the desktop runners, iOS — leave
/// [appFlavor] empty.
const String appFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

/// The Google Play build, assembled by `scripts/build_store.dart`.
const bool kStoreBuild = appFlavor == 'store';

/// F-Droid reviews an in-app update check as `UpdaterDetectionService`, and the
/// request to `api.github.com` as `NonFreeNet` plus `Tracking`, so the fdroid
/// flavor ships without one. See osociety/vernet#496.
const bool kUpdateChecksEnabled = appFlavor != 'fdroid';

/// List rows reserved for a leading store banner.
///
/// Subtract from the item index to reach the data row, and add to the item
/// count. Zero in every build that has no ads, so the FOSS lists keep their
/// original indices.
const int kStoreBannerRows = kStoreBuild ? 1 : 0;
