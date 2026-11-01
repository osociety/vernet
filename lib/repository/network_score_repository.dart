import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/network_score.dart';

@injectable
class NetworkScoreRepository {
  static const _scoreKey = 'networkScore.lastScore';
  static const _speedSnapshotKey = 'networkScore.speedSnapshot';
  static const _pingSnapshotKey = 'networkScore.pingSnapshot';
  static const _ispInfoKey = 'networkScore.ispInfo';

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

  Future<IspInfo?> loadIspInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_ispInfoKey);
    if (encoded == null) return null;
    try {
      return IspInfo.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> saveIspInfo(IspInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ispInfoKey, jsonEncode(info.toJson()));
  }
}

class SpeedSnapshot {
  const SpeedSnapshot({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    this.ispRating,
    this.ispAvgDownloadMbps,
    this.ispAvgUploadMbps,
    this.ispName,
  });

  final double downloadMbps;
  final double uploadMbps;
  final double latencyMs;
  final double? ispRating;
  final double? ispAvgDownloadMbps;
  final double? ispAvgUploadMbps;
  final String? ispName;

  Map<String, Object?> toJson() => {
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'latencyMs': latencyMs,
        'ispRating': ispRating,
        'ispAvgDownloadMbps': ispAvgDownloadMbps,
        'ispAvgUploadMbps': ispAvgUploadMbps,
        'ispName': ispName,
      };

  factory SpeedSnapshot.fromJson(Map<String, dynamic> json) => SpeedSnapshot(
        downloadMbps: (json['downloadMbps'] as num).toDouble(),
        uploadMbps: (json['uploadMbps'] as num).toDouble(),
        latencyMs: (json['latencyMs'] as num).toDouble(),
        ispRating: (json['ispRating'] as num?)?.toDouble(),
        ispAvgDownloadMbps: (json['ispAvgDownloadMbps'] as num?)?.toDouble(),
        ispAvgUploadMbps: (json['ispAvgUploadMbps'] as num?)?.toDouble(),
        ispName: json['ispName'] as String?,
      );
}

class PingSnapshot {
  const PingSnapshot({
    required this.avgLatencyMs,
    required this.packetLossPercent,
    this.jitterMs,
    this.minLatencyMs,
    this.maxLatencyMs,
  });

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

  factory PingSnapshot.fromJson(Map<String, dynamic> json) => PingSnapshot(
        avgLatencyMs: (json['avgLatencyMs'] as num).toDouble(),
        packetLossPercent: (json['packetLossPercent'] as num).toDouble(),
        jitterMs: (json['jitterMs'] as num?)?.toDouble(),
        minLatencyMs: (json['minLatencyMs'] as num?)?.toDouble(),
        maxLatencyMs: (json['maxLatencyMs'] as num?)?.toDouble(),
      );
}

class IspInfo {
  const IspInfo({
    this.ispName,
    this.ispRating,
    this.avgDownloadMbps,
    this.avgUploadMbps,
  });

  final String? ispName;
  final double? ispRating;
  final double? avgDownloadMbps;
  final double? avgUploadMbps;

  Map<String, Object?> toJson() => {
        'ispName': ispName,
        'ispRating': ispRating,
        'avgDownloadMbps': avgDownloadMbps,
        'avgUploadMbps': avgUploadMbps,
      };

  factory IspInfo.fromJson(Map<String, dynamic> json) => IspInfo(
        ispName: json['ispName'] as String?,
        ispRating: (json['ispRating'] as num?)?.toDouble(),
        avgDownloadMbps: (json['avgDownloadMbps'] as num?)?.toDouble(),
        avgUploadMbps: (json['avgUploadMbps'] as num?)?.toDouble(),
      );
}
