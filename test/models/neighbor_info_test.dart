import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';

void main() {
  test('hostname prefers sysName then deviceId', () {
    const a = NeighborInfo(protocol: NeighborProtocol.lldp, deviceId: 'aa:bb');
    expect(a.hostname, 'aa:bb');

    const b = NeighborInfo(
      protocol: NeighborProtocol.cdp,
      deviceId: 'id',
      sysName: 'core-sw1',
    );
    expect(b.hostname, 'core-sw1');
  });

  test('hostname falls back to Unknown device when empty', () {
    const c = NeighborInfo(protocol: NeighborProtocol.lldp);
    expect(c.hostname, 'Unknown device');
    const d = NeighborInfo(protocol: NeighborProtocol.cdp, deviceId: '  ', sysName: '');
    expect(d.hostname, 'Unknown device');
  });

  test('switch displayName falls back to IP when sysName is empty', () {
    const unnamed = SwitchIdentity(ip: '10.0.0.1');
    expect(unnamed.displayName, '10.0.0.1');
    const emptyName = SwitchIdentity(ip: '10.0.0.1', sysName: '  ');
    expect(emptyName.displayName, '10.0.0.1');
    const named = SwitchIdentity(ip: '10.0.0.1', sysName: 'core-sw1');
    expect(named.displayName, 'core-sw1');
  });

  test('NeighborInfo copyWith updates specified fields and preserves others', () {
    const original = NeighborInfo(
      protocol: NeighborProtocol.cdp,
      deviceId: 'dev1',
      sysName: 'sys1',
      managementIp: '10.0.0.1',
      localPort: 'Gi1/0/1',
      remotePort: 'Gi0/1',
      platform: 'cisco',
      vlan: '10',
      speedDuplex: 'full',
      capabilities: 'Router',
    );

    final modified = original.copyWith(
      protocol: NeighborProtocol.lldp,
      deviceId: 'dev2',
      sysName: 'sys2',
      managementIp: '10.0.0.2',
      localPort: 'Gi1/0/2',
      remotePort: 'Gi0/2',
      platform: 'juniper',
      vlan: '20',
      speedDuplex: 'half',
      capabilities: 'Bridge',
    );

    expect(modified.protocol, NeighborProtocol.lldp);
    expect(modified.deviceId, 'dev2');
    expect(modified.sysName, 'sys2');
    expect(modified.managementIp, '10.0.0.2');
    expect(modified.localPort, 'Gi1/0/2');
    expect(modified.remotePort, 'Gi0/2');
    expect(modified.platform, 'juniper');
    expect(modified.vlan, '20');
    expect(modified.speedDuplex, 'half');
    expect(modified.capabilities, 'Bridge');

    final preserved = original.copyWith();
    expect(preserved.protocol, original.protocol);
    expect(preserved.deviceId, original.deviceId);
    expect(preserved.sysName, original.sysName);
    expect(preserved.managementIp, original.managementIp);
    expect(preserved.localPort, original.localPort);
    expect(preserved.remotePort, original.remotePort);
    expect(preserved.platform, original.platform);
    expect(preserved.vlan, original.vlan);
    expect(preserved.speedDuplex, original.speedDuplex);
    expect(preserved.capabilities, original.capabilities);
  });

  test('NeighborDiscoveryResult constructor creates valid result with defaults', () {
    const identity = SwitchIdentity(ip: '192.168.1.1');
    const result = NeighborDiscoveryResult(
      switchInfo: identity,
      neighbors: [],
    );
    expect(result.switchInfo.ip, '192.168.1.1');
    expect(result.neighbors, isEmpty);
    expect(result.warnings, isEmpty);
  });
}
