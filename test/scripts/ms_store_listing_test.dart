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

  // Microsoft states this budget twice, as "21 unique words TOTAL across all
  // search terms" in the submission API table and "no more than 21 separate
  // words across all keywords" in the MSIX page and the Partner Center form, and
  // counting every occurrence is the stricter reading. What the prose leaves out
  // is that the server splits a keyword on a hyphen as well as a space, so a
  // list that reads as 20 words by whitespace is charged 22 — which is how the
  // Spanish, Italian, Portuguese and Russian lists passed `--check` and were
  // refused anyway. A locale on its own breaches the listing budget and the
  // shared submission budget, so both are reported.
  test('counts every word a keyword list uses, not each word once', () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'network tool\n'
          'wifi scanner device\n'
          'ip address lookup scanner\n'
          'port check scanner tool\n'
          'speed test wifi\n'
          'dns lookup tool\n'
          'lan device scanner\n',
    });

    final violations = validateListingTree(readListingTree(root));
    expect(violations, hasLength(2));
    expect(violations.first, startsWith('en-us: Keywords uses 22 words'));
    expect(violations.last, contains('KeywordsTotalCount'));
  });

  test('a hyphen separates, so Wi-Fi spends two words', () {
    expect(
      keywordWords(['Wi-Fi device scanner', 'Wi-Fi monitoring app']),
      [
        'wi', 'fi', 'device', 'scanner', //
        'wi', 'fi', 'monitoring', 'app',
      ],
    );
    expect(keywordWords(['privacy\u2011focused\u2010app']).length, 3);
  });

  test('a repeated word spends the budget again in every keyword', () {
    expect(keywordWords(List.filled(7, 'aa bb')).length, 14,
        reason: 'seven terms of two words is 14 words, not two unique words');
  });

  test('punctuation around a word does not make another one', () {
    expect(keywordWords(['"network" scanner, app']).length, 3);
  });

  test('a comma-joined list is refused rather than published as one bullet',
      () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'features.txt': 'Wifi details, find devices, ping and DNS\n',
      'keywords.txt': 'network scanner, wifi monitor, ip lookup\n',
    });

    expect(validateListingTree(readListingTree(root)), [
      'en-us: Features is one comma-joined line; put each entry on its own line',
      'en-us: Keywords is one comma-joined line; put each entry on its own line',
    ]);
  });

  test('a keyword list inside the word budget is publishable', () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'network scanner\n'
          'network monitor\n'
          'wifi scanner\n'
          'wifi monitor\n'
          'ip scanner\n'
          'port scan\n'
          'speed test\n',
    });

    expect(validateListingTree(readListingTree(root)), isEmpty);
  });

  // The budget is words, not listings, and the whole submission shares it, so
  // the tree cannot let every market spend 21 of them. Clearing the field rather
  // than skipping it is what makes the policy real: an omitted field keeps the
  // keywords the captured draft already serves, and those words are charged
  // against the same 21 whether git named the locale or not.
  test('the keyword budget clears the locales the allowlist does not name', () {
    final listings = <String, dynamic>{};
    for (final tag in ['en-us', 'de-de', 'fr-fr']) {
      listings[tag] = {
        baseListingField: {
          'Title': 'Live',
          'Description': 'Live',
          'Keywords': ['served', 'by', 'the', 'store'],
        },
        platformOverridesField: <String, dynamic>{},
      };
      writeLocale(root, tag, {
        'title.txt': 'A\n',
        'description.txt': 'B\n',
        'keywords.txt': 'alpha\n' 'beta\n',
      });
    }

    Map baseOf(Map payload, String tag) =>
        ((payload[listingField] as Map)[tag] as Map)[baseListingField] as Map;
    final payload = overlaySubmission(
        capture(listings: listings), readListingTree(root),
        keywordLocales: ['en-us', 'de-de']);

    expect(baseOf(payload, 'en-us')['Keywords'], ['alpha', 'beta']);
    expect(baseOf(payload, 'de-de')['Keywords'], ['alpha', 'beta']);
    expect(baseOf(payload, 'fr-fr')['Keywords'], isEmpty,
        reason: 'an empty list is what removes them from the storefront');
  });

  test('an allowlist the tree does not carry publishes nothing by accident',
      () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'alpha\n',
    });
    writeLocale(root, 'de-de', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'alpha\n',
    });

    final violations = validateListingTree(readListingTree(root),
        keywordLocales: ['en-us', 'pl-pl']);
    expect(violations.single, startsWith('keyword_locales.txt names pl-pl'));
    expect(violations.single, contains('does not carry'));
  });

  // Twenty-two one-word keyword lists with no allowlist is the shape the 2026-11
  // payloads had, and the shape of the 2026-11-22+87 retry one level down: every
  // listing individually valid, the submission charged for spending 22 words
  // against a budget of 21. The release's `--check` step runs this same code, so
  // the tree now fails in seconds instead of costing a Store round trip and an
  // uncommitted draft.
  test('a submission over the shared word budget names the spend and the file',
      () {
    final locales = [
      for (var i = 0; i < 22; i++)
        ListingLocale('aa-$i', {
          'Title': 'A',
          'Description': 'B',
          'Keywords': ['alpha'],
        })
    ];

    final violations = validateListingTree(locales);
    expect(
        violations.single,
        startsWith('the keyword lists that publish spend '
            '22 words, and the Store refuses a submission over 21'));
    expect(violations.single, contains('keyword_locales.txt'));
    expect(
        validateListingTree(locales, keywordLocales: ['aa-0', 'aa-1']), isEmpty,
        reason: 'the allowlist is what brings the same tree inside the budget');
  });

  test('an out-of-budget locale keeps an over-budget list inert', () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'alpha\n' 'beta\n',
    });
    writeLocale(root, 'es-es', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'escaner de red casa oficina\n'
          'monitorizacion de red local wifi\n'
          'direccion ip publica y privada\n'
          'escaner de dispositivos wifi red\n'
          'analisis de red completa online\n'
          'herramienta de red domestica ip\n'
          'velocidad de red test rapido\n',
    });

    expect(
        validateListingTree(readListingTree(root), keywordLocales: ['en-us']),
        isEmpty,
        reason: 'a list the assembler blanks cannot breach a limit the Store '
            'never sees');
    expect(
      validateListingTree(readListingTree(root),
          keywordLocales: ['en-us', 'es-es']),
      isNotEmpty,
      reason: 'moving the budget onto it is what makes its words a release '
          'blocker',
    );
  });

  test('a locale over the shared budget is refused before any overlay', () {
    writeLocale(root, 'en-us', {
      'title.txt': 'A\n',
      'description.txt': 'B\n',
      'keywords.txt': 'network monitoring app\n'
          'network insights\n'
          'Wi-Fi device scanner\n'
          'Wi-Fi monitoring app\n'
          'IP address tracker\n'
          'home network manager\n'
          'extra keyword here\n',
    });

    expect(
      () => overlaySubmission(capture(), readListingTree(root),
          keywordLocales: ['en-us']),
      throwsA(isA<ListingFailure>().having(
        (failure) => failure.violations.join(' '),
        'violation',
        allOf(contains('KeywordsTotalCount'), contains('en-us=22')),
      )),
    );
  });

  test('the keyword allowlist comes from the listing root', () {
    expect(readKeywordLocales(root), isEmpty,
        reason: 'absent file, absent policy: every committed list is sent');
    File('${root.path}${Platform.pathSeparator}$keywordLocalesFile')
        .writeAsStringSync('en-us\r\nde-de\r\n');
    expect(readKeywordLocales(root), ['en-us', 'de-de']);
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
    final tree = readListingTree(committed);
    final allowed = readKeywordLocales(committed);
    expect(validateListingTree(tree, keywordLocales: allowed), isEmpty);
    expect(
        tree.map((locale) => locale.locale), containsAll(['en-us', 'de-de']));
    for (final locale in tree) {
      expect(locale.fields['Features'], hasLength(greaterThan(1)),
          reason: '${locale.locale} declares its bullets comma-joined, so the '
              'Store would show one feature instead of ten');
    }
    // The release PUTs what this tree says, and the ingestion API counts the
    // words of the lists that publish: 29 locales of multi-word keywords is the
    // payload refused on 2026-11-18 and 2026-11-22, and the 10-locale retry that
    // spent 192 words was refused the same way on 2026-11-22+87.
    expect(allowed, isNotEmpty,
        reason: 'without an allowlist every locale spends the budget');
    expect(keywordSpend(tree, allowed).keys, unorderedEquals(allowed),
        reason: 'a listed locale with no keywords.txt is budget spent on '
            'nothing a shopper can be found by');
    expect(
      keywordSpend(tree, allowed).values.fold<int>(0, (a, b) => a + b),
      lessThanOrEqualTo(maxSubmissionKeywordWords),
      reason: 'the words this tree publishes are the number the Store charges',
    );
    expect(
      keywordSpend(tree, const []).values.fold<int>(0, (a, b) => a + b),
      greaterThan(maxSubmissionKeywordWords),
      reason: 'the tree is wider than the word budget, which is the whole '
          'reason the allowlist exists; the assembler clears what it does not '
          'name rather than refusing the tree',
    );
  });
}
