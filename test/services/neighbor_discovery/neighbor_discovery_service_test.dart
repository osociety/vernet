import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_discovery_service.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_mib_mapper.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

class FakeSnmpClient implements SnmpClient {
  FakeSnmpClient(this.scalars, this.tables);

  final Map<String, SnmpValue> scalars;
  final Map<String, Map<String, SnmpValue>> tables;
  int getCalls = 0;
  int walkCalls = 0;

  @override
  Future<SnmpValue?> get(
    String host,
    String community,
    String oid, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    getCalls++;
    return scalars[oid];
  }

  @override
  Future<Map<String, SnmpValue>> walk(
    String host,
    String community,
    String oid, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    walkCalls++;
    return tables[oid] ?? {};
  }
}

SnmpValue str(String value) => SnmpValue(tag: 0x04, bytes: value.codeUnits);

void main() {
  test('discover combines switch identity with CDP neighbors', () async {
    final client = FakeSnmpClient(
      {
        NeighborMibs.sysName: str('core-sw1'),
        NeighborMibs.sysDescr: str('Cisco IOS-XE Software'),
      },
      {
        NeighborMibs.ifName: {'${NeighborMibs.ifName}.24': str('Gi1/0/24')},
        NeighborMibs.ifHighSpeed: {},
        NeighborMibs.cdpCache: {
          '${NeighborMibs.cdpCache}.6.24.1': str('ap-floor2'),
          '${NeighborMibs.cdpCache}.7.24.1': str('Gi0'),
          '${NeighborMibs.cdpCache}.8.24.1': str('cisco AIR-AP2802'),
        },
        NeighborMibs.lldpRem: {},
        NeighborMibs.lldpRemManAddr: {},
        NeighborMibs.lldpLocPortId: {},
        NeighborMibs.lldpLocPortDesc: {},
        NeighborMibs.lldpXdot1RemVlan: {},
      },
    );

    final result = await NeighborDiscoveryService(client: client).discover(
      switchIp: '192.168.1.1',
      community: 'public',
    );

    expect(result.switchInfo.displayName, 'core-sw1');
    expect(result.neighbors, hasLength(1));
    expect(result.neighbors.first.hostname, 'ap-floor2');
    expect(result.neighbors.first.localPort, 'Gi1/0/24');
  });

  test('discover rejects an empty switch address', () {
    expect(
      () => NeighborDiscoveryService(client: FakeSnmpClient({}, {})).discover(
        switchIp: '  ',
        community: 'public',
      ),
      throwsA(isA<NeighborDiscoveryException>()),
    );
  });

  test('parseCli uses the CLI parser', () {
    const text = '''
Device ID: leaf-1
IP address: 10.0.0.9
Interface: GigabitEthernet1/0/1
Port ID (outgoing port): eth0
Platform: arista
''';
    final neighbors = NeighborDiscoveryService(client: FakeSnmpClient({}, {})).parseCli(text);
    expect(neighbors.first.protocol, NeighborProtocol.cdp);
    expect(neighbors.first.hostname, 'leaf-1');
  });
}
