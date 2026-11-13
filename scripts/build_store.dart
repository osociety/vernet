// Assembles the Google Play app bundle from this checkout.
//
// The committed tree is the ad-free build that F-Droid, the GitHub releases and
// the snap ship. This script applies store_overlay/ — the two `lib/store/`
// implementations and the two Play-only plugins — builds `--flavor store`, then
// puts the tree back byte for byte, including on a failed build.
//
//     dart run scripts/build_store.dart [--dry-run] [--keep] [extra flutter args]
//
// Run it instead of hand-copying the overlay: a tree left overlaid is a tree
// that would publish an ad SDK to F-Droid.

import 'dart:io';

const String overlayDir = 'store_overlay';
const String pubspecPath = 'pubspec.yaml';
const String lockfilePath = 'pubspec.lock';
const String additionsPath = '$overlayDir/pubspec_additions.yaml';
const String bundlePath =
    'build/app/outputs/bundle/storeRelease/app-store-release.aab';

/// Overlay file -> the tracked file it replaces during a store build.
const Map<String, String> overlaidSources = {
  '$overlayDir/lib/store/store_features.dart': 'lib/store/store_features.dart',
  '$overlayDir/lib/store/inline_adaptive_banner.dart':
      'lib/store/inline_adaptive_banner.dart',
};

/// Tracked files a store build rewrites, so each one is restored afterwards.
///
/// `pubspec.lock` is in the list because `flutter pub get` resolves the
/// overlaid dependencies into it, and F-Droid builds with
/// `--enforce-lockfile`: a lock that names the ad SDK fails their build.
final List<String> restoredFiles = [
  pubspecPath,
  lockfilePath,
  ...overlaidSources.values,
];

Future<void> main(List<String> args) async {
  final options = _Options.from(args);
  final root = _findRepositoryRoot();
  if (root == null) {
    stderr.writeln(
      'Could not find $overlayDir next to a $pubspecPath. '
      'Run this from the repository root.',
    );
    exitCode = 64;
    return;
  }

  final additions = _additionLines(File('$root/$additionsPath'));
  final problem = _preflight(root, additions);
  if (problem != null) {
    stderr.writeln(problem);
    exitCode = 65;
    return;
  }

  if (options.dryRun) {
    stdout.writeln('Store build in $root would:');
    overlaidSources.forEach(
      (overlay, target) => stdout.writeln('  copy $overlay over $target'),
    );
    stdout.writeln('  add to $pubspecPath dependencies:');
    for (final line in additions) {
      stdout.writeln(line);
    }
    stdout.writeln('  flutter pub get');
    stdout.writeln('  flutter build appbundle --flavor store');
    stdout.writeln('  restore ${restoredFiles.join(', ')}');
    return;
  }

  final backupPath =
      Directory.systemTemp.createTempSync('vernet_store_build_').path;
  // Byte-for-byte snapshots of everything the overlay touches, taken before the
  // first write, so the restore never depends on git state.
  for (final path in restoredFiles) {
    final original = File('$root/$path');
    if (!original.existsSync()) continue;
    final snapshot = File('$backupPath/$path');
    Directory(snapshot.parent.path).createSync(recursive: true);
    original.copySync(snapshot.path);
  }

  var restored = false;
  Future<void> restore() async {
    if (restored) return;
    restored = true;
    for (final path in restoredFiles) {
      final snapshot = File('$backupPath/$path');
      if (snapshot.existsSync()) snapshot.copySync('$root/$path');
    }
    Directory(backupPath).deleteSync(recursive: true);
    stdout.writeln('Restored ${restoredFiles.join(', ')}');
    if (!options.keep) {
      // The build resolved the overlaid dependencies into .dart_tool/, so the
      // restored tree needs its own resolution or the next analyze trips over
      // ad imports that the committed pubspec does not carry.
      await _run(root, 'flutter', ['pub', 'get'], stage: 'rebind');
    }
  }

  try {
    overlaidSources.forEach(
      (overlay, target) => File('$root/$overlay').copySync('$root/$target'),
    );
    final pubspec = File('$root/$pubspecPath');
    pubspec.writeAsStringSync(
      _splicedDependencies(pubspec.readAsStringSync(), additions),
    );
    stdout.writeln(
      'Applied $overlayDir: ${overlaidSources.length} sources, '
      '${additions.length} dependencies.',
    );

    if (await _run(root, 'flutter', ['pub', 'get'], stage: 'resolve') != 0) {
      exitCode = 1;
      return;
    }
    if (await _run(
          root,
          'flutter',
          ['build', 'appbundle', '--flavor', 'store', ...options.flutterArgs],
          stage: 'build',
        ) !=
        0) {
      exitCode = 1;
      return;
    }

    final bundle = File('$root/$bundlePath');
    stdout.writeln(
      bundle.existsSync()
          ? 'Wrote $bundlePath (${bundle.lengthSync()} bytes).'
          : 'Build succeeded but $bundlePath is missing.',
    );
  } finally {
    if (options.keep) {
      stdout.writeln(
        '--keep: $overlayDir is still applied. Undo it with '
        '`git checkout -- ${restoredFiles.join(' ')}` before any other build.',
      );
    } else {
      await restore();
    }
  }
}

