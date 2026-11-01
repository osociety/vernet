import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/network_score.dart';

void main() {
  group('NetworkScore', () {
    test('serializes and deserializes correctly', () {
      final score = NetworkScore(
        overallScore: 85,
        computedAt: DateTime(2024, 1, 15, 10, 30),
        security: const DimensionScore(
          name: 'Security',
          value: 90,
          description: 'Good security',
          factors: ['✓ All devices identified'],
        ),
        health: const DimensionScore(
          name: 'Health',
          value: 80,
          description: 'Good health',
          factors: ['✓ Strong signal'],
        ),
        reliability: const DimensionScore(
          name: 'Reliability',
          value: 75,
          description: 'Moderate reliability',
          factors: ['~ Moderate latency'],
        ),
        speed: const DimensionScore(
          name: 'Speed',
          value: 70,
          description: 'Moderate speed',
          factors: ['~ Average download'],
        ),
        vulnerabilities: const DimensionScore(
          name: 'Vulnerabilities',
          value: 95,
          description: 'Low risk',
          factors: ['✓ No vulnerabilities'],
        ),
        metadata: {'gateway': '192.168.1.1', 'deviceIp': '192.168.1.100'},
      );

      final json = score.toJson();
      final restored = NetworkScore.fromJson(json);

      expect(restored.overallScore, 85);
      expect(restored.computedAt, DateTime(2024, 1, 15, 10, 30));
      expect(restored.security.value, 90);
      expect(restored.health.value, 80);
      expect(restored.reliability.value, 75);
      expect(restored.speed.value, 70);
      expect(restored.vulnerabilities.value, 95);
      expect(restored.metadata['gateway'], '192.168.1.1');
      expect(restored.metadata['deviceIp'], '192.168.1.100');
    });

    test('copyWith creates modified copy', () {
      final original = NetworkScore(
        overallScore: 85,
        computedAt: DateTime(2024, 1, 15),
        security: const DimensionScore(name: 'Security', value: 90, description: ''),
        health: const DimensionScore(name: 'Health', value: 80, description: ''),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: ''),
        speed: const DimensionScore(name: 'Speed', value: 70, description: ''),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 95, description: ''),
      );

      final modified = original.copyWith(
        overallScore: 90,
        metadata: {'key': 'value'},
      );

      expect(modified.overallScore, 90);
      expect(modified.computedAt, original.computedAt);
      expect(modified.security, original.security);
      expect(modified.metadata['key'], 'value');
    });

    test('dimensions returns all five dimensions', () {
      final score = NetworkScore(
        overallScore: 85,
        computedAt: DateTime.now(),
        security: const DimensionScore(name: 'Security', value: 90, description: ''),
        health: const DimensionScore(name: 'Health', value: 80, description: ''),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: ''),
        speed: const DimensionScore(name: 'Speed', value: 70, description: ''),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 95, description: ''),
      );

      expect(score.dimensions.length, 5);
      expect(score.dimensions.map((d) => d.name), [
        'Security',
        'Health',
        'Reliability',
        'Speed',
        'Vulnerabilities',
      ]);
    });

    test('level returns correct ScoreLevel', () {
      expect(
        NetworkScore(
          overallScore: 85,
          computedAt: DateTime.now(),
          security: const DimensionScore(name: '', value: 0, description: ''),
          health: const DimensionScore(name: '', value: 0, description: ''),
          reliability: const DimensionScore(name: '', value: 0, description: ''),
          speed: const DimensionScore(name: '', value: 0, description: ''),
          vulnerabilities: const DimensionScore(name: '', value: 0, description: ''),
        ).level,
        ScoreLevel.good,
      );

      expect(
        NetworkScore(
          overallScore: 50,
          computedAt: DateTime.now(),
          security: const DimensionScore(name: '', value: 0, description: ''),
          health: const DimensionScore(name: '', value: 0, description: ''),
          reliability: const DimensionScore(name: '', value: 0, description: ''),
          speed: const DimensionScore(name: '', value: 0, description: ''),
          vulnerabilities: const DimensionScore(name: '', value: 0, description: ''),
        ).level,
        ScoreLevel.moderate,
      );

      expect(
        NetworkScore(
          overallScore: 30,
          computedAt: DateTime.now(),
          security: const DimensionScore(name: '', value: 0, description: ''),
          health: const DimensionScore(name: '', value: 0, description: ''),
          reliability: const DimensionScore(name: '', value: 0, description: ''),
          speed: const DimensionScore(name: '', value: 0, description: ''),
          vulnerabilities: const DimensionScore(name: '', value: 0, description: ''),
        ).level,
        ScoreLevel.poor,
      );
    });

    test('hasData returns true when metadata is not empty', () {
      final scoreWithData = NetworkScore(
        overallScore: 85,
        computedAt: DateTime.now(),
        security: const DimensionScore(name: '', value: 0, description: ''),
        health: const DimensionScore(name: '', value: 0, description: ''),
        reliability: const DimensionScore(name: '', value: 0, description: ''),
        speed: const DimensionScore(name: '', value: 0, description: ''),
        vulnerabilities: const DimensionScore(name: '', value: 0, description: ''),
        metadata: {'key': 'value'},
      );

      final scoreWithoutData = NetworkScore(
        overallScore: 85,
        computedAt: DateTime.now(),
        security: const DimensionScore(name: '', value: 0, description: ''),
        health: const DimensionScore(name: '', value: 0, description: ''),
        reliability: const DimensionScore(name: '', value: 0, description: ''),
        speed: const DimensionScore(name: '', value: 0, description: ''),
        vulnerabilities: const DimensionScore(name: '', value: 0, description: ''),
      );

      expect(scoreWithData.hasData, true);
      expect(scoreWithoutData.hasData, false);
    });
  });

  group('DimensionScore', () {
    test('unknown factory creates default unknown dimension', () {
      final unknown = DimensionScore.unknown('Security');
      expect(unknown.name, 'Security');
      expect(unknown.value, 50);
      expect(unknown.description, 'Not enough data to assess');
      expect(unknown.factors, isEmpty);
    });

    test('level returns correct ScoreLevel', () {
      expect(const DimensionScore(name: '', value: 85, description: '').level, ScoreLevel.good);
      expect(const DimensionScore(name: '', value: 50, description: '').level, ScoreLevel.moderate);
      expect(const DimensionScore(name: '', value: 30, description: '').level, ScoreLevel.poor);
    });

    test('serializes and deserializes correctly', () {
      const dimension = DimensionScore(
        name: 'Security',
        value: 90,
        description: 'Good security',
        factors: ['✓ All devices identified', '~ Some concerns'],
      );

      final json = dimension.toJson();
      final restored = DimensionScore.fromJson(json);

      expect(restored.name, 'Security');
      expect(restored.value, 90);
      expect(restored.description, 'Good security');
      expect(restored.factors.length, 2);
      expect(restored.factors[0], '✓ All devices identified');
    });

    test('copyWith creates modified copy', () {
      const original = DimensionScore(
        name: 'Security',
        value: 90,
        description: 'Good',
        factors: ['factor1'],
      );

      final modified = original.copyWith(value: 95, description: 'Excellent');

      expect(modified.name, 'Security');
      expect(modified.value, 95);
      expect(modified.description, 'Excellent');
      expect(modified.factors, ['factor1']);
    });
  });

  group('ScoreLevel', () {
    test('fromScore returns correct level', () {
      expect(ScoreLevel.fromScore(100), ScoreLevel.good);
      expect(ScoreLevel.fromScore(70), ScoreLevel.good);
      expect(ScoreLevel.fromScore(69), ScoreLevel.moderate);
      expect(ScoreLevel.fromScore(40), ScoreLevel.moderate);
      expect(ScoreLevel.fromScore(39), ScoreLevel.poor);
      expect(ScoreLevel.fromScore(0), ScoreLevel.poor);
    });
  });
}
