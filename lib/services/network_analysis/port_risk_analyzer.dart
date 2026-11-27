import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/network_finding.dart';

/// Oldest OpenSSH release Vernet treats as current.
///
/// This is a product baseline, not a CVE claim: 8.0 dates from 2019, so a
/// server still advertising something older has missed years of hardening.
const (int, int) recommendedOpenSshVersion = (8, 0);

/// A well-known port and the risk of leaving it reachable.
class PortRiskRule {
  const PortRiskRule(this.port, this.service, this.severity, this.code);

  final int port;
  final String service;
  final NetworkFindingSeverity severity;
  final NetworkFindingCode code;
}

/// Turns open ports into findings using a local rule table.
///
/// Everything here is pure: the host scan stores port numbers, and no request
/// leaves the device to decide what an open port means.
class PortRiskAnalyzer {
  const PortRiskAnalyzer._();

  /// Ports whose service is risky to expose on the local network, worst first.
  ///
  /// A host scan is LAN-only, so SMB and NetBIOS are warnings rather than the
  /// critical they would be on an internet-facing host.
  static const List<PortRiskRule> rules = [
    PortRiskRule(
      23,
      'Telnet',
      NetworkFindingSeverity.critical,
      NetworkFindingCode.telnet,
    ),
    PortRiskRule(
      20,
      'FTP',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.ftp,
    ),
    PortRiskRule(
      21,
      'FTP',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.ftp,
    ),
    PortRiskRule(
      69,
      'TFTP',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.tftp,
    ),
    PortRiskRule(
      139,
      'NetBIOS',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.netbios,
    ),
    PortRiskRule(
      445,
      'SMB',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.smb,
    ),
    PortRiskRule(
      3389,
      'RDP',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.rdp,
    ),
    PortRiskRule(
      5900,
      'VNC',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.vnc,
    ),
    PortRiskRule(
      3306,
      'MySQL',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.database,
    ),
    PortRiskRule(
      5432,
      'PostgreSQL',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.database,
    ),
    PortRiskRule(
      6379,
      'Redis',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.database,
    ),
    PortRiskRule(
      27017,
      'MongoDB',
      NetworkFindingSeverity.warning,
      NetworkFindingCode.database,
    ),
    PortRiskRule(
      161,
      'SNMP',
      NetworkFindingSeverity.info,
      NetworkFindingCode.snmp,
    ),
    PortRiskRule(
      80,
      'HTTP',
      NetworkFindingSeverity.info,
      NetworkFindingCode.unencryptedWeb,
    ),
  ];

  /// Ports that commonly carry a service on a number that is not its default.
  ///
  /// The scan only reports numbers, so these are worded as possibilities; a
  /// banner read on each one would cost more than the hint is worth.
  static const Map<int, String> alternatePorts = {
    2121: 'FTP',
    2222: 'SSH',
    2323: 'Telnet',
    8080: 'HTTP',
    8443: 'HTTPS',
  };

  static List<int> parsePorts(String? openPorts) {
    if (openPorts == null || openPorts.isEmpty) return const [];
    return openPorts
        .split(',')
        .map((port) => int.tryParse(port.trim()))
        .whereType<int>()
        .where((port) => port > 0 && port <= 65535)
        .toList();
  }

