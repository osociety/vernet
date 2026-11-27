import 'package:drift/drift.dart';

/// The summary of one scan's health report, kept for the trend line.
///
/// Findings are not stored: the device rows of the scan already persist, so a
/// report page rebuilds its lists from them and only the score, the grade and
/// the counts are snapshotted here.
class HealthReport extends Table {
  IntColumn get scanId => integer().named('scan_id')();
  DateTimeColumn get scanStartTime =>
      dateTime().nullable().named('scan_start_time')();
  IntColumn get score => integer()();
  TextColumn get grade => text()();
  IntColumn get criticalCount => integer().named('critical_count')();
  IntColumn get warningCount => integer().named('warning_count')();
  IntColumn get infoCount => integer().named('info_count')();
  IntColumn get lowRiskCount => integer().named('low_risk_count')();
  IntColumn get mediumRiskCount => integer().named('medium_risk_count')();
  IntColumn get highRiskCount => integer().named('high_risk_count')();
  DateTimeColumn get generatedAt => dateTime().named('generated_at')();

  @override
  Set<Column> get primaryKey => {scanId};
}
