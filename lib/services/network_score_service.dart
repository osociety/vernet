import 'package:injectable/injectable.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/server_monitor_service.dart';
import 'package:vernet/utils/app_strings.dart';

@injectable
class NetworkScoreService {
  NetworkScoreService({
    required this.scanRepository,
    required this.deviceRepository,
    required this.scoreRepository,
  }) : serverMonitorService = ServerMonitorService();

  final ScanRepository scanRepository;
  final DeviceRepository deviceRepository;
  final ServerMonitorService serverMonitorService;
  final NetworkScoreRepository scoreRepository;

  static const _securityWeight = 0.25;
  static const _healthWeight = 0.25;
  static const _reliabilityWeight = 0.25;
  static const _speedWeight = 0.15;
  static const _vulnerabilitiesWeight = 0.10;

  Future<NetworkScore> computeScore({
    WifiInfo? liveWifiInfo,
    NetworkConnectionStatus? liveConnectivityStatus,
  }) async {
    final security = await _computeSecurityDimension();
    final health = _computeHealthDimension(
      wifiInfo: liveWifiInfo,
      connectivityStatus: liveConnectivityStatus,
    );
    final reliability = await _computeReliabilityDimension();
    final speed = await _computeSpeedDimension();
    final vulnerabilities = _computeVulnerabilitiesDimension(security);

    var overallScore = _computeWeightedAverage([
      _WeightedScore(security.value, _securityWeight),
      _WeightedScore(health.value, _healthWeight),
      _WeightedScore(reliability.value, _reliabilityWeight),
      _WeightedScore(speed.value, _speedWeight),
      _WeightedScore(vulnerabilities.value, _vulnerabilitiesWeight),
    ]);

    final metadata = <String, String>{};
    if (liveWifiInfo != null) {
      metadata['gateway'] = liveWifiInfo.gatewayIp;
      metadata['deviceIp'] = liveWifiInfo.ip;
    }

    // Apply staleness decay if score is old
    final cachedScore = await scoreRepository.loadLastScore();
    final stalenessInfo = _computeStalenessDecay(cachedScore);
    if (stalenessInfo.decay > 0) {
      overallScore = (overallScore - stalenessInfo.decay).clamp(0, 100);
      metadata['stalenessDecay'] = stalenessInfo.decay.toString();
      metadata['stalenessReason'] = stalenessInfo.reason;
      metadata['lastComputed'] =
          cachedScore?.computedAt.toIso8601String() ?? 'never';
    }

    final score = NetworkScore(
      overallScore: overallScore,
      computedAt: DateTime.now(),
      security: security,
      health: health,
      reliability: reliability,
      speed: speed,
      vulnerabilities: vulnerabilities,
      metadata: metadata,
    );

    await scoreRepository.saveScore(score);
    return score;
  }

  _StalenessInfo _computeStalenessDecay(NetworkScore? cachedScore) {
    if (cachedScore == null) {
      return const _StalenessInfo(decay: 0, reason: '');
    }

    final now = DateTime.now();
    final hoursSinceLastComputation =
        now.difference(cachedScore.computedAt).inHours;

    // Decay: 5 points per hour after 2 hours, max 30 points
    if (hoursSinceLastComputation <= 2) {
      return const _StalenessInfo(decay: 0, reason: '');
    }

    final decay = ((hoursSinceLastComputation - 2) * 5).clamp(0, 30);
    final reason = appStrings().scoreStaleReason(
      '$hoursSinceLastComputation',
      '$decay',
    );
    return _StalenessInfo(decay: decay, reason: reason);
  }

