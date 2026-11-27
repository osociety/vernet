import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/models/network_health_report.dart';

/// Snapshot storage for health reports, one row per scan.
///
/// The row keeps the score, the grade and the counts so the report page can
/// compare a scan against the one before it without rebuilding that earlier
/// report from its device rows.
@Injectable()
class HealthReportRepository {
  HealthReportRepository(this._database);
  final DatabaseService<AppDatabase> _database;

  Future<HealthReportData?> get(int scanId) async {
    final database = await _database.open();
    return await (database!.select(database.healthReport)
          ..where((row) => row.scanId.equals(scanId)))
        .getSingleOrNull();
  }

  Future<List<HealthReportData>> getAll() async {
    final database = await _database.open();
    return await (database!.select(database.healthReport)
          ..orderBy([
            (row) => OrderingTerm(
                  expression: row.scanStartTime,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// The report of the most recent scan that started before [startTime].
  Future<HealthReportData?> previousBefore(DateTime? startTime) async {
    if (startTime == null) return null;
    final database = await _database.open();
    return await (database!.select(database.healthReport)
          ..where((row) => row.scanStartTime.isSmallerThanValue(startTime))
          ..orderBy([
            (row) => OrderingTerm(
                  expression: row.scanStartTime,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> save(NetworkHealthReport report) async {
    final database = await _database.open();
    await database!.into(database.healthReport).insertOnConflictUpdate(
          HealthReportCompanion.insert(
            scanId: Value(report.scanId),
            scanStartTime: Value(report.scanStartTime),
            score: report.score,
            grade: report.grade.name,
            criticalCount: report.critical.length,
            warningCount: report.warnings.length,
            infoCount: report.infos.length,
            lowRiskCount: report.lowRiskDevices,
            mediumRiskCount: report.mediumRiskDevices,
            highRiskCount: report.highRiskDevices,
            generatedAt: report.generatedAt,
          ),
        );
  }
}
