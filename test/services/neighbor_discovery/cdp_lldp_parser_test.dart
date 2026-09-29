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

  test('parses CDP with capabilities, half duplex, and version fallback for platform', () {
    List<int> tlv(int type, List<int> val) {
      final len = val.length + 4;
      return [(type >> 8) & 0xff, type & 0xff, (len >> 8) & 0xff, len & 0xff, ...val];
    }

    final tlvVersion = tlv(0x0005, 'Cisco IOS Software\nVersion 15.0'.codeUnits);
    final tlvCaps = tlv(0x0004, [0x00, 0x00, 0x00, 0x19]); // Router (0x01), Switch (0x08), Host (0x10)
    final tlvDevice = tlv(0x0001, 'SW-CAP'.codeUnits);
    final tlvDuplex = tlv(0x000b, [0x00]); // half duplex

    final payload = <int>[2, 180, 0, 0, ...tlvDevice, ...tlvVersion, ...tlvCaps, ...tlvDuplex];
    final neighbor = CdpParser.parse(payload);
    expect(neighbor, isNotNull);
    expect(neighbor!.hostname, 'SW-CAP');
    expect(neighbor.platform, 'Cisco IOS Software');
    expect(neighbor.capabilities, contains('Router'));
    expect(neighbor.capabilities, contains('Switch'));
    expect(neighbor.capabilities, contains('Host'));
    expect(neighbor.speedDuplex, 'half');
  });

  test('parses CDP with 802.1Q VLAN tagged frame', () {
    final cdp = CdpParser.buildTestPayload(
      deviceIdValue: 'SW-VLAN',
      port: 'Gi0/1',
      platformValue: 'cisco',
    );
    final frame = <int>[
      0x01, 0x00, 0x0c, 0xcc, 0xcc, 0xcc, // dst
      0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, // src
      0x81, 0x00, 0x00, 0x0a, // 802.1Q tag (vlan 10)
      0x00, 0x40, // length
      0xaa, 0xaa, 0x03, 0x00, 0x00, 0x0c, 0x20, 0x00, // SNAP
      ...cdp,
    ];
    expect(CdpParser.parse(frame)?.hostname, 'SW-VLAN');
  });

  test('CDP parser returns null for invalid or empty payload', () {
    expect(CdpParser.parse([]), isNull);
    expect(CdpParser.parse([1, 2, 3]), isNull);
    expect(CdpParser.parse([2, 180, 0, 0]), isNull);
  });

  test('parses LLDP Ethernet frame with 802.1Q tag and EtherType 0x88cc', () {
    final lldp = LldpParser.buildTestPayload(
      sysNameValue: 'tagged-switch',
      port: 'eth0',
      platform: 'Arista',
    );
    final frame = <int>[
      0x01, 0x80, 0xc2, 0x00, 0x00, 0x0e, // dst
      0x00, 0x11, 0x22, 0x33, 0x44, 0x55, // src
      0x81, 0x00, 0x00, 0x05, // 802.1Q
      0x88, 0xcc, // LLDP ethertype
      ...lldp,
    ];
    final neighbor = LldpParser.parse(frame);
    expect(neighbor, isNotNull);
    expect(neighbor!.hostname, 'tagged-switch');
  });

  test('parses LLDP capabilities and various MAU types', () {
    final mauTypes = {
      10: '10 Mbps half',
      11: '10 Mbps full',
      15: '100 Mbps half',
      16: '100 Mbps full',
      30: '1 Gbps full',
      39: '10 Gbps full',
      99: 'MAU 99',
    };

    for (final entry in mauTypes.entries) {
      final chassisTlv = [(1 << 1) | 0, 7, 4, 1, 2, 3, 4, 5, 6];
      final portTlv = [(2 << 1) | 0, 5, 5, ...'eth0'.codeUnits];
      final mauTlv = [
        ((127 << 1) | 0), 9,
        0x00, 0x12, 0x0f, 0x01, 0x00, 0x00, 0x00, 0x00, entry.key,
      ];
      final capsTlv = [
        ((7 << 1) | 0), 4,
        0x00, 0x14, 0x00, 0x14, // Bridge (0x04) + Router (0x10)
      ];
      final nameTlv = [
        ((5 << 1) | 0), 3,
        ...'MAU'.codeUnits,
      ];
      final endTlv = [0x00, 0x00];

      final payload = <int>[...chassisTlv, ...portTlv, ...nameTlv, ...capsTlv, ...mauTlv, ...endTlv];
      final neighbor = LldpParser.parse(payload);
      expect(neighbor, isNotNull);
      expect(neighbor!.speedDuplex, entry.value);
      expect(neighbor.capabilities, contains('Bridge'));
      expect(neighbor.capabilities, contains('Router'));
    }
  });

  test('LLDP parser returns null for invalid or empty payload', () {
    expect(LldpParser.parse([]), isNull);
    expect(LldpParser.parse([0x00, 0x00]), isNull);
  });
}
