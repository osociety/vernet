import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/repository/network_score_repository.dart';

void main() {
  group('NetworkScoreRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveScore and loadScore persist score correctly', () async {
      final repository = NetworkScoreRepository();
      final score = NetworkScore(
        overallScore: 85,
        computedAt: DateTime(2024, 1, 15, 10, 30),
        security: const DimensionScore(
            name: 'Security', value: 90, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 80, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Moderate'),
        speed: const DimensionScore(
            name: 'Speed', value: 70, description: 'Moderate'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 95, description: 'Low risk'),
        metadata: {'gateway': '192.168.1.1'},
      );

      await repository.saveScore(score);
      final loaded = await repository.loadLastScore();

      expect(loaded, isNotNull);
      expect(loaded!.overallScore, 85);
      expect(loaded.computedAt, DateTime(2024, 1, 15, 10, 30));
      expect(loaded.security.value, 90);
      expect(loaded.metadata['gateway'], '192.168.1.1');
    });

    test('loadLastScore returns null when no score saved', () async {
      final repository = NetworkScoreRepository();
      final loaded = await repository.loadLastScore();
      expect(loaded, isNull);
    });

    test('clearScore removes saved score', () async {
      final repository = NetworkScoreRepository();
      final score = NetworkScore(
        overallScore: 85,
        computedAt: DateTime.now(),
        security: const DimensionScore(name: '', value: 0, description: ''),
        health: const DimensionScore(name: '', value: 0, description: ''),
        reliability: const DimensionScore(name: '', value: 0, description: ''),
        speed: const DimensionScore(name: '', value: 0, description: ''),
        vulnerabilities:
            const DimensionScore(name: '', value: 0, description: ''),
      );

      await repository.saveScore(score);
      await repository.clearScore();

      final loaded = await repository.loadLastScore();
      expect(loaded, isNull);
    });

    test('saveSpeedSnapshot and loadSpeedSnapshot persist correctly', () async {
      final repository = NetworkScoreRepository();
      const snapshot = SpeedSnapshot(
        downloadMbps: 85.5,
        uploadMbps: 25.3,
        latencyMs: 15.0,
      );

      await repository.saveSpeedSnapshot(snapshot);
      final loaded = await repository.loadSpeedSnapshot();

      expect(loaded, isNotNull);
      expect(loaded!.downloadMbps, 85.5);
      expect(loaded.uploadMbps, 25.3);
      expect(loaded.latencyMs, 15.0);
    });

    test('loadSpeedSnapshot returns null when no snapshot saved', () async {
      final repository = NetworkScoreRepository();
      final loaded = await repository.loadSpeedSnapshot();
      expect(loaded, isNull);
    });

    test('savePingSnapshot and loadPingSnapshot persist correctly', () async {
      final repository = NetworkScoreRepository();
      const snapshot = PingSnapshot(
        avgLatencyMs: 25.5,
        packetLossPercent: 2.5,
        jitterMs: 5.0,
        minLatencyMs: 10.0,
        maxLatencyMs: 50.0,
      );

      await repository.savePingSnapshot(snapshot);
      final loaded = await repository.loadPingSnapshot();

      expect(loaded, isNotNull);
      expect(loaded!.avgLatencyMs, 25.5);
      expect(loaded.packetLossPercent, 2.5);
      expect(loaded.jitterMs, 5.0);
      expect(loaded.minLatencyMs, 10.0);
      expect(loaded.maxLatencyMs, 50.0);
    });

    test('loadPingSnapshot returns null when no snapshot saved', () async {
      final repository = NetworkScoreRepository();
      final loaded = await repository.loadPingSnapshot();
      expect(loaded, isNull);
    });
  });
}
