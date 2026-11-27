import 'package:injectable/injectable.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_analysis/device_risk_analyzer.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';
import 'package:vernet/utils/device_util.dart';

/// Adds the one signal a single scan row cannot know: whether the device keeps
/// vanishing between scans.
///
/// The report renders devices after they were stored, so this service reads the
/// stored device rows and scans once for the whole page and hands each device
/// to [DeviceRiskAnalyzer]. Live scan rows use the analyzer directly and show
/// their tier without the history flag, because the scan they belong to is not
/// complete yet.
@injectable
class DeviceRiskService {
  DeviceRiskService(this._devices, this._scans);

  final DeviceRepository _devices;
  final ScanRepository _scans;

  Future<Map<String, DeviceRiskAssessment>> assessDevices(
    List<DeviceData> devices,
    AppLocalizations l10n,
  ) async {
    if (devices.isEmpty) return const {};
    final scanIdsByKey = await _devices.scanIdsByDeviceKey();
    final scans = await _scans.getList();
    return {
      for (final device in devices)
        DeviceUtil.deviceKey(device): DeviceRiskAnalyzer.assess(
          device,
          findings: PortRiskAnalyzer.analyze(
            PortRiskAnalyzer.parsePorts(device.openPorts),
            l10n: l10n,
            deviceAddress: device.internetAddress,
          ),
          appearsIntermittently: _isIntermittent(
            device,
            scanIdsByKey: scanIdsByKey,
            scans: scans,
          ),
        ),
    };
  }

  /// True when the device missed at least [DeviceRiskAnalyzer.minimumMissedScans]
  /// of the scans that ran while it was part of the network's history, and was
  /// absent from at least half of them.
  ///
  /// The span runs from its first to its last stored appearance, so a device
  /// that arrived late is compared only against the scans it could have been in.
  static bool _isIntermittent(
    DeviceData device, {
    required Map<String, Set<int>> scanIdsByKey,
    required List<ScanData> scans,
  }) {
    final seenIds = <int>{};
    for (final key in DeviceUtil.deviceKeys(device)) {
      seenIds.addAll(scanIdsByKey[key] ?? const {});
    }
    final startTimes = {
      for (final scan in scans)
        if (scan.startTime != null) scan.id: scan.startTime!,
    };
    final seenTimes = [
      for (final id in seenIds)
        if (startTimes[id] != null) startTimes[id]!,
    ]..sort();
    if (seenTimes.length < 2) return false;

    final first = seenTimes.first;
    final last = seenTimes.last;
    final scansInSpan = startTimes.values
        .where((start) => !start.isBefore(first) && !start.isAfter(last))
        .length;
    final missed = scansInSpan - seenTimes.length;
    return missed >= DeviceRiskAnalyzer.minimumMissedScans &&
        missed * 2 >= scansInSpan;
  }
}
