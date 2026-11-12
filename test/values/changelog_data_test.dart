import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/changelog_data.dart';

void main() {
  group('changelogEntryForVersion', () {
    test('finds an entry by plain version', () {
      expect(changelogEntryForVersion('1.4.20')?.version, '1.4.20');
    });

    test('ignores a leading v and a build number', () {
      expect(changelogEntryForVersion('v1.4.20+77')?.version, '1.4.20');
    });

    test('ignores the store flavor suffix', () {
      expect(changelogEntryForVersion('1.4.20-store')?.version, '1.4.20');
    });

    test('returns null for an unknown version', () {
      expect(changelogEntryForVersion('0.1.2'), isNull);
    });
  });

  // The What's New dialog opens empty whenever a release bumps pubspec.yaml
  // without adding a matching entry, which is what shipped in beta.
  group('release notes coverage', () {
    test('current pubspec version has a changelog entry', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;

      expect(
        changelogEntryForVersion(version),
        isNotNull,
        reason:
            'Add a ChangelogEntry for $version to lib/values/changelog_data.dart.',
      );
    });
  });
}