/// Verifies nothing is already overlaid and no target has uncommitted work.
String? _preflight(String root, List<String> additions) {
  for (final overlay in overlaidSources.keys) {
    if (!File('$root/$overlay').existsSync()) {
      return 'Missing $overlay — it and lib/store/ must stay in step.';
    }
  }
  if (additions.isEmpty) {
    return '$additionsPath has no dependency lines.';
  }

  if (File('$root/$pubspecPath')
      .readAsStringSync()
      .contains('google_mobile_ads')) {
    return '$pubspecPath already declares the ad SDK, so this tree is either '
        'overlaid or the dependency was committed. Restore it first: F-Droid '
        'builds this file.';
  }

  final dirty = Process.runSync(
    'git',
    ['status', '--porcelain', '--', ...restoredFiles],
    workingDirectory: root,
  );
  if (dirty.exitCode != 0) {
    return '`git status` failed: ${dirty.stderr}';
  }
  // Untracked seam files are fine: they are snapshotted like any other target.
  // Only a file with uncommitted content is a risk the restore cannot see.
  final conflicting = dirty.stdout
      .toString()
      .split('\n')
      .where((line) => line.trim().isNotEmpty && !line.startsWith('??'))
      .join('\n');
  if (conflicting.isNotEmpty) {
    return 'Uncommitted changes in files this script overwrites:\n'
        '$conflicting\n'
        'Commit or stash them first so the restore cannot lose work.';
  }
  return null;
}

/// The dependency lines to insert, with comments and blanks dropped.
List<String> _additionLines(File additions) {
  if (!additions.existsSync()) return const [];
  return additions
      .readAsLinesSync()
      .where((line) {
        final text = line.trim();
        return text.isNotEmpty && !text.startsWith('#');
      })
      // The file carries the pubspec block indentation already, so only a line
      // written flush left needs the two-space key indent added.
      .map((line) => line.startsWith('  ') ? line : '  $line')
      .toList();
}

/// Inserts [additions] under the `dependencies:` block of [pubspec].
String _splicedDependencies(String pubspec, List<String> additions) {
  final lines = pubspec.split('\n');
  final index = lines.indexWhere((line) => line.trim() == 'dependencies:');
  if (index == -1) {
    throw StateError('No dependencies: block found in $pubspecPath');
  }
  return <String>[
    ...lines.sublist(0, index + 1),
    ...additions,
    ...lines.sublist(index + 1),
  ].join('\n');
}

/// The directory holding both `pubspec.yaml` and `store_overlay/`.
String? _findRepositoryRoot() {
  final scriptDirectory = File.fromUri(Platform.script).parent.parent.path;
  for (final start in <String>[Directory.current.path, scriptDirectory]) {
    if (File('$start/$pubspecPath').existsSync() &&
        Directory('$start/$overlayDir').existsSync()) {
      return start;
    }
  }
  return null;
}

Future<int> _run(
  String workingDirectory,
  String executable,
  List<String> arguments, {
  required String stage,
}) async {
  stdout.writeln('[$stage] $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  return await process.exitCode;
}

class _Options {
  const _Options({
    required this.dryRun,
    required this.keep,
    required this.flutterArgs,
  });

  factory _Options.from(List<String> args) {
    final rest = <String>[...args];
    return _Options(
      dryRun: rest.remove('--dry-run'),
      keep: rest.remove('--keep'),
      flutterArgs: rest,
    );
  }

  final bool dryRun;
  final bool keep;
  final List<String> flutterArgs;
}