  Future<DimensionScore> _computeSecurityDimension() async {
    const name = 'Security';
    final l10n = appStrings();
    final factors = <String>[];
    var score = 100;

    try {
      final recentScans = await scanRepository.getRecentScans(limit: 5);
      if (recentScans.isEmpty) {
        return DimensionScore(
          name: name,
          value: 50,
          description: l10n.scoreSecurityNoScansDesc,
          factors: [
            l10n.scoreSecurityNoScans,
            l10n.scoreSecurityNoScansTip,
          ],
        );
      }

      final latestScan = recentScans.first;
      final devices = await deviceRepository.getListForScan(latestScan.id);

      var unknownDeviceCount = 0;
      for (final device in devices) {
        final hasMac =
            device.macAddress != null && device.macAddress!.isNotEmpty;
        final hasName =
            (device.hostMake != null && device.hostMake!.isNotEmpty) ||
                (device.mdnsDomainName != null &&
                    device.mdnsDomainName!.isNotEmpty);
        if (!hasMac && !hasName) {
          unknownDeviceCount++;
        }
      }

      if (unknownDeviceCount > 0) {
        final deduction = unknownDeviceCount * 5;
        score -= deduction;
        factors.add(l10n.scoreSecurityUnknownDevices(
            '$unknownDeviceCount', '$deduction'));
        factors.add(l10n.scoreSecurityUnknownTip);
      } else {
        factors.add(l10n.scoreSecurityAllIdentified('${devices.length}'));
      }

      if (latestScan.onGoing == true) {
        factors.add(l10n.scoreSecurityScanRunning);
      }

      score = score.clamp(0, 100);

      return DimensionScore(
        name: name,
        value: score,
        description: _securityDescription(score),
        factors: factors.isEmpty ? [l10n.scoreSecuritySecure] : factors,
      );
    } on Object {
      return DimensionScore(
        name: name,
        value: 50,
        description: l10n.scoreSecurityUnable,
        factors: [l10n.scoreSecurityError],
      );
    }
  }

  String _securityDescription(int score) {
    final l10n = appStrings();
    if (score >= 80) return l10n.scoreSecurityDescGood;
    if (score >= 60) return l10n.scoreSecurityDescConcerns;
    if (score >= 40) return l10n.scoreSecurityDescIssues;
    return l10n.scoreSecurityDescRisks;
  }

  DimensionScore _computeHealthDimension({
    WifiInfo? wifiInfo,
    NetworkConnectionStatus? connectivityStatus,
  }) {
    const name = 'Health';
    final l10n = appStrings();
    final factors = <String>[];
    var score = 0;

    if (wifiInfo == null) {
      return DimensionScore(
        name: name,
        value: 0,
        description: l10n.scoreHealthNoWifiDesc,
        factors: [l10n.scoreHealthNoWifi, l10n.scoreHealthNoWifiTip],
      );
    }

    if (wifiInfo.unknown || wifiInfo.ip == 'x.x.x.x') {
      return DimensionScore(
        name: name,
        value: 20,
        description: l10n.scoreHealthUnstableDesc,
        factors: [
          l10n.scoreHealthInvalidIp(wifiInfo.ip),
          l10n.scoreHealthUnstableNote,
          l10n.scoreHealthReconnectTip,
        ],
      );
    }

    score += 25;
    factors.add(l10n.scoreHealthValidIp(wifiInfo.ip));

    final signalLevel = wifiInfo.metrics.normalizedLevel;
    if (signalLevel >= 3) {
      score += 25;
      factors.add(
          l10n.scoreHealthStrongSignal(wifiInfo.metrics.quality.label(l10n)));
    } else if (signalLevel >= 2) {
      score += 15;
      factors.add(
          l10n.scoreHealthModerateSignal(wifiInfo.metrics.quality.label(l10n)));
      factors.add(l10n.scoreHealthStrongSignalTip);
    } else if (signalLevel >= 1) {
      score += 5;
      factors.add(
          l10n.scoreHealthWeakSignal(wifiInfo.metrics.quality.label(l10n)));
      factors.add(l10n.scoreHealthWeakSignalTip);
    } else {
      factors.add(l10n.scoreHealthNoSignal);
      factors.add(l10n.scoreHealthNoSignalTip);
    }

    if (wifiInfo.gatewayIp.isNotEmpty && wifiInfo.gatewayIp != '0.0.0.0') {
      score += 20;
      if (wifiInfo.isCustomGateway) {
        factors.add(l10n.scoreHealthCustomGateway(wifiInfo.gatewayIp));
      } else {
        factors.add(l10n.scoreHealthGateway(wifiInfo.gatewayIp));
      }
    } else {
      factors.add(l10n.scoreHealthNoGateway);
      factors.add(l10n.scoreHealthNoGatewayTip);
    }

    if (connectivityStatus != null) {
      if (connectivityStatus.isConnected) {
        score += 30;
        factors.add(l10n.scoreHealthInternetOn);
        if (connectivityStatus.latency != null) {
          final latencyMs = connectivityStatus.latency!.inMilliseconds;
          if (latencyMs < 100) {
            factors.add(l10n.scoreHealthLatencyLow('$latencyMs'));
          } else if (latencyMs < 300) {
            factors.add(l10n.scoreHealthLatencyModerate('$latencyMs'));
          } else {
            factors.add(l10n.scoreHealthLatencyHigh('$latencyMs'));
          }
        }
      } else if (connectivityStatus.isChecking) {
        score += 10;
        factors.add(l10n.scoreHealthChecking);
      } else {
        factors.add(l10n.scoreHealthNoInternet);
        factors.add(l10n.scoreHealthNoInternetTip);
      }
    } else {
      factors.add(l10n.scoreHealthStatusUnknown);
    }

    score = score.clamp(0, 100);

    return DimensionScore(
      name: name,
      value: score,
      description: _healthDescription(score),
      factors: factors,
    );
  }

