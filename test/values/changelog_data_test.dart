import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/changelog_data.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('changelogEntryForVersion', () {
    test('finds the notes of the shipped version', () {
      expect(
        changelogEntryForVersion(changelogVersion, l10nEn())?.version,
        changelogVersion,
      );
    });

    test('ignores a leading v and a build number', () {
      expect(
        changelogEntryForVersion('v$changelogVersion+77', l10nEn())?.version,
        changelogVersion,
      );
    });

    test('ignores the store flavor suffix', () {
      expect(
        changelogEntryForVersion('$changelogVersion-store', l10nEn())?.version,
        changelogVersion,
      );
    });

    test('has nothing for an older release, whose notes live on GitHub', () {
      expect(changelogEntryForVersion('1.4.20', l10nEn()), isNull);
    });

    test('holds the same shape in German', () {
      final english = currentChangelog(l10nEn());
      final german = currentChangelog(l10nDe());

      expect(german.version, english.version);
      expect(german.changes, hasLength(english.changes.length));
      expect(
        german.changes,
        isNot(equals(english.changes)),
        reason: 'The release notes are prose, so they are written per locale.',
      );
    });
  });

  // The dialog opens empty whenever a release bumps pubspec.yaml without
  // rewriting these notes, which is what shipped in beta.
  group('release notes coverage', () {
    test('notes describe the version in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;

      expect(
        changelogEntryForVersion(version, l10nEn()),
        isNotNull,
        reason: 'Set changelogVersion to $version and replace the bullets in '
            'lib/values/changelog_data.dart.',
      );
    });
  });
}
