import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/play_store_listing.dart';

/// A locale directory shaped like the ones fastlane publishes.
void writeLocale(
  Directory root,
  String locale, {
  String title = 'Vernet - Know your network',
  String shortDescription = 'Know your network. Discover, scan & diagnose.',
  String fullDescription = 'Take control of your network.',
  Map<String, String> changelogs = const {'84.txt': 'New notes.'},
  String? video,
  List<int>? icon,
}) {
  final dir = Directory('${root.path}${Platform.pathSeparator}$locale')
    ..createSync(recursive: true);
  void write(String name, String contents) =>
      File('${dir.path}${Platform.pathSeparator}$name')
          .writeAsStringSync(contents);
  write('title.txt', '$title\n');
  write('short_description.txt', '$shortDescription\n');
  write('full_description.txt', '$fullDescription\n');
  if (video != null) write('video.txt', video);
  if (icon != null) {
    final images = Directory(
      '${dir.path}${Platform.pathSeparator}$imagesDirectory',
    )..createSync();
    File('${images.path}${Platform.pathSeparator}$iconFile')
        .writeAsBytesSync(icon);
  }
  if (changelogs.isEmpty) return;
  final notes = Directory('${dir.path}${Platform.pathSeparator}changelogs')
    ..createSync();
  changelogs.forEach(
    (name, contents) => File('${notes.path}${Platform.pathSeparator}$name')
        .writeAsStringSync(contents),
  );
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('play_store_listing'));
  tearDown(() => root.deleteSync(recursive: true));

  group('build number', () {
    test('comes from the pubspec version line', () {
      expect(buildNumberFromPubspec('version: 1.7.0+84\n'), 84);
    });

    test('is refused when the version carries no build', () {
      expect(
        () => buildNumberFromPubspec('version: 1.7.0\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('validateListingTree', () {
    test('accepts a locale set that carries this build', () {
      writeLocale(root, 'en-US');
      writeLocale(root, 'de-DE', title: 'Vernet - Kenn dein Netzwerk');
      expect(validateListingTree(readListingTree(root), 84), isEmpty);
    });

    test('refuses an empty tree', () {
      expect(
        validateListingTree(readListingTree(root), 84),
        contains(
          'no language directories under the Play metadata tree',
        ),
      );
    });

    test('refuses a language with no note for the build being released', () {
      writeLocale(root, 'en-US');
      writeLocale(root, 'fr-FR', changelogs: const {'83.txt': 'Older notes.'});
      final violations = validateListingTree(readListingTree(root), 84);
      expect(violations, hasLength(1));
      expect(violations.single, contains('fr-FR has no changelogs/84.txt'));
    });

    test('refuses a default.txt, which ships instead of failing', () {
      writeLocale(
        root,
        'de-DE',
        changelogs: const {'84.txt': 'Notes.', 'default.txt': 'Old notes.'},
      );
      expect(
        validateListingTree(readListingTree(root), 84).join('\n'),
        contains('falls back to it instead of failing'),
      );
    });

    test('refuses a note ahead of the release bump', () {
      writeLocale(root, 'en-US',
          changelogs: const {'84.txt': 'a', '85.txt': 'b'});
      expect(
        validateListingTree(readListingTree(root), 84).join('\n'),
        contains('a changelog for a build past 84'),
      );
    });

    test('refuses Play field limits being exceeded', () {
      writeLocale(
        root,
        'de-DE',
        title: 'Vernet - ein Titel, der deutlich zu lang fuer Play ist',
        shortDescription: 'x' * 81,
        changelogs: {'84.txt': 'y' * 501},
      );
      final violations =
          validateListingTree(readListingTree(root), 84).join('\n');
      expect(violations, contains('title.txt is'));
      expect(violations, contains('the Play limit is 30'));
      expect(violations, contains('short_description.txt is'));
      expect(violations,
          contains('84.txt is 501 characters, the Play limit is 500'));
    });

    test('refuses a missing or empty listing field', () {
      writeLocale(root, 'en-US', title: '   ');
      final violations = validateListingTree(readListingTree(root), 84);
      expect(violations, hasLength(1));
      expect(violations.single, contains('title.txt is missing or empty'));
    });

    test('refuses a directory fastlane would publish as a language', () {
      writeLocale(root, 'en-US');
      writeLocale(root, 'pending');
      expect(
        validateListingTree(readListingTree(root), 84).join('\n'),
        contains('pending is not a Play language code'),
      );
    });

    test('refuses a video that is not a URL', () {
      writeLocale(root, 'en-US', video: 'somewhere out there');
      expect(
        validateListingTree(readListingTree(root), 84).join('\n'),
        contains('video.txt must hold the promo video URL'),
      );
    });

    test('sees only the language directories, not the images inside them', () {
      writeLocale(root, 'en-US');
      Directory(
        '${root.path}${Platform.pathSeparator}en-US${Platform.pathSeparator}'
        'images${Platform.pathSeparator}phoneScreenshots',
      ).createSync(recursive: true);
      expect(readListingTree(root).map((locale) => locale.locale), ['en-US']);
    });
  });

  // The icon is the one image the beta lane uploads, so a committed copy left
  // behind by a logo change is what Play keeps serving to every user.
  group('icon drift', () {
    test('reads the committed icon', () {
      writeLocale(root, 'en-US', icon: [1, 2, 3]);
      expect(readListingTree(root).single.iconBytes, [1, 2, 3]);
    });

    test('accepts an icon that is the shipped brand mark', () {
      writeLocale(root, 'en-US', icon: [9, 8, 7]);
      expect(
        validateListingTree(readListingTree(root), 84, appIconBytes: [9, 8, 7]),
        isEmpty,
      );
    });

    test('refuses an icon the app no longer uses', () {
      writeLocale(root, 'en-US', icon: [1, 2, 3]);
      final violations = validateListingTree(readListingTree(root), 84,
          appIconBytes: [1, 2, 4]);
      expect(violations, hasLength(1));
      expect(
        violations.single,
        contains('images/icon.png differs from assets/app_icon.png'),
      );
    });

    test('ignores a locale with no icon, which fastlane leaves untouched', () {
      writeLocale(root, 'en-US');
      expect(
        validateListingTree(readListingTree(root), 84, appIconBytes: [1, 2, 3]),
        isEmpty,
      );
    });

    test('is not judged without the app icon to compare against', () {
      writeLocale(root, 'en-US', icon: [1, 2, 3]);
      expect(validateListingTree(readListingTree(root), 84), isEmpty);
    });
  });

  // One tree, two stores: F-Droid ingests a graphic from anywhere in the locale
  // directory, supply uploads only what sits in `images/`. So the shared banner
  // belongs beside the text, where Play cannot pick it up.
  group('shared store graphics', () {
    void writeBanner(String locale, String relativeDir) {
      final dir = Directory('${root.path}${Platform.pathSeparator}$locale'
          '${Platform.pathSeparator}$relativeDir')
        ..createSync(recursive: true);
      File('${dir.path}${Platform.pathSeparator}featureGraphic.png')
          .writeAsBytesSync([1, 2, 3]);
    }

    test('refuses a feature graphic where supply would upload it', () {
      writeLocale(root, 'en-US');
      writeBanner('en-US', 'images');
      final violations = validateListingTree(readListingTree(root), 84);
      expect(violations, hasLength(1));
      expect(violations.single, contains('would upload to Play'));
    });

    test('accepts the banner in the locale directory, where F-Droid reads it',
        () {
      writeLocale(root, 'en-US');
      writeBanner('en-US', '.');
      expect(validateListingTree(readListingTree(root), 84), isEmpty);
    });
  });

  // The tree this repository publishes, checked the way CI does before any Play
  // credential is used: a locale added without this build's changelog, copy over
  // a Play limit, or an icon behind the shipped brand mark fails here rather
  // than blanking or misbranding a live listing.
  test('the committed listing tree is publishable for the release build', () {
    final metadata = Directory('android/fastlane/metadata/android');
    expect(metadata.existsSync(), isTrue,
        reason: 'run from the repository root');
    final build = buildNumberFromPubspec(
      File('pubspec.yaml').readAsStringSync(),
    );
    final locales = readListingTree(metadata);
    expect(locales.map((locale) => locale.locale),
        containsAll(['en-US', 'de-DE']));
    // F-Droid serves this as its banner, so it is a shared asset, not a Play one
    // that can be dropped when Play stops wanting it.
    expect(
      File('android/fastlane/metadata/android/en-US/$featureGraphicFile')
          .existsSync(),
      isTrue,
      reason: 'fdroidserver reads the banner out of the fastlane tree',
    );
    expect(
      validateListingTree(
        locales,
        build,
        appIconBytes: File(appIconFile).readAsBytesSync(),
      ),
      isEmpty,
    );
  });
}
