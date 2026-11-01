import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/network_score.dart';

@injectable
class NetworkScoreRepository {
  static const _scoreKey = 'networkScore.lastScore';
  static const _speedSnapshotKey = 'networkScore.speedSnapshot';
  static const _pingSnapshotKey = 'networkScore.pingSnapshot';

  Future<NetworkScore?> loadLastScore() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_scoreKey);
    if (encoded == null) return null;
    try {
      return NetworkScore.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> saveScore(NetworkScore score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scoreKey, jsonEncode(score.toJson()));
  }

  Future<void> clearScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scoreKey);
  }

  Future<SpeedSnapshot?> loadSpeedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_speedSnapshotKey);
    if (encoded == null) return null;
    try {
      return SpeedSnapshot.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> saveSpeedSnapshot(SpeedSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_speedSnapshotKey, jsonEncode(snapshot.toJson()));
  }

  Future<PingSnapshot?> loadPingSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_pingSnapshotKey);
    if (encoded == null) return null;
    try {
      return PingSnapshot.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> savePingSnapshot(PingSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pingSnapshotKey, jsonEncode(snapshot.toJson()));
  }
}

class SpeedSnapshot {
  const SpeedSnapshot({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    this.packetLossPercent,
    this.retransmissions,
    this.serverLocation,
    this.testProvider,
  });

  factory SpeedSnapshot.fromJson(Map<String, dynamic> json) => SpeedSnapshot(
        downloadMbps: (json['downloadMbps'] as num).toDouble(),
        uploadMbps: (json['uploadMbps'] as num).toDouble(),
        latencyMs: (json['latencyMs'] as num).toDouble(),
        packetLossPercent: (json['packetLossPercent'] as num?)?.toDouble(),
        retransmissions: json['retransmissions'] as int?,
        serverLocation: json['serverLocation'] as String?,
        testProvider: json['testProvider'] as String?,
      );

  final double downloadMbps;
  final double uploadMbps;
  final double latencyMs;
  final double? packetLossPercent;
  final int? retransmissions;
  final String? serverLocation;
  final String? testProvider;

  Map<String, Object?> toJson() => {
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'latencyMs': latencyMs,
        'packetLossPercent': packetLossPercent,
        'retransmissions': retransmissions,
        'serverLocation': serverLocation,
        'testProvider': testProvider,
      };
}

class PingSnapshot {
  const PingSnapshot({
    required this.avgLatencyMs,
    required this.packetLossPercent,
    this.jitterMs,
    this.minLatencyMs,
    this.maxLatencyMs,
  });

  factory PingSnapshot.fromJson(Map<String, dynamic> json) => PingSnapshot(
        avgLatencyMs: (json['avgLatencyMs'] as num).toDouble(),
        packetLossPercent: (json['packetLossPercent'] as num).toDouble(),
        jitterMs: (json['jitterMs'] as num?)?.toDouble(),
        minLatencyMs: (json['minLatencyMs'] as num?)?.toDouble(),
        maxLatencyMs: (json['maxLatencyMs'] as num?)?.toDouble(),
      );

  final double avgLatencyMs;
  final double packetLossPercent;
  final double? jitterMs;
  final double? minLatencyMs;
  final double? maxLatencyMs;

  Map<String, Object?> toJson() => {
        'avgLatencyMs': avgLatencyMs,
        'packetLossPercent': packetLossPercent,
        'jitterMs': jitterMs,
        'minLatencyMs': minLatencyMs,
        'maxLatencyMs': maxLatencyMs,
      };
}
