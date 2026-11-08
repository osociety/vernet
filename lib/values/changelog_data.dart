import 'package:vernet/models/changelog_entry.dart';

const List<ChangelogEntry> kChangelogEntries = [
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
