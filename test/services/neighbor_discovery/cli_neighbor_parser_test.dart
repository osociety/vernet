import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/cli_neighbor_parser.dart';

void main() {
  test('parses show cdp neighbors detail', () {
    const text = '''
Device ID: AP-FLOOR2.lab.local
Entry address(es):
  IP address: 10.10.10.50
Platform: cisco AIR-AP2802I-B-K9,  Capabilities: Trans-Bridge
Interface: GigabitEthernet1/0/24,  Port ID (outgoing port): GigabitEthernet0
Holdtime : 150 sec
Native VLAN: 20
Duplex: full
''';

    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(1));
    expect(neighbors.first.protocol, NeighborProtocol.cdp);
    expect(neighbors.first.hostname, 'AP-FLOOR2.lab.local');
    expect(neighbors.first.managementIp, '10.10.10.50');
    expect(neighbors.first.localPort, 'GigabitEthernet1/0/24');
    expect(neighbors.first.platform, 'cisco AIR-AP2802I-B-K9');
    expect(neighbors.first.vlan, '20');
    expect(neighbors.first.speedDuplex, 'full');
  });

  test('parses show lldp neighbors detail', () {
    const text = '''
Local Intf: Gi1/0/8
Chassis id: 00:11:22:33:44:55
Port id: eth0
Port Description: uplink
System Name: camera-lobby
System Description: Axis camera
Management Address: 10.20.30.40
VLAN ID: 40
''';

    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(1));
    expect(neighbors.first.protocol, NeighborProtocol.lldp);
    expect(neighbors.first.hostname, 'camera-lobby');
    expect(neighbors.first.localPort, 'Gi1/0/8');
    expect(neighbors.first.managementIp, '10.20.30.40');
  });

  test('parses show lldp neighbors detail with multiline management address', () {
    const text = '''
------------------------------------------------
Local Intf: Gi1/0/12
Chassis id: 00:aa:bb:cc:dd:ee
Port id: eth0
Port Description: Switch Uplink
System Name: switch-access2
System Description: ArubaOS Switch
Management Addresses:
    IP: 192.168.10.2
VLAN ID: 10
Physical media capabilities: 1000baseT(FD)
------------------------------------------------
''';

    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(1));
    expect(neighbors.first.protocol, NeighborProtocol.lldp);
    expect(neighbors.first.hostname, 'switch-access2');
    expect(neighbors.first.localPort, 'Gi1/0/12');
    expect(neighbors.first.managementIp, '192.168.10.2');
    expect(neighbors.first.vlan, '10');
    expect(neighbors.first.speedDuplex, '1000baseT(FD)');
  });

  test('parses multiple CDP neighbors in single output', () {
    const text = '''
-------------------------
Device ID: SWITCH-A
IP address: 10.1.1.1
Interface: GigabitEthernet1/0/1
Port ID (outgoing port): Gi1/0/24
Platform: cisco WS-C3850-24T
Native VLAN: 1
Duplex: full
-------------------------
Device ID: SWITCH-B
IP address: 10.1.1.2
Interface: GigabitEthernet1/0/2
Port ID (outgoing port): Gi1/0/24
Platform: cisco WS-C3850-24T
Native VLAN: 10
Duplex: full
''';

    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(2));
    expect(neighbors[0].hostname, 'SWITCH-A');
    expect(neighbors[0].managementIp, '10.1.1.1');
    expect(neighbors[1].hostname, 'SWITCH-B');
    expect(neighbors[1].managementIp, '10.1.1.2');
  });

  test('parses combined CDP and LLDP output', () {
    const text = '''
Device ID: CISCO-AP
IP address: 10.0.0.5
Interface: GigabitEthernet1/0/5
Port ID (outgoing port): Gig0
Platform: cisco AIR-AP

Local Intf: Gi1/0/6
Chassis id: 00:11:22:33:44:99
Port id: eth1
System Name: LINUX-SRV
Management Address: 10.0.0.6
''';

    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(2));
    expect(neighbors.any((n) => n.hostname == 'CISCO-AP'), isTrue);
    expect(neighbors.any((n) => n.hostname == 'LINUX-SRV'), isTrue);
  });

  test('parses CDP with both speed and duplex', () {
    const text = '''
Device ID: SWITCH-C
IP address: 10.1.1.3
Interface: Gi1/0/3
Platform: cisco
Duplex: full
Full-duplex, 1000Mb/s
''';
    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(1));
    expect(neighbors.first.speedDuplex, '1000Mb/s full');
  });

  test('parses LLDP with Media Attachment Unit type', () {
    const text = '''
Local Intf: Gi1/0/4
Chassis id: 00:11:22:33:44:aa
System Name: SWITCH-D
Media Attachment Unit type: 30
''';
    final neighbors = CliNeighborParser.parse(text);
    expect(neighbors, hasLength(1));
    expect(neighbors.first.speedDuplex, '30');
  });

  test('returns empty list for empty or irrelevant text', () {
    expect(CliNeighborParser.parse(''), isEmpty);
    expect(CliNeighborParser.parse('Random log text with no neighbors'), isEmpty);
  });
}
