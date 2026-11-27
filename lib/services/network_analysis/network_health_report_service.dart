import 'package:injectable/injectable.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/models/network_finding.dart';
import 'package:vernet/models/network_health_report.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/health_report_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_analysis/device_risk_analyzer.dart';
import 'package:vernet/services/network_analysis/device_risk_service.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';
import 'package:vernet/utils/device_util.dart';

/// Builds the network health report for a scan and keeps its summary.
///
/// The findings are the same ones the device detail page shows: the analyzer
/// runs over the ports the scan stored, and the risk tiers come from the
/// history-aware pass, so a device that keeps disappearing lowers the grade.
@injectable
class NetworkHealthReportService {
  NetworkHealthReportService(
    this._devices,
    this._scans,
    this._reports,
    this._risk,
  );

  final DeviceRepository _devices;
  final ScanRepository _scans;
  final HealthReportRepository _reports;
  final DeviceRiskService _risk;

  /// Builds a report over [devices], which are the rows of [scan].
  Future<NetworkHealthReport> buildFor(
    ScanData scan,
    List<DeviceData> devices,
    AppLocalizations l10n,
  ) async {
    final assessments = await _risk.assessDevices(devices, l10n);
    final critical = <HealthFinding>[];
    final warnings = <HealthFinding>[];
    final infos = <HealthFinding>[];
    final highRiskLabels = <String>[];
    var low = 0;
    var medium = 0;
    var high = 0;

    for (final device in devices) {
      final label = DeviceUtil.makeLabel(
            l10n,
            DeviceUtil.getDeviceMake(device),
          ) ??
          l10n.unknownDevice;
      final findings = PortRiskAnalyzer.analyze(
        PortRiskAnalyzer.parsePorts(device.openPorts),
        l10n: l10n,
        deviceAddress: device.internetAddress,
      );
      for (final finding in findings) {
        final entry = HealthFinding(
          deviceLabel: label,
          address: device.internetAddress,
          finding: finding,
        );
        switch (finding.severity) {
          case NetworkFindingSeverity.critical:
            critical.add(entry);
          case NetworkFindingSeverity.warning:
            warnings.add(entry);
          case NetworkFindingSeverity.info:
            infos.add(entry);
        }
      }

      final level = assessments[DeviceUtil.deviceKey(device)]?.level ??
          DeviceRiskAnalyzer.assess(device, findings: findings).level;
      switch (level) {
        case DeviceRiskLevel.low:
          low++;
        case DeviceRiskLevel.medium:
          medium++;
        case DeviceRiskLevel.high:
          high++;
          if (!highRiskLabels.contains(label)) highRiskLabels.add(label);
      }
    }

    _sort(critical);
    _sort(warnings);
    _sort(infos);
    highRiskLabels.sort();

    final score = NetworkHealthReport.scoreFor(
      critical: critical.length,
      warnings: warnings.length,
      infos: infos.length,
      highRiskDevices: high,
      mediumRiskDevices: medium,
    );
    final previous = await _reports.previousBefore(scan.startTime);
    return NetworkHealthReport(
      scanId: scan.id,
      scanStartTime: scan.startTime,
      generatedAt: DateTime.now(),
      score: score,
      critical: critical,
      warnings: warnings,
      infos: infos,
      lowRiskDevices: low,
      mediumRiskDevices: medium,
      highRiskDevices: high,
      notableDevices: highRiskLabels,
      trend: NetworkHealthReport.directionFor(score, previous?.score),
      previousScore: previous?.score,
    );
  }

  /// Rebuilds the report of a stored scan from its device rows.
  Future<NetworkHealthReport> buildForStoredScan(
    ScanData scan,
    AppLocalizations l10n,
  ) async {
    final devices = await _devices.getListForScan(scan.id);
    return await buildFor(scan, devices, l10n);
  }

  /// Builds and stores the report of the scan that just finished.
  Future<void> saveForCurrentScan(
    List<DeviceData> devices,
    AppLocalizations l10n,
  ) async {
    final scan = await _currentScan();
    if (scan == null) return;
    final report = await buildFor(scan, devices, l10n);
    await _reports.save(report);
  }

  Future<void> save(NetworkHealthReport report) => _reports.save(report);

  Future<ScanData?> _currentScan() async {
    final scanId = await getCurrentScanId();
    if (scanId == null) return null;
    return await _scans.get(scanId);
  }

  /// One list per severity; the worst port first, then by address so two
  /// scans of the same network read the same way.
  static void _sort(List<HealthFinding> findings) {
    findings.sort((left, right) {
      final byFinding = NetworkFinding.compare(left.finding, right.finding);
      if (byFinding != 0) return byFinding;
      return left.address.compareTo(right.address);
    });
  }
}
