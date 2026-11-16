import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/network_score/score_display.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('scoreDimensionName', () {
    test('keeps a name the service does not know', () {
      expect(scoreDimensionName(l10nEn(), 'Throughput'), 'Throughput');
      expect(scoreDimensionName(l10nDe(), 'Throughput'), 'Throughput');
    });

    test('translates the five stored dimension tokens', () {
      final de = l10nDe();
      expect(scoreDimensionName(de, 'Health'), 'Zustand');
      expect(scoreDimensionName(de, 'Reliability'), 'Verfügbarkeit');
      expect(scoreDimensionEn('Security'), 'Security');
    });
  });

  group('scoreDimensionChip', () {
    test('keeps the English abbreviations byte-identical', () {
      final en = l10nEn();
      expect(scoreDimensionChip(en, 'Security'), 'SEC');
      expect(scoreDimensionChip(en, 'Health'), 'HLT');
      expect(scoreDimensionChip(en, 'Reliability'), 'REL');
      expect(scoreDimensionChip(en, 'Speed'), 'SPD');
      expect(scoreDimensionChip(en, 'Vulnerabilities'), 'VUL');
    });

    test('abbreviates the translated names for German', () {
      final de = l10nDe();
      expect(scoreDimensionChip(de, 'Health'), 'ZUS');
      expect(scoreDimensionChip(de, 'Vulnerabilities'), 'SCH');
    });

    test('clips an unknown name to three letters', () {
      expect(scoreDimensionChip(l10nEn(), 'Throughput'), 'THR');
      expect(scoreDimensionChip(l10nEn(), 'IO'), 'IO');
    });
  });
}

String scoreDimensionEn(String name) => scoreDimensionName(l10nEn(), name);
