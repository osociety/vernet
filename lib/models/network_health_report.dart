import 'package:vernet/models/network_finding.dart';

/// The letter grade of a report. Thresholds are a product baseline, not a
/// standard: A 90+, B 80+, C 70+, D 60+, anything lower is F.
enum HealthGrade {
  a,
  b,
  c,
  d,
  f;

  static HealthGrade fromScore(int score) {
    if (score >= 90) return HealthGrade.a;
    if (score >= 80) return HealthGrade.b;
    if (score >= 70) return HealthGrade.c;
    if (score >= 60) return HealthGrade.d;
    return HealthGrade.f;
  }

  String get letter => switch (this) {
        HealthGrade.a => 'A',
        HealthGrade.b => 'B',
        HealthGrade.c => 'C',
        HealthGrade.d => 'D',
        HealthGrade.f => 'F',
      };
}

/// How the score moved against the report of the previous scan.
enum HealthTrendDirection { improving, degrading, stable, unknown }

/// A finding tied to the device it was found on.
class HealthFinding {
  const HealthFinding({
    required this.deviceLabel,
    required this.address,
    required this.finding,
  });

  final String deviceLabel;
  final String address;
  final NetworkFinding finding;
}

/// Everything a health report page renders plus the snapshot the trend uses.
class NetworkHealthReport {
  const NetworkHealthReport({
    required this.scanId,
    required this.generatedAt,
    required this.score,
    required this.critical,
    required this.warnings,
    required this.infos,
    required this.lowRiskDevices,
    required this.mediumRiskDevices,
    required this.highRiskDevices,
    required this.notableDevices,
    required this.trend,
    this.scanStartTime,
    this.previousScore,
  });

  final int scanId;
  final DateTime? scanStartTime;
  final DateTime generatedAt;
  final int score;
  final List<HealthFinding> critical;
  final List<HealthFinding> warnings;
  final List<HealthFinding> infos;
  final int lowRiskDevices;
  final int mediumRiskDevices;
  final int highRiskDevices;

  /// Labels of the devices that reached the high tier, worst context first.
  final List<String> notableDevices;
  final HealthTrendDirection trend;
  final int? previousScore;

  HealthGrade get grade => HealthGrade.fromScore(score);
  int get deviceCount => lowRiskDevices + mediumRiskDevices + highRiskDevices;

  /// Points lost for one finding of each kind, plus the device tiers that
  /// carry risk beyond a single port. Starts from a perfect 100.
  static int scoreFor({
    required int critical,
    required int warnings,
    required int infos,
    required int highRiskDevices,
    required int mediumRiskDevices,
  }) {
    final raw = 100 -
        25 * critical -
        10 * warnings -
        3 * infos -
        10 * highRiskDevices -
        3 * mediumRiskDevices;
    return raw.clamp(0, 100);
  }

  /// Five points or more is a visible move; anything smaller reads as noise.
  static HealthTrendDirection directionFor(
    int score,
    int? previousScore,
  ) {
    if (previousScore == null) return HealthTrendDirection.unknown;
    final delta = score - previousScore;
    if (delta >= 5) return HealthTrendDirection.improving;
    if (delta <= -5) return HealthTrendDirection.degrading;
    return HealthTrendDirection.stable;
  }
}
