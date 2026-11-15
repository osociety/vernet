import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// gen-l10n falls back to the template for any key a locale leaves out, so an
/// incompletely translated locale renders as English and nothing fails. This is
/// the guard that turns a missing key into a CI failure.
void main() {
  final arbFiles = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the template ARB exists', () {
    expect(arbFiles.map(nameOf), contains('app_en.arb'));
  });

  test('every locale ARB carries exactly the template key set', () {
    final templateKeys = messageKeys(File('lib/l10n/app_en.arb'));
    expect(templateKeys, isNotEmpty);

    for (final file in arbFiles.where((f) => nameOf(f) != 'app_en.arb')) {
      expect(
        messageKeys(file),
        equals(templateKeys),
        reason: '${file.path} does not carry the same keys as app_en.arb',
      );
    }
  });

  test('each ARB declares the locale its file name promises', () {
    for (final file in arbFiles) {
      final code =
          RegExp(r'app_([a-zA-Z-]+)\.arb$').firstMatch(file.path)!.group(1);
      final declared = (jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['@@locale'];
      expect(declared, equals(code), reason: '${file.path} declares $declared');
    }
  });
}

Set<String> messageKeys(File file) {
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.keys.where((key) => !key.startsWith('@')).toSet();
}

/// ARB files are named by locale, and `Directory.listSync` builds its paths with
/// the platform separator, so the name is the only part safe to compare.
String nameOf(File file) => file.uri.pathSegments.last;
