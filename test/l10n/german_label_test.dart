import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A key missing from `app_de.arb` fails `arb_parity_test.dart`, but a key whose
/// German value was copied from English passes every guard there and still
/// renders English inside a German UI — `DNS & Diagnose` and `Wake on LAN` both
/// shipped that way. This is the second net: a German value may equal its
/// English source only where the two languages truly use the same words, and the
/// list below has to stay exact, so a new copy-paste fails and a translation
/// that lands forces the list to shrink.
void main() {
  final english = _messagesOf('en');
  final german = _messagesOf('de');

  test('the template has messages to compare', () {
    expect(english, isNotEmpty);
    expect(german.keys, equals(english.keys));
  });

  test('German differs from English except where the words are the same', () {
    final identical = <String>{
      for (final key in english.keys)
        if (german[key] == english[key]) key,
    };

    expect(
      identical,
      equals(kGermanKeepsTheEnglish),
      reason: 'anything listed only in the first set is an untranslated German '
          'value; anything listed only in the second set has been translated '
          'and should be removed from the allowlist',
    );
  });
}

/// The keys where English is also correct German, by reason.
///
/// Adding to this list is a decision about copy, not a test fix — prefer giving
/// the key a real German value.
const Set<String> kGermanKeepsTheEnglish = {
  // Units and protocol tokens.
  'signalStrengthUnit',
  'serverCheckerLatencyMs',
  'serverCheckerHttpStatus',
  'pingMethodIcmp',
  'deviceDetailPortNumber',
  'neighborVlan',
  'portScanChipSsh',
  'portScanChipHttp',
  'portScanChipHttps',
  'deviceTypeNas',
  'deviceDetailPing',

  // Labels German networking uses as-is.
  'homeInternet',
  'homeGateway',
  'homeAccessPoint',
  'deviceDetailGateway',
  'deviceDetailHostname',
  'deviceMakeRouterGateway',
  'netDetailInterface',
  'netDetailAccessPointBssid',
  'deviceTypeServer',
  'speedTestMlabTitle',

  // Words identical in both languages.
  'homeDownload',
  'homeUpload',
  'speedTestMetricDownload',
  'speedTestMetricUpload',
  'commonName',
  'trustedDevicesNameLabel',
  'wakeOnLanNameLabel',
  'scanHistoryScansLabel',
  'scanHistoryStatusColumn',
  'scoreFactorsInfo',
  'updatesChannelBeta',
  'speedCapGaming',

  // Nothing but a placeholder and a label German abbreviates the same way.
  'pingSummaryMin',
  'pingSummaryMax',
  'speedTestServerAt',
  'scoreSpeedServerAt',
};

/// The message entries of one ARB file, metadata (`@`-prefixed) left out.
Map<String, String> _messagesOf(String locale) {
  final decoded =
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value as String,
  };
}
