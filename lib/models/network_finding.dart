/// How much attention a [NetworkFinding] needs.
enum NetworkFindingSeverity { critical, warning, info }

/// What a [NetworkFinding] describes, independent of the language it is
/// rendered in.
enum NetworkFindingCode {
  telnet,
  ftp,
  smb,
  netbios,
  tftp,
  rdp,
  vnc,
  database,
  snmp,
  unencryptedWeb,
  outdatedSsh,
  alternateService,
}

/// One security issue found on a device's open ports.
///
/// The analyzer fills [title] and [description] in the language active when it
/// ran; the enum, port and service keep the finding usable for grouping and
/// scoring without depending on that text.
class NetworkFinding {
  const NetworkFinding({
    required this.code,
    required this.severity,
    required this.port,
    required this.service,
    required this.title,
    required this.description,
    this.deviceAddress,
  });

  final NetworkFindingCode code;
  final NetworkFindingSeverity severity;
  final int port;
  final String service;
  final String title;
  final String description;
  final String? deviceAddress;

  /// Critical first, then warning, then info; within one severity the lower
  /// port comes first so a list keeps a stable order between scans.
  static int compare(NetworkFinding left, NetworkFinding right) {
    final bySeverity = left.severity.index.compareTo(right.severity.index);
    if (bySeverity != 0) return bySeverity;
    return left.port.compareTo(right.port);
  }

  static List<NetworkFinding> sorted(Iterable<NetworkFinding> findings) =>
      findings.toList()..sort(compare);
}
