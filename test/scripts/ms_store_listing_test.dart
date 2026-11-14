import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/ms_store_listing.dart';

/// A capture shaped like `msstore submission get` for a packaged product: one
/// live locale, screenshots by id, and a package set that must never move.
///
/// Round-tripped through JSON so the nested maps have the
/// `Map<String, dynamic>` shape the CLI's payload decodes to, not the tighter
/// types a Dart literal would infer.
Map<String, dynamic> capture({
  Map<String, dynamic>? listings,
  String priceId = 'Free',
}) =>
    jsonDecode(
      jsonEncode({
        'Id': '1152921505702387718',
        'Status': 'Published',
        'Pricing': {'PriceId': priceId, 'TrialPeriod': 'NoFreeTrial'},
        'ApplicationPackages': [
          {
            'FileName': 'Vernet-v1.6.2+81.msixbundle',
            'Id': '2000000000100629768'
          },
        ],
        listingField: listings ??
            {
              'en-us': {
                baseListingField: {
                  'Title': 'old title',
                  'ShortDescription': 'kept when git has no file',
                  'Description': 'old description',
                  'ReleaseNotes': 'old notes',
                  'Features': ['old feature'],
                  'Keywords': ['old'],
                  'Images': [
                    {
                      'Id': '1152922700028561868',
                      'FileStatus': 'Uploaded',
                      'ImageType': 'Screenshot'
                    },
                  ],
                },
                platformOverridesField: <String, dynamic>{},
              },
            },
      }),
    ) as Map<String, dynamic>;

