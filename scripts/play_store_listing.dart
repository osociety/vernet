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
// Screenshots and the feature graphic stay out of the publish on purpose: the
// committed images are a snapshot from whenever they were last saved, and
// fastlane replaces the live set for a language wholesale.
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
  });

  final String locale;

  /// File name -> contents, with a null value meaning no file committed.
  final Map<String, String?> files;

  /// Contents of every `changelogs/<name>.txt`, keyed by file name.
  final Map<String, String> changelogs;

  final bool hasChangelogDirectory;

  /// The promo video URL, when one is committed.
  final String? video;
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
  return PlayLocale(
    name,
    files: files,
    changelogs: changelogs,
    hasChangelogDirectory: changelogDir.existsSync(),
    video: files['video.txt'],
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
List<String> validateListingTree(List<PlayLocale> locales, int buildNumber) {
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
      default:
        stderr.writeln(
          'usage: dart run scripts/play_store_listing.dart '
          '[--check] [--metadata <dir>] [--pubspec <file>]',
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
  final violations = validateListingTree(locales, buildNumber);
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
