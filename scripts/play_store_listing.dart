// Checks the Google Play listing tree that the fastlane beta lane publishes.
//
//     dart run scripts/play_store_listing.dart [--check]
//
// Every release uploads the store bundle together with this tree: one directory
// per language under `android/fastlane/metadata/android/` becomes that language's
// store listing, and `changelogs/<build>.txt` becomes its "What's new". fastlane
// writes what git carries instead of merging into the Console, so a language with
// no note for the build being released ships an empty one, and a title over Play's
// 30 characters fails in the Console rather than here.
//
// A locale dir added for its listing text carries the note for the build being
// released and nothing older. supply only ever reads `<build>.txt`, and the
// GitHub release page is where earlier versions' notes live, so a new language is
// never backfilled with the history `en-US` happens to hold — `en-US` keeps that
// history because F-Droid maps every `<n>.txt` to that build's changelog.
//
// The tree is shared, not Play's own. The repository root carries a `fastlane`
// symlink to `android/fastlane`, and fdroidserver reads the same locale dirs for
// its listing: the text, the changelogs, the icon, the banner and the
// screenshots. So no asset here is safe to delete to stop one store publishing it.
// What Play receives is decided by placement: `images/icon.png` is the one image
// the beta lane uploads, checked byte-for-byte against `assets/app_icon.png`
// below; `featureGraphic.png` sits in the locale directory because F-Droid takes
// graphics from anywhere in it while supply only looks in `images/`; and
// `images/phoneScreenshots/` stays out of the publish, since supply replaces a
// language's live screenshot set wholesale.
//
// `--check` is the gate CI runs before any Play credential is used.

import 'dart:io';

/// Play's own counters, from the Console listing editor. A listing over any of
/// these is refused by Google.
const Map<String, int> maxFieldLength = {
  'title.txt': 30,
  'short_description.txt': 80,
  'full_description.txt': 4000,
};

const int maxChangelogLength = 500;

/// The text a language needs before it can be published as a listing of its own.
const List<String> requiredFiles = [
  'title.txt',
  'short_description.txt',
  'full_description.txt',
];

const String changelogDirectory = 'changelogs';
const String fallbackChangelogFile = 'default.txt';

/// The one image type that follows the app instead of being hand-uploaded.
const String iconFile = 'icon.png';
const String imagesDirectory = 'images';

/// The shared store banner, which F-Droid reads and Play must not.
const String featureGraphicFile = 'featureGraphic.png';

/// The brand mark the committed Play icon has to be byte-identical with, so the
/// listing icon cannot silently lag a logo change.
const String appIconFile = 'assets/app_icon.png';

/// The banner `android/fastlane/metadata/android/en-US/featureGraphic.png` holds
/// for F-Droid. It must not sit in `images/`: supply uploads every image type it
/// finds there, and this one is stale art nobody maintains as a Play asset.
final RegExp featureGraphicInImages =
    RegExp(r'^featureGraphic\.(png|jpe?g)$', caseSensitive: false);

/// A directory fastlane would upload as one language.
///
/// fastlane takes every non-hidden directory in the metadata tree, whatever it is
/// named, so [locale] is kept as found and judged by [validateListingTree] rather
/// than filtered out here.
class PlayLocale {
  PlayLocale(
    this.locale, {
    required this.files,
    required this.changelogs,
    required this.hasChangelogDirectory,
    this.video,
    this.iconBytes,
    this.playUploadableFeatureGraphic = false,
  });

  final String locale;

  /// File name -> contents, with a null value meaning no file committed.
  final Map<String, String?> files;

  /// Contents of every `changelogs/<name>.txt`, keyed by file name.
  final Map<String, String> changelogs;

  final bool hasChangelogDirectory;

  /// The promo video URL, when one is committed.
  final String? video;

  /// Raw bytes of `images/icon.png`, when one is committed. The icon is the only
  /// image fastlane uploads, so its bytes are the app icon Play will serve.
  final List<int>? iconBytes;

  /// Whether `images/` holds a feature graphic, which fastlane would upload.
  final bool playUploadableFeatureGraphic;
}

/// Reads the metadata tree, one entry per directory fastlane would publish.
List<PlayLocale> readListingTree(Directory root) {
  final locales = <PlayLocale>[];
  if (!root.existsSync()) return locales;
  final entries = root.listSync();
  entries.sort((a, b) => a.path.compareTo(b.path));
  for (final entity in entries) {
    if (entity is! Directory) continue;
    final name = _baseName(entity.path);
    if (name.startsWith('.')) continue;
    locales.add(_readLocale(entity, name));
  }
  return locales;
}