void writeLocale(Directory root, String locale, Map<String, String> files) {
  final dir = Directory('${root.path}${Platform.pathSeparator}$locale')
    ..createSync();
  files.forEach((name, contents) {
    File('${dir.path}${Platform.pathSeparator}$name')
        .writeAsStringSync(contents);
  });
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('ms_store_listing'));
  tearDown(() => root.deleteSync(recursive: true));

  test('overlays the git text and carries everything else through', () {
    writeLocale(root, 'en-us', {
      'title.txt': 'Vernet - Know your network\n',
      'description.txt': 'New description.\n',
      'features.txt': 'one\n' 'two\n',
      'keywords.txt': 'alpha\n' 'beta\n',
      'release_notes.txt': 'Fixes.\n',
    });

    final payload = overlaySubmission(capture(), readListingTree(root));
    final base = ((payload[listingField] as Map)['en-us']
        as Map)[baseListingField] as Map;

    expect(base['Title'], 'Vernet - Know your network');
    expect(base['Description'], 'New description.');
    expect(base['Features'], ['one', 'two']);
    expect(base['Keywords'], ['alpha', 'beta']);
    expect(base['ReleaseNotes'], 'Fixes.');
    expect(base['ShortDescription'], 'kept when git has no file',
        reason: 'no file committed');
    expect(base['Images'], hasLength(1),
        reason: 'screenshots come from the store');
    expect(payload['ApplicationPackages'], hasLength(1),
        reason: 'packages come from the store');
  });

  test('a locale the store has and git does not is preserved, not dropped', () {
    writeLocale(root, 'en-us', {'title.txt': 'A\n', 'description.txt': 'B\n'});
    final payload = overlaySubmission(
      capture(
        listings: {
          'en-us': {
            baseListingField: {'Title': 'A', 'Description': 'B'}
          },
          'de-de': {
            baseListingField: {
              'Title': 'Live German',
              'Description': 'Lebende Beschreibung'
            },
          },
        },
      ),
      readListingTree(root),
    );

    expect((payload[listingField] as Map).keys,
        containsAll(<String>['en-us', 'de-de']));
    expect(
      ((payload[listingField] as Map)['de-de'] as Map)[baseListingField],
      {'Title': 'Live German', 'Description': 'Lebende Beschreibung'},
    );
  });

  test('a new locale is refused until the product serves it', () {
    writeLocale(root, 'en-us', {'title.txt': 'A\n', 'description.txt': 'B\n'});
    writeLocale(root, 'fr-fr', {'title.txt': 'A\n', 'description.txt': 'B\n'});

    expect(
      () => overlaySubmission(capture(), readListingTree(root)),
      throwsA(
        isA<ListingFailure>().having(
          (failure) => failure.violations.join(' '),
          'violation',
          allOf(contains('fr-fr'), contains('Add/remove languages')),
        ),
      ),
    );

    final payload = overlaySubmission(capture(), readListingTree(root),
        allowNewLocales: true);
    final added = (payload[listingField] as Map)['fr-fr'];
    expect(((added as Map)[baseListingField] as Map)['Title'], 'A');
    expect(added[platformOverridesField], isA<Map<String, dynamic>>());
  });

  test('reports every limit and completeness violation in one pass', () {
    writeLocale(root, 'de-de', {
      'description.txt': 'x' * 10001,
      'features.txt': List.filled(21, 'f').join('\n'),
      'keywords.txt':
          '${List.filled(6, 'k').join('\n')}\n${'l' * 41}\n${'m' * 80}',
    });

    List<String>? violations;
    try {
      overlaySubmission(capture(), readListingTree(root));
    } on ListingFailure catch (failure) {
      violations = failure.violations;
    }

    expect(violations, hasLength(6));
    expect(violations, contains('de-de: title.txt is required'));
    expect(violations,
        contains('de-de: Description is 10001 characters, the limit is 10000'));
    expect(violations,
        contains('de-de: Features has 21 entries, the limit is 20'));
    expect(
        violations, contains('de-de: Keywords has 8 entries, the limit is 7'));
    expect(violations,
        contains('de-de: Keywords entry is 41 characters, the limit is 40'));
    expect(violations,
        contains('de-de: Keywords entry is 80 characters, the limit is 40'));
  });

  test('an empty required file is refused the same way a missing one is', () {
    writeLocale(root, 'en-us', {'title.txt': '\n', 'description.txt': 'B\n'});

    List<String>? violations;
    try {
      overlaySubmission(capture(), readListingTree(root));
    } on ListingFailure catch (failure) {
      violations = failure.violations;
    }

    expect(violations, ['en-us: title.txt is required']);
  });

  test('an empty listing tree is refused rather than publishing nothing', () {
    expect(
      () => overlaySubmission(capture(), readListingTree(root)),
      throwsA(
        isA<ListingFailure>().having(
          (failure) => failure.violations.single,
          'violation',
          contains('declares no locales'),
        ),
      ),
    );
  });

  test('a placeholder price is repaired so the update is accepted', () {
    writeLocale(root, 'en-us', {'title.txt': 'A\n', 'description.txt': 'B\n'});
    for (final placeholder in ['Base', '']) {
      final payload = overlaySubmission(
          capture(priceId: placeholder), readListingTree(root));
      expect((payload['Pricing'] as Map)['PriceId'], 'Free');
    }
  });

  test('locale directories are matched strictly and newlines normalised', () {
    File('${root.path}${Platform.pathSeparator}README.md')
        .writeAsStringSync('notes\n');
    Directory('${root.path}${Platform.pathSeparator}en').createSync();
    writeLocale(root, 'en-us',
        {'title.txt': 'A\r\n', 'keywords.txt': 'one\r\ntwo\r\n'});

    final locales = readListingTree(root);
    expect(locales.map((locale) => locale.locale), ['en-us']);
    expect(locales.single.fields['Title'], 'A');
    expect(locales.single.fields['Keywords'], ['one', 'two']);
  });

  test('the overlay report names the fields that move, without the text', () {
    final captured = <String, dynamic>{
      'Title': 'same title',
      'Description': 'x' * 400,
      'Features': ['a', 'b'],
      'Keywords': ['a', 'b'],
    };

    final unchanged = describeOverlayChanges('en-us', captured, {
      'Title': 'same title',
      'Features': ['a', 'b'],
      'Keywords': ['a', 'b'],
      'ReleaseNotes': null,
    });
    expect(unchanged, isEmpty,
        reason: 'identical values and a missing file are not changes');

    final moved = describeOverlayChanges('en-us', captured, {
      'Description': 'y' * 1181,
      'Features': ['a'],
      'Title': 'a brand new title',
    });
    expect(moved, [
      'en-us: Description 400 chars -> 1181 chars',
      'en-us: Features 2 entries -> 1 entry',
      'en-us: Title 10 chars -> 17 chars',
    ]);

    expect(
      describeOverlayChanges('de-de', <String, dynamic>{}, {'Title': 'A'}),
      ['de-de: Title absent -> 1 chars'],
    );
  });

  test('the payload stays valid JSON and keeps non-ascii readable', () {
    writeLocale(root, 'en-us',
        {'title.txt': 'Vernet — Réseau\n', 'description.txt': '🔍 scan\n'});
    final output = File('${root.path}${Platform.pathSeparator}payload.json');
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(
        overlaySubmission(capture(), readListingTree(root)),
      ),
    );

    final reread =
        jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    final base = ((reread[listingField] as Map)['en-us']
        as Map)[baseListingField] as Map;
    expect(base['Title'], 'Vernet — Réseau');
    expect(output.readAsStringSync(), isNot(contains(r'\u')));
  });
}
