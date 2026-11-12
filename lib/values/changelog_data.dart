import 'package:vernet/models/changelog_entry.dart';

/// Release notes shown by the What's New dialog. A new entry is required for
/// every version bump in pubspec.yaml, otherwise the dialog opens empty.
const List<ChangelogEntry> kChangelogEntries = [
  ChangelogEntry(
    version: '1.5.0',
    changes: [
      'New first-time onboarding flow with app walkthrough and Wi-Fi prompt',
      'Wi-Fi settings open system preferences on every platform',
      'Better Android 17+ permission handling for local network access',
    ],
  ),
  ChangelogEntry(
    version: '1.4.20',
    changes: [
      'IPv6 port scanning support',
      'Improved local network permission on Android 17',
      'Reorganized project structure for easier contribution',
    ],
  ),
  ChangelogEntry(
    version: '1.4.19',
    changes: [
      'Network score with security, health, reliability and speed factors',
      'Device trust and camera detection indicators',
      'Smoother speed test progress and graph display',
    ],
  ),
];

/// The entry for [version], tolerating the shapes `PackageInfo` and release
/// tags use: a leading `v`, a build number, and the store flavor's `-store`.
ChangelogEntry? changelogEntryForVersion(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  normalized = normalized.replaceAll('-store', '');
  final buildSeparator = normalized.indexOf('+');
  if (buildSeparator != -1) {
    normalized = normalized.substring(0, buildSeparator);
  }

  for (final entry in kChangelogEntries) {
    if (entry.version == normalized) return entry;
  }
  return null;
}
