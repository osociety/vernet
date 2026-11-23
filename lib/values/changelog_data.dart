import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/values/store_links.dart';

/// The version these notes describe: the `version:` in `pubspec.yaml`.
const String changelogVersion = '1.7.4';

/// Release notes for [changelogVersion], in the language [l10n] renders.
///
/// The app only ever describes the build it ships in, so this entry is
/// replaced at every version bump instead of appended to. The notes of earlier
/// releases live on the GitHub releases page, which also keeps the list short
/// enough to read in one dialog.
ChangelogEntry currentChangelog(AppLocalizations l10n) => ChangelogEntry(
      version: changelogVersion,
      changes: [
        l10n.changelogMoreDevices,
        l10n.changelogSnapLocalizedName,
      ],
    );

/// [currentChangelog], but only for the build that is running.
///
/// [version] comes from `PackageInfo`, so it tolerates the shapes it and the
/// release tags use: a leading `v`, a build number and the store flavor's
/// `-store`. Anything else returns null and the dialog stays closed rather than
/// announcing the previous release again.
ChangelogEntry? changelogEntryForVersion(
    String version, AppLocalizations l10n) {
  return normalizeReleaseVersion(version) == changelogVersion
      ? currentChangelog(l10n)
      : null;
}

/// [version] reduced to the plain `1.7.0` form [changelogVersion] uses.
///
/// Shared with [githubReleaseUrl] so both read `PackageInfo` the same way.
String normalizeReleaseVersion(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  normalized = normalized.replaceAll('-store', '');
  final buildSeparator = normalized.indexOf('+');
  if (buildSeparator != -1) {
    normalized = normalized.substring(0, buildSeparator);
  }
  return normalized;
}

/// The GitHub release page for a running build, or null when its version or
/// build number cannot be read.
///
/// `flutter_release.yml` tags a release `v<version>+<build>` straight from the
/// `version:` line in `pubspec.yaml`, so the tag is rebuilt from the two halves
/// `PackageInfo` reports rather than stored a third time. A pre-release build
/// still has a tag; a dev build with no matching release lands on GitHub's 404,
/// which is why the caller hides the link on null instead of on a guess.
String? githubReleaseUrl(String version, String buildNumber) {
  final normalized = normalizeReleaseVersion(version);
  final build = buildNumber.trim();
  if (normalized.isEmpty || build.isEmpty) return null;
  return '$githubRepositoryUrl/releases/tag/v$normalized+$build';
}