PlayLocale _readLocale(Directory directory, String name) {
  final files = <String, String?>{};
  for (final file in [...requiredFiles, 'video.txt']) {
    files[file] =
        _read(File('${directory.path}${Platform.pathSeparator}$file'));
  }
  final changelogDir = Directory(
      '${directory.path}${Platform.pathSeparator}$changelogDirectory');
  final changelogs = <String, String>{};
  if (changelogDir.existsSync()) {
    for (final entity in changelogDir.listSync()) {
      if (entity is! File) continue;
      final text = entity.readAsStringSync().replaceAll('\r\n', '\n');
      changelogs[_baseName(entity.path)] = _trim(text);
    }
  }
  final images =
      Directory('${directory.path}${Platform.pathSeparator}$imagesDirectory');
  final icon = File('${images.path}${Platform.pathSeparator}$iconFile');
  final bannerInImages = images.existsSync() &&
      images
          .listSync()
          .whereType<File>()
          .any((file) => featureGraphicInImages.hasMatch(_baseName(file.path)));
  return PlayLocale(
    name,
    files: files,
    changelogs: changelogs,
    hasChangelogDirectory: changelogDir.existsSync(),
    video: files['video.txt'],
    iconBytes: icon.existsSync() ? icon.readAsBytesSync() : null,
    playUploadableFeatureGraphic: bannerInImages,
  );
}

/// The build number in a `pubspec.yaml`, which is the version code Play keys the
/// changelog file name on.
int buildNumberFromPubspec(String pubspec) {
  final match = RegExp(r'^version:\s*\S*\+(\d+)\s*$', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    throw FormatException(
      'no build number in the pubspec version line',
      pubspec,
      pubspec.indexOf('version:'),
    );
  }
  return int.parse(match.group(1)!);
}

/// Every problem that would reach Play, in one report, so a contributor sees all
/// of them from a single run.
/// [appIconBytes] is the brand mark the app actually ships with. When it is
/// given, every committed listing icon has to be that same file, because Play
/// keeps serving whatever icon it last received and a stale one is invisible in
/// git.
List<String> validateListingTree(
  List<PlayLocale> locales,
  int buildNumber, {
  List<int>? appIconBytes,
}) {
  final violations = <String>[];
  if (locales.isEmpty) {
    return ['no language directories under the Play metadata tree'];
  }
  for (final locale in locales) {
    _checkLocaleName(locale, violations);
    for (final name in requiredFiles) {
      final value = locale.files[name];
      if (value == null || value.trim().isEmpty) {
        violations.add(
          '${locale.locale}: $name is missing or empty, so this listing cannot '
          'be published',
        );
        continue;
      }
      final max = maxFieldLength[name]!;
      if (value.length > max) {
        violations.add(
          '${locale.locale}: $name is ${value.length} characters, '
          'the Play limit is $max',
        );
      }
    }
    _checkChangelog(locale, buildNumber, violations);
    _checkVideo(locale, violations);
    _checkIcon(locale, appIconBytes, violations);
    _checkFeatureGraphicPlacement(locale, violations);
  }
  return violations;
}

/// fastlane publishes every directory it finds, so a directory that is not a
/// Play language code would push a listing Google refuses and abort the release.
void _checkLocaleName(PlayLocale locale, List<String> violations) {
  if (RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,4})?$').hasMatch(locale.locale)) {
    return;
  }
  violations.add(
    '${locale.locale} is not a Play language code, and fastlane would upload '
    'the directory as one',
  );
}

void _checkChangelog(
  PlayLocale locale,
  int buildNumber,
  List<String> violations,
) {
  if (!locale.hasChangelogDirectory) {
    violations.add(
      '${locale.locale} has no $changelogDirectory directory, so its release '
      'notes are blanked for build $buildNumber',
    );
    return;
  }
  final current = locale.changelogs['$buildNumber.txt'];
  if (current == null || current.trim().isEmpty) {
    violations.add(
      '${locale.locale} has no $changelogDirectory/$buildNumber.txt, so Play '
      'shows no "What\'s new" for that language',
    );
  } else if (current.length > maxChangelogLength) {
    violations.add(
      '${locale.locale}: $buildNumber.txt is ${current.length} characters, '
      'the Play limit is $maxChangelogLength',
    );
  }
  if (locale.changelogs.containsKey(fallbackChangelogFile)) {
    violations.add(
      '${locale.locale} has $changelogDirectory/$fallbackChangelogFile: '
      'fastlane falls back to it instead of failing, so a note written for '
      'another release ships in its place',
    );
  }
  final ahead = locale.changelogs.keys
      .map(_changelogBuild)
      .whereType<int>()
      .where((build) => build > buildNumber)
      .fold<int>(-1, (a, b) => a > b ? a : b);
  if (ahead > buildNumber) {
    violations.add(
      '${locale.locale} has $changelogDirectory/$ahead.txt, a changelog for a '
      'build past $buildNumber, so the release bump and the notes disagree',
    );
  }
}

