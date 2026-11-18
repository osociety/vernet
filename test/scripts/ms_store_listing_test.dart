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
    Directory('${root.path}${Platform.pathSeparator}assets').createSync();
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

  test('a title outside the reserved names leaves the store title alone', () {
    final listings = {
      'en-us': {
        baseListingField: {
          'Title': 'Vernet - Know your network',
          'Description': 'old english',
        },
        platformOverridesField: <String, dynamic>{},
      },
      'de-de': {
        baseListingField: {
          'Title': 'Vernet - Know your network',
          'Description': 'old german',
        },
        platformOverridesField: <String, dynamic>{},
      },
    };
    final live = capture(listings: listings);
    writeLocale(root, 'en-us', {
      'title.txt': 'Vernet - Know your network\n',
      'description.txt': 'New english.\n',
    });
    writeLocale(root, 'de-de', {
      'title.txt': 'Vernet - Dein Netzwerk im Blick\n',
      'description.txt': 'Neue Beschreibung.\n',
    });
    Map baseOf(Map payload, String locale) =>
        ((payload[listingField] as Map)[locale] as Map)[baseListingField]
            as Map;

    final guarded = overlaySubmission(
      live,
      readListingTree(root),
      reservedTitles: ['Vernet - Know your network'],
    );
    expect(baseOf(guarded, 'de-de')['Title'], 'Vernet - Know your network',
        reason: 'the Store refuses a name nobody reserved');
    expect(baseOf(guarded, 'de-de')['Description'], 'Neue Beschreibung.',
        reason: 'the rest of the locale still overlays');
    expect(baseOf(guarded, 'en-us')['Title'], 'Vernet - Know your network',
        reason: 'a reserved git title is written like any other field');

    final unguarded =
        overlaySubmission(capture(listings: listings), readListingTree(root));
    expect(
        baseOf(unguarded, 'de-de')['Title'], 'Vernet - Dein Netzwerk im Blick',
        reason: 'no reserved_titles.txt means nothing is enforced');
  });

  test('the reserved names come from the listing root', () {
    expect(readReservedTitles(root), isEmpty,
        reason: 'absent file, absent enforcement');
    File('${root.path}${Platform.pathSeparator}$reservedTitlesFile')
        .writeAsStringSync('Vernet - Know your network\r\nVernet App\r\n');
    expect(
        readReservedTitles(root), ['Vernet - Know your network', 'Vernet App']);
  });

  test('pending locales are written without being publishable', () {
    Directory('${root.path}${Platform.pathSeparator}pending').createSync();
    writeLocale(root, 'pending/cs-cz', {
      'title.txt': 'Vernet - Přehled sítě\n',
      'description.txt': 'Popis.\n',
    });
    writeLocale(root, 'en-us', {'title.txt': 'A\n', 'description.txt': 'B\n'});

    expect(
      readListingTree(root).map((locale) => locale.locale),
      ['en-us'],
      reason: 'a directory named pending is not a locale tag',
    );
  });

  // The capture, not Microsoft's table, decides the spelling: the live product
  // serves `ru` bare alongside `cs-cz`, `it-it`, `pl-pl` and `sk-sk`. A pattern
  // that demanded a region silently skipped the bare one, and the only symptom
  // was a payload with fewer languages than git holds.
  test('a bare Store tag reads as a locale and a stray directory does not', () {
    writeLocale(root, 'ru', {'title.txt': 'A\n', 'description.txt': 'B\n'});
    writeLocale(root, 'cs-cz', {'title.txt': 'A\n', 'description.txt': 'B\n'});
    writeLocale(root, 'docs', {'title.txt': 'A\n', 'description.txt': 'B\n'});

    final found = readListingTree(root).map((locale) => locale.locale).toList();
    expect(found, containsAll(<String>['ru', 'cs-cz']));
    expect(found, isNot(contains('docs')));
  });

  // F-Droid builds this same checkout, and fdroidserver scans
  // `build/<package>/metadata/<locale>` for listing text, copying whatever it
  // finds over what it read from fastlane. A listing tree under the repository's
  // `metadata/` would therefore become F-Droid's English name and summary, with
  // Windows prose that is three times the 80 characters that store allows.
  test('the committed tree stays out of the path F-Droid scans', () {
    expect(
      Directory('metadata').existsSync(),
      isFalse,
      reason:
          'a root metadata/ directory is a second, ungoverned F-Droid listing',
    );

    final committed = Directory(defaultListingsDirectory);
    expect(committed.existsSync(), isTrue,
        reason: 'run from the repository root');
    expect(validateListingTree(readListingTree(committed)), isEmpty);
    expect(readListingTree(committed).map((locale) => locale.locale),
        containsAll(['en-us', 'de-de']));
  });
}