  String _healthDescription(int score) {
    final l10n = appStrings();
    if (score >= 80) return l10n.scoreHealthDescExcellent;
    if (score >= 60) return l10n.scoreHealthDescGood;
    if (score >= 40) return l10n.scoreHealthDescAttention;
    return l10n.scoreHealthDescPoor;
  }

  Future<DimensionScore> _computeReliabilityDimension() async {
    const name = 'Reliability';
    final l10n = appStrings();
    final factors = <String>[];

    try {
      final monitors = await serverMonitorService.loadMonitors();
      if (monitors.isEmpty) {
        return DimensionScore(
          name: name,
          value: 0,
          description: l10n.scoreReliabilityNoMonitorsDesc,
          factors: [
            l10n.scoreReliabilityNoMonitors,
            l10n.scoreReliabilityAddRouter,
            l10n.scoreReliabilityAddInternet,
          ],
        );
      }

      // Check for required monitor types
      final hasRouterMonitor = monitors.any((m) =>
          m.type == ServerCheckType.icmp &&
          m.name.toLowerCase().contains('router'));
      final hasUpstreamMonitor = monitors.any((m) =>
          m.type == ServerCheckType.https || m.type == ServerCheckType.http);

      if (!hasRouterMonitor) {
        factors.add(l10n.scoreReliabilityMissingRouter);
      }
      if (!hasUpstreamMonitor) {
        factors.add(l10n.scoreReliabilityMissingInternet);
      }

      var totalUptimePercent = 0.0;
      var monitorCount = 0;

      for (final monitor in monitors) {
        final history = await serverMonitorService.loadHistory(monitor.id);
        if (history.isEmpty) continue;

        monitorCount++;
        final upCount = history.where((r) => r.isUp).length;
        final uptimePercent = (upCount / history.length) * 100;
        totalUptimePercent += uptimePercent;
      }

      if (monitorCount == 0) {
        return DimensionScore(
          name: name,
          value: 30,
          description: l10n.scoreReliabilityNoHistoryDesc,
          factors: [...factors, l10n.scoreReliabilityNoHistory],
        );
      }

      final avgUptime = totalUptimePercent / monitorCount;
      var score = avgUptime.round();

      // Cap score based on required monitor types
      if (!hasRouterMonitor && !hasUpstreamMonitor) {
        score = score > 50 ? 50 : score;
        factors.add(l10n.scoreReliabilityCap50);
      } else if (!hasRouterMonitor || !hasUpstreamMonitor) {
        score = score > 75 ? 75 : score;
        factors.add(l10n.scoreReliabilityCap75);
      }

      score = score.clamp(0, 100);
      factors.insert(
          0,
          l10n.scoreReliabilityUptime(
              avgUptime.toStringAsFixed(1), '$monitorCount'));

      return DimensionScore(
        name: name,
        value: score,
        description: _reliabilityDescription(score),
        factors: factors,
      );
    } on Object {
      return DimensionScore(
        name: name,
        value: 0,
        description: l10n.scoreReliabilityUnable,
        factors: [l10n.scoreReliabilityError],
      );
    }
  }

