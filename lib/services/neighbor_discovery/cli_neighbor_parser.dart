import 'package:vernet/models/neighbor_info.dart';

/// Parses `show cdp neighbors detail` and `show lldp neighbors detail` text.
class CliNeighborParser {
  static List<NeighborInfo> parse(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final results = <NeighborInfo>[];
    if (normalized.contains(
          RegExp(
            r'Chassis\s*(?:id|Id|Type)|System Name|SysName|Local Intf',
            caseSensitive: false,
          ),
        )) {
      results.addAll(_parseLldp(normalized));
    }
    if (normalized.contains(RegExp('Device ID', caseSensitive: false))) {
      results.addAll(_parseCdp(normalized));
    }
    if (results.isNotEmpty) {
      return results;
    }
    final cdp = _parseCdp(normalized);
    if (cdp.isNotEmpty) return cdp;
    return _parseLldp(normalized);
  }

  static List<NeighborInfo> _parseCdp(String text) {
    final blocks = text.split(
      RegExp(r'-{5,}|\n\s*\n|(?:\n|^)(?=Device ID:)', caseSensitive: false),
    );
    final results = <NeighborInfo>[];
    for (final block in blocks) {
      if (!block.contains(RegExp('Device ID', caseSensitive: false))) {
        continue;
      }
      results.add(
        NeighborInfo(
          protocol: NeighborProtocol.cdp,
          deviceId: _field(block, r'Device ID:\s*(.+)'),
          sysName: _field(block, r'Device ID:\s*(.+)'),
          managementIp: _field(
            block,
            r'(?:IP address|Management address(?:es)?(?:\s*\(IPv4\))?):\s*(?:IP address:\s*)?([0-9.]+)',
          ),
          localPort: _field(
            block,
            r'(?:Interface|Local Intrfce):\s*([^,\n]+)',
          ),
          remotePort: _field(
            block,
            r'(?:Port ID(?:\s*\(outgoing port\))?):\s*(\S+)',
          ),
          platform: _field(block, r'Platform:\s*([^,\n]+)'),
          vlan: _field(block, r'Native VLAN:\s*(\d+)'),
          speedDuplex: _duplex(block),
        ),
      );
    }
    return results;
  }

  static List<NeighborInfo> _parseLldp(String text) {
    final hasLocalIntf = text.contains(
      RegExp(
        r'Local (?:Intf|Interface|Port(?:\s*id)?)\s*:',
        caseSensitive: false,
      ),
    );
    final splitPattern = hasLocalIntf
        ? r'-{5,}|\n\s*\n|(?:\n|^)(?=Local (?:Intf|Interface|Port(?:\s*id)?)\s*:)'
        : r'-{5,}|\n\s*\n|(?:\n|^)(?=Chassis\s*(?:id|Id|Type)\s*:)';
    final blocks = text.split(RegExp(splitPattern, caseSensitive: false));
    final results = <NeighborInfo>[];
    for (final block in blocks) {
      if (!block.contains(
        RegExp(
          r'Chassis\s*(?:id|Id|Type)|System Name|SysName',
          caseSensitive: false,
        ),
      )) {
        continue;
      }
      final duplex = _field(block, r'Duplex:\s*(\S+)') ??
          _field(block, r'Physical media capabilities:\s*([^\r\n]+)') ??
          _field(block, r'Media Attachment Unit type:\s*([^\r\n]+)');
      results.add(
        NeighborInfo(
          protocol: NeighborProtocol.lldp,
          deviceId: _field(block, r'Chassis\s*(?:id|Id):\s*(.+)'),
          sysName: _field(block, r'(?:System Name|SysName):\s*(.+)'),
          managementIp: _field(
            block,
            r'(?:Management Address(?:es)?:\s*(?:(?:IP|IPv4):\s*)?|Management IP:\s*|IPv4:\s*)([0-9.]+)',
          ),
          localPort: _field(
            block,
            r'Local (?:Intf|Interface|Port(?:\s*id)?)\s*:\s*(\S+)',
          ),
          remotePort: _field(
            block,
            r'(?:Port (?:id|info|Description)|PortId):\s*(\S+)',
          ),
          platform: _field(block, r'System\s*Descr(?:iption)?:\s*(.+)'),
          vlan: _field(block, r'(?:Vlan|VLAN|Port VLAN)\s*ID:\s*(\d+)'),
          speedDuplex: duplex,
        ),
      );
    }
    return results
        .where((n) => n.deviceId != null || n.sysName != null)
        .toList();
  }

  static String? _field(String block, String pattern) {
    final match = RegExp(pattern, caseSensitive: false, multiLine: true)
        .firstMatch(block);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String? _duplex(String block) {
    final duplex = _field(block, r'Duplex:\s*(\S+)');
    final speed = _field(block, r'(?:Full|Half)-duplex,\s*(\S+)');
    if (duplex != null && speed != null) {
      return '$speed $duplex';
    }
    return duplex;
  }
}
