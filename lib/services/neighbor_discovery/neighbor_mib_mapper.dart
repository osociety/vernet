import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

class NeighborMibs {
  static const sysDescr = '1.3.6.1.2.1.1.1.0';
  static const sysName = '1.3.6.1.2.1.1.5.0';
  static const ifName = '1.3.6.1.2.1.31.1.1.1.1';
  static const ifHighSpeed = '1.3.6.1.2.1.31.1.1.1.15';
  static const cdpCache = '1.3.6.1.4.1.9.9.23.1.2.1.1';
  static const lldpRem = '1.0.8802.1.1.2.1.4.1.1';
  static const lldpRemManAddr = '1.0.8802.1.1.2.1.4.2.1';
  static const lldpLocPortId = '1.0.8802.1.1.2.1.3.7.1.3';
  static const lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4';
  static const lldpXdot1RemVlan = '1.0.8802.1.1.2.1.5.32962.1.5.1.1.4';
}

class NeighborMibMapper {
  static List<NeighborInfo> mapCdp({
    required Map<String, SnmpValue> cache,
    required Map<String, SnmpValue> ifNames,
    required Map<String, SnmpValue> ifSpeeds,
  }) {
    final rows = <String, _CdpRow>{};
    for (final entry in cache.entries) {
      final parsed = _suffixAfter(entry.key, NeighborMibs.cdpCache);
      if (parsed == null || parsed.length < 3) {
        continue;
      }
      final column = int.tryParse(parsed[0]);
      if (column == null) {
        continue;
      }
      final key = parsed.sublist(1).join('.');
      final row = rows.putIfAbsent(key, _CdpRow.new);
      row.ifIndex = parsed[1];
      switch (column) {
        case 4:
          row.address = entry.value.asIp ?? entry.value.asString;
        case 6:
          row.deviceId = entry.value.asString;
        case 7:
          row.port = entry.value.asString;
        case 8:
          row.platform = entry.value.asString;
        case 9:
          row.capabilities = _cdpCaps(entry.value.asInt);
        case 11:
          row.vlan = entry.value.asString;
        case 12:
          row.duplex = _cdpDuplex(entry.value.asInt);
        case 17:
          row.sysName = entry.value.asString;
        case 20:
          row.mgmt = entry.value.asIp ?? entry.value.asString;
      }
    }

    return rows.values.map((row) {
      final local = _ifName(ifNames, row.ifIndex);
      final speed = _speed(ifSpeeds, row.ifIndex);
      final duplex = row.duplex;
      String? speedDuplex;
      if (speed != null && duplex != null) {
        speedDuplex = '$speed $duplex';
      } else {
        speedDuplex = speed ?? duplex;
      }
      return NeighborInfo(
        protocol: NeighborProtocol.cdp,
        deviceId: row.deviceId,
        sysName: row.sysName ?? row.deviceId,
        managementIp: _preferIp(row.mgmt, row.address),
        localPort: local ?? (row.ifIndex == null ? null : 'ifIndex ${row.ifIndex}'),
        remotePort: row.port,
        platform: row.platform,
        vlan: row.vlan,
        speedDuplex: speedDuplex,
        capabilities: row.capabilities,
      );
    }).toList();
  }

