import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A page reads `context.l10n`, and with `nullable-getter: false` that throws
/// unless the localization delegates are mounted. Driving `MyApp` mounts them;
/// a suite that builds its own `MaterialApp` around a page has to mount them
/// too, which is what `TestUtils.wrapWithLocalizations` exists for.
void main() {
  test('no integration suite builds a MaterialApp around a page', () {
    final offenders = <String>[];
    for (final file in _dartFiles('integration_test')) {
      if (file.endsWith('test_utils.dart')) continue;
      final lines = File(file).readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (lines[index].contains('MaterialApp(')) {
          offenders.add('$file:${index + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Pump the page through TestUtils.wrapWithLocalizations instead '
          'of a bare MaterialApp: the delegates it carries are what keeps '
          'context.l10n from throwing inside the page build.',
    );
  });
}

/// Forward slashes, because the Windows leg of CI lists files with backslashes
/// and a guard that misses one reports it as an offender.
List<String> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => file.path.replaceAll(r'\', '/'))
    .toList()
  ..sort();