  /// Findings for [ports], with [sshVersion] being a banner such as
  /// `SSH-2.0-OpenSSH_7.4p1` when one could be read.
  static List<NetworkFinding> analyze(
    Iterable<int> ports, {
    required AppLocalizations l10n,
    String? sshVersion,
    String? deviceAddress,
  }) {
    final openPorts = ports
        .where((port) => port > 0 && port <= 65535)
        .toSet()
        .toList()
      ..sort();
    final findings = <NetworkFinding>[];

    for (final port in openPorts) {
      final alternate = alternatePorts[port];
      if (alternate != null) {
        findings.add(
          NetworkFinding(
            code: NetworkFindingCode.alternateService,
            severity: NetworkFindingSeverity.info,
            port: port,
            service: alternate,
            title: l10n.securityFindingAlternateTitle(alternate),
            description: l10n.securityFindingAlternateBody('$port', alternate),
            deviceAddress: deviceAddress,
          ),
        );
      }

      final rule = _ruleFor(port);
      if (rule != null) {
        findings.add(_findingFor(rule, l10n, deviceAddress));
      }
    }

    if (openPorts.contains(22) && sshVersion != null) {
      final version = OpenSshVersion.parse(sshVersion);
      if (version != null && version.isOlderThan(recommendedOpenSshVersion)) {
        findings.add(
          NetworkFinding(
            code: NetworkFindingCode.outdatedSsh,
            severity: NetworkFindingSeverity.warning,
            port: 22,
            service: 'SSH',
            title: l10n.securityFindingSshOutdatedTitle,
            description: l10n.securityFindingSshOutdatedBody(
              version.label,
              _formatVersion(recommendedOpenSshVersion),
            ),
            deviceAddress: deviceAddress,
          ),
        );
      }
    }

    return NetworkFinding.sorted(findings);
  }

  static PortRiskRule? _ruleFor(int port) {
    for (final rule in rules) {
      if (rule.port == port) return rule;
    }
    return null;
  }

  static NetworkFinding _findingFor(
    PortRiskRule rule,
    AppLocalizations l10n,
    String? deviceAddress,
  ) {
    final text = switch (rule.code) {
      NetworkFindingCode.telnet => (
          l10n.securityFindingTelnetTitle,
          l10n.securityFindingTelnetBody,
        ),
      NetworkFindingCode.ftp => (
          l10n.securityFindingFtpTitle,
          l10n.securityFindingFtpBody,
        ),
      NetworkFindingCode.smb => (
          l10n.securityFindingSmbTitle,
          l10n.securityFindingSmbBody,
        ),
      NetworkFindingCode.netbios => (
          l10n.securityFindingNetbiosTitle,
          l10n.securityFindingNetbiosBody,
        ),
      NetworkFindingCode.tftp => (
          l10n.securityFindingTftpTitle,
          l10n.securityFindingTftpBody,
        ),
      NetworkFindingCode.rdp => (
          l10n.securityFindingRdpTitle,
          l10n.securityFindingRdpBody,
        ),
      NetworkFindingCode.vnc => (
          l10n.securityFindingVncTitle,
          l10n.securityFindingVncBody,
        ),
      NetworkFindingCode.database => (
          l10n.securityFindingDatabaseTitle(rule.service),
          l10n.securityFindingDatabaseBody,
        ),
      NetworkFindingCode.snmp => (
          l10n.securityFindingSnmpTitle,
          l10n.securityFindingSnmpBody,
        ),
      NetworkFindingCode.unencryptedWeb => (
          l10n.securityFindingWebTitle,
          l10n.securityFindingWebBody,
        ),
      NetworkFindingCode.outdatedSsh ||
      NetworkFindingCode.alternateService =>
        throw StateError('${rule.code} is built from its own branch'),
    };
    return NetworkFinding(
      code: rule.code,
      severity: rule.severity,
      port: rule.port,
      service: rule.service,
      title: text.$1,
      description: text.$2,
      deviceAddress: deviceAddress,
    );
  }

  static String _formatVersion((int, int) version) =>
      'OpenSSH ${version.$1}.${version.$2}';
}

/// The OpenSSH version an SSH banner advertises.
class OpenSshVersion {
  const OpenSshVersion(this.major, this.minor);

  final int major;
  final int minor;

  /// Reads `OpenSSH_7.4p1`, `OpenSSH-9.6` and equivalent spellings out of a
  /// banner line; anything else, such as Dropbear, returns null.
  static OpenSshVersion? parse(String banner) {
    final match = RegExp(r'OpenSSH[_-](\d+)\.(\d+)').firstMatch(banner);
    if (match == null) return null;
    return OpenSshVersion(
        int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  bool isOlderThan((int, int) version) =>
      major < version.$1 || (major == version.$1 && minor < version.$2);

  String get label => 'OpenSSH $major.$minor';
}
