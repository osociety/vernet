import 'package:injectable/injectable.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/server_monitor_service.dart';

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
      metadata['lastComputed'] = cachedScore?.computedAt.toIso8601String() ?? 'never';
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
    final hoursSinceLastComputation = now.difference(cachedScore.computedAt).inHours;

    // Decay: 5 points per hour after 2 hours, max 30 points
    if (hoursSinceLastComputation <= 2) {
      return const _StalenessInfo(decay: 0, reason: '');
    }

    final decay = ((hoursSinceLastComputation - 2) * 5).clamp(0, 30);
    final reason = 'Score is ${hoursSinceLastComputation}h old (-$decay points for staleness)';
    return _StalenessInfo(decay: decay, reason: reason);
  }

  Future<DimensionScore> _computeSecurityDimension() async {
    const name = 'Security';
    final factors = <String>[];
    var score = 100;

    try {
      final recentScans = await scanRepository.getRecentScans(limit: 5);
      if (recentScans.isEmpty) {
        return const DimensionScore(
          name: name,
          value: 50,
          description: 'Run a network scan to assess security',
          factors: [
            '✗ No network scans found -50 points',
            'Tip: Run a network scan from the home screen to discover devices and assess security',
          ],
        );
      }

      final latestScan = recentScans.first;
      final devices = await deviceRepository.getListForScan(latestScan.id);

      var unknownDeviceCount = 0;
      for (final device in devices) {
        final hasMac = device.macAddress != null && device.macAddress!.isNotEmpty;
        final hasName = (device.hostMake != null && device.hostMake!.isNotEmpty) ||
            (device.mdnsDomainName != null && device.mdnsDomainName!.isNotEmpty);
        if (!hasMac && !hasName) {
          unknownDeviceCount++;
        }
      }

      if (unknownDeviceCount > 0) {
        final deduction = unknownDeviceCount * 5;
        score -= deduction;
        factors.add('✗ $unknownDeviceCount unidentified device(s) on network (-$deduction points)');
        factors.add('Tip: Identify unknown devices or run network scan to refresh device list');
      } else {
        factors.add('✓ All ${devices.length} device(s) identified');
      }

      if (latestScan.onGoing == true) {
        factors.add('~ Scan in progress - results may be incomplete');
      }

      score = score.clamp(0, 100);

      return DimensionScore(
        name: name,
        value: score,
        description: _securityDescription(score),
        factors: factors.isEmpty ? ['✓ All devices identified - network appears secure'] : factors,
      );
    } on Object {
      return const DimensionScore(
        name: name,
        value: 50,
        description: 'Unable to assess security',
        factors: ['✗ Error reading scan data - try running a new network scan'],
      );
    }
  }

  String _securityDescription(int score) {
    if (score >= 80) return 'Your network security looks good';
    if (score >= 60) return 'Some security concerns detected';
    if (score >= 40) return 'Security issues need attention';
    return 'Significant security risks detected';
  }

  DimensionScore _computeHealthDimension({
    WifiInfo? wifiInfo,
    NetworkConnectionStatus? connectivityStatus,
  }) {
    const name = 'Health';
    final factors = <String>[];
    var score = 0;

    if (wifiInfo == null) {
      return const DimensionScore(
        name: name,
        value: 0,
        description: 'Connect to Wi-Fi to assess network health',
        factors: [
          'No Wi-Fi connection detected',
          'Tip: Connect to a Wi-Fi network to see health score',
        ],
      );
    }

    if (wifiInfo.unknown || wifiInfo.ip == 'x.x.x.x') {
      return DimensionScore(
        name: name,
        value: 20,
        description: 'Wi-Fi connection unstable',
        factors: [
          'Invalid IP address assigned (${wifiInfo.ip})',
          'Connection may be unstable or not fully established',
          'Tip: Try disconnecting and reconnecting to Wi-Fi',
        ],
      );
    }

    score += 25;
    factors.add('✓ Valid IP address (${wifiInfo.ip})');

    final signalLevel = wifiInfo.metrics.normalizedLevel;
    if (signalLevel >= 3) {
      score += 25;
      factors.add('✓ Strong Wi-Fi signal (${wifiInfo.metrics.statusMessage})');
    } else if (signalLevel >= 2) {
      score += 15;
      factors.add('~ Moderate Wi-Fi signal (${wifiInfo.metrics.statusMessage}) -10 points');
      factors.add('Tip: Move closer to router or reduce obstacles for better signal');
    } else if (signalLevel >= 1) {
      score += 5;
      factors.add('~ Weak Wi-Fi signal (${wifiInfo.metrics.statusMessage}) -20 points');
      factors.add('Tip: Move closer to router or check for interference');
    } else {
      factors.add('✗ Very weak or no signal -25 points');
      factors.add('Tip: Check Wi-Fi connection and move closer to router');
    }

    if (wifiInfo.gatewayIp.isNotEmpty && wifiInfo.gatewayIp != '0.0.0.0') {
      score += 20;
      if (wifiInfo.isCustomGateway) {
        factors.add('✓ Custom gateway configured (${wifiInfo.gatewayIp})');
      } else {
        factors.add('✓ Gateway reachable (${wifiInfo.gatewayIp})');
      }
    } else {
      factors.add('✗ No gateway detected -20 points');
      factors.add('Tip: Check router connection and network settings');
    }

    if (connectivityStatus != null) {
      if (connectivityStatus.isConnected) {
        score += 30;
        factors.add('✓ Internet connection active');
        if (connectivityStatus.latency != null) {
          final latencyMs = connectivityStatus.latency!.inMilliseconds;
          if (latencyMs < 100) {
            factors.add('✓ Low latency (${latencyMs}ms) - excellent for gaming/video calls');
          } else if (latencyMs < 300) {
            factors.add('~ Moderate latency (${latencyMs}ms) - acceptable for most uses');
          } else {
            factors.add('~ High latency (${latencyMs}ms) - may affect real-time applications');
          }
        }
      } else if (connectivityStatus.isChecking) {
        score += 10;
        factors.add('~ Checking internet connectivity...');
      } else {
        factors.add('✗ No internet connection -30 points');
        factors.add('Tip: Check router and modem, verify internet service is active');
      }
    } else {
      factors.add('? Internet status unknown');
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
    if (score >= 80) return 'Network health is excellent';
    if (score >= 60) return 'Network health is good';
    if (score >= 40) return 'Network health needs attention';
    return 'Network health is poor';
  }

  Future<DimensionScore> _computeReliabilityDimension() async {
    const name = 'Reliability';
    final factors = <String>[];

    try {
      final monitors = await serverMonitorService.loadMonitors();
      if (monitors.isEmpty) {
        return const DimensionScore(
          name: name,
          value: 0,
          description: 'Add monitors to track reliability',
          factors: [
            '✗ No monitors configured -100 points',
            'Add ICMP monitor to local router',
            'Add HTTPS monitor to internet server (e.g., google.com)',
          ],
        );
      }

      // Check for required monitor types
      final hasRouterMonitor = monitors.any((m) => 
        m.type == ServerCheckType.icmp && 
        m.name.toLowerCase().contains('router')
      );
      final hasUpstreamMonitor = monitors.any((m) => 
        m.type == ServerCheckType.https || 
        m.type == ServerCheckType.http
      );

      if (!hasRouterMonitor) {
        factors.add('✗ Missing: ICMP monitor to local router');
      }
      if (!hasUpstreamMonitor) {
        factors.add('✗ Missing: HTTPS monitor to internet server');
      }

      var totalUptimePercent = 0.0;
      var totalLatencyMs = 0;
      var latencyCount = 0;
      var monitorCount = 0;

      for (final monitor in monitors) {
        final history = await serverMonitorService.loadHistory(monitor.id);
        if (history.isEmpty) continue;

        monitorCount++;
        final upCount = history.where((r) => r.isUp).length;
        final uptimePercent = (upCount / history.length) * 100;
        totalUptimePercent += uptimePercent;

        final latencies = history
            .where((r) => r.isUp && r.latency != null)
            .map((r) => r.latency!.inMilliseconds)
            .toList();
        if (latencies.isNotEmpty) {
          totalLatencyMs += latencies.reduce((a, b) => a + b) ~/ latencies.length;
          latencyCount++;
        }
      }

      if (monitorCount == 0) {
        return DimensionScore(
          name: name,
          value: 30,
          description: 'No monitoring history yet',
          factors: [
            ...factors,
            '~ Monitors configured but no data collected yet -70 points',
          ],
        );
      }

      final avgUptime = totalUptimePercent / monitorCount;
      var score = (avgUptime * 0.7).round();

      if (latencyCount > 0) {
        final avgLatency = totalLatencyMs ~/ latencyCount;
        if (avgLatency < 100) {
          score += 30;
          factors.add('✓ Low average latency (${avgLatency}ms)');
        } else if (avgLatency < 300) {
          score += 15;
          factors.add('~ Moderate average latency (${avgLatency}ms) -15 points');
        } else {
          score += 5;
          factors.add('~ High average latency (${avgLatency}ms) -25 points');
        }
      }

      // Cap score based on required monitor types
      if (!hasRouterMonitor && !hasUpstreamMonitor) {
        score = score > 50 ? 50 : score;
        factors.add('✗ Score capped at 50: Add both router and internet monitors');
      } else if (!hasRouterMonitor || !hasUpstreamMonitor) {
        score = score > 75 ? 75 : score;
        factors.add('✗ Score capped at 75: Add missing monitor type for full score');
      }

      score = score.clamp(0, 100);
      factors.insert(0, '✓ ${avgUptime.toStringAsFixed(1)}% uptime across $monitorCount monitor(s)');

      return DimensionScore(
        name: name,
        value: score,
        description: _reliabilityDescription(score),
        factors: factors,
      );
    } on Object {
      return const DimensionScore(
        name: name,
        value: 0,
        description: 'Unable to assess reliability',
        factors: ['✗ Error reading monitor data'],
      );
    }
  }

  String _reliabilityDescription(int score) {
    if (score >= 80) return 'Network reliability is excellent';
    if (score >= 60) return 'Network reliability is good';
    if (score >= 40) return 'Network reliability is inconsistent';
    return 'Network reliability is poor';
  }

  Future<DimensionScore> _computeSpeedDimension() async {
    const name = 'Speed';
    final factors = <String>[];

    try {
      final snapshot = await scoreRepository.loadSpeedSnapshot();
      if (snapshot == null) {
        return const DimensionScore(
          name: name,
          value: 30,
          description: 'Run a speed test to assess performance',
          factors: [
            'No speed test results found',
            'Tip: Run a speed test from the network score page to measure your connection',
          ],
        );
      }

      final downloadMbps = snapshot.downloadMbps;
      final uploadMbps = snapshot.uploadMbps;
      final latencyMs = snapshot.latencyMs;

      var score = 0;

      // Download speed scoring (max 30 points)
      if (downloadMbps >= 100) {
        score += 30;
        factors.add('✓ Download: ${downloadMbps.toStringAsFixed(1)} Mbps (excellent)');
      } else if (downloadMbps >= 50) {
        score += 25;
        factors.add('✓ Download: ${downloadMbps.toStringAsFixed(1)} Mbps (good)');
      } else if (downloadMbps >= 25) {
        score += 18;
        factors.add('~ Download: ${downloadMbps.toStringAsFixed(1)} Mbps (moderate) -12 points');
        factors.add('Tip: For HD streaming, aim for 25+ Mbps');
      } else if (downloadMbps >= 10) {
        score += 10;
        factors.add('~ Download: ${downloadMbps.toStringAsFixed(1)} Mbps (slow) -20 points');
        factors.add('Tip: Contact ISP about upgrading your plan');
      } else {
        score += 4;
        factors.add('✗ Download: ${downloadMbps.toStringAsFixed(1)} Mbps (very slow) -26 points');
        factors.add('Tip: Check for background downloads, restart router, or contact ISP');
      }

      // Upload speed scoring (max 15 points)
      if (uploadMbps >= 20) {
        score += 15;
        factors.add('✓ Upload: ${uploadMbps.toStringAsFixed(1)} Mbps (excellent)');
      } else if (uploadMbps >= 10) {
        score += 12;
        factors.add('✓ Upload: ${uploadMbps.toStringAsFixed(1)} Mbps (good)');
      } else if (uploadMbps >= 5) {
        score += 8;
        factors.add('~ Upload: ${uploadMbps.toStringAsFixed(1)} Mbps (moderate) -7 points');
        factors.add('Tip: For video calls, aim for 5+ Mbps upload');
      } else {
        score += 3;
        factors.add('✗ Upload: ${uploadMbps.toStringAsFixed(1)} Mbps (slow) -12 points');
        factors.add('Tip: Limit uploads during important calls or contact ISP');
      }

      // Latency scoring (max 15 points)
      if (latencyMs < 20) {
        score += 15;
        factors.add('✓ Latency: ${latencyMs.toStringAsFixed(0)}ms (excellent for gaming)');
      } else if (latencyMs < 50) {
        score += 12;
        factors.add('✓ Latency: ${latencyMs.toStringAsFixed(0)}ms (good)');
      } else if (latencyMs < 100) {
        score += 8;
        factors.add('~ Latency: ${latencyMs.toStringAsFixed(0)}ms (moderate) -7 points');
        factors.add('Tip: High latency affects gaming and video calls');
      } else {
        score += 3;
        factors.add('✗ Latency: ${latencyMs.toStringAsFixed(0)}ms (high) -12 points');
        factors.add('Tip: Use wired connection, reduce network congestion, or contact ISP');
      }

      // Ping data scoring (max 10 points)
      final pingSnapshot = await scoreRepository.loadPingSnapshot();
      if (pingSnapshot != null) {
        // Packet loss (max 5 points)
        if (pingSnapshot.packetLossPercent == 0) {
          score += 5;
          factors.add('✓ No packet loss');
        } else if (pingSnapshot.packetLossPercent < 1) {
          score += 3;
          factors.add('~ Minimal packet loss (${pingSnapshot.packetLossPercent.toStringAsFixed(1)}%)');
        } else if (pingSnapshot.packetLossPercent < 5) {
          score += 1;
          factors.add('~ Some packet loss (${pingSnapshot.packetLossPercent.toStringAsFixed(1)}%) -4 points');
          factors.add('Tip: Check Wi-Fi signal strength and router placement');
        } else {
          factors.add('✗ High packet loss (${pingSnapshot.packetLossPercent.toStringAsFixed(1)}%) -5 points');
          factors.add('Tip: Network congestion or hardware issues - restart router');
        }

        // Jitter (max 5 points)
        if (pingSnapshot.jitterMs != null) {
          final jitter = pingSnapshot.jitterMs!;
          if (jitter < 5) {
            score += 5;
            factors.add('✓ Jitter: ${jitter.toStringAsFixed(1)}ms (stable connection)');
          } else if (jitter < 15) {
            score += 3;
            factors.add('✓ Jitter: ${jitter.toStringAsFixed(1)}ms (acceptable)');
          } else if (jitter < 30) {
            score += 1;
            factors.add('~ Jitter: ${jitter.toStringAsFixed(1)}ms (variable) -4 points');
            factors.add('Tip: High jitter affects video/voice quality');
          } else {
            factors.add('✗ Jitter: ${jitter.toStringAsFixed(1)}ms (unstable) -5 points');
            factors.add('Tip: Use wired connection or reduce network congestion');
          }
        }
      } else if (snapshot.packetLossPercent != null) {
        // Fallback to NDT7 packet loss if ping snapshot not available
        if (snapshot.packetLossPercent! == 0) {
          score += 5;
          factors.add('✓ No packet loss (M-Lab)');
        } else if (snapshot.packetLossPercent! < 1) {
          score += 3;
          factors.add('~ Minimal packet loss (${snapshot.packetLossPercent!.toStringAsFixed(1)}%, M-Lab)');
        } else if (snapshot.packetLossPercent! < 5) {
          score += 1;
          factors.add('~ Some packet loss (${snapshot.packetLossPercent!.toStringAsFixed(1)}%, M-Lab) -4 points');
        } else {
          factors.add('✗ High packet loss (${snapshot.packetLossPercent!.toStringAsFixed(1)}%, M-Lab) -5 points');
        }
      }

      // Add test provider info
      if (snapshot.testProvider == 'mlab') {
        factors.add('ℹ Measured via M-Lab NDT7 protocol');
        if (snapshot.serverLocation != null) {
          factors.add('📍 Server: ${snapshot.serverLocation}');
        }
      }

      score = score.clamp(0, 100);

      return DimensionScore(
        name: name,
        value: score,
        description: _speedDescription(score),
        factors: factors,
      );
    } on Object {
      return const DimensionScore(
        name: name,
        value: 30,
        description: 'Unable to assess speed',
        factors: [
          'Error reading speed data',
          'Tip: Try running a new speed test',
        ],
      );
    }
  }

  String _speedDescription(int score) {
    if (score >= 80) return 'Network speed is excellent';
    if (score >= 60) return 'Network speed is good';
    if (score >= 40) return 'Network speed is moderate';
    return 'Network speed needs improvement';
  }

  DimensionScore _computeVulnerabilitiesDimension(DimensionScore security) {
    const name = 'Vulnerabilities';

    if (security.value >= 95) {
      // Near-perfect security - minimal baseline risk
      return const DimensionScore(
        name: name,
        value: 98,
        description: 'Excellent security posture',
        factors: [
          '✓ Strong security posture detected',
          '✓ All network devices identified',
          '✓ No obvious vulnerabilities found',
          '~ Minimal baseline risk: -2 points (theoretical)',
        ],
      );
    } else if (security.value >= 80) {
      // Good security - small baseline risk
      return const DimensionScore(
        name: name,
        value: 95,
        description: 'Low vulnerability risk',
        factors: [
          '✓ Strong security posture detected',
          '✓ All network devices identified',
          '✓ No obvious vulnerabilities found',
          '~ Small baseline risk: -5 points (theoretical)',
        ],
      );
    } else if (security.value >= 50) {
      return DimensionScore(
        name: name,
        value: 60,
        description: 'Some vulnerabilities detected',
        factors: [
          '~ Moderate security score (${security.value}/100) -35 points',
          '~ Some devices on network not fully identified',
          'Tip: Run a network scan to identify all devices',
          "Tip: Review unknown devices and verify they're authorized",
        ],
      );
    } else {
      return DimensionScore(
        name: name,
        value: 30,
        description: 'Vulnerabilities require attention',
        factors: [
          '✗ Low security score (${security.value}/100) -65 points',
          '✗ Unknown devices detected on network',
          '✗ Potential exposed services',
          'Action required:',
          '• Run a network scan immediately to discover all devices',
          '• Identify and verify all unknown devices',
          '• Run a port scan to check for exposed services',
          '• Consider enabling device trust features',
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
