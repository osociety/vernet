import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_store_claims.dart';

/// Judges [text] as the copy of one field in one language.
List<String> claims(String text, {String language = 'en'}) =>
    findUnqualifiedClaims(splitIntoSentences([
      ListingText(path: 'test/fixture.txt', language: language, body: text),
    ]));

void writeLocale(
  Directory root,
  String locale,
  Map<String, String> fields, {
  Map<String, String> changelogs = const {},
}) {
  final dir = Directory('${root.path}${Platform.pathSeparator}$locale')
    ..createSync(recursive: true);
  fields.forEach((name, contents) {
    File('${dir.path}${Platform.pathSeparator}$name')
        .writeAsStringSync(contents);
  });
  if (changelogs.isEmpty) return;
  final notes = Directory(
    '${dir.path}${Platform.pathSeparator}$changelogsDirectory',
  )..createSync();
  changelogs.forEach((name, contents) {
    File('${notes.path}${Platform.pathSeparator}$name')
        .writeAsStringSync(contents);
  });
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('store_claims'));
  tearDown(() => root.deleteSync(recursive: true));

  group('an unqualified claim', () {
    test('is refused, naming the spelling and the sentence', () {
      final violations = claims(
        'Vernet is free and open source. No tracking, no telemetry.',
      );
      expect(violations, hasLength(1));
      expect(violations.single, contains('no tracking'));
      expect(violations.single, contains('No tracking, no telemetry.'));
    });

    test('is refused wherever the listing puts it', () {
      expect(claims('Ad-free network tools for everyone.'), hasLength(1));
      expect(claims('This app has zero ads and no advertising.'), hasLength(1));
      expect(claims('We do not track you, ever.'), hasLength(1));
    });

    test('is accepted once the sentence names a channel', () {
      expect(
        claims(
          'The Google Play build contains ads. '
          'The F-Droid and GitHub builds are ad-free.',
        ),
        isEmpty,
      );
    });

    test('is judged in its sentence, not in the neighbouring one', () {
      final violations = claims(
        'The F-Droid build is ad-free. No tracking, no telemetry.',
      );
      expect(violations, hasLength(1));
      expect(violations.single, contains('no tracking'));
    });

    test('may be wrapped across the lines of its paragraph', () {
      expect(
        claims(
          'The Google Play build contains ads; the F-Droid, GitHub and snap\n'
          'builds are ad-free.',
        ),
        isEmpty,
      );
    });

    test('is a paragraph break away from its qualifier, so it stays refused',
        () {
      final violations =
          claims('The F-Droid build is ad-free.\n\nNo tracking.');
      expect(violations, hasLength(1));
    });

    test('is only what the vocabulary lists', () {
      expect(claims('No account is required, and the app ships no analytics.'),
          isEmpty);
    });
  });

  group('matching', () {
    test('needs a whole word, so a feature keyword is not a claim', () {
      expect(claims('IP address tracker, home network manager.'), isEmpty);
      expect(containsWholeWord('various network tools', 'ios'), isFalse);
      expect(containsWholeWord('the ios build', 'ios'), isTrue);
    });

    test('sees an inflected spelling as its own entry', () {
      expect(containsWholeWord('eine werbefreie app', 'werbefrei'), isFalse);
      expect(containsWholeWord('eine werbefreie app', 'werbefreie'), isTrue);
    });
  });

  group('languages', () {
    test('are read from the locale code, aliases and regions included', () {
      expect(languageForLocaleDirectory('de-DE', playLocaleDirectory), 'de');
      expect(languageForLocaleDirectory('id', playLocaleDirectory), 'id');
      expect(languageForLocaleDirectory('es-419', playLocaleDirectory), 'es');
      expect(languageForLocaleDirectory('iw-IL', playLocaleDirectory), 'he');
      expect(languageForLocaleDirectory('no-NO', playLocaleDirectory), 'nb');
      expect(languageForLocaleDirectory('pending', msstoreLocaleDirectory),
          isNull);
      expect(languageForLocaleDirectory('en-us', msstoreLocaleDirectory), 'en');
    });

    test('carry their own claim spellings', () {
      expect(
        claims('Ohne Werbung und ohne Tracking.', language: 'de'),
        hasLength(1),
      );
      expect(
        claims(
          'Diese Version kann Werbung enthalten. '
          'Eine werbefreie App gibt es bei F-Droid.',
          language: 'de',
        ),
        isEmpty,
      );
    });

    test('are refused when the vocabulary has no entry for them', () {
      final violations = claims('Hlas bez reklam.', language: 'hr');
      expect(violations, hasLength(1));
      expect(violations.single, contains('claimsByLanguage'));
    });
  });

  group('the trees', () {
    test('are read one text per field, changelogs included', () {
      writeLocale(
        root,
        'de-DE',
        {
          'title.txt': 'Vernet',
          'short_description.txt': 'Kenne dein Netzwerk.',
          'full_description.txt': 'Ohne Werbung.',
        },
        changelogs: {'84.txt': 'Feste Latency tracking behoben.'},
      );
      final texts = readPlayTree(root);
      expect(texts.map((text) => text.path), [
        'de-DE/title.txt',
        'de-DE/short_description.txt',
        'de-DE/full_description.txt',
        'de-DE/changelogs/84.txt',
      ]);
      expect(texts.every((text) => text.language == 'de'), isTrue);
    });

    test('report a claim in a changelog the same way as one in a listing', () {
      writeLocale(
        root,
        'fr-FR',
        {'title.txt': 'Vernet'},
        changelogs: {'84.txt': 'Application gratuite et sans publicité.'},
      );
      expect(
        findUnqualifiedClaims(splitIntoSentences(readPlayTree(root))),
        hasLength(1),
      );
    });

    test('skip an msstore directory that is not an enabled locale', () {
      writeLocale(root, 'en-us', {'title.txt': 'Vernet'});
      writeLocale(root, 'pending', {'title.txt': 'Vernet'});
      expect(
          readMsstoreTree(root).map((text) => text.path), ['en-us/title.txt']);
    });

    test('keep a Play directory that is not a language code in the report', () {
      writeLocale(root, 'images', {'title.txt': 'Ad-free.'});
      final texts = readPlayTree(root);
      expect(texts, hasLength(1));
      final violations = findUnqualifiedClaims(splitIntoSentences(texts));
      expect(violations, hasLength(1));
      expect(violations.single, contains('claimsByLanguage'));
    });
  });

  test('the copy in git makes no unqualified claim', () {
    final texts = readPublishedCopy();
    expect(texts, isNotEmpty);
    expect(findUnqualifiedClaims(splitIntoSentences(texts)), isEmpty);
  });
}