  String _reliabilityDescription(int score) {
    final l10n = appStrings();
    if (score >= 80) return l10n.scoreReliabilityDescExcellent;
    if (score >= 60) return l10n.scoreReliabilityDescGood;
    if (score >= 40) return l10n.scoreReliabilityDescInconsistent;
    return l10n.scoreReliabilityDescPoor;
  }

  Future<DimensionScore> _computeSpeedDimension() async {
    const name = 'Speed';
    final l10n = appStrings();
    final factors = <String>[];

    try {
      final snapshot = await scoreRepository.loadSpeedSnapshot();
      if (snapshot == null) {
        return DimensionScore(
          name: name,
          value: 30,
          description: l10n.scoreSpeedNoResultDesc,
          factors: [l10n.scoreSpeedNoResult, l10n.scoreSpeedNoResultTip],
        );
      }

      final downloadMbps = snapshot.downloadMbps;
      final uploadMbps = snapshot.uploadMbps;
      final latencyMs = snapshot.latencyMs;

      var score = 0;

      // Download speed scoring (max 30 points)
      if (downloadMbps >= 100) {
        score += 30;
        factors.add(
            l10n.scoreSpeedDownloadExcellent(downloadMbps.toStringAsFixed(1)));
      } else if (downloadMbps >= 50) {
        score += 25;
        factors
            .add(l10n.scoreSpeedDownloadGood(downloadMbps.toStringAsFixed(1)));
      } else if (downloadMbps >= 25) {
        score += 18;
        factors.add(
            l10n.scoreSpeedDownloadModerate(downloadMbps.toStringAsFixed(1)));
        factors.add(l10n.scoreSpeedHdTip);
      } else if (downloadMbps >= 10) {
        score += 10;
        factors
            .add(l10n.scoreSpeedDownloadSlow(downloadMbps.toStringAsFixed(1)));
        factors.add(l10n.scoreSpeedIspTip);
      } else {
        score += 4;
        factors.add(
            l10n.scoreSpeedDownloadVerySlow(downloadMbps.toStringAsFixed(1)));
        factors.add(l10n.scoreSpeedBackgroundTip);
      }

      // Upload speed scoring (max 15 points)
      if (uploadMbps >= 20) {
        score += 15;
        factors
            .add(l10n.scoreSpeedUploadExcellent(uploadMbps.toStringAsFixed(1)));
      } else if (uploadMbps >= 10) {
        score += 12;
        factors.add(l10n.scoreSpeedUploadGood(uploadMbps.toStringAsFixed(1)));
      } else if (uploadMbps >= 5) {
        score += 8;
        factors
            .add(l10n.scoreSpeedUploadModerate(uploadMbps.toStringAsFixed(1)));
        factors.add(l10n.scoreSpeedVideoCallTip);
      } else {
        score += 3;
        factors.add(l10n.scoreSpeedUploadSlow(uploadMbps.toStringAsFixed(1)));
        factors.add(l10n.scoreSpeedUploadLimitTip);
      }

      // Latency scoring (max 15 points)
      if (latencyMs < 20) {
        score += 15;
        factors
            .add(l10n.scoreSpeedLatencyExcellent(latencyMs.toStringAsFixed(0)));
      } else if (latencyMs < 50) {
        score += 12;
        factors.add(l10n.scoreSpeedLatencyGood(latencyMs.toStringAsFixed(0)));
      } else if (latencyMs < 100) {
        score += 8;
        factors
            .add(l10n.scoreSpeedLatencyModerate(latencyMs.toStringAsFixed(0)));
        factors.add(l10n.scoreSpeedLatencyTip);
      } else {
        score += 3;
        factors.add(l10n.scoreSpeedLatencyHigh(latencyMs.toStringAsFixed(0)));
        factors.add(l10n.scoreSpeedWiredTip);
      }

      // Ping data scoring (max 10 points)
      final pingSnapshot = await scoreRepository.loadPingSnapshot();
      if (pingSnapshot != null) {
        // Packet loss (max 5 points)
        if (pingSnapshot.packetLossPercent == 0) {
          score += 5;
          factors.add(l10n.scoreSpeedNoPacketLoss);
        } else if (pingSnapshot.packetLossPercent < 1) {
          score += 3;
          factors.add(l10n.scoreSpeedLossMinimal(
              pingSnapshot.packetLossPercent.toStringAsFixed(1)));
        } else if (pingSnapshot.packetLossPercent < 5) {
          score += 1;
          factors.add(l10n.scoreSpeedLossSome(
              pingSnapshot.packetLossPercent.toStringAsFixed(1)));
          factors.add(l10n.scoreSpeedWifiTip);
        } else {
          factors.add(l10n.scoreSpeedLossHigh(
              pingSnapshot.packetLossPercent.toStringAsFixed(1)));
          factors.add(l10n.scoreSpeedCongestionTip);
        }

        // Jitter (max 5 points)
        if (pingSnapshot.jitterMs != null) {
          final jitter = pingSnapshot.jitterMs!;
          if (jitter < 5) {
            score += 5;
            factors.add(l10n.scoreSpeedJitterStable(jitter.toStringAsFixed(1)));
          } else if (jitter < 15) {
            score += 3;
            factors.add(
                l10n.scoreSpeedJitterAcceptable(jitter.toStringAsFixed(1)));
          } else if (jitter < 30) {
            score += 1;
            factors
                .add(l10n.scoreSpeedJitterVariable(jitter.toStringAsFixed(1)));
            factors.add(l10n.scoreSpeedJitterVoiceTip);
          } else {
            factors
                .add(l10n.scoreSpeedJitterUnstable(jitter.toStringAsFixed(1)));
            factors.add(l10n.scoreSpeedJitterWiredTip);
          }
        }
      } else if (snapshot.packetLossPercent != null) {
        // Fallback to NDT7 packet loss if ping snapshot not available
        if (snapshot.packetLossPercent! == 0) {
          score += 5;
          factors.add(l10n.scoreSpeedNoLossMlab);
        } else if (snapshot.packetLossPercent! < 1) {
          score += 3;
          factors.add(l10n.scoreSpeedLossMinimalMlab(
              snapshot.packetLossPercent!.toStringAsFixed(1)));
        } else if (snapshot.packetLossPercent! < 5) {
          score += 1;
          factors.add(l10n.scoreSpeedLossSomeMlab(
              snapshot.packetLossPercent!.toStringAsFixed(1)));
        } else {
          factors.add(l10n.scoreSpeedLossHighMlab(
              snapshot.packetLossPercent!.toStringAsFixed(1)));
        }
      } else {
        // No ping data available - show missing points
        factors.add(l10n.scoreSpeedNoPingData);
        factors.add(l10n.scoreSpeedNoPingDataTip);
      }

      // Add test provider info
      if (snapshot.testProvider == 'mlab') {
        factors.add(l10n.scoreSpeedMeasuredMlab);
        if (snapshot.serverLocation != null) {
          factors.add(l10n.scoreSpeedServerAt(snapshot.serverLocation!));
        }
      }

      // Scale score from 70-point max to 100-point scale
      // Max possible: 30 (download) + 15 (upload) + 15 (latency) + 5 (packet loss) + 5 (jitter) = 70
      const maxPossibleScore = 70;
      score = ((score / maxPossibleScore) * 100).round();

      score = score.clamp(0, 100);

      return DimensionScore(
        name: name,
        value: score,
        description: _speedDescription(score),
        factors: factors,
      );
    } on Object {
      return DimensionScore(
        name: name,
        value: 30,
        description: l10n.scoreSpeedUnable,
        factors: [l10n.scoreSpeedError, l10n.scoreSpeedErrorTip],
      );
    }
  }

