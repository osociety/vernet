import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/changelog_entry.dart';

/// The version these notes describe: the `version:` in `pubspec.yaml`.
const String changelogVersion = '1.6.4';

/// Release notes for [changelogVersion], in the language [l10n] renders.
///
/// The app only ever describes the build it ships in, so this entry is
/// replaced at every version bump instead of appended to. The notes of earlier
/// releases live on the GitHub releases page, which also keeps the list short
/// enough to read in one dialog.
ChangelogEntry currentChangelog(AppLocalizations l10n) => ChangelogEntry(
      version: changelogVersion,
      changes: [
        l10n.changelogLinuxDatabaseIncluded,
        l10n.changelogNothingElseChanged,
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
  var normalized = version.trim();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  normalized = normalized.replaceAll('-store', '');
  final buildSeparator = normalized.indexOf('+');
  if (buildSeparator != -1) {
    normalized = normalized.substring(0, buildSeparator);
  }

  return normalized == changelogVersion ? currentChangelog(l10n) : null;
}
