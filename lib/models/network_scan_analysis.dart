import 'package:vernet/models/network_finding.dart';

/// One flagged service from a scan, without the localized title.
///
/// The score is computed in services, but a caller can hand in the analysis of
/// a scan that just finished. Keeping only the code-independent fields lets the
/// service word the breakdown in whatever language is active when it renders.
class NetworkServiceFinding {
  const NetworkServiceFinding({
    required this.severity,
    required this.port,
    required this.service,
    this.deviceAddress,
  });

  final NetworkFindingSeverity severity;
  final int port;
  final String service;
  final String? deviceAddress;

  int get deduction => switch (severity) {
        NetworkFindingSeverity.critical =>
          NetworkScanAnalysis.criticalDeduction,
        NetworkFindingSeverity.warning => NetworkScanAnalysis.warningDeduction,
        NetworkFindingSeverity.info => NetworkScanAnalysis.infoDeduction,
      };
}

/// What the network score needs to know about a scan.
///
/// Built either from the stored scan or from the live rows a host scan just
/// produced, so the same numbers feed the score whichever path asked.
class NetworkScanAnalysis {
  const NetworkScanAnalysis({
    required this.deviceCount,
    required this.unidentifiedDeviceCount,
    required this.untrustedDeviceCount,
    required this.exposedServiceCount,
    required this.findings,
    this.scanInProgress = false,
  });

  static const int criticalDeduction = 25;
  static const int warningDeduction = 10;
  static const int infoDeduction = 3;

  /// Most points service hygiene can take off, so a network that exposes one
  /// risky service among many still reads as mostly clean.
  static const int maximumHygieneDeduction = 20;

  final int deviceCount;
  final int unidentifiedDeviceCount;
  final int untrustedDeviceCount;

  /// Open ports seen across all devices, flagged or not.
  final int exposedServiceCount;

  /// One entry per flagged service, worst first.
  final List<NetworkServiceFinding> findings;

  final bool scanInProgress;

  int get postureDeduction => findings.fold(
        0,
        (total, finding) => total + finding.deduction,
      );

  int get riskyServiceCount => findings.length;

  int get riskyServicePercent => exposedServiceCount == 0
      ? 0
      : ((riskyServiceCount / exposedServiceCount) * 100).round();

  int get hygieneDeduction => exposedServiceCount == 0
      ? 0
      : ((riskyServiceCount / exposedServiceCount) * maximumHygieneDeduction)
          .round();

  /// The vulnerabilities dimension after both the finding severity and the
  /// share of risky services are taken off a perfect hundred.
  int get vulnerabilityScore =>
      (100 - postureDeduction - hygieneDeduction).clamp(0, 100);
}
