import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_mib_mapper.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

SnmpValue str(String value) => SnmpValue(tag: 0x04, bytes: value.codeUnits);
SnmpValue integer(int value) {
  final bytes = <int>[];
  var remaining = value;
  if (remaining == 0) {
    bytes.add(0);
  }
  while (remaining > 0) {
    bytes.insert(0, remaining & 0xff);
    remaining >>= 8;
  }
  if (bytes.first & 0x80 != 0) {
    bytes.insert(0, 0);
  }
  return SnmpValue(tag: 0x02, bytes: bytes);
}

SnmpValue ip(String address) {
  return SnmpValue(
    tag: 0x04,
    bytes: address.split('.').map(int.parse).toList(),
  );
}

void main() {
  test('maps Cisco CDP cache plus IF-MIB names and speed', () {
    const cachePrefix = NeighborMibs.cdpCache;
    final neighbors = NeighborMibMapper.mapCdp(
      cache: {
        '$cachePrefix.4.24.1': ip('10.0.0.50'),
        '$cachePrefix.6.24.1': str('ap-floor2'),
        '$cachePrefix.7.24.1': str('GigabitEthernet0'),
        '$cachePrefix.8.24.1': str('cisco AIR-AP2802'),
        '$cachePrefix.11.24.1': integer(20),
        '$cachePrefix.12.24.1': integer(3),
        '$cachePrefix.17.24.1': str('AP-FLOOR2'),
      },
      ifNames: {'${NeighborMibs.ifName}.24': str('Gi1/0/24')},
      ifSpeeds: {'${NeighborMibs.ifHighSpeed}.24': integer(1000)},
    );

    expect(neighbors, hasLength(1));
    expect(neighbors.first.protocol, NeighborProtocol.cdp);
    expect(neighbors.first.hostname, 'AP-FLOOR2');
    expect(neighbors.first.managementIp, '10.0.0.50');
    expect(neighbors.first.localPort, 'Gi1/0/24');
    expect(neighbors.first.remotePort, 'GigabitEthernet0');
    expect(neighbors.first.platform, 'cisco AIR-AP2802');
    expect(neighbors.first.vlan, '20');
    expect(neighbors.first.speedDuplex, '1 Gbps full');
  });

  test('maps LLDP remote table to switch port and management IP', () {
    const rem = NeighborMibs.lldpRem;
    final neighbors = NeighborMibMapper.mapLldp(
      rem: {
        '$rem.5.0.8.1': str('00:11:22:33:44:55'),
        '$rem.7.0.8.1': str('eth0'),
        '$rem.8.0.8.1': str('eth0'),
        '$rem.9.0.8.1': str('camera-lobby'),
        '$rem.10.0.8.1': str('Axis P3245'),
      },
      manAddr: {
        '${NeighborMibs.lldpRemManAddr}.3.0.8.1.1.10.20.30.40': integer(0),
      },
      locPortId: {'${NeighborMibs.lldpLocPortId}.8': str('Gi1/0/8')},
      locPortDesc: {'${NeighborMibs.lldpLocPortDesc}.8': str('GigabitEthernet1/0/8')},
      vlans: {'${NeighborMibs.lldpXdot1RemVlan}.0.8.1': integer(40)},
      ifSpeeds: {'${NeighborMibs.ifHighSpeed}.8': integer(1000)},
    );

    expect(neighbors, hasLength(1));
    expect(neighbors.first.protocol, NeighborProtocol.lldp);
    expect(neighbors.first.hostname, 'camera-lobby');
    expect(neighbors.first.managementIp, '10.20.30.40');
    expect(neighbors.first.localPort, 'GigabitEthernet1/0/8');
    expect(neighbors.first.platform, 'Axis P3245');
    expect(neighbors.first.vlan, '40');
    expect(neighbors.first.speedDuplex, '1 Gbps');
  });

  test('maps CDP capabilities, mgmt address, half duplex, and ifIndex fallback', () {
    const cachePrefix = NeighborMibs.cdpCache;
    final neighbors = NeighborMibMapper.mapCdp(
      cache: {
        '$cachePrefix.4.10.1': str('unformatted-ip'),
        '$cachePrefix.6.10.1': str('router-1'),
        '$cachePrefix.9.10.1': integer(0x09), // Router + Switch
        '$cachePrefix.12.10.1': integer(2), // half duplex
        '$cachePrefix.20.10.1': ip('10.0.0.99'), // management address
      },
      ifNames: {}, // no ifName mapped -> should fall back to ifIndex 10
      ifSpeeds: {'${NeighborMibs.ifHighSpeed}.10': integer(100)}, // 100 Mbps
    );

    expect(neighbors, hasLength(1));
    expect(neighbors.first.localPort, 'ifIndex 10');
    expect(neighbors.first.managementIp, '10.0.0.99');
    expect(neighbors.first.speedDuplex, '100 Mbps half');
    expect(neighbors.first.capabilities, 'Router, Switch');
  });

  test('maps LLDP port fallbacks when desc or names are missing', () {
    const rem = NeighborMibs.lldpRem;
    final neighbors = NeighborMibMapper.mapLldp(
      rem: {
        '$rem.5.0.3.1': str('00:aa:bb:cc:dd:ee'),
        '$rem.7.0.3.1': str('eth0'),
      },
      manAddr: {},
      locPortId: {'${NeighborMibs.lldpLocPortId}.3': str('Gi0/3')},
      locPortDesc: {}, // missing desc -> fallback to locPortId
      vlans: {},
      ifSpeeds: {},
    );

    expect(neighbors, hasLength(1));
    expect(neighbors.first.localPort, 'Gi0/3');
    expect(neighbors.first.remotePort, 'eth0');

    // And fallback to port number when locPortId is also missing:
    final neighborsPortNumFallback = NeighborMibMapper.mapLldp(
      rem: {
        '$rem.5.0.4.1': str('00:aa:bb:cc:dd:ff'),
      },
      manAddr: {},
      locPortId: {},
      locPortDesc: {},
      vlans: {},
      ifSpeeds: {},
    );
    expect(neighborsPortNumFallback.first.localPort, 'port 4');
  });
}