  String _speedDescription(int score) {
    final l10n = appStrings();
    if (score >= 80) return l10n.scoreSpeedDescExcellent;
    if (score >= 60) return l10n.scoreSpeedDescGood;
    if (score >= 40) return l10n.scoreSpeedDescModerate;
    return l10n.scoreSpeedDescImprove;
  }

  DimensionScore _computeVulnerabilitiesDimension(DimensionScore security) {
    const name = 'Vulnerabilities';
    final l10n = appStrings();

    if (security.value >= 95) {
      // Near-perfect security - minimal baseline risk
      return DimensionScore(
        name: name,
        value: 98,
        description: l10n.scoreVulnExcellentDesc,
        factors: [
          l10n.scoreVulnStrongPosture,
          l10n.scoreVulnAllIdentified,
          l10n.scoreVulnNoVulnerabilities,
          l10n.scoreVulnMinimalBaseline,
        ],
      );
    } else if (security.value >= 80) {
      // Good security - small baseline risk
      return DimensionScore(
        name: name,
        value: 95,
        description: l10n.scoreVulnLowDesc,
        factors: [
          l10n.scoreVulnStrongPosture,
          l10n.scoreVulnAllIdentified,
          l10n.scoreVulnNoVulnerabilities,
          l10n.scoreVulnSmallBaseline,
        ],
      );
    } else if (security.value >= 50) {
      return DimensionScore(
        name: name,
        value: 60,
        description: l10n.scoreVulnSomeDesc,
        factors: [
          l10n.scoreVulnModerateScore('${security.value}'),
          l10n.scoreVulnPartialIdentification,
          l10n.scoreVulnScanTip,
          l10n.scoreVulnReviewTip,
        ],
      );
    } else {
      return DimensionScore(
        name: name,
        value: 30,
        description: l10n.scoreVulnAttentionDesc,
        factors: [
          l10n.scoreVulnLowScore('${security.value}'),
          l10n.scoreVulnUnknownDevices,
          l10n.scoreVulnExposedServices,
          l10n.scoreVulnActionRequired,
          l10n.scoreVulnActionScan,
          l10n.scoreVulnActionVerify,
          l10n.scoreVulnActionPorts,
          l10n.scoreVulnActionTrust,
        ],
      );
    }
  }

  int _computeWeightedAverage(List<_WeightedScore> scores) {
    final totalWeight = scores.fold<double>(0, (sum, s) => sum + s.weight);
    if (totalWeight == 0) return 0;
    final weightedSum = scores.fold<double>(
      0,
      (sum, s) => sum + (s.score * s.weight),
    );
    return (weightedSum / totalWeight).round();
  }
}

class _WeightedScore {
  const _WeightedScore(this.score, this.weight);
  final int score;
  final double weight;
}

class _StalenessInfo {
  const _StalenessInfo({required this.decay, required this.reason});
  final int decay;
  final String reason;
}
