import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What issue #644 leaves behind: no English copy survives in `lib/`. Anything
/// the app renders belongs in an ARB file, because a literal that lives in code
/// is a string German can never translate.
void main() {
  test('lib/ renders no copy that the ARB files do not own', () {
    final offenders = [
      for (final file in _dartFiles('lib'))
        for (final found in _copyLiterals(file).entries)
          if (kCopyOutsideTheARB[found.key] == null)
            '$file:$found.value  "${found.key}"',
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'Move these into lib/l10n/app_en.arb and app_de.arb and read '
          'them from context.l10n. If one is genuinely not copy, add it to '
          'kCopyOutsideTheARB with the reason it earns its place there.',
    );
  });

  test('the allowlist still describes something that is there', () {
    final rendered = <String>{
      for (final file in _dartFiles('lib')) ..._copyLiterals(file).keys,
    };

    expect(
      kCopyOutsideTheARB.keys.toSet().difference(rendered),
      isEmpty,
      reason: 'This literal is gone, so its allowlist entry is free to go too.',
    );
  });
}

/// Copy-shaped literals in a rendering slot, keyed by the text with the line it
/// sits on, so a protocol token or a cast that reads like a string cannot trip
/// the guard.
Map<String, int> _copyLiterals(String path) {
  final found = <String, int>{};
  final lines = File(path).readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    for (final match in _renderSlotLiteral.allMatches(lines[index])) {
      final literal = match.group(1)!.trim();
      // A literal only reaches the user as words when it starts a sentence or
      // holds one, which keeps an identifier, a URL or a channel name out of
      // the guard.
      if (literal.contains(' ') || _capitals.contains(literal[0])) {
        found.putIfAbsent(literal, () => index + 1);
      }
    }
  }
  return found;
}

const _capitals = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

final _renderSlotLiteral = RegExp(
  "(?:Text|title|label|hintText|helperText|tooltip|message|semanticsLabel|subtitle|heading)"
  r"[^A-Za-z0-9_]{0,3}(?:const\s+)?\(?\s*'([A-Za-z0-9][^'\\$]{2,})'",
);

/// Every copy-shaped literal in `lib/` that is not app copy, with the reason.
const Map<String, String> kCopyOutsideTheARB = {
  'Vernet': 'App name; the store listings localise the tagline, not the name.',
  'GitHub': 'Brand name of the release host.',
  'M-Lab': 'Brand name of the speed-test provider.',
  'TCP': 'Protocol token used as a column tag.',
  'UDP': 'Protocol token used as a column tag.',
  'CDP': 'Protocol token used as a filter chip.',
  'LLDP': 'Protocol token used as a filter chip.',
  'AA:BB:CC:DD:EE:FF': 'MAC address format shown as a field hint.',
  '00.0 Mbps': 'Skeleton shown before a speed reading arrives.',
  '0.0 Mbps': 'Skeleton shown before a speed reading arrives.',
  '00 ms': 'Skeleton shown before a latency reading arrives.',
  'Getting things ready...': 'Shown only when globals.testingActive is set, '
      'which happens when integration tests launch the app and never in a '
      'build a user can install.',
};

List<String> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    // Forward slashes: the Windows leg of CI lists files with backslashes, and
    // this filter has to keep the generated bundles out on every platform.
    .map((file) => file.path.replaceAll(r'\', '/'))
    .where((path) => !path.contains('/l10n/app_localizations'))
    .toList()
  ..sort();
