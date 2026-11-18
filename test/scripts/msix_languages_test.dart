import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/ms_store_listing.dart';

/// The `msix_config: languages` value is what `msix:create` writes into the
/// AppxManifest as `<Resource Language="..."/>`, and it is how the Store reads
/// which languages the package itself carries. `msstore/` decides which
/// languages the listing is published in, so the two have to agree — and a
/// release build is the first place a mismatch shows up, on Windows, with
/// credentials in play.
final RegExp _languagesLine = RegExp(r'^  languages: (\S.*)$');

List<String> declaredLanguages() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((line) => line.startsWith('msix_config:'));
  if (start < 0) throw StateError('pubspec.yaml has no msix_config block.');
  final block =
      lines.skip(start + 1).takeWhile((line) => line.startsWith('  '));
  for (final line in block) {
    final match = _languagesLine.firstMatch(line);
    if (match != null) {
      return match
          .group(1)!
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
  }
  // msix parses this key as a String, so a YAML list of entries dies in the
  // Windows build rather than declaring anything: the one-line comma form is
  // part of the contract, not a style choice.
  throw StateError(
    'msix_config needs one comma-separated languages: line. '
    'test/scripts/msix_languages_test.dart reads it that way.',
  );
}

/// The locales `scripts/ms_store_listing.dart` overlays onto a capture, which
/// is the same set the Store serves; `pending/` is excluded because its own
/// name does not match the locale pattern.
List<String> publishedLocales() {
  return Directory(defaultListingsDirectory)
      .listSync()
      .whereType<Directory>()
      .map(
        (entry) =>
            entry.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
      )
      .where(localeDirectoryPattern.hasMatch)
      .toList()
    ..sort();
}

void main() {
  group('msix_config languages', () {
    late final List<String> declared;
    late final List<String> published;

    setUpAll(() {
      declared = declaredLanguages();
      published = publishedLocales();
    });

    test('matches the msstore/ listing tree', () {
      expect(
        declared.toList()..sort(),
        equals(published),
        reason: 'every msstore/ locale has to be declared in the package, and '
            'no package language may be missing from the listing tree. Move a '
            'directory out of msstore/pending/ and add it here in the same '
            'change, or the Store and the package disagree about which '
            'languages Vernet ships in.',
      );
    });

    test('leads with en-us, the manifest fallback', () {
      expect(declared.first, 'en-us');
    });

    test('declares each locale once, in the lowercase spelling msstore/ uses',
        () {
      expect(declared.toSet(), hasLength(declared.length));
      for (final language in declared) {
        expect(
          localeDirectoryPattern.hasMatch(language),
          isTrue,
          reason: '$language is not a locale msstore/ could hold.',
        );
      }
    });

    test('covers the locales the Store was captured serving', () {
      expect(
          published, containsAll(<String>['en-us', 'de-de', 'fr-fr', 'zh-cn']));
    });
  });
}
