import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/cdp_parser.dart';
import 'package:vernet/services/neighbor_discovery/lldp_parser.dart';

void main() {
  test('parses CDP TLVs for hostname, port, platform, VLAN, IP', () {
    final payload = CdpParser.buildTestPayload(
      deviceIdValue: 'ACCESS-SW1',
      port: 'GigabitEthernet1/0/24',
      platformValue: 'cisco WS-C2960X',
      ip: '10.0.0.2',
      vlan: 20,
    );

    final neighbor = CdpParser.parse(payload);
    expect(neighbor, isNotNull);
    expect(neighbor!.protocol, NeighborProtocol.cdp);
    expect(neighbor.hostname, 'ACCESS-SW1');
    expect(neighbor.remotePort, 'GigabitEthernet1/0/24');
    expect(neighbor.platform, 'cisco WS-C2960X');
    expect(neighbor.vlan, '20');
    expect(neighbor.managementIp, '10.0.0.2');
    expect(neighbor.speedDuplex, 'full');
  });

  test('parses CDP after an Ethernet SNAP header', () {
    final cdp = CdpParser.buildTestPayload(
      deviceIdValue: 'SW1',
      port: 'Gi0/1',
      platformValue: 'cisco',
    );
    final frame = <int>[
      0x01, 0x00, 0x0c, 0xcc, 0xcc, 0xcc,
      0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
      0x00, 0x40,
      0xaa, 0xaa, 0x03, 0x00, 0x00, 0x0c, 0x20, 0x00,
      ...cdp,
    ];
    expect(CdpParser.parse(frame)?.hostname, 'SW1');
  });

  test('parses LLDP TLVs including VLAN and gigabit MAU type', () {
    final payload = LldpParser.buildTestPayload(
      sysNameValue: 'dist-sw1',
      port: 'Gi1/0/1',
      platform: 'Juniper EX4300',
      ip: '10.1.1.1',
      vlan: 30,
    );

    final neighbor = LldpParser.parse(payload);
    expect(neighbor, isNotNull);
    expect(neighbor!.protocol, NeighborProtocol.lldp);
    expect(neighbor.hostname, 'dist-sw1');
    expect(neighbor.remotePort, 'Gi1/0/1');
    expect(neighbor.platform, 'Juniper EX4300');
    expect(neighbor.vlan, '30');
    expect(neighbor.managementIp, '10.1.1.1');
    expect(neighbor.speedDuplex, '1 Gbps full');
  });
}