void _checkVideo(PlayLocale locale, List<String> violations) {
  final video = locale.video;
  if (video == null) return;
  if (!video.trim().startsWith('https://')) {
    violations.add(
      '${locale.locale}: video.txt must hold the promo video URL, '
      'not "${_clip(video.trim())}"',
    );
  }
}

/// `featureGraphic.png` belongs one level up, in the locale directory: F-Droid
/// ingests a graphic from anywhere in it, while supply only uploads what sits in
/// `images/`. Left there, the next release republishes whatever banner the file
/// happens to hold, which is how the pre-rebrand art nearly came back.
void _checkFeatureGraphicPlacement(
  PlayLocale locale,
  List<String> violations,
) {
  if (!locale.playUploadableFeatureGraphic) return;
  violations.add(
    '${locale.locale}: a feature graphic in $imagesDirectory/ would upload to '
    'Play, where only the icon is owned by git — move it to '
    '${locale.locale}/$featureGraphicFile for F-Droid',
  );
}

/// The icon is the one image fastlane uploads, and Play keeps serving the last
/// one it received. A committed copy that is not the shipped brand mark means the
/// logo changed and the listing did not.
void _checkIcon(
  PlayLocale locale,
  List<int>? appIconBytes,
  List<String> violations,
) {
  final icon = locale.iconBytes;
  if (appIconBytes == null || icon == null) return;
  if (_bytesEqual(icon, appIconBytes)) return;
  violations.add(
    '${locale.locale}: $imagesDirectory/$iconFile differs from $appIconFile, '
    'so Play serves an icon the app no longer uses',
  );
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The build number a changelog file names, or null for `default.txt` and any
/// other file that is not a numbered note.
int? _changelogBuild(String fileName) {
  final match = RegExp(r'^(\d+)\.txt$').firstMatch(fileName);
  return match == null ? null : int.parse(match.group(1)!);
}

/// One line per language with the size of every field, which is what a reviewer
/// of a listing change needs to see without opening each file.
List<String> describeListingTree(List<PlayLocale> locales, int buildNumber) {
  return locales.map((locale) {
    final sizes = <String>[
      for (final name in requiredFiles)
        '${name.replaceAll('.txt', '')} ${locale.files[name]?.length ?? '-'}',
      '$buildNumber.txt ${locale.changelogs['$buildNumber.txt']?.length ?? '-'}',
    ];
    return '${locale.locale}: ${sizes.join(', ')}';
  }).toList();
}

String? _read(File file) {
  if (!file.existsSync()) return null;
  return _trim(file.readAsStringSync().replaceAll('\r\n', '\n'));
}

String _trim(String text) => text.replaceFirst(RegExp(r'\n$'), '');

String _baseName(String path) => path.split(Platform.pathSeparator).last;

String _clip(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 40)}...';

void main(List<String> args) {
  Directory metadata = Directory('android/fastlane/metadata/android');
  String pubspecPath = 'pubspec.yaml';
  String appIconPath = appIconFile;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--check':
        break;
      case '--metadata':
        if (++i >= args.length) {
          stderr.writeln('--metadata needs a path');
          exitCode = 64;
          return;
        }
        metadata = Directory(args[i]);
      case '--pubspec':
        if (++i >= args.length) {
          stderr.writeln('--pubspec needs a path');
          exitCode = 64;
          return;
        }
        pubspecPath = args[i];
      case '--app-icon':
        if (++i >= args.length) {
          stderr.writeln('--app-icon needs a path');
          exitCode = 64;
          return;
        }
        appIconPath = args[i];
      default:
        stderr.writeln(
          'usage: dart run scripts/play_store_listing.dart '
          '[--check] [--metadata <dir>] [--pubspec <file>] '
          '[--app-icon <file>]',
        );
        exitCode = 64;
        return;
    }
  }

  final int buildNumber;
  try {
    buildNumber = buildNumberFromPubspec(File(pubspecPath).readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('cannot read the build number: ${error.message}');
    exitCode = 1;
    return;
  }

  final locales = readListingTree(metadata);
  for (final line in describeListingTree(locales, buildNumber)) {
    stdout.writeln(line);
  }
  final appIcon = File(appIconPath);
  final violations = validateListingTree(
    locales,
    buildNumber,
    appIconBytes: appIcon.existsSync() ? appIcon.readAsBytesSync() : null,
  );
  if (violations.isEmpty) {
    stdout.writeln(
      '${locales.map((locale) => locale.locale).join(', ')}: Play listing tree '
      'is publishable for build $buildNumber.',
    );
    return;
  }
  stderr.writeln('the Play listing tree is not publishable:');
  for (final violation in violations) {
    stderr.writeln('  - $violation');
  }
  exitCode = 1;
}