  static List<NeighborInfo> mapLldp({
    required Map<String, SnmpValue> rem,
    required Map<String, SnmpValue> manAddr,
    required Map<String, SnmpValue> locPortId,
    required Map<String, SnmpValue> locPortDesc,
    required Map<String, SnmpValue> vlans,
    required Map<String, SnmpValue> ifSpeeds,
  }) {
    final rows = <String, _LldpRow>{};
    for (final entry in rem.entries) {
      final parsed = _suffixAfter(entry.key, NeighborMibs.lldpRem);
      if (parsed == null || parsed.length < 4) {
        continue;
      }
      final column = int.tryParse(parsed[0]);
      if (column == null) {
        continue;
      }
      final key = parsed.sublist(1).join('.');
      final row = rows.putIfAbsent(key, _LldpRow.new);
      row.localPortNum = parsed[2];
      switch (column) {
        case 5:
          row.chassis = entry.value.asString;
        case 7:
          row.portId = entry.value.asString;
        case 8:
          row.portDesc = entry.value.asString;
        case 9:
          row.sysName = entry.value.asString;
        case 10:
          row.sysDesc = entry.value.asString;
      }
    }

    for (final entry in manAddr.entries) {
      final parsed = _suffixAfter(entry.key, NeighborMibs.lldpRemManAddr);
      if (parsed == null || parsed.length < 6) {
        continue;
      }
      final key = parsed.sublist(1, 4).join('.');
      final row = rows[key];
      if (row == null) {
        continue;
      }
      final addrParts = parsed.sublist(5);
      if (addrParts.length == 4) {
        row.mgmt = addrParts.join('.');
      }
    }

    for (final entry in vlans.entries) {
      final parsed = _suffixAfter(entry.key, NeighborMibs.lldpXdot1RemVlan);
      if (parsed == null || parsed.length < 3) {
        continue;
      }
      final key = parsed.join('.');
      final row = rows[key];
      row?.vlan = entry.value.asString;
    }

    return rows.values.map((row) {
      final local = locPortDesc['${NeighborMibs.lldpLocPortDesc}.${row.localPortNum}']
              ?.asString ??
          locPortId['${NeighborMibs.lldpLocPortId}.${row.localPortNum}']?.asString ??
          (row.localPortNum == null ? null : 'port ${row.localPortNum}');
      return NeighborInfo(
        protocol: NeighborProtocol.lldp,
        deviceId: row.chassis,
        sysName: row.sysName ?? row.chassis,
        managementIp: row.mgmt,
        localPort: local,
        remotePort: (row.portDesc?.isNotEmpty ?? false) ? row.portDesc : row.portId,
        platform: row.sysDesc?.split('\n').first.trim(),
        vlan: row.vlan,
        speedDuplex: _speed(ifSpeeds, row.localPortNum),
      );
    }).toList();
  }

  static List<String>? _suffixAfter(String oid, String prefix) {
    if (oid == prefix) {
      return const [];
    }
    if (!oid.startsWith('$prefix.')) {
      return null;
    }
    return oid.substring(prefix.length + 1).split('.');
  }

  static String? _ifName(Map<String, SnmpValue> ifNames, String? ifIndex) {
    if (ifIndex == null) {
      return null;
    }
    return ifNames['${NeighborMibs.ifName}.$ifIndex']?.asString;
  }

  static String? _speed(Map<String, SnmpValue> speeds, String? ifIndex) {
    if (ifIndex == null) {
      return null;
    }
    final mbps = speeds['${NeighborMibs.ifHighSpeed}.$ifIndex']?.asInt;
    if (mbps == null || mbps == 0) {
      return null;
    }
    if (mbps >= 1000 && mbps % 1000 == 0) {
      return '${mbps ~/ 1000} Gbps';
    }
    return '$mbps Mbps';
  }

  static String? _cdpDuplex(int? value) {
    return switch (value) {
      2 => 'half',
      3 => 'full',
      _ => null,
    };
  }

  static String? _cdpCaps(int? bits) {
    if (bits == null) {
      return null;
    }
    const labels = {
      0x01: 'Router',
      0x08: 'Switch',
      0x10: 'Host',
      0x80: 'Phone',
    };
    final found = <String>[];
    for (final entry in labels.entries) {
      if (bits & entry.key != 0) {
        found.add(entry.value);
      }
    }
    return found.isEmpty ? null : found.join(', ');
  }

  static String? _preferIp(String? a, String? b) {
    if (a != null && RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(a)) {
      return a;
    }
    if (b != null && RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(b)) {
      return b;
    }
    return a ?? b;
  }
}

class _CdpRow {
  String? ifIndex;
  String? address;
  String? deviceId;
  String? port;
  String? platform;
  String? capabilities;
  String? vlan;
  String? duplex;
  String? sysName;
  String? mgmt;
}

class _LldpRow {
  String? localPortNum;
  String? chassis;
  String? portId;
  String? portDesc;
  String? sysName;
  String? sysDesc;
  String? mgmt;
  String? vlan;
}
